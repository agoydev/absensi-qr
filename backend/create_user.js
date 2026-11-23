require('dotenv').config();

const { createDatabasePool } = require('./database');
const crypto = require('crypto');

const required = ['DATABASE_URL', 'USER_NAME', 'USER_USERNAME', 'USER_PASSWORD', 'USER_ROLE'];
for (const key of required) {
  if (!process.env[key]) {
    throw new Error(`${key} is required`);
  }
}

const role = process.env.USER_ROLE.trim().toLowerCase();
if (!['admin', 'teacher'].includes(role)) {
  throw new Error('USER_ROLE must be admin or teacher');
}
if (process.env.USER_PASSWORD.length < 8) {
  throw new Error('USER_PASSWORD must be at least 8 characters');
}

const salt = crypto.randomBytes(16).toString('hex');
const derived = crypto.scryptSync(process.env.USER_PASSWORD, salt, 64).toString('hex');
const passwordHash = `scrypt$${salt}$${derived}`;

async function main() {
  const pool = createDatabasePool();

  try {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      const result = await client.query(
        `INSERT INTO users (name, username, password_hash, role)
         VALUES ($1, $2, $3, $4)
         RETURNING id`,
        [
          process.env.USER_NAME.trim(),
          process.env.USER_USERNAME.trim().toLowerCase(),
          passwordHash,
          role,
        ],
      );
      if (role === 'teacher') {
        await client.query(
          'INSERT INTO guru (user_id, nama) VALUES ($1, $2)',
          [result.rows[0].id, process.env.USER_NAME.trim()],
        );
      }
      await client.query('COMMIT');
      console.log(`Created ${role} user ${process.env.USER_USERNAME} with id ${result.rows[0].id}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  if (error.code === '23505') {
    console.error('Username already exists');
  } else {
    console.error(error.message);
  }
  process.exitCode = 1;
});
