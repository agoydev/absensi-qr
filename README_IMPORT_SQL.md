# Memindahkan database ke Supabase

Schema Supabase yang Anda buat dan berisi 31 tabel kini disimpan di
[sql/supabase_absensi_qr_schema.sql](sql/supabase_absensi_qr_schema.sql).
File aslinya tetap ada di Downloads dan tidak diubah.

Schema tersebut membuat tabel dalam namespace `absensi_qr`, bukan `public`.
Karena Anda sudah membuat tabel-tabel ini di Supabase, tidak perlu menjalankan
ulang schema kecuali memang ingin membuatnya di database lain. Script memakai
`IF NOT EXISTS`; itu tidak memperbarui tabel yang sudah ada.

**Penting:** backend saat ini masih memakai bentuk tabel API yang berbeda dan
query tanpa prefix `absensi_qr`. Menambahkan connection string saja belum
membuat API kompatibel dengan 31 tabel tersebut. Endpoint perlu dipetakan ke
struktur baru sebelum aplikasi digunakan dengan schema ini. Lihat
[backend/README.md](backend/README.md).

Jangan jalankan [sql/mysql_schema.sql](sql/mysql_schema.sql) di Supabase; file
tersebut hanya untuk MySQL/phpMyAdmin.

Script di `tools/` yang bernama `*_sqlite_to_mysql*` menghasilkan data untuk
MySQL saja; script tersebut tidak digunakan untuk migrasi ke Supabase.
