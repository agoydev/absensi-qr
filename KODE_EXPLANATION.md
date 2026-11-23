# 📖 Penjelasan Lengkap Kode Absensi QR Siswa

## **Daftar Isi**
1. [Arsitektur Umum](#arsitektur-umum)
2. [Authentication Flow](#authentication-flow)
3. [API Service & Backend Integration](#-api-service--backend-integration)
4. [Database Structure](#database-structure)
5. [QR Scanning Logic](#qr-scanning-logic)
6. [Report Generation](#report-generation)
7. [Data Models](#data-models)
8. [Design Patterns](#design-patterns)

---

## **🏗️ ARSITEKTUR UMUM**

### Struktur Lapisan (Layered Architecture)

```
┌─────────────────────────────────────────┐
│         UI LAYER (Screens)              │
│  LoginScreen, Dashboard, ScanScreen,    │
│  ReportScreen, StudentList, etc         │
└────────────────┬────────────────────────┘
                 │ (depends on)
┌─────────────────▼────────────────────────┐
│      SERVICES LAYER (Business Logic)     │
│  - AuthService (authentication)          │
│  - DatabaseService (data management)     │
│  - ApiService (backend integration)      │
└────────────────┬────────────────────────┘
                 │ (uses)
┌─────────────────▼────────────────────────┐
│       DATA LAYER                        │
│  - SQLite Database (Local)              │
│  - Shared Preferences (Session)         │
│  - Backend API (Cloud)                  │
└─────────────────────────────────────────┘
```

**Keuntungan Arsitektur Ini:**
- ✅ **Separation of Concerns**: UI terpisah dari business logic
- ✅ **Testability**: Setiap layer bisa ditest independen
- ✅ **Maintainability**: Mudah untuk update atau fix bugs
- ✅ **Flexibility**: Bisa ganti database/API tanpa ubah UI

---

## **🔐 AUTHENTICATION FLOW**

### File: `lib/services/auth_service.dart`

#### **1. Konsep: Singleton Pattern**

```dart
class AuthService {
  AuthService._();  // Private constructor (prevent instantiation)
  
  static final AuthService instance = AuthService._();  // Singleton instance
}
```

**Mengapa Singleton?**
- Hanya ada **1 instance** AuthService di aplikasi
- Semua screen share data yang sama
- Efisien: tidak perlu create/destroy object berkali-kali

#### **2. Data Structure - Accounts Storage**

```dart
final Map<String, Map<String, String>> _accounts = {
  'admin': {'password': 'admin123', 'role': 'Admin'},
  'guru': {'password': 'guru123', 'role': 'Guru'},
};

String? _currentRole;  // Menyimpan role user yang login sekarang
```

**Struktur:**
```
_accounts = {
  "admin" => {
    "password": "admin123",
    "role": "Admin"
  },
  "guru" => {
    "password": "guru123",
    "role": "Guru"
  }
}
```

#### **3. Initialization - `init()` Method**

```dart
Future<void> init() async {
  // Step 1: Ambil data akun dari Shared Preferences
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_storageKey);
  
  // Step 2: Jika kosong, return (gunakan default accounts)
  if (stored == null || stored.trim().isEmpty) {
    return;
  }
  
  // Step 3: Deserialize JSON data
  final decoded = jsonDecode(stored);
  
  // Step 4: Validate & load setiap account
  for (final entry in decoded.entries) {
    final value = entry.value;
    if (value is Map) {
      // Cek password & role tidak kosong
      if (password != null && role != null) {
        _accounts[username] = {'password': password, 'role': role};
      }
    }
  }
}
```

**Alur:**
1. Aplikasi start → `main()` call `AuthService.instance.init()`
2. `init()` buka Shared Preferences
3. Ambil data akun yang tersimpan
4. Merge dengan default accounts
5. Siap untuk login

#### **4. Registration - `registerAccount()` Method**

```dart
Future<bool> registerAccount({
  required String username,
  required String password,
  required String role,
}) async {
  // Step 1: Normalize input (trim, lowercase)
  final normalizedUsername = username.trim().toLowerCase();
  
  // Step 2: Validation
  if (normalizedUsername.isEmpty || 
      normalizedPassword.isEmpty || 
      normalizedRole.isEmpty) {
    return false;  // Gagal: ada field kosong
  }
  
  // Step 3: Cek duplikasi
  if (_accounts.containsKey(normalizedUsername)) {
    return false;  // Gagal: username sudah ada
  }
  
  // Step 4: Tambah akun baru
  _accounts[normalizedUsername] = {
    'password': normalizedPassword,
    'role': normalizedRole,
  };
  
  // Step 5: Simpan ke Shared Preferences
  await _saveAccounts();
  return true;  // Sukses
}
```

**Validasi yang dilakukan:**
- ✅ Username tidak kosong
- ✅ Password tidak kosong
- ✅ Role tidak kosong
- ✅ Username belum terdaftar (no duplicates)
- ✅ Input di-normalize (lowercase, trim)

#### **5. Login - `login()` Method**

```dart
String? login(String username, String password) {
  // Step 1: Normalize input
  final normalizedUsername = username.trim().toLowerCase();
  final normalizedPassword = password.trim();
  
  // Step 2: Cari account di _accounts map
  final account = _accounts[normalizedUsername];
  
  // Step 3: Validasi password
  if (account == null || account['password'] != normalizedPassword) {
    return null;  // Gagal: username/password salah
  }
  
  // Step 4: Set current role & return
  _currentRole = account['role'];
  return _currentRole;  // Sukses: return role user
}
```

**Alur Login:**
1. User input username + password di LoginScreen
2. Call `AuthService.instance.login(username, password)`
3. `login()` cari username di `_accounts` map
4. Jika tidak ada → return `null` (failed login)
5. Jika password salah → return `null` (failed login)
6. Jika berhasil → set `_currentRole` & return role
7. LoginScreen check hasilnya:
   - Jika `null` → tampilkan error snackbar
   - Jika role → navigate ke Dashboard dengan role sebagai argument

---

## **🌐 API SERVICE & BACKEND INTEGRATION**

### File: `lib/services/api_service.dart`

#### **1. Konsep: Optional Backend Integration**

ApiService adalah abstraction layer untuk backend REST API. Aplikasi bisa bekerja **tanpa API** (offline-first dengan SQLite), tapi siap untuk scale dengan API di masa depan.

**Architecture:**
```
┌─────────────────────────────┐
│   UI Layer (Screens)        │
└────────┬────────────────────┘
         │
┌────────▼────────────────────┐
│ DatabaseService             │
│ (Business Logic)            │
└────┬────────────────┬───────┘
     │                │
     ▼                ▼
┌──────────────┐  ┌──────────────────┐
│  SQLite DB   │  │  ApiService      │
│  (Local)     │  │  (Backend API)   │
└──────────────┘  └──────────────────┘
```

**Flow Selection:**
```dart
bool get _useApi => ApiService.instance.isConfigured;

if (_useApi) {
  // Use backend API
  return await ApiService.instance.getStudents();
} else if (kIsWeb) {
  // Use web memory cache
  return _memoryStudents;
} else {
  // Use SQLite (default)
  return await database.query('students');
}
```

#### **2. Configuration**

File: `lib/config/app_config.dart`

```dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',  // Empty = offline mode (use SQLite)
  );

  static bool get useApi => apiBaseUrl.trim().isNotEmpty;
}
```

**Bagaimana Cara Mengaktifkan API?**

**Saat Development (testing):**
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

**Saat Production:**
```bash
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

**Jika tidak dikonfigurasi:**
```bash
flutter run  # API_BASE_URL = '' (default)
# → useApi = false
# → aplikasi gunakan SQLite lokal
```

#### **3. Core Methods - REST Operations**

##### **A. GET - Fetch Data**

```dart
// Get all students
Future<List<Student>> getStudents() async {
  final response = await http.get(_uri('/students'));
  if (response.statusCode != 200) {
    throw Exception('Gagal memuat siswa: ${response.statusCode}');
  }
  return _decodeList(response.body).map(Student.fromMap).toList();
}

// Find student by QR code
Future<Student?> findStudentByQr(String qrCode) async {
  final response = await http.get(
    _uri('/students/lookup', {'qr': qrCode.trim()}),
  );
  
  if (response.statusCode == 404) {
    return null;  // Not found
  }
  if (response.statusCode != 200) {
    throw Exception('Gagal mencari siswa');
  }
  
  return Student.fromMap(_decodeObject(response.body));
}
```

**HTTP Status Codes:**
- `200 OK` - Success
- `404 Not Found` - Resource tidak ada
- `5xx Server Error` - Error di server

##### **B. POST - Create Data**

```dart
Future<int> insertStudent(Student student) async {
  final response = await http.post(
    _uri('/students'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(student.toMap()),  // Send as JSON
  );
  
  if (response.statusCode != 201) {
    throw Exception('Gagal menambah siswa');
  }
  
  final payload = _decodeObject(response.body);
  return payload['id'] as int;  // Return created ID
}
```

**HTTP Status Code:**
- `201 Created` - Resource berhasil dibuat

##### **C. PUT - Update Data**

```dart
Future<int> updateStudent(Student student) async {
  final id = student.id;
  if (id == null) throw ArgumentError('Student id required');
  
  final response = await http.put(
    _uri('/students/$id'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(student.toMap()),
  );
  
  if (response.statusCode != 200) {
    throw Exception('Gagal mengubah siswa');
  }
  
  return 1;
}
```

##### **D. DELETE - Remove Data**

```dart
Future<int> deleteStudent(int id) async {
  final response = await http.delete(_uri('/students/$id'));
  
  if (response.statusCode != 200) {
    throw Exception('Gagal menghapus siswa');
  }
  
  return 1;
}
```

#### **4. URI Builder - URL Construction**

```dart
Uri _uri(String path, [Map<String, String>? queryParameters]) {
  final base = AppConfig.apiBaseUrl
    .trim()
    .replaceAll(RegExp(r'/$'), '');  // Remove trailing slash
  
  return Uri.parse('$base$path')
    .replace(queryParameters: queryParameters);
}
```

**Contoh Penggunaan:**
```dart
// GET /students
_uri('/students')
// Result: https://api.example.com/students

// GET /students/lookup?qr=12345
_uri('/students/lookup', {'qr': '12345'})
// Result: https://api.example.com/students/lookup?qr=12345

// PUT /students/1
_uri('/students/1')
// Result: https://api.example.com/students/1
```

#### **5. JSON Encoding/Decoding**

```dart
// Decode single object
Map<String, dynamic> _decodeObject(String body) {
  final decoded = jsonDecode(body);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return Map<String, dynamic>.from(decoded as Map);
}

// Decode array
List<Map<String, dynamic>> _decodeList(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return decoded
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  }
  return const [];
}
```

**Contoh Response:**
```json
// GET /students response
[
  {
    "id": 1,
    "name": "Budi Santoso",
    "nis": "001",
    "class_name": "X RPL A",
    "qr_code": "QRCODE001"
  },
  {...}
]

// POST /attendance response
{
  "id": 5,
  "student_id": 1,
  "date": "2024-06-14",
  "time": "07:30:00",
  "status": "Hadir"
}
```

#### **6. Error Handling Pattern**

```dart
Future<void> safeApiCall() async {
  try {
    // API call
    final students = await ApiService.instance.getStudents();
  } on SocketException {
    // Network error (no internet)
    print('Network error: no internet connection');
  } on TimeoutException {
    // Timeout (API too slow)
    print('Timeout: API took too long');
  } on Exception catch (e) {
    // Other errors
    print('Error: $e');
  }
}
```

---

## **💾 DATABASE STRUCTURE**

### File: `lib/services/database_service.dart`

#### **1. Konsep: Database Service Pattern**

- **Singleton Pattern**: Hanya 1 instance DatabaseService
- **Lazy Loading**: Database dibuka saat pertama kali diakses
- **Abstraction**: UI tidak perlu tahu detail SQLite, hanya call method

#### **2. Database Schema (SQLite)**

```sql
-- Table 1: Students
CREATE TABLE students (
  id INTEGER PRIMARY KEY AUTOINCREMENT,          -- Auto-increment ID
  name TEXT NOT NULL,                            -- Nama siswa
  nis TEXT NOT NULL UNIQUE,                      -- Nomor Induk Siswa (unique)
  class_name TEXT NOT NULL,                      -- Nama kelas (e.g., "X RPL A")
  qr_code TEXT NOT NULL UNIQUE                   -- QR Code data (unique)
);

-- Table 2: Attendance
CREATE TABLE attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,          -- Auto-increment ID
  student_id INTEGER NOT NULL,                   -- Foreign Key → students.id
  student_name TEXT NOT NULL,                    -- Nama siswa (cached)
  date TEXT NOT NULL,                            -- Tanggal (format: yyyy-MM-dd)
  time TEXT NOT NULL,                            -- Waktu (format: HH:mm:ss)
  status TEXT NOT NULL,                          -- Status: Hadir/Terlambat/Tidak Hadir
  FOREIGN KEY (student_id) REFERENCES students(id)  -- Constraint
);
```

**Why These Columns?**

| Column | Reason |
|--------|--------|
| `nis UNIQUE` | Mencegah siswa double-entry |
| `qr_code UNIQUE` | Setiap siswa punya QR unik |
| `student_name` di attendance | Caching untuk performa (avoid JOIN) |
| `date TEXT` | Lebih mudah untuk filter/report |
| `status TEXT` | Flexible untuk tambah status baru |

#### **3. Core Methods**

##### **A. getStudents() - Ambil semua siswa**

```dart
Future<List<Student>> getStudents() async {
  // Cek priority: API > Web Memory > SQLite
  if (_useApi) {
    return ApiService.instance.getStudents();
  }
  
  if (kIsWeb) {
    return List<Student>.from(_memoryStudents)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  
  final db = await database;
  final result = await db.query('students', orderBy: 'name ASC');
  return result.map(Student.fromMap).toList();
}
```

**Multi-Backend Support:**
1. **API Priority**: Jika backend ada, gunakan API (cloud sync)
2. **Web Fallback**: Di web, gunakan in-memory list
3. **SQLite Default**: Di mobile, gunakan SQLite

##### **B. findStudentByQr() - Cari siswa by QR/NIS**

```dart
Future<Student?> findStudentByQr(String qrCode) async {
  final normalizedCode = qrCode.trim();
  
  // Query mencari by QR OR NIS (karena QR bisa berisi NIS)
  final db = await database;
  final result = await db.query(
    'students',
    where: 'qr_code = ? OR nis = ?',           // Search by QR or NIS
    whereArgs: [normalizedCode, normalizedCode],
    limit: 1,                                   // Only first match
  );
  
  if (result.isEmpty) return null;
  return Student.fromMap(result.first);
}
```

**Mengapa `OR nis = ?`?**
- QR code bisa contain NIS
- Flexible scanning: scan QR OR input NIS langsung

##### **C. insertAttendance() - Simpan absensi**

```dart
Future<int> insertAttendance(Attendance attendance) async {
  final db = await database;
  final id = await db.insert('attendance', attendance.toMap());
  _dataChangesController.add(null);  // Notify listeners
  return id;
}
```

**Proses:**
1. Convert `Attendance` object → Map (SQL-compatible)
2. Insert ke database
3. Emit event ke listeners (refresh UI)
4. Return inserted ID

##### **D. hasAttendanceToday() - Cek duplikasi absensi**

```dart
Future<bool> hasAttendanceToday(int studentId, String date) async {
  final db = await database;
  final result = await db.query(
    'attendance',
    where: 'student_id = ? AND date = ?',
    whereArgs: [studentId, date],
    limit: 1,
  );
  return result.isNotEmpty;
}
```

**Kegunaan:**
- Cegah siswa scan 2x dalam sehari
- Tampilkan warning jika sudah absen

#### **4. Data Change Notification System**

```dart
final StreamController<void> _dataChangesController =
    StreamController<void>.broadcast();

Stream<void> get dataChanges => _dataChangesController.stream;

// Setiap kali data berubah:
_dataChangesController.add(null);  // Emit event
```

**Alur:**
1. User scan QR → insertAttendance()
2. insertAttendance() emit event
3. ReportScreen listen ke event
4. Ketika event received → rebuild UI (fresh data)

**Keuntungan Stream approach:**
- UI otomatis update tanpa manual refresh
- Real-time feedback untuk user
- Efficient: hanya update ketika ada data changes

---

## **🔍 QR SCANNING LOGIC**

### File: `lib/screens/scan_screen.dart`

#### **1. QR Scanning Setup**

```dart
class _ScanScreenState extends State<ScanScreen> {
  static const int _onTimeHour = 7;           // Jam masuk on-time
  static const int _onTimeMinute = 30;        // Menit masuk on-time
  static const int _lateGraceMinutes = 15;    // Grace period: 15 menit
  static const Duration _successDialogDuration = Duration(seconds: 2);
  
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,  // Don't repeat same QR
  );
  
  bool _isProcessing = false;  // Prevent concurrent processing
}
```

**Konfigurasi:**
- On-time: **07:30**
- Grace period: **15 menit** (sampai 07:45 masih "Hadir")
- Setelah 07:45: status "Terlambat"
- Lebih dari 08:00-an: status "Tidak Hadir"

#### **2. Scanning Flow - `_onDetect()` Method**

```dart
Future<void> _onDetect(BarcodeCapture capture) async {
  // ===== STEP 1: Prevent Concurrent Processing =====
  if (_isProcessing) {
    return;  // Already processing, ignore this scan
  }
  
  // ===== STEP 2: Extract QR Raw Value =====
  final rawValue = capture.barcodes.firstOrNull?.rawValue;
  if (rawValue == null || rawValue.trim().isEmpty) {
    return;  // No valid barcode detected
  }
  
  // ===== STEP 3: Extract NIS from QR Code =====
  final extracted = _extractNis(rawValue);
  
  // ===== STEP 4: Set Processing Flag =====
  _isProcessing = true;
  
  try {
    // ===== STEP 5: Query Database =====
    final student = await DatabaseService.instance
        .findStudentByQr(extracted);
    
    if (student == null) {
      // Student not found
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('QR tidak terdaftar sebagai siswa'))
      );
      return;
    }
    
    // ===== STEP 6: Calculate Attendance Status =====
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final time = DateFormat('HH:mm:ss').format(now);
    
    // Convert time to minutes for comparison
    final scanMinutes = now.hour * 60 + now.minute;
    final onTimeMinutes = _onTimeHour * 60 + _onTimeMinute;  // 7:30 = 450 minutes
    final lateLimitMinutes = onTimeMinutes + _lateGraceMinutes;  // 7:45 = 465 minutes
    
    String status;
    if (scanMinutes <= onTimeMinutes) {
      status = 'Hadir';
    } else if (scanMinutes <= lateLimitMinutes) {
      status = 'Terlambat';
    } else {
      status = 'Tidak Hadir';
    }
    
    // ===== STEP 7: Check Duplicate Attendance Today =====
    final alreadyAttendance = await DatabaseService.instance
        .hasAttendanceToday(student.id!, date);
    
    if (alreadyAttendance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} sudah absen hari ini.'))
      );
      return;
    }
    
    // ===== STEP 8: Insert Attendance Record =====
    await DatabaseService.instance.insertAttendance(
      Attendance(
        studentId: student.id!,
        studentName: student.name,
        date: date,
        time: time,
        status: status,
      ),
    );
    
    // ===== STEP 9: Show Success Dialog =====
    await _showSuccessDialog(
      studentName: student.name,
      status: status,
      date: date,
      time: time,
    );
    
  } finally {
    // ===== STEP 10: Reset Processing Flag =====
    _isProcessing = false;
  }
}
```

**Flow Diagram:**
```
Scan QR Code
    ↓
Extract NIS from QR
    ↓
Query: Find Student by QR/NIS
    ├─ Not Found? → Show Error & Return
    └─ Found? → Continue
    ↓
Get Current Time
    ↓
Calculate Status based on Time
    ├─ <= 07:30 → Status = "Hadir"
    ├─ 07:30 < time <= 07:45 → Status = "Terlambat"
    └─ > 07:45 → Status = "Tidak Hadir"
    ↓
Check: Sudah absen hari ini?
    ├─ Yes? → Show "Sudah absen" & Return
    └─ No? → Continue
    ↓
Insert Attendance Record to Database
    ↓
Show Success Dialog
    ↓
Reset Processing Flag
```

#### **3. NIS Extraction - `_extractNis()` Method**

```dart
String _extractNis(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  
  // Remove all whitespaces
  final cleaned = trimmed.replaceAll(RegExp(r'\s+'), '');
  
  // Try to parse as URI for query param or last path segment
  try {
    final uri = Uri.parse(cleaned);
    
    // Try to get query parameter first
    if (uri.queryParameters.isNotEmpty) {
      final value = uri.queryParameters.values.firstOrNull;
      if (value != null && value.isNotEmpty) {
        return value;  // Found: return query param
      }
    }
    
    // If no query param, get last path segment
    if (uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.isNotEmpty) {
        return lastSegment;  // Found: return last segment
      }
    }
  } catch (e) {
    // Parsing as URI failed, continue
  }
  
  // No QR data found, return cleaned input as-is
  return cleaned;
}
```

**Contoh QR Data Parsing:**

| QR Input | Extracted | Reason |
|----------|-----------|--------|
| `12345` | `12345` | Plain number |
| `http://example.com?nis=12345` | `12345` | Query parameter |
| `http://example.com/12345` | `12345` | URL path segment |
| `12 34 5` | `12345` | Whitespace removed |

#### **4. Success Dialog**

```dart
Future<void> _showSuccessDialog({
  required String studentName,
  required String status,
  required String date,
  required String time,
}) async {
  final statusColor = status == 'Hadir'
      ? Colors.green
      : status == 'Terlambat'
      ? Colors.orange
      : Colors.red;
  
  showDialog(
    barrierDismissible: false,  // Can't dismiss by tapping outside
    builder: (context) {
      return AlertDialog(
        // Show student name + status + date + time
      );
    },
  );
  
  // Auto-close after 2 seconds
  await Future<void>.delayed(Duration(seconds: 2));
  Navigator.pop(context);
}
```

**Kegunaan:**
- Confirm scanning success ke user
- Tampilkan info: nama siswa, status, waktu
- Auto-close setelah 2 detik (continue scanning)

---

## **📊 REPORT GENERATION & FILTERING**

### File: `lib/screens/report_screen.dart`

#### **1. Report Screen Architecture**

```dart
class _ReportScreenState extends State<ReportScreen> {
  Timer? _timer;                          // Auto-refresh timer
  List<_ReportItem> _reportItems = [];    // Filtered report data
  String? dateFilter;                     // Selected date filter
  bool _isLoading = true;
}
```

#### **2. Auto-Refresh Mechanism**

```dart
@override
void initState() {
  super.initState();
  _loadAttendance();
  
  // Auto-refresh every 30 seconds
  _timer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => _loadAttendance(),
  );
}

@override
void dispose() {
  _timer?.cancel();  // Important: cleanup resources
  super.dispose();
}
```

**Mengapa perlu auto-refresh?**
- User dapat melihat data terbaru secara real-time
- Ketika guru lain scan di kelas lain, laporan update otomatis
- 30 detik interval: balance antara freshness & performance

#### **3. Loading Attendance Data**

```dart
Future<void> _loadAttendance() async {
  if (!mounted) return;  // Prevent setState after dispose
  
  setState(() {
    _isLoading = true;  // Show loading indicator
  });
  
  // Fetch all attendance records
  final attendanceData = 
      await DatabaseService.instance.getAttendance();
  
  final selectedDate = dateFilter;
  
  List<_ReportItem> items;
  if (selectedDate == null) {
    // No filter: show all attendance
    items = attendanceData
        .map((attendance) => _ReportItem(
          attendanceId: attendance.id,
          studentId: attendance.studentId,
          studentName: attendance.studentName,
          date: attendance.date,
          time: attendance.time,
          status: attendance.status,
        ))
        .toList();
  } else {
    // With date filter: build daily report for selected date
    final students = await DatabaseService.instance.getStudents();
    items = _buildDailyReportItems(
      students: students,
      attendanceData: attendanceData,
      date: selectedDate,
    );
  }
  
  if (mounted) {
    setState(() {
      _reportItems = items;
      _isLoading = false;
    });
  }
}
```

**Dua Mode Report:**

**Mode 1: All Attendance (No Date Filter)**
```
Menampilkan semua record absensi:
- 2024-06-14, 07:30, Budi Santoso, Hadir
- 2024-06-14, 07:45, Ahmad Wijaya, Terlambat
- 2024-06-13, 07:00, Budi Santoso, Hadir
...
```

**Mode 2: Daily Report (With Date Filter)**
```
Menampilkan status absensi semua siswa untuk satu hari:
- Budi Santoso, Hadir, 07:30
- Ahmad Wijaya, Terlambat, 07:45
- Siti Nurhaliza, Tidak Hadir, -
- Rina Putri, Hadir, 07:15
...
```

#### **4. Building Daily Report**

```dart
List<_ReportItem> _buildDailyReportItems({
  required List<Student> students,
  required List<Attendance> attendanceData,
  required String date,
}) {
  // Create map: studentId → Attendance record for quick lookup
  final attendanceByStudentId = <int, Attendance>{
    for (final item in attendanceData) 
      item.studentId: item,
  };
  
  // For each student, check if they have attendance today
  final items = students.map((student) {
    final attendance = attendanceByStudentId[student.id];
    
    if (attendance != null) {
      // Student has attendance record today
      return _ReportItem(
        attendanceId: attendance.id,
        studentName: student.name,
        studentId: student.id,
        date: attendance.date,
        time: attendance.time,
        status: attendance.status,
      );
    } else {
      // Student has NO attendance record today
      return _ReportItem(
        studentName: student.name,
        studentId: student.id,
        date: date,
        time: '-',
        status: 'Tidak Absen',  // Default status
      );
    }
  }).toList();
  
  return items;
}
```

**Algoritma:**
1. Buat map `studentId → Attendance` untuk O(1) lookup
2. Loop semua students
3. Untuk setiap student:
   - Cek apakah ada attendance record di map
   - Jika ada: gunakan attendance data
   - Jika tidak: create default "Tidak Absen" record
4. Return full list (semua siswa)

**Keuntungan approach ini:**
- ✅ Semua siswa tampil di report (tidak ada yang terlewat)
- ✅ Mudah lihat siapa yang tidak absen
- ✅ Efficient: O(n) complexity

#### **5. Edit Attendance (Role-Based Access)**

```dart
// In ReportScreen build method
ElevatedButton.icon(
  onPressed: 
    // Only allow edit if user is Admin or Guru
    (AuthService.instance.currentRole?.contains('admin') ?? false) ||
    (AuthService.instance.currentRole?.contains('guru') ?? false)
    ? () => _editAttendance(item)
    : null,
  icon: const Icon(Icons.edit),
  label: const Text('Edit'),
)
```

**RBAC Implementation:**
- Admin: dapat edit semua attendance
- Guru: dapat edit attendance di kelasnya
- Student: read-only (tidak ada di aplikasi ini)

---

## **📦 DATA MODELS**

### File: `lib/models/student.dart`

```dart
class Student {
  final int? id;              // Database ID (null before insert)
  final String name;          // Nama siswa
  final String nis;           // Nomor Induk Siswa
  final String className;     // Nama kelas (e.g., "X RPL A")
  final String qrCode;        // QR Code data
  
  // ===== toMap() =====
  // Convert Dart object → Map (for SQL insert/update)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nis': nis,
      'class_name': className,
      'qr_code': qrCode,
    };
  }
  
  // ===== fromMap() =====
  // Convert Map (from SQL query) → Dart object
  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] as int?,
      name: map['name'] as String,
      nis: map['nis'] as String,
      className: map['class_name'] as String,
      qrCode: map['qr_code'] as String,
    );
  }
  
  // ===== copyWith() =====
  // Create new instance with some fields changed
  Student copyWith({
    int? id,
    String? name,
    String? nis,
    String? className,
    String? qrCode,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      nis: nis ?? this.nis,
      className: className ?? this.className,
      qrCode: qrCode ?? this.qrCode,
    );
  }
}
```

**Mengapa `toMap()` & `fromMap()`?**

SQLite bekerja dengan Map:
```dart
// Insert
final id = await db.insert('students', student.toMap());

// Query
final result = await db.query('students');  // Returns List<Map>
return result.map(Student.fromMap).toList();  // Convert to List<Student>
```

**Mengapa `copyWith()`?**
```dart
// Update one field, keep others same
final updated = student.copyWith(name: 'New Name');
// Result: Student(id: 1, name: 'New Name', nis: '12345', ...)
```

### File: `lib/models/attendance.dart`

```dart
class Attendance {
  final int? id;              // Database ID
  final int studentId;        // Foreign key → students.id
  final String studentName;   // Student name (cached)
  final String date;          // Format: yyyy-MM-dd
  final String time;          // Format: HH:mm:ss
  final String status;        // Hadir / Terlambat / Tidak Hadir / Dispensasi
  
  // Same pattern: toMap(), fromMap()
}
```

---

## **🎨 DESIGN PATTERNS**

### **1. Singleton Pattern (AuthService, DatabaseService)**

**Tujuan:** Ensure only 1 instance exists

```dart
class AuthService {
  AuthService._();  // Private constructor
  static final AuthService instance = AuthService._();  // Static instance
}

// Usage:
AuthService.instance.login(user, pass);  // Always same instance
```

**Keuntungan:**
- Global access point
- Single state management
- Memory efficient

---

### **2. Repository Pattern (DatabaseService)**

**Tujuan:** Abstract data source behind interface

```dart
// DatabaseService menyembunyikan SQL details
class DatabaseService {
  // UI tidak perlu tahu SQLite, hanya call methods
  Future<List<Student>> getStudents()
  Future<int> insertStudent(Student student)
  Future<int> updateStudent(Student student)
}

// Usage in UI:
final students = await DatabaseService.instance.getStudents();
// (UI tidak perlu import sqflite)
```

**Keuntungan:**
- Easier to test (mock database)
- Easy to switch database (SQLite → Firebase)
- Decoupled UI from data source

---

### **3. Observer Pattern (StreamController)**

**Tujuan:** Notify listeners when data changes

```dart
final StreamController<void> _dataChangesController =
    StreamController<void>.broadcast();

Stream<void> get dataChanges => _dataChangesController.stream;

// When data changes:
_dataChangesController.add(null);  // Emit event

// In UI:
DatabaseService.instance.dataChanges.listen((_) {
  // Refresh UI when this event received
  _loadAttendance();
});
```

**Keuntungan:**
- Reactive updates
- Decoupled components
- Real-time UI refresh

---

### **4. Model Conversion Pattern (toMap/fromMap)**

**Tujuan:** Bridge between Dart objects & SQL data

```dart
// Dart object → SQL insert
final id = await db.insert('students', student.toMap());

// SQL query → Dart objects
final result = await db.query('students');
return result.map(Student.fromMap).toList();
```

---

## **🚀 KEY ALGORITHMS**

### **1. Attendance Status Calculation**

```
Time Mapping:
- 07:30 = 7*60 + 30 = 450 minutes
- 07:45 = 7*60 + 45 = 465 minutes

Current time → minutes:
- now.hour * 60 + now.minute

Status logic:
```
if (scanMinutes <= 450)        → "Hadir"
else if (scanMinutes <= 465)   → "Terlambat"
else                           → "Tidak Hadir"
```
```

### **2. QR Code Extraction**

```
Input: URL atau plain number dari QR code
Output: Extracted NIS

Algorithm:
1. Remove whitespaces
2. Try parse as URI:
   a. Check query parameters (e.g., nis=12345)
   b. Check last path segment (e.g., /scan/12345)
3. If URI parsing fails, return cleaned input as-is
```

### **3. Duplicate Prevention**

```
Problem: User scan 2x sehari untuk student yang sama

Solution:
- Before insert attendance
- Query: SELECT * FROM attendance 
         WHERE student_id = ? AND date = ?
- If found → show error
- If not found → proceed with insert
```

---

## **✅ BEST PRACTICES DITERAPKAN**

✓ **Error Handling**: Try-catch blocks, null safety  
✓ **Resource Management**: Timer disposal, stream cleanup  
✓ **Input Validation**: Normalize, trim, check empty  
✓ **Separation of Concerns**: UI ≠ Business Logic ≠ Data  
✓ **Design Patterns**: Singleton, Repository, Observer  
✓ **Performance**: Memory efficiency, O(n) algorithms  
✓ **Security**: Role-based access control  
✓ **Maintainability**: Clear code, meaningful names  

---

## **🔗 DEPENDENCIES**

| Package | Purpose |
|---------|---------|
| `sqflite` | Local SQLite database |
| `mobile_scanner` | QR code scanning |
| `shared_preferences` | Persist auth data |
| `intl` | Date/time formatting |
| `http` | API communication |
| `pdf` | Generate PDF reports |
| `share_plus` | Share functionality |

---

**End of Documentation**
