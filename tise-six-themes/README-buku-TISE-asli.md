# Buku Quarto — Enam Tema Kompetensi Akademik Berbantuan AI

Proyek buku berbasis diskusi TISE, disusun 22 November 2026. Semua ilustrasi tema yang tersedia telah ditempatkan pada bab masing-masing.

## Render

```bash
quarto preview
quarto render --to html
quarto render --to epub
```

Format yang digunakan adalah `book` bawaan Quarto (tema HTML Cosmo dengan CSS kustom). Referensi yang diberikan pengguna `https://quarto.org/docs/extensions/listing-formats.html` adalah katalog ekstensi format, bukan template buku khusus. Buku bawaan dipilih karena tidak membutuhkan dependensi ekstensi tambahan.

**Catatan**: Quarto CLI tidak tersedia pada lingkungan penyusunan ini sehingga output HTML/EPUB belum di-render atau diuji secara langsung. Semua sumber, konfigurasi, aset, dan contoh disertakan untuk dirender di komputer Anda.

## Periksa sebelum digunakan formal

- Rumus dan data kasus Bayes telah diverifikasi secara aritmetika.
- Dataset eksternal hanya dicantumkan sebagai tautan; data mentah tidak disertakan.
- Infografik perlu diperiksa ulang jika dijadikan sumber numerik; teks bab merupakan rujukan utama.
- Klaim/rujukan ilmiah dan peraturan perlu dicek kembali terhadap sumber terkini.
