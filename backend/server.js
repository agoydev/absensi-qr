require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { createDatabasePool } = require('./database');
const crypto = require('crypto');

const app = express();

app.use(cors());
app.use(express.json());

let pool;

function toPostgresPlaceholders(sql) {
  let index = 0;
  return sql.replace(/\?/g, () => `$${++index}`);
}

async function query(sql, params = []) {
  return pool.query(toPostgresPlaceholders(sql), params);
}

async function queryRows(sql, params = []) {
  const result = await query(sql, params);
  return result.rows;
}

async function transaction(callback) {
  const client = await pool.connect();
  const run = (sql, params = []) =>
    client.query(toPostgresPlaceholders(sql), params);

  try {
    await client.query('BEGIN');
    const result = await callback(run);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

function isUniqueViolation(error) {
  return error.code === '23505';
}

const authSecret = process.env.AUTH_SECRET;
if (!authSecret || authSecret.length < 32) {
  throw new Error('AUTH_SECRET must be configured with at least 32 characters');
}

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function signToken(payload) {
  const encodedPayload = base64Url(JSON.stringify(payload));
  const signature = crypto
    .createHmac('sha256', authSecret)
    .update(encodedPayload)
    .digest('base64url');
  return `${encodedPayload}.${signature}`;
}

function verifyToken(token) {
  const [encodedPayload, signature] = String(token || '').split('.');
  if (!encodedPayload || !signature) return null;

  const expected = crypto
    .createHmac('sha256', authSecret)
    .update(encodedPayload)
    .digest();
  const received = Buffer.from(signature, 'base64url');
  if (received.length !== expected.length ||
      !crypto.timingSafeEqual(received, expected)) {
    return null;
  }

  try {
    const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString());
    return payload.exp > Math.floor(Date.now() / 1000) ? payload : null;
  } catch (_) {
    return null;
  }
}

function verifyPassword(password, storedHash) {
  const [algorithm, salt, expectedHex] = String(storedHash || '').split('$');
  if (algorithm !== 'scrypt' || !salt || !expectedHex) return false;
  const actual = crypto.scryptSync(password, salt, 64);
  const expected = Buffer.from(expectedHex, 'hex');
  return expected.length === actual.length && crypto.timingSafeEqual(actual, expected);
}

function requireAuth(req, res, next) {
  const authorization = req.get('authorization') || '';
  const token = authorization.startsWith('Bearer ')
    ? authorization.slice('Bearer '.length)
    : '';
  const user = verifyToken(token);
  if (!user) {
    return res.status(401).json({ message: 'authentication required' });
  }
  req.authUser = user;
  next();
}

function requireAdmin(req, res, next) {
  if (req.authUser.role !== 'admin') {
    return res.status(403).json({ message: 'admin role required' });
  }
  next();
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

function normalizeTime(value) {
  if (!value || value === '-') {
    return '00:00:00';
  }

  const text = String(value).trim();
  if (/^\d{1,2}:\d{2}$/.test(text)) {
    const [hour, minute] = text.split(':');
    return `${hour.padStart(2, '0')}:${minute}:00`;
  }
  if (/^\d{1,2}:\d{2}:\d{2}$/.test(text)) {
    const [hour, minute, second] = text.split(':');
    return `${hour.padStart(2, '0')}:${minute}:${second}`;
  }
  return '00:00:00';
}

function isValidTime(value) {
  return typeof value === 'string' &&
    /^([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$/.test(value.trim());
}

function normalizeDate(value) {
  const text = String(value || '').trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function todayInJakarta() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

const studentSelect = `
  SELECT s.id, s.full_name AS name, s.student_number AS nis,
         COALESCE(c.name, '') AS class_name,
         s.student_number AS qr_code,
         ''::text AS parent_name,
         ''::text AS parent_phone
  FROM students s
  LEFT JOIN classes c ON c.id = s.class_id
`;

async function findClassId(className) {
  const rows = await queryRows(
    'SELECT id FROM classes WHERE name = ? AND is_active = TRUE ORDER BY id LIMIT 1',
    [className],
  );
  return rows[0]?.id ?? null;
}

function buildAttendanceMessage({ studentName, date, time, status }) {
  return [
    'Informasi Absensi Siswa',
    `Nama: ${studentName}`,
    `Tanggal: ${date}`,
    `Waktu: ${time}`,
    `Status: ${status}`,
  ].join('\n');
}

async function createWhatsAppNotification({
  attendanceId,
  studentId,
  studentName,
  date,
  time,
  status,
}) {
  const students = await queryRows(
    `SELECT p.id AS parent_id, p.no_hp
     FROM students s
     JOIN student_parents sp ON sp.student_id = s.id AND sp.is_primary = TRUE
     JOIN orang_tua p ON p.id = sp.parent_id
     WHERE s.id = ? LIMIT 1`,
    [studentId],
  );
  const parentPhone = String(students[0]?.no_hp || '').trim();
  if (!parentPhone) {
    return { status: 'failed', reason: 'parent WhatsApp number is not configured' };
  }

  const message = buildAttendanceMessage({ studentName, date, time, status });
  const result = await query(
    `INSERT INTO whatsapp_notifications
       (attendance_id, student_id, parent_id, parent_phone, message, status)
     VALUES (?, ?, ?, ?, ?, 'pending')
     RETURNING id`,
    [attendanceId, studentId, students[0].parent_id, parentPhone, message],
  );
  const notificationId = result.rows[0].id;
  const webhookUrl = String(process.env.WHATSAPP_WEBHOOK_URL || '').trim();
  if (!webhookUrl) {
    await query(
      `UPDATE whatsapp_notifications
       SET status = 'failed', error_message = ?
       WHERE id = ?`,
      ['WHATSAPP_WEBHOOK_URL is not configured', notificationId],
    );
    return { status: 'failed', reason: 'WhatsApp provider is not configured' };
  }

  try {
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(process.env.WHATSAPP_API_TOKEN
          ? { Authorization: `Bearer ${process.env.WHATSAPP_API_TOKEN}` }
          : {}),
      },
      body: JSON.stringify({
        to: parentPhone,
        message,
        attendance_id: attendanceId,
      }),
    });
    const responseBody = await response.text();
    if (!response.ok) {
      throw new Error(`provider returned ${response.status}: ${responseBody.slice(0, 300)}`);
    }

    let providerMessageId = null;
    try {
      providerMessageId = JSON.parse(responseBody).message_id || null;
    } catch (_) {
      providerMessageId = null;
    }
    await query(
      `UPDATE whatsapp_notifications
       SET status = 'sent', provider_message_id = ?, sent_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
      [providerMessageId, notificationId],
    );
    return { status: 'sent', notificationId };
  } catch (error) {
    await query(
      `UPDATE whatsapp_notifications
       SET status = 'failed', error_message = ?
       WHERE id = ?`,
      [String(error.message).slice(0, 500), notificationId],
    );
    return { status: 'failed', notificationId, reason: error.message };
  }
}

async function ensureSessionsForDate(date) {
  const weekday = new Date(`${date}T00:00:00Z`).getUTCDay();
  const dayOfWeek = weekday === 0 ? 7 : weekday;
  const schedules = await queryRows(
    `SELECT id, start_time, end_time, late_after_minutes
     FROM schedules
     WHERE day_of_week = ? AND is_active = TRUE`,
    [dayOfWeek],
  );

  for (const schedule of schedules) {
    await query(
      `INSERT INTO sessions
       (schedule_id, session_date, meeting_number, start_at, end_at,
        attendance_deadline, status)
       SELECT ?, ?, COALESCE(MAX(meeting_number), 0) + 1,
              (?::date + ?::time) AT TIME ZONE 'Asia/Jakarta',
              (?::date + ?::time) AT TIME ZONE 'Asia/Jakarta',
              (?::date + ?::time) AT TIME ZONE 'Asia/Jakarta',
              'scheduled'
       FROM sessions
       WHERE schedule_id = ?
       ON CONFLICT (schedule_id, session_date) DO NOTHING`,
      [
        schedule.id,
        date,
        date,
        schedule.start_time,
        date,
        schedule.end_time,
        date,
        schedule.end_time,
        schedule.id,
      ],
    );
  }
}

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.post('/auth/login', async (req, res) => {
  try {
    const username = String(req.body.username || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    if (!username || !password) {
      return res.status(400).json({ message: 'username and password are required' });
    }

    const rows = await queryRows(
      `SELECT u.id, u.name, u.username, u.password_hash, u.role,
              NULL::bigint AS teacher_id
       FROM users u
       WHERE u.username = ? AND u.is_active = TRUE LIMIT 1`,
      [username],
    );
    const user = rows[0];
    if (!user || !verifyPassword(password, user.password_hash)) {
      return res.status(401).json({ message: 'invalid credentials' });
    }

    const token = signToken({
      sub: user.id,
      teacherId: user.teacher_id ?? null,
      username: user.username,
      role: user.role,
      exp: Math.floor(Date.now() / 1000) + 60 * 60 * 8,
    });

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        username: user.username,
        role: user.role,
      },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/auth/register', async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const username = String(req.body.username || '').trim().toLowerCase();
    const password = String(req.body.password || '');

    if (!name || !username || !password) {
      return res.status(400).json({
        message: 'name, username, and password are required',
      });
    }
    if (password.length < 8) {
      return res.status(400).json({
        message: 'password must be at least 8 characters',
      });
    }

    const userId = await transaction(async (run) => {
      const result = await run(
        `INSERT INTO users (name, username, password_hash, role)
         VALUES (?, ?, ?, 'teacher')
         RETURNING id`,
        [name, username, hashPassword(password)],
      );
      await run(
        'INSERT INTO guru (user_id, nama) VALUES (?, ?)',
        [result.rows[0].id, name],
      );
      return result.rows[0].id;
    });
    res.status(201).json({ id: userId, username, role: 'teacher' });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ message: 'username already exists' });
    }
    res.status(500).json({ message: error.message });
  }
});

app.post('/users', requireAuth, requireAdmin, async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const username = String(req.body.username || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const role = String(req.body.role || '').trim().toLowerCase();

    if (!name || !username || !password || !['admin', 'teacher'].includes(role)) {
      return res.status(400).json({
        message: 'name, username, password, and valid role are required',
      });

    }
    if (password.length < 8) {
      return res.status(400).json({ message: 'password must be at least 8 characters' });
    }

    const userId = await transaction(async (run) => {
      const result = await run(
        `INSERT INTO users (name, username, password_hash, role)
         VALUES (?, ?, ?, ?)
         RETURNING id`,
        [name, username, hashPassword(password), role],
      );
      if (role === 'teacher') {
        await run(
          'INSERT INTO guru (user_id, nama) VALUES (?, ?)',
          [result.rows[0].id, name],
        );
      }
      return result.rows[0].id;
    });
    res.status(201).json({ id: userId, username, role });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ message: 'username already exists' });
    }
    res.status(500).json({ message: error.message });
  }
});

app.get('/users', requireAuth, requireAdmin, async (req, res) => {
  try {
    const rows = await queryRows(
      `SELECT id, name, username, role, is_active, created_at
       FROM users
       ORDER BY created_at DESC, name ASC`,
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/students', async (req, res) => {
  try {
    const rows = await queryRows(
      `${studentSelect}
       WHERE s.status = 'aktif'
       ORDER BY s.full_name ASC`,
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/classes', async (req, res) => {
  try {
    const rows = await queryRows(
      `SELECT c.id, c.name, c.grade_level, c.major,
              COALESCE(ay.name, '') AS school_year, c.is_active
       FROM classes c
       LEFT JOIN academic_years ay ON ay.id = c.academic_year_id
       WHERE c.is_active = TRUE
       ORDER BY c.name ASC`,
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/classes', async (req, res) => {
  try {
    const { name, grade_level, major, school_year } = req.body;
    if (!name || !grade_level || !major || !school_year) {
      return res.status(400).json({ message: 'class fields are required' });
    }
    const result = await query(
      `INSERT INTO classes (name, grade_level, major, academic_year_id)
       SELECT ?, ?, ?, ay.id
       FROM academic_years ay
       WHERE ay.name = ?
       RETURNING id`,
      [name, grade_level, major, school_year],
    );
    if (!result.rows.length) {
      const academicYear = await queryRows(
        `SELECT ay.id, c.id AS class_id,
                EXISTS (
                  SELECT 1 FROM semesters sem
                  WHERE sem.academic_year_id = ay.id AND sem.is_active = TRUE
                ) AS has_active_semester
         FROM academic_years ay
         LEFT JOIN classes c ON c.id = ? AND c.academic_year_id = ay.id
         WHERE ay.name = ?`,
        [class_id, school_year],
      );
      if (!academicYear.length) {
        return res.status(400).json({
          message: `school_year "${school_year}" does not exist in academic_years`,
        });
      }
      if (!academicYear[0].class_id) {
        return res.status(400).json({
          message: 'The selected class does not belong to this school year',
        });
      }
      if (!academicYear[0].has_active_semester) {
        return res.status(400).json({
          message: `No active semester exists for school year "${school_year}"`,
        });
      }
      return res.status(400).json({ message: 'Unable to create schedule with the selected data' });
    }
    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/subjects', async (req, res) => {
  try {
    const rows = await queryRows(
      'SELECT id, code, name, is_active FROM subjects WHERE is_active = TRUE ORDER BY name ASC',
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/subjects', async (req, res) => {
  try {
    const { code, name } = req.body;
    if (!code || !name) {
      return res.status(400).json({ message: 'subject code and name are required' });
    }
    const result = await query(
      'INSERT INTO subjects (code, name) VALUES (?, ?) RETURNING id',
      [code, name],
    );
    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/teachers', async (req, res) => {
  try {
    const rows = await queryRows(
      `SELECT g.id, g.nama AS name
       FROM guru g
       LEFT JOIN users u ON u.id = g.user_id
       WHERE g.status IS DISTINCT FROM FALSE
         AND (g.user_id IS NULL OR u.is_active = TRUE)
       ORDER BY g.nama ASC`,
    );
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/schedules', async (req, res) => {
  try {
    const rows = await queryRows(`
      SELECT s.id, s.class_id, c.name AS class_name, s.subject_id,
             sub.code AS subject_code, sub.name AS subject_name,
             s.teacher_id, g.nama AS teacher_name, s.day_of_week,
             s.start_time::text AS start_time,
             s.end_time::text AS end_time,
             s.late_after_minutes, ay.name AS school_year,
             s.is_active
      FROM schedules s
      JOIN classes c ON c.id = s.class_id
      JOIN subjects sub ON sub.id = s.subject_id
      JOIN guru g ON g.id = s.teacher_id
      JOIN semesters sem ON sem.id = s.semester_id
      JOIN academic_years ay ON ay.id = sem.academic_year_id
      WHERE s.is_active = TRUE
      ORDER BY s.day_of_week, s.start_time
    `);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/schedules', async (req, res) => {
  try {
    const {
      class_id,
      subject_id,
      teacher_id,
      day_of_week,
      start_time,
      end_time,
      late_after_minutes,
      school_year,
    } = req.body;

    if (
      !class_id ||
      !subject_id ||
      !teacher_id ||
      !day_of_week ||
      !start_time ||
      !end_time ||
      !school_year
    ) {
      return res.status(400).json({ message: 'schedule fields are required' });
    }

    const result = await query(
      `INSERT INTO schedules
       (class_id, subject_id, teacher_id, day_of_week, start_time, end_time,
        late_after_minutes, semester_id)
       SELECT ?, ?, ?, ?, ?, ?, ?, sem.id
       FROM academic_years ay
        JOIN classes c ON c.id = ? AND c.academic_year_id = ay.id
        JOIN semesters sem
          ON sem.academic_year_id = ay.id AND sem.is_active = TRUE
       WHERE ay.name = ?
       ORDER BY sem.id NULLS LAST
       LIMIT 1
       RETURNING id`,
      [
        class_id,
        subject_id,
        teacher_id,
        day_of_week,
        start_time,
        end_time,
        late_after_minutes || 15,
        class_id,
        school_year,
      ],
    );
    if (!result.rows.length) {
      return res.status(400).json({ message: 'school_year does not exist in academic_years' });
    }
    res.status(201).json({ id: result.rows[0].id });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/sessions', requireAuth, async (req, res) => {
  try {
    if (req.query.date && !normalizeDate(req.query.date)) {
      return res.status(400).json({ message: 'date must use YYYY-MM-DD format' });
    }
    const date = normalizeDate(req.query.date) ||
      todayInJakarta();
    await ensureSessionsForDate(date);

    const params = [];
    let sql = `
      SELECT se.id, se.schedule_id, se.session_date, se.meeting_number,
             se.start_at, se.end_at, se.attendance_deadline, se.status,
             s.class_id, c.name AS class_name, s.subject_id,
             sub.name AS subject_name, s.teacher_id, g.nama AS teacher_name,
             s.late_after_minutes
      FROM sessions se
      JOIN schedules s ON s.id = se.schedule_id
      JOIN classes c ON c.id = s.class_id
      JOIN subjects sub ON sub.id = s.subject_id
      JOIN guru g ON g.id = s.teacher_id
    `;

    const filters = ['se.session_date = ?'];
    params.push(date);
    if (req.authUser.role === 'teacher') {
      if (!req.authUser.teacherId) {
        return res.status(403).json({ message: 'teacher profile is not configured' });
      }
      filters.push('s.teacher_id = ?');
      params.push(req.authUser.teacherId);
    }
    sql += ` WHERE ${filters.join(' AND ')}`;

    sql += ' ORDER BY se.session_date DESC, se.start_at DESC';
    const rows = await queryRows(sql, params);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/sessions/generate', requireAuth, async (req, res) => {
  try {
    if (req.body.date && !normalizeDate(req.body.date)) {
      return res.status(400).json({ message: 'date must use YYYY-MM-DD format' });
    }
    const date = normalizeDate(req.body.date) ||
      todayInJakarta();
    await ensureSessionsForDate(date);
    res.status(201).json({ date });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch('/sessions/:id/status', requireAuth, async (req, res) => {
  try {
    const sessionId = Number(req.params.id);
    const status = String(req.body.status || '').trim();
    const userId = req.authUser.sub;
    const allowedStatuses = new Set(['ongoing', 'completed', 'cancelled']);

    if (!sessionId || !allowedStatuses.has(status)) {
      return res.status(400).json({ message: 'valid session id and status are required' });
    }

    if (req.authUser.role === 'teacher') {
      if (!req.authUser.teacherId) {
        return res.status(403).json({ message: 'teacher profile is not configured' });
      }
      const owned = await queryRows(
        `SELECT se.id
         FROM sessions se
         JOIN schedules s ON s.id = se.schedule_id
         WHERE se.id = ? AND s.teacher_id = ?`,
        [sessionId, req.authUser.teacherId],
      );
      if (!owned.length) {
        return res.status(403).json({ message: 'session is not assigned to this teacher' });
      }
    }

    const fields = ['status = ?'];
    const params = [status];
    if (status === 'ongoing') {
      fields.push('opened_by = ?');
      params.push(userId);
    } else if (status === 'completed' || status === 'cancelled') {
      fields.push('closed_by = ?');
      params.push(userId);
    }
    params.push(sessionId);

    const result = await query(
      `UPDATE sessions SET ${fields.join(', ')} WHERE id = ?`,
      params,
    );
    if (!result.rowCount) {
      return res.status(404).json({ message: 'session not found' });
    }
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/students/lookup', async (req, res) => {
  try {
    const qr = String(req.query.qr || '').trim();
    if (!qr) {
      return res.status(400).json({ message: 'qr is required' });
    }

    const rows = await queryRows(
      `${studentSelect}
       WHERE s.status = 'aktif' AND s.student_number = ?
       ORDER BY s.id
       LIMIT 1`,
      [qr],
    );

    if (!rows.length) {
      return res.status(404).json({ message: 'student not found' });
    }

    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/students', async (req, res) => {
  try {
    const { id, name, nis, class_name, qr_code, parent_name, parent_phone } = req.body;
    if (![name, nis, class_name, qr_code].every((value) =>
      typeof value === 'string' && value.trim(),
    )) {
      return res.status(400).json({
        message: 'name, nis, class_name, and qr_code are required',
      });
    }
    if (qr_code.trim() !== nis.trim()) {
      return res.status(400).json({ message: 'qr_code must match nis for this database schema' });
    }
    if (id != null && (!Number.isInteger(Number(id)) || Number(id) < 1)) {
      return res.status(400).json({ message: 'student id must be a positive integer' });
    }
    if (String(parent_name || '').trim() || String(parent_phone || '').trim()) {
      return res.status(400).json({
        message: 'Guardian details cannot be saved because this Supabase schema has no guardian table',
      });
    }
    const classId = await findClassId(class_name.trim());
    if (!classId) {
      return res.status(400).json({ message: 'class_name does not match an active class' });
    }
    const studentId = await transaction(async (run) => {
      const result = id
        ? await run(
            `INSERT INTO students
             (id, full_name, student_number, class_id, status)
             VALUES (?, ?, ?, ?, 'aktif')
             RETURNING id`,
            [id, name.trim(), nis.trim(), classId],
          )
        : await run(
            `INSERT INTO students
             (full_name, student_number, class_id, status)
             VALUES (?, ?, ?, 'aktif')
             RETURNING id`,
            [name.trim(), nis.trim(), classId],
          );
      if (id) {
        await run(
          `SELECT setval(
             pg_get_serial_sequence('students', 'id'),
             GREATEST((SELECT COALESCE(MAX(id), 1) FROM students), 1),
             TRUE
           )`,
        );
      }
      return result.rows[0].id;
    });
    res.status(201).json({ id: studentId });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ message: 'nis or qr_code already exists' });
    }
    res.status(500).json({ message: error.message });
  }
});

app.get('/students/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) {
      return res.status(400).json({ message: 'valid student id is required' });
    }
    const rows = await queryRows(
      `${studentSelect} WHERE s.id = ? AND s.status = 'aktif'`,
      [id],
    );
    if (!rows.length) {
      return res.status(404).json({ message: 'student not found' });
    }
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put('/students/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) {
      return res.status(400).json({ message: 'valid student id is required' });
    }
    const { name, nis, class_name, qr_code, parent_name, parent_phone } = req.body;
    if (![name, nis, class_name, qr_code].every((value) =>
      typeof value === 'string' && value.trim(),
    )) {
      return res.status(400).json({
        message: 'name, nis, class_name, and qr_code are required',
      });
    } 
    if (qr_code.trim() !== nis.trim()) {
      return res.status(400).json({ message: 'qr_code must match nis for this database schema' });
    }
    if (String(parent_name || '').trim() || String(parent_phone || '').trim()) {
      return res.status(400).json({
        message: 'Guardian details cannot be saved because this Supabase schema has no guardian table',
      });
    }
    const classId = await findClassId(class_name.trim());
    if (!classId) {
      return res.status(400).json({ message: 'class_name does not match an active class' });
    }
    const updated = await transaction(async (run) => {
      const result = await run(
        `UPDATE students
         SET full_name = ?, student_number = ?, class_id = ?
         WHERE id = ? AND status = 'aktif'`,
        [name.trim(), nis.trim(), classId, id],
      );
      if (!result.rowCount) return false;
      return true;
    });
    if (!updated) {
      return res.status(404).json({ message: 'student not found' });
    }
    res.json({ ok: true });
  } catch (error) {
    if (isUniqueViolation(error)) {
      return res.status(409).json({ message: 'nis or qr_code already exists' });
    }
    res.status(500).json({ message: error.message });
  }
});

app.delete('/students/:id', async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id < 1) {
      return res.status(400).json({ message: 'valid student id is required' });
    }
    const result = await query(
      `UPDATE students SET status = 'nonaktif'
       WHERE id = ? AND status = 'aktif'`,
      [id],
    );
    if (!result.rowCount) {
      return res.status(404).json({ message: 'student not found' });
    }
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/attendance', async (req, res) => {
  try {
    const date = req.query.date ? String(req.query.date).trim() : null;
    if (date && !normalizeDate(date)) {
      return res.status(400).json({ message: 'date must use YYYY-MM-DD format' });
    }
    let sql = `
      SELECT a.id, a.session_id, a.student_id, s.full_name AS student_name,
             a.attendance_date::text AS date,
             COALESCE(to_char(a.check_in_at AT TIME ZONE 'Asia/Jakarta',
                              'HH24:MI:SS'), '00:00:00') AS time,
             a.status, a.notes, a.recorded_by
      FROM attendance a
      JOIN students s ON s.id = a.student_id
    `;
    const params = [];

    if (date) {
      sql += ' WHERE a.attendance_date = ?::date';
      params.push(date);
    }

    sql += ' ORDER BY a.attendance_date DESC, a.check_in_at DESC NULLS LAST';
    const rows = await queryRows(sql, params);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/attendance/exists', async (req, res) => {
  try {
    const studentId = Number(req.query.studentId);
    const date = String(req.query.date || '').trim();
    const sessionId = req.query.sessionId ? Number(req.query.sessionId) : null;

    if (!Number.isInteger(studentId) || studentId < 1 ||
        (!date && !sessionId) || (date && !normalizeDate(date)) ||
        (sessionId && (!Number.isInteger(sessionId) || sessionId < 1))) {
      return res.status(400).json({ message: 'studentId and date or sessionId are required' });
    }

    const attendanceQuery = sessionId
      ? 'SELECT id FROM attendance WHERE student_id = ? AND session_id = ? LIMIT 1'
      : 'SELECT id FROM attendance WHERE student_id = ? AND attendance_date = ?::date LIMIT 1';
    const rows = await queryRows(
      attendanceQuery,
      sessionId ? [studentId, sessionId] : [studentId, date],
    );

    res.json({ exists: rows.length > 0 });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/attendance', async (req, res) => {
  try {
    const {
      session_id,
      student_id,
      date,
      time,
      status,
      notes,
    } = req.body;
    const normalizedDate = normalizeDate(date);
    const normalizedTime = normalizeTime(time);
    const validStatuses = new Set([
      'Hadir',
      'Terlambat',
      'Sakit',
      'Izin',
      'Dispensasi',
      'Tidak Hadir',
    ]);

    if (!Number.isInteger(Number(student_id)) || Number(student_id) < 1 ||
        !normalizedDate || !isValidTime(time) || !validStatuses.has(status)) {
      return res.status(400).json({
        message: 'valid student_id, date, and attendance status are required',
      });
    }

    let sessionId = Number(session_id) || null;
    if (!sessionId) {
      const activeSessions = await queryRows(
        `SELECT se.id
         FROM sessions se
         JOIN schedules sc ON sc.id = se.schedule_id
         JOIN students st ON st.class_id = sc.class_id
         WHERE st.id = ? AND se.session_date = ?::date
           AND se.status = 'ongoing'
         ORDER BY se.start_at`,
        [student_id, normalizedDate],
      );
      if (activeSessions.length !== 1) {
        return res.status(400).json({
          message: activeSessions.length
            ? 'session_id is required when multiple active sessions match this student'
            : 'no active session found for this student and date',
        });
      }
      sessionId = Number(activeSessions[0].id);
    }

    const sessionRows = await queryRows(
      `SELECT se.session_date, se.status, sc.class_id
       FROM sessions se
       JOIN schedules sc ON sc.id = se.schedule_id
       JOIN students st ON st.id = ? AND st.class_id = sc.class_id
       WHERE se.id = ?`,
      [student_id, sessionId],
    );
    if (!sessionRows.length) {
      return res.status(400).json({ message: 'session is not assigned to the student class' });
    }
    if (String(sessionRows[0].session_date).slice(0, 10) !== normalizedDate) {
      return res.status(400).json({ message: 'attendance date does not match the session date' });
    }
    if (sessionRows[0].status !== 'ongoing') {
      return res.status(409).json({ message: 'session must be ongoing before attendance can be recorded' });
    }

    const studentRows = await queryRows(
      'SELECT full_name AS name FROM students WHERE id = ?',
      [student_id],
    );
    if (!studentRows.length) {
      return res.status(404).json({ message: 'student not found' });
    }

    const result = await query(
      `INSERT INTO attendance
       (session_id, student_id, attendance_date, check_in_at, status,
        notes, recorded_by)
       VALUES (?, ?, ?::date, (?::date + ?::time) AT TIME ZONE 'Asia/Jakarta',
               ?, ?, ?)
       ON CONFLICT (session_id, student_id) DO UPDATE SET
         attendance_date = EXCLUDED.attendance_date,
         check_in_at = EXCLUDED.check_in_at,
         status = EXCLUDED.status,
         notes = EXCLUDED.notes,
         recorded_by = EXCLUDED.recorded_by
       RETURNING id`,
      [
        sessionId,
        student_id,
        normalizedDate,
        normalizedDate,
        normalizedTime,
        status,
        notes || null,
        null,
      ],
    );

    const attendanceId = result.rows[0].id;
    let notification = { status: 'failed', reason: 'attendance id is unavailable' };
    if (attendanceId) {
      try {
        notification = await createWhatsAppNotification({
          attendanceId,
          studentId: student_id,
          studentName: studentRows[0].name,
          date: normalizedDate,
          time: normalizedTime,
          status,
        })
      } catch (error) {
        console.error(`Failed to create WhatsApp notification: ${error.message}`);
        notification = { status: 'failed', reason: 'notification could not be recorded' };
      }
    }

    res.status(201).json({ id: attendanceId, notification });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/notifications/whatsapp', requireAuth, requireAdmin, async (req, res) => {
  try {
    const status = req.query.status ? String(req.query.status).trim() : null;
    const params = [];
    let sql = `
      SELECT id, attendance_id, student_id, parent_id, parent_phone, message, status,
             provider_message_id, error_message, created_at, sent_at
      FROM whatsapp_notifications
    `;
    if (status) {
      sql += ' WHERE status = ?';
      params.push(status);
    }
    sql += ' ORDER BY created_at DESC LIMIT 200';
    const rows = await queryRows(sql, params);
    res.json(rows);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put('/attendance/:id', requireAuth, requireAdmin, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const {
      session_id,
      student_id,
      date,
      time,
      status,
      notes,
      recorded_by,
    } = req.body;
    const normalizedDate = normalizeDate(date);
    const sessionId = Number(session_id);
    const studentId = Number(student_id);
    const validStatuses = new Set([
      'Hadir',
      'Terlambat',
      'Sakit',
      'Izin',
      'Dispensasi',
      'Tidak Hadir',
    ]);
    if (!Number.isInteger(sessionId) || sessionId < 1 ||
        !Number.isInteger(studentId) || studentId < 1 ||
        !normalizedDate || !isValidTime(time) || !validStatuses.has(status)) {
      return res.status(400).json({ message: 'valid session, student, date, and status are required' });
    }
    const matchingSession = await queryRows(
      `SELECT se.session_date
       FROM sessions se
       JOIN schedules sc ON sc.id = se.schedule_id
       JOIN students st ON st.id = ? AND st.class_id = sc.class_id
       WHERE se.id = ?`,
      [studentId, sessionId],
    );
    if (!matchingSession.length ||
        String(matchingSession[0].session_date).slice(0, 10) !== normalizedDate) {
      return res.status(400).json({ message: 'session, student, and date do not match' });
    }
    const result = await query(
      `UPDATE attendance
       SET session_id = ?, student_id = ?, attendance_date = ?::date,
           check_in_at = (?::date + ?::time) AT TIME ZONE 'Asia/Jakarta',
           status = ?, notes = ?, recorded_by = ?
       WHERE id = ?`,
      [
        sessionId,
        studentId,
        normalizedDate,
        normalizedDate,
        normalizeTime(time),
        status,
        notes || null,
        recorded_by || null,
        id,
      ],
    );
    if (!result.rowCount) {
      return res.status(404).json({ message: 'attendance record not found' });
    }
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.use((req, res) => {
  res.status(404).json({ message: 'not found' });
});

const port = Number(process.env.PORT || 3000);

async function startServer() {
  await pool.query('SELECT 1');
  app.listen(port, () => {
    console.log(`Absensi QR API connected to Supabase and listening on port ${port}`);
  });
}

if (require.main === module) {
  pool = createDatabasePool();
  startServer().catch(async (error) => {
    console.error(`Failed to connect to Supabase: ${error.message}`);
    await pool.end();
    process.exitCode = 1;
  });
} else {
  module.exports = {
    app,
    setPoolForTests(testPool) {
      pool = testPool;
    },
  };
}
