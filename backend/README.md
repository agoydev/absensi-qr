# Absensi QR API

REST API Node.js untuk aplikasi Flutter. Database cloud yang digunakan adalah
PostgreSQL di Supabase; phpMyAdmin hanya mengelola MySQL dan tidak menjadi
koneksi aplikasi.

## Schema Supabase

Backend memakai schema PostgreSQL `absensi_qr` yang sudah ada di project.
Struktur live yang diperiksa pada 2026-11-08 berbeda dari snapshot
`../sql/supabase_absensi_qr_schema.sql`: database live memiliki 33 tabel
(termasuk tabel lain yang sudah ada), memakai `guru`, `orang_tua`,
`student_parents`, `students.student_number`/`full_name`, dan kolom absensi
`check_in_at`. Karena itu **jangan jalankan ulang snapshot SQL tersebut** pada
database live. API memetakan respons lama yang dipakai Flutter ke tabel/kolom
live tersebut; tidak ada tabel yang dihapus atau dibuat otomatis.

QR siswa pada aplikasi saat ini berisi NIS. Di database live NIS disimpan pada
`students.student_number`, sehingga endpoint mengembalikan nomor tersebut
sebagai `qr_code` dan tidak menulis ke tabel QR yang terkait sesi.

## Menyiapkan Supabase

1. Buat project Supabase.
2. Buka **Connect** di dashboard, lalu salin connection string PostgreSQL
   dengan mode **Session pooler** untuk backend Node.js yang berjalan terus.
3. Unduh sertifikat CA database dari **Project Settings → Database → SSL
   Configuration** di dashboard Supabase. Simpan file PEM tersebut sebagai
   `backend/supabase-ca.crt`. Backend memverifikasi CA dan nama host; jangan
   menonaktifkan verifikasi TLS. Pengaturan SSL pada URL koneksi dihapus oleh
   loader agar tidak menimpa CA yang dikonfigurasi.
4. Jangan jalankan file SQL snapshot lama pada project yang sudah memiliki
   schema live.
5. Salin `.env.example` menjadi `.env`, lalu isi `DATABASE_URL` dengan connection
   string tadi dan ganti `AUTH_SECRET` dengan string acak minimal 32 karakter.
   Atur `SUPABASE_CA_CERT=./supabase-ca.crt` jika lokasi file CA berbeda.
   Jangan commit atau membagikan `.env` maupun file sertifikat.
6. Jalankan API:

   ```powershell
   npm install
   npm start
   ```

`DATABASE_URL` adalah kredensial database backend. Jangan menaruh database
password atau Supabase `service_role` key di aplikasi Flutter. API melakukan tes koneksi PostgreSQL sebelum mulai mendengarkan pada port
`3000`. Jika CA, URL, atau koneksi salah, proses akan gagal dengan pesan error
agar masalahnya terlihat langsung di terminal. API memakai koneksi terenkripsi
dan memverifikasi sertifikat server.

## Data awal yang dibutuhkan

Untuk fitur tambah kelas dan jadwal, pastikan tahun ajaran dan semester sudah
tersedia. Contoh berikut aman dijalankan bila data tersebut belum ada:

```sql
INSERT INTO absensi_qr.academic_years
  (name, start_date, end_date, is_active)
VALUES
  ('2026/2027', '2026-07-01', '2027-06-30', TRUE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO absensi_qr.semesters
  (academic_year_id, name, start_date, end_date, is_active)
SELECT id, 'Ganjil', '2026-07-01', '2026-12-31', TRUE
FROM absensi_qr.academic_years
WHERE name = '2026/2027'
ON CONFLICT (academic_year_id, name) DO NOTHING;
```

Ganti nama dan tanggal sesuai tahun ajaran sekolah. Jika tahunnya sudah ada,
pastikan `name` pada form kelas/jadwal sama persis dengan nilai database.
Tambahkan mata pelajaran dan akun admin/guru melalui aplikasi/CLI. Akun guru
dipasangkan ke tabel `guru` melalui `user_id`.

Schema Supabase tidak mengimpor isi MySQL/phpMyAdmin. Data lama harus diekspor
dan dimigrasikan terpisah dengan pemetaan relasi. File
`../sql/mysql_schema.sql` tetap khusus untuk MySQL/phpMyAdmin.

Endpoint dan contoh Postman di bawah memakai pemetaan API ke schema
`absensi_qr`. File
`../sql/mysql_schema.sql` tetap khusus MySQL/phpMyAdmin.

### Menyiapkan akun admin

Di PowerShell, dari folder `backend`, jalankan:

```powershell
.\setup-admin.ps1
```

