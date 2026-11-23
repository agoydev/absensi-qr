require('dotenv').config();

const crypto = require('crypto');
const { createDatabasePool } = require('./database');

const password = process.env.ADMIN_PASSWORD;
if (!password || password.length < 8) {
  throw new Error('ADMIN_PASSWORD must be at least 8 characters');
}

const salt = crypto.randomBytes(16).toString('hex');
const derived = crypto.scryptSync(password, salt, 64).toString('hex');
const passwordHash = `scrypt$${salt}$${derived}`;

async function main() {
  const pool = createDatabasePool();
  try {
    const result = await pool.query(
      `INSERT INTO users (name, username, password_hash, role, is_active)
       VALUES ('Administrator', 'admin', $1, 'admin', TRUE)
       ON CONFLICT (username)
       DO UPDATE SET name = EXCLUDED.name,
                     password_hash = EXCLUDED.password_hash,
                     role = 'admin',
                     is_active = TRUE
       RETURNING id`,
      [passwordHash],
    );
    console.log(`Admin account is ready (id ${result.rows[0].id}).`);
  } finally {
    await pool.end();
  }
}

main().catch((error) => {
  console.error(`Admin setup failed: ${error.message}`);
  process.exitCode = 1;
});
