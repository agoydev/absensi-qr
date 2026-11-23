# 🎯 QUICK REFERENCE -

## **A. PERTANYAAN TENTANG ARSITEKTUR**

### Q: "Jelaskan arsitektur aplikasi ini"
**A:** Aplikasi menggunakan **3-layer architecture**:

1. **UI Layer** (LoginScreen, ScanScreen, ReportScreen, etc)
   - Bertanggung jawab hanya untuk tampilan
   - Mengambil data dari Services

2. **Services Layer** (AuthService, DatabaseService, ApiService)
   - Business logic disini
   - Auth, database operations, API calls
   - Singleton pattern untuk single instance

3. **Data Layer** (SQLite, Shared Preferences, Backend API)
   - Menyimpan data persistent
   - DatabaseService abstract detail implementasi

**Keuntungan:** Separation of concerns, mudah test, mudah maintain.

---

### Q: "Mengapa memilih Flutter?"
**A:** Beberapa alasan:
- **Cross-platform**: Satu codebase untuk Android, iOS, Windows, Web, Linux, macOS
- **Hot reload**: Develop lebih cepat
- **Material Design**: UI modern dan professional
- **Performance**: Compiled to native code
- **Community**: Large community, banyak packages tersedia

---

## **B. PERTANYAAN TENTANG AUTHENTICATION**

### Q: "Bagaimana login bekerja?"
**A:** 
1. User input username & password
2. LoginScreen call `AuthService.instance.login(username, password)`
3. AuthService normalize input (lowercase, trim)
4. Cari username di `_accounts` map
5. Validasi password
6. Jika cocok → return role user, set `_currentRole`
7. Jika tidak → return null, tampilkan error

**Default accounts:**
- Username: `admin`, Password: `admin123`, Role: `Admin`
- Username: `guru`, Password: `guru123`, Role: `Guru`

### Q: "Apakah password encrypted?"
**A:** Saat ini password disimpan plain text (for simplicity). 
**Untuk production**, harus encrypt menggunakan:
- bcrypt
- PBKDF2
- Argon2

### Q: "Bagaimana registrasi akun baru?"
**A:**
1. User input username, password, role
2. Register screen validate input (tidak kosong)
3. Cek username tidak duplikat
4. Insert ke `_accounts` map
5. Serialize to JSON & save ke Shared Preferences
6. Setiap app restart, data dimuat kembali dari SharedPreferences

---

## **B.5 PERTANYAAN TENTANG API SERVICE**

### Q: "Untuk apa ApiService? Perlu atau tidak?"
**A:** 
ApiService adalah **optional backend integration layer** untuk future scalability.

**Saat ini (aplikasi masih digunakan lokal):**
- Tidak perlu API
- Data disimpan di SQLite lokal
- Cukup untuk 1 sekolah/kelas

**Masa depan (jika scale-up):**
- Perlu API untuk multi-device sync
- Perlu cloud backup
- Perlu centralized database untuk banyak sekolah

**Desain:**
Aplikasi bisa bekerja **2 mode**:
1. **Offline Mode**: Gunakan SQLite (saat ini)
2. **Cloud Mode**: Gunakan API (optional di masa depan)

```dart
// Di DatabaseService
bool get _useApi => ApiService.instance.isConfigured;

if (_useApi) {
  return ApiService.instance.getStudents();  // Use API
} else {
  return await db.query('students');  // Use SQLite
}
```

### Q: "Bagaimana ApiService dikonfigurasi?"
**A:**
Di `lib/config/app_config.dart`:

```dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',  // Empty = gunakan SQLite
);

static bool get useApi => apiBaseUrl.trim().isNotEmpty;
```

**Jika API tidak dikonfigurasi** (`defaultValue = ''`)
→ `useApi = false` → aplikasi gunakan SQLite

**Jika production mau API:**
```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com
```
→ `useApi = true` → aplikasi gunakan API

### Q: "Apa saja endpoint API yang tersedia?"
**A:**
ApiService menyediakan endpoints untuk CRUD operations:

| Method | Endpoint | Fungsi |
|--------|----------|--------|
| GET | `/students` | Ambil semua siswa |
| GET | `/students/lookup?qr=` | Cari siswa by QR code |
| POST | `/students` | Tambah siswa baru |
| PUT | `/students/{id}` | Update siswa |
| DELETE | `/students/{id}` | Hapus siswa |
| GET | `/attendance` | Ambil semua attendance |
| GET | `/attendance?date=` | Filter attendance by date |
| POST | `/attendance` | Record absensi |
| PUT | `/attendance/{id}` | Update attendance |
| GET | `/attendance/exists?studentId=&date=` | Cek sudah absen hari ini |

