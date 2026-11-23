# 🚀 API SERVICE - CHEAT SHEET SIDANG

## **RINGKAS JAWAB DALAM 30 DETIK**

### **Q: "Apa itu API Service dan perlu kah?"**

**Jawab (Pendek):**
> "API Service adalah **opsional backend integration** untuk future scalability.
> 
> Saat ini: tidak perlu (gunakan SQLite lokal)
> Nanti: perlu untuk multi-device sync & cloud backup
> 
> Aplikasi bisa bekerja **2 mode**:
> - Offline (SQLite) → saat ini
> - Cloud (API) → di masa depan
> 
> Desain untuk flexibility: bisa switch tanpa ubah UI"

**Waktu:** 20-30 detik ✅

---

## **KEY POINTS UNTUK DIINGAT**

### **1. Bagaimana Aplikasi Memilih Backend?**

```
┌─────────────────────┐
│ Check API_BASE_URL  │
└────┬────────────────┘
     │
  Ada? ───→ Use API
     │
  Tidak ──→ Use SQLite
```

**Kode:**
```dart
if (ApiService.instance.isConfigured) {
  // Use API
} else {
  // Use SQLite
}
```

### **2. 3 REST Methods yang Perlu Diingat**

| Method | Untuk | Status |
|--------|-------|--------|
| **GET** | Ambil data | 200 OK |
| **POST** | Buat data | 201 Created |
| **PUT** | Update data | 200 OK |
| **DELETE** | Hapus data | 200 OK |

**Contoh:**
```
GET    /students              → Ambil semua
POST   /students              → Buat siswa baru
PUT    /students/1            → Update siswa 1
DELETE /students/1            → Hapus siswa 1
```

### **3. Response Format**

**GET Response:**
```json
[
  { "id": 1, "name": "Budi", "nis": "001" },
  { "id": 2, "name": "Ahmad", "nis": "002" }
]
```

**POST Response:**
```json
{ "id": 3, "name": "Siti", "nis": "003" }
```

### **4. Kapan Perlu API?**

❌ **Tidak Perlu Sekarang:**
- Single school usage
- Data sudah cukup di lokal
- Tidak perlu multi-device sync
- Performa: SQLite lebih cepat

✅ **Perlu di Masa Depan:**
- 10+ sekolah
- Multi-device sync
- Cloud backup
- Real-time collaboration

---

## **JAWABAN UNTUK PERTANYAAN LANJUTAN**

### **Q: "Backend sudah ada?"**

**A:** Ada template di folder `backend/` tapi belum production-ready.
- Node.js + Express
- Bisa dikembangkan lebih lanjut
- Belum integrate dengan mobile app sekarang

### **Q: "Jika API down, apa aplikasi error?"**

**A:** 
- Jika saat ini gunakan SQLite → tetap jalan (no API call)
- Jika future pakai API:
  - Bisa implement fallback ke SQLite cache
  - Atau show user-friendly error message

### **Q: "Mengapa tidak langsung pakai API dari awal?"**

**A:**
1. **Offline-first better**: User bisa scan absensi tanpa internet
2. **Development faster**: Tidak perlu setup server dulu
3. **Security simpler**: Tidak perlu API authentication layer
4. **Performa lebih baik**: Local database lebih cepat
5. **Cost lebih murah**: Tidak perlu server hosting

### **Q: "Bagaimana implementasi API di backend?"**

**A (jika ditanya detail):**

```javascript
// Node.js Express
const express = require('express');
const app = express();

// GET /students
app.get('/students', (req, res) => {
  const students = database.getAll('students');
  res.json(students);  // Return array
});

// POST /students
app.post('/students', (req, res) => {
  const { name, nis, class_name, qr_code } = req.body;
  const id = database.insert('students', { ... });
  res.status(201).json({ id });
});

// PUT /students/:id
app.put('/students/:id', (req, res) => {
  database.update('students', req.params.id, req.body);
  res.json({ success: true });
});

// DELETE /students/:id
app.delete('/students/:id', (req, res) => {
  database.delete('students', req.params.id);
  res.json({ success: true });
});
```

---

## **QUICK COMPARISON**

### **SQLite vs API**

```
╔════════════════╦═════════════╦════════════╗
║ Aspek          ║ SQLite      ║ API        ║
╠════════════════╬═════════════╬════════════╣
║ Performa       ║ ⚡⚡⚡⚡⚡   ║ ⚡⚡⚡     ║
║ Offline        ║ ✅ Ya       ║ ❌ Tidak   ║
║ Multi-device   ║ ❌ Tidak    ║ ✅ Ya      ║
║ Backup         ║ Manual      ║ Otomatis   ║
║ Setup          ║ Mudah       ║ Kompleks   ║
║ Skalabilitas   ║ Terbatas    ║ Unlimited  ║
╚════════════════╩═════════════╩════════════╝
```

---

## **TIPS JAWAB DI SIDANG**

✅ **DO:**
- Jelaskan: "Saat ini tidak perlu, untuk flexibility di masa depan"
- Tunjukkan kode: `AppConfig.useApi` dan `_useApi` logic
- Jika ada api_service tapi tidak dipakai → "Ini best practice design"

❌ **DON'T:**
- Jangan bilang "ini unnecessary" (itu bukan best practice)
- Jangan jelaskan backend detail jika belum ditanya
- Jangan terlalu technical jika dosen masih general-level

---

## **MEMORIZE THIS**

> "API Service adalah **optional layer** untuk future scalability.
> 
> Aplikasi **offline-first** dengan SQLite, 
> tapi **ready untuk cloud** dengan API.
> 
> Desain: **flexibility & maintainability**."

---

**Print & Baca Sebelum Sidang! 📋**
