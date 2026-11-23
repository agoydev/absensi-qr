const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { after, before, test } = require('node:test');

process.env.AUTH_SECRET ||= 'test-only-secret-that-is-never-used-outside-tests';

const { app, setPoolForTests } = require('./server');
const testSalt = 'backend-schema-test-salt';
const testPasswordHash =
  `scrypt$${testSalt}$${crypto.scryptSync('teacher-secret', testSalt, 64).toString('hex')}`;
const adminPasswordHash =
  `scrypt$${testSalt}$${crypto.scryptSync('admin123', testSalt, 64).toString('hex')}`;

const executedQueries = [];
const pool = {
  async query(sql, params = []) {
    executedQueries.push({ sql, params });
    if (sql.includes('SELECT id FROM classes WHERE name')) {
      return { rows: [{ id: 4 }], rowCount: 1 };
    }
    if (sql.includes('FROM users u')) {
      const isAdmin = params[0] === 'admin';
      return {
        rows: [{
          id: isAdmin ? 2 : 9,
          name: isAdmin ? 'Administrator' : 'Guru Uji',
          username: isAdmin ? 'admin' : 'guru.uji',
          password_hash: isAdmin ? adminPasswordHash : testPasswordHash,
          role: isAdmin ? 'admin' : 'teacher',
          teacher_id: null,
        }],
        rowCount: 1,
      };
    }
    if (sql.includes('FROM students s')) {
      return {
        rows: [{
          id: 73,
          name: 'Siswa Uji',
          nis: 'TEST-001',
          class_name: 'X RPL 1',
          qr_code: 'QR-TEST-001',
          parent_name: '',
          parent_phone: '',
        }],
        rowCount: 1,
      };
    }
    return { rows: [], rowCount: 1 };
  },
  async connect() {
    return {
      async query(sql, params = []) {
        executedQueries.push({ sql, params });
        if (sql.includes('INSERT INTO students')) {
          return { rows: [{ id: 73 }], rowCount: 1 };
        }
        return { rows: [], rowCount: 1 };
      },
      release() {},
    };
  },
};

let server;
let baseUrl;

before(async () => {
  setPoolForTests(pool);
  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
});

test('GET /students maps the normalized Supabase relations to the Flutter API shape', async () => {
  executedQueries.length = 0;
  const response = await fetch(`${baseUrl}/students`);
  const students = await response.json();

  assert.equal(response.status, 200);
  assert.equal(students[0].class_name, 'X RPL 1');
  assert.equal(students[0].qr_code, 'QR-TEST-001');
  assert.match(executedQueries[0].sql, /LEFT JOIN classes c ON c\.id = s\.class_id/);
  assert.match(executedQueries[0].sql, /''::text AS parent_name/);
  assert.doesNotMatch(executedQueries[0].sql, /student_parents|orang_tua/);
  assert.match(executedQueries[0].sql, /s\.student_number AS qr_code/);
  assert.doesNotMatch(executedQueries[0].sql, /FROM qr_codes/);
});

test('POST /auth/login does not depend on an optional teacher profile table', async () => {
  executedQueries.length = 0;
  const response = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'guru.uji', password: 'teacher-secret' }),
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.user.role, 'teacher');
  assert.ok(payload.token);
  assert.match(executedQueries[0].sql, /FROM users u/);
  assert.doesNotMatch(executedQueries[0].sql, /guru/);
});

test('POST /auth/login accepts the configured admin account', async () => {
  const response = await fetch(`${baseUrl}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' }),
  });
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(payload.user.username, 'admin');
  assert.equal(payload.user.role, 'admin');
  assert.ok(payload.token);
});

test('POST /students maps Flutter fields to the deployed students table', async () => {
  executedQueries.length = 0;
  const response = await fetch(`${baseUrl}/students`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'Siswa Uji',
      nis: 'TEST-001',
      class_name: 'X RPL 1',
      qr_code: 'TEST-001',
    }),
  });
  const payload = await response.json();

  assert.equal(response.status, 201);
  assert.equal(payload.id, 73);
  assert.ok(executedQueries.some(({ sql }) =>
    sql.includes('(full_name, student_number, class_id, status)'),
  ));
  assert.ok(executedQueries.some(({ sql }) => sql === 'COMMIT'));
});

test('POST /students explains when guardian fields are unsupported by the live schema', async () => {
  const response = await fetch(`${baseUrl}/students`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: 'Siswa Uji',
      nis: 'TEST-002',
      class_name: 'X RPL 1',
      qr_code: 'TEST-002',
      parent_name: 'Wali Uji',
      parent_phone: '628123456789',
    }),
  });
  const payload = await response.json();

  assert.equal(response.status, 400);
  assert.match(payload.message, /no guardian table/);
});