### Q: "Apakah backend sudah ada?"
**A:**
Backend masih **dalam tahap development**:
- Ada template di folder `backend/` (Node.js + Express)
- `server.js` - main server file
- `package.json` - dependencies

Tapi **belum production-ready**. Saat ini fokus di mobile frontend dengan SQLite.

**Jika mau implementasi backend di masa depan:**
1. Develop REST API menggunakan Node.js
2. Buat database (PostgreSQL/MySQL)
3. Set `API_BASE_URL` environment variable
4. Aplikasi otomatis sync dengan backend

### Q: "Bagaimana jika API down? Apakah aplikasi error?"
**A:**
- Jika saat ini gunakan SQLite (tidak ada API) → **tetap jalan** (offline-first)
- Jika future pakai API dan API down → aplikasi akan:
  1. Throw exception
  2. UI layer catch error
  3. Show error message ke user
  
**Untuk production**: Bisa implement fallback strategy:
```dart
// If API error, use local SQLite as cache
try {
  return await ApiService.instance.getStudents();
} catch (e) {
  // Fallback to local database
  return await DatabaseService.local.getStudents();
}
```

### Q: "SQLite atau API, mana yang lebih baik?"
**A:**
Tergantung use case:

| Aspek | SQLite | API + Cloud |
|-------|--------|------------|
| **Performa** | Cepat (local) | Lebih lambat (network) |
| **Offline capability** | ✅ Bisa | ❌ Tidak bisa |
| **Multi-device sync** | ❌ Tidak | ✅ Bisa |
| **Data backup** | Manual | Otomatis (cloud) |
| **Setup complexity** | Simple | Complex |
| **Scalability** | Terbatas | Unlimited |

**Rekomendasi untuk skala besar:**
- **Hybrid approach**: SQLite + API
  - SQLite untuk local cache (performa, offline)
  - API untuk sync & backup (scalability)

---

## **C. PERTANYAAN TENTANG DATABASE**

### Q: "Jelaskan database schema"
**A:** Ada 2 table:

**1. students**
```
id (PK)          - Auto increment
name             - Nama siswa
nis (UNIQUE)     - Nomor Induk Siswa, unik
class_name       - Nama kelas
qr_code (UNIQUE) - QR code, unik
```

**2. attendance**
```
id (PK)        - Auto increment
student_id (FK)- Link ke students.id
student_name   - Cached untuk performa
date           - yyyy-MM-dd format
time           - HH:mm:ss format
status         - Hadir / Terlambat / Tidak Hadir / Dispensasi
```

**Why foreign key?** - Relational integrity, jika siswa dihapus, attendance juga dihapus

### Q: "Mengapa NIS dan QR_CODE unique?"
**A:** Untuk mencegah duplikasi:
- Satu siswa = satu NIS
- Satu siswa = satu QR code
- Database enforce constraint ini

Jika ada yang duplikat → database reject insert.

### Q: "Bagaimana sistem update data di database?"
**A:**
```dart
// DatabaseService.updateStudent(student)
final db = await database;
await db.update(
  'students',
  student.toMap(),
  where: 'id = ?',
  whereArgs: [student.id],
);
```

- Update mencari by ID
- Replace semua columns dengan data baru
- Return jumlah rows yang affected

### Q: "Bagaimana mencegah data duplikat saat scan 2x sehari?"
**A:**
```dart
// Sebelum insert attendance
final alreadyAttendance = await DatabaseService.instance
    .hasAttendanceToday(student.id, date);

if (alreadyAttendance) {
  // Show error: sudah absen
  return;
}
// Jika tidak ada record hari ini, baru insert
```

---

## **D. PERTANYAAN TENTANG QR SCANNING**

### Q: "Bagaimana proses scanning QR code?"
**A:** 
```
1. User buka ScanScreen
2. MobileScannerController detect barcode
3. _onDetect() trigger dengan barcode data
4. Extract NIS dari QR code
5. Query database: cari student by NIS
6. Hitung status based on waktu saat ini
7. Cek: sudah absen hari ini?
8. Insert ke attendance table
9. Show success dialog
10. Siap scan student berikutnya
```

### Q: "Bagaimana status absensi ditentukan?"
**A:** Berdasarkan **waktu scan**:

```
Waktu On-Time: 07:30
Grace Period: 15 menit (sampai 07:45)

if (scanTime <= 07:30)
  → Status = "Hadir"
else if (scanTime <= 07:45)
  → Status = "Terlambat"
else
  → Status = "Tidak Hadir"
```

**Contoh:**
- 07:15 → "Hadir"
- 07:40 → "Terlambat"
- 08:00 → "Tidak Hadir"

### Q: "Bagaimana data QR code di-parse?"
**A:** 
1. Hapus whitespace
2. Coba parse sebagai URL
   - Cek query parameter (e.g., `?nis=12345`)
   - Cek path segment terakhir (e.g., `/scan/12345`)
3. Jika URL parsing gagal, return cleaned input

Flexible: bisa scan dari URL atau plain number

### Q: "Apa yang terjadi jika siswa scan QR orang lain?"
**A:** 
- Akan scan siswa yang QR-nya di-scan
- Absensi akan tercatat untuk siswa tersebut
- **Untuk mencegah:** Setiap siswa harus punya QR unik
- **Kontrol manual:** Guru bisa monitoring scan di display

---

## **E. PERTANYAAN TENTANG REPORT**

### Q: "Jelaskan Report Screen"
**A:** Ada 2 mode report:

**Mode 1: All Attendance (no date filter)**
- Tampilkan semua record absensi
- Dapat diedit (Guru/Admin saja)
- Auto-refresh setiap 30 detik

**Mode 2: Daily Report (with date filter)**
- Tampilkan status absensi semua siswa untuk satu hari
- Siswa yang tidak absen tampil dengan status "Tidak Absen"
- Semua siswa tercakup (no one left out)

### Q: "Bagaimana daily report dibangun?"
**A:**
```dart
1. Fetch semua attendance records
2. Create map: studentId → Attendance
3. Loop semua students:
   - Jika student ada di map → gunakan attendance data
   - Jika tidak → create default "Tidak Absen"
4. Return lengkap list semua siswa
```

**Keuntungan:** O(n) complexity, semua siswa visible

### Q: "Siapa yang bisa edit attendance?"
**A:** 
- **Admin**: Bisa edit semua
- **Guru**: Bisa edit attendance di kelasnya (role-based check)
- **Student**: Tidak ada akses edit

```dart
// Role check:
if (currentRole.contains('admin') || currentRole.contains('guru')) {
  // Show edit button
}
```

### Q: "Bagaimana auto-refresh bekerja?"
**A:**
```dart
_timer = Timer.periodic(
  Duration(seconds: 30),  // Every 30 seconds
  (_) => _loadAttendance(),  // Fetch fresh data
);

// Cleanup saat screen ditutup
@override
void dispose() {
  _timer?.cancel();
  super.dispose();
}
```

---

## **F. PERTANYAAN TENTANG FITUR KHUSUS**

### Q: "Apakah ada fitur status Dispensasi?"
**A:** Ya, recently added:
- Status absensi sekarang include "Dispensasi"
- Sama dengan status lain: disimpan sebagai plain string
- Edit laporan dapat mengubah status ke Dispensasi
- Hanya Admin & Guru yang bisa set Dispensasi

### Q: "Bagaimana export ke PDF?"
**A:** Menggunakan package `pdf`:
```dart
final doc = pw.Document();
doc.addPage(
  pw.Page(
    build: (context) {
      return pw.Column(children: [
        // Add attendance data to PDF
      ]);
    },
  ),
);
await Printing.layoutPdf(onLayout: (_) => doc.save());
```

### Q: "Bagaimana share laporan?"
**A:** Menggunakan package `share_plus`:
```dart
await Share.share(
  'Laporan Absensi: ...',  // Content
  subject: 'Absensi Report',
);
// System picker akan muncul (WhatsApp, Email, etc)
```

---

## **G. PERTANYAAN TENTANG DESIGN PATTERNS**

### Q: "Apa itu Singleton Pattern?"
**A:** 
- Memastikan hanya ada **1 instance** dari class
- Implementasi: private constructor + static instance

```dart
class AuthService {
  AuthService._();  // Private
  static final instance = AuthService._();  // Static
}

// Everywhere:
AuthService.instance.login(...)  // Same instance
```

**Keuntungan:** Global access, single state, efficient

### Q: "Apa itu Repository Pattern?"
**A:**
- DatabaseService adalah repository
- Abstract detail data storage (SQLite) behind interface
- UI tidak perlu tahu SQLite implementasi

```dart
// UI layer tidak import sqflite, hanya DatabaseService
final students = await DatabaseService.instance.getStudents();
```