Masukkan password minimal 8 karakter saat diminta. Input password tidak
ditampilkan dan tidak disimpan ke file. Script membuat username `admin`;
jika username itu sudah ada, password diganti dan akun diaktifkan kembali
dengan peran admin. Pastikan `DATABASE_URL` di `.env` menunjuk ke project
Supabase yang benar. Setelah berhasil, login dari aplikasi dengan username
`admin` dan password yang baru dimasukkan.

## Endpoint

- `GET /health`
- `POST /auth/login`
- `POST /auth/register`
- `GET /users`, `POST /users` (admin only)
- `GET /students`
- `GET /students/:id`
- `GET /students/lookup?qr=...`
- `POST /students`
- `PUT /students/:id`
- `DELETE /students/:id`
- `GET /attendance`
- `GET /attendance/exists?studentId=1&date=2026-04-30`
- `POST /attendance`
- `PUT /attendance/:id` (admin only)
- `GET /classes`, `POST /classes`
- `GET /subjects`, `POST /subjects`
- `GET /teachers`
- `GET /schedules`, `POST /schedules`
- `GET /sessions?date=YYYY-MM-DD` (authentication required)
- `POST /sessions/generate` (authentication required)
- `PATCH /sessions/:id/status` (authentication required)
- `GET /notifications/whatsapp?status=sent` (admin only)

Untuk demonstrasi tugas, endpoint siswa memenuhi CRUD lengkap: GET semua data,
GET berdasarkan ID, POST, PUT, dan DELETE.

Contoh body untuk `POST /students` dan `PUT /students/:id`:

```json
{
  "name": "Nama Siswa",
  "nis": "12345",
  "class_name": "X RPL 1",
  "qr_code": "SISWA-12345",
  "parent_name": "Nama Wali",
  "parent_phone": "628123456789"
}
```

Tes di Postman/API Client:

1. `GET http://localhost:3000/students`
2. `POST http://localhost:3000/students` dengan body JSON di atas.
3. Gunakan `id` dari respons POST untuk `GET /students/:id`.
4. `PUT /students/:id` dengan body JSON yang sudah diubah.
5. `DELETE /students/:id`, lalu ulangi GET berdasarkan ID untuk memastikan
   server mengembalikan `404`.

Screenshot yang relevan untuk laporan: tabel `students` di Supabase, route dan
kode CRUD ini, respons Postman untuk tiap method, serta perubahan baris data
setelah POST/PUT/DELETE.

`GET /sessions`, `POST /sessions/generate`, dan `PATCH /sessions/:id/status`
memerlukan header `Authorization: Bearer <token>` yang diperoleh dari
`POST /auth/login`. Guru hanya dapat melihat dan mengubah sesi yang ditugaskan
kepadanya; admin dapat melihat semua sesi. Password pada kolom
`users.password_hash` memakai format `scrypt$salt$derivedKey`.

Sebelum mencatat absensi, generate sesi untuk tanggal tersebut lalu ubah status
sesi menjadi `ongoing`. `POST /attendance` hanya menyimpan absensi untuk siswa
yang kelasnya cocok dengan jadwal sesi. Jika aplikasi tidak mengirim
`session_id`, API hanya memilih otomatis bila tepat satu sesi aktif cocok;
jika ada beberapa atau tidak ada sesi aktif, API mengembalikan pesan validasi.

## Membuat akun admin pertama

Endpoint pembuatan user memerlukan token admin. Buat admin pertama melalui CLI:

```powershell
$env:USER_NAME="Administrator"
$env:USER_USERNAME="admin"
$env:USER_PASSWORD="gunakan-password-kuat"
$env:USER_ROLE="admin"
npm run create-user
```

Password hanya digunakan untuk membuat hash scrypt dan tidak disimpan oleh
utilitas. Pastikan `DATABASE_URL` dan `AUTH_SECRET` sudah tersedia di `.env`.

## Menjalankan Flutter

Flutter Web pada komputer yang sama memakai `http://localhost:3000`. Pada HP
fisik, `localhost` menunjuk ke HP; gunakan IP komputer pada Wi-Fi yang sama:

```powershell
flutter run -d <device> --dart-define=API_BASE_URL=http://192.168.1.10:3000
```

Izinkan port `3000` pada Windows Firewall. Tes dari HP dengan membuka
`http://192.168.1.10:3000/health`; respons yang benar adalah `{"ok":true}`.

## Notifikasi WhatsApp

Setelah absensi cloud berhasil disimpan, API membuat log pada tabel
`whatsapp_notifications` dan mengirim payload ke `WHATSAPP_WEBHOOK_URL`.
Webhook menerima JSON `{ "to": "...", "message": "...", "attendance_id": 1 }`.
Jika URL provider belum dikonfigurasi, notifikasi dicatat sebagai `failed` dan
respons absensi tetap memuat status pengiriman.
