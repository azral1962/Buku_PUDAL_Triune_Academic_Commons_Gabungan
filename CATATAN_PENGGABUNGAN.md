# Catatan penggabungan buku (22 November 2026)

## Prinsip

1. **PUDAL** adalah buku induk: semua 17 bab dan empat lampiran tetap dipertahankan.
2. **TISE Six Themes** menjadi **Bagian IV**; konten sembilan bab tematik dan kerangka, pengantar, referensi, gambar, serta lampiran tersertakan.
3. Bab **Penutup** buku PUDAL tetap berada setelah Bagian IV, lalu lampiran terpadu.
4. Seluruh aset TISE dipisahkan di `tise-six-themes/` untuk menghindari tabrakan nama file.
5. Referensi BibTeX TISE digunakan pada level buku dan gaya HTML TISE dilampirkan dalam konfigurasi global.

## Pemetaan

| Buku kedua | Lokasi gabungan |
|---|---|
| `index.qmd` | `tise-six-themes/00-pengantar-enam-tema.qmd` |
| `01-kerangka-tise.qmd` | `tise-six-themes/01-kerangka-tise.qmd` |
| `02-tema1-learning.qmd`–`07-tema6-problem-solving.qmd` | File sama di `tise-six-themes/` |
| `08-implementasi-asesmen.qmd` | `tise-six-themes/08-implementasi-asesmen.qmd` |
| `09-template-kerja.qmd` | `tise-six-themes/09-template-kerja.qmd` |
| `references.qmd`, `references.bib` | Di dalam `tise-six-themes/` |
| `appendix-tools.qmd` | Lampiran terakhir buku gabungan |
| `images/`, `styles/`, `templates/` | Folder sama di dalam `tise-six-themes/` |

## Perubahan editorial minimal

- Pengantar buku kedua berganti judul agar berfungsi sebagai bab pembuka Bagian IV dan diberi pengait ke kerangka buku induk.
- Prakata buku induk mencantumkan Bagian IV dan tautan antara buku.
- Bab `13-enam-learning-paths.qmd` menambahkan tabel tautan enam modul.
- Lampiran sumber buku induk mencatat asal Bagian IV, dan lampiran teknis buku kedua menambahkan petunjuk render dari akar proyek.
- Naskah keenam modul, kasus, rumus, ilustrasi, serta rubrik tetap dipertahankan.
- **Normalisasi teknis gambar:** 21 aset asli ternyata berisi file WebP dengan ekstensi `.png`; seluruhnya dikonversi lossless menjadi PNG sebenarnya (tanpa mengubah ukuran atau isi visual) demi kompatibilitas Quarto/EPUB/PDF.

## Status pemeriksaan

Penggabungan dipastikan melalui pemeriksaan sintaks YAML, keberadaan berkas bab, pemeriksaan tautan lokal, serta pembukaan semua gambar. Render Quarto perlu dicoba pada komputer yang sudah memasang Quarto CLI.