### Q: "Apa itu Observer Pattern?"
**A:**
- Menggunakan StreamController untuk notify listeners
- Ketika data change → emit event
- UI listen & refresh

```dart
// In service:
_dataChangesController.add(null);  // Emit

// In UI:
DatabaseService.instance.dataChanges.listen((_) {
  _loadAttendance();  // Refresh
});
```

---

## **H. PERTANYAAN TENTANG KEAMANAN & QUALITY**

### Q: "Bagaimana validasi input?"
**A:**
1. **Front-end validation:**
   - Check tidak kosong
   - Check format (jika perlu)
   - User-friendly error messages

2. **Back-end validation:**
   - Check duplikasi
   - Check constraints (UNIQUE, NOT NULL)
   - Prevent SQL injection

### Q: "Apakah ada error handling?"
**A:** Ya, beberapa jenis:
- Try-catch blocks untuk async operations
- Null checks sebelum access
- Database constraints
- User feedback via SnackBar

```dart
try {
  await operation();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')),
  );
}
```

### Q: "Bagaimana input sanitization?"
**A:**
```dart
// Normalize input
final normalized = input
  .trim()           // Remove leading/trailing spaces
  .toLowerCase();   // Consistent case

// Prevent duplicate
if (_accounts.containsKey(normalized)) {
  return false;
}
```

---

## **I. PERTANYAAN TENTANG PERFORMA**

### Q: "Bagaimana handle banyak siswa (1000+)?"
**A:**
1. **Database indexing:** Index pada `nis`, `qr_code`
2. **Pagination:** Load data in chunks (tidak semua sekaligus)
3. **Caching:** Student name di attendance table (avoid JOIN)
4. **Query optimization:** Only fetch needed columns
5. **Memory:** Use stream untuk large datasets

### Q: "Bagaimana handle internet putus?"
**A:** 
- Data disimpan di **local SQLite** (offline-first)
- Jika ada backend, data sync ketika online kembali
- User tetap bisa scan/absensi offline
- Data persist hingga sync berhasil

### Q: "Apakah ada caching?"
**A:** 
- **Student name** disimpan di attendance table (denormalized)
  - Pro: Tidak perlu JOIN, lebih cepat
  - Con: Update name perlu update di 2 tempat
- **In-memory cache** di web version
- **SharedPreferences** untuk auth data

---

## **J. PERTANYAAN TENTANG TESTING**

### Q: "Apakah ada unit test?"
**A:** Currently tidak ada, tapi perlu ditambah untuk:
- AuthService.login()
- AuthService.registerAccount()
- DatabaseService methods
- Attendance status calculation

```dart
test('login dengan password benar return role', () async {
  final result = AuthService.instance.login('admin', 'admin123');
  expect(result, 'Admin');
});

test('login dengan password salah return null', () async {
  final result = AuthService.instance.login('admin', 'wrong');
  expect(result, null);
});
```

### Q: "Bagaimana test QR scanning logic?"
**A:**
```dart
test('extractNis parse URL dengan query param', () {
  final result = extractNis('http://example.com?nis=12345');
  expect(result, '12345');
});

test('calculateStatus hadir jika <= 07:30', () {
  // Mock time 07:15
  expect(calculateStatus(07, 15), 'Hadir');
});
```

---

## **K. PERTANYAAN TENTANG FUTURE IMPROVEMENT**

### Q: "Apa improvement untuk future?"
**A:**
1. **Security:**
   - Hash password dengan bcrypt
   - JWT tokens untuk API
   - HTTPS untuk communication

2. **Features:**
   - Biometric login (fingerprint)
   - Cloud sync untuk multi-device
   - Analytics dashboard
   - SMS/Email notification

3. **Performance:**
   - Database indexing
   - Pagination di report
   - Caching strategies

4. **Quality:**
   - Unit tests coverage
   - Integration tests
   - E2E tests

---

## **L. TIPS SAAT SIDANG**

✅ **DO:**
- Mulai dengan gambaran umum (architecture overview)
- Berikan concrete examples
- Tunjukkan kode spesifik saat ditanya detail
- Jujur jika tidak tahu (tapi tawarkan research)
- Gunakan technical terms yang tepat

❌ **DON'T:**
- Jangan langsung teknisnya, mulai dari big picture
- Jangan terlalu panjang
- Jangan membela jika ada kritik (terima & suggest improvement)
- Jangan khawatir error/limitations (normal untuk aplikasi real-world)

---

**Good Luck dengan sidang! 💪**
