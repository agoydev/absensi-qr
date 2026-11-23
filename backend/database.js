const fs = require('fs');
const path = require('path');
const { Pool, types } = require('pg');

types.setTypeParser(20, (value) => {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) ? parsed : value;
});

function createDatabasePool() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL must be configured with the Supabase PostgreSQL connection string');
  }

  const certificatePath = process.env.SUPABASE_CA_CERT;
  if (!certificatePath) {
    throw new Error('SUPABASE_CA_CERT must point to the Supabase database CA certificate');
  }

  const resolvedCertificatePath = path.resolve(__dirname, certificatePath);
  if (!fs.existsSync(resolvedCertificatePath)) {
    throw new Error(`Supabase CA certificate not found: ${resolvedCertificatePath}`);
  }

  const ca = fs.readFileSync(resolvedCertificatePath, 'utf8');
  if (!ca.includes('-----BEGIN CERTIFICATE-----')) {
    throw new Error('SUPABASE_CA_CERT must point to a PEM-encoded CA certificate');
  }

  const parsedConnectionString = new URL(connectionString);
  for (const sslParameter of ['sslmode', 'sslcert', 'sslkey', 'sslrootcert']) {
    parsedConnectionString.searchParams.delete(sslParameter);
  }

  return new Pool({
    connectionString: parsedConnectionString.toString(),
    ssl: { ca, rejectUnauthorized: true },
    options: '-c search_path=absensi_qr,public',
    max: 10,
  });
}

module.exports = { createDatabasePool };
