// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#import "@preview/orange-book:0.7.1": book, part, chapter, appendices

#show: book.with(
  title: [PUDAL: Navigasi Cerdas, Engine, dan Pembelajaran Adaptif],
  subtitle: [Dari Titik A ke B melalui Graf, Milestones, Energi, Mixed Engines, dan Triune Academic Commons],
  author: "Pengembangan konseptual dari diskusi KIPP --- naskah kerja",
  date: "2026-11-22",
  lang: "id",
  main-color: brand-color.at("primary", default: blue),
  logo: {
    let logo-info = brand-logo.at("medium", default: none)
    if logo-info != none { image(logo-info.path, alt: logo-info.at("alt", default: none)) }
  },
  outline-depth: 3,
  supplement-chapter: "Bab",
)


// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

#heading(level: 1, numbering: none)[Prakata]
<prakata>
#figure([
#box(image("images/overview.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Enam learning paths dan hubungan Knowledge, Skills, Prompts, serta Case Study dalam KIPP Triune Academic Commons.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-overview-1>


#heading(level: 2, numbering: none)[Tentang buku ini]
<tentang-buku-ini>
Buku ini mengembangkan sebuah gagasan yang tumbuh bertahap melalui diskusi proyek #strong[KIPP (Komunikasi Interpersonal dan Publik)]: seseorang atau suatu sistem perlu berpindah dari keadaan awal #strong[A] menuju keadaan tujuan #strong[B]. Perpindahan itu memerlukan peta keadaan dan rute, tujuan antara, kemampuan menjalankan pekerjaan, sumber daya lingkungan, serta mekanisme untuk belajar dan mengubah strategi. Keseluruhan proses dikendalikan melalui #strong[PUDAL --- Perceive, Understand, Decide, Act, Learn].

Gagasan berkembang dari learning paths enam tema akademik menjadi model #strong[Hierarchical Adaptive Resource-Aware PUDAL Navigation and Learning Engine]. Di dalamnya terdapat lima fungsi yang masing-masing dapat menjalankan putaran PUDAL: #emph[Orientation, Understanding, Planning, Execution,] dan #emph[Learning]. Engine dapat bekerja secara #strong[natural, instrumental,] dan #strong[vehicular], termasuk dalam kombinasi antartahap.

Buku ini juga menjelaskan penerapannya pada proyek UAS #strong[Triune Academic Commons]: 12 kelompok mahasiswa, 6 learning paths/agen akademik, dan 42 artefak. Gambar yang dihasilkan pada percakapan awal disertakan sebagai bahan visual pembelajaran. Rumus matematika dan skema kendali adalah #strong[formalisasi konseptual yang diusulkan], bukan hasil validasi empiris atau model fisika tunggal untuk semua jenis sumber daya.

#heading(level: 2, numbering: none)[Cara membaca]
<cara-membaca>
- #strong[Bagian I]: tujuan komunikasi, TAIDA, Triune Intelligence, dan empat pendekatan pengembangan artefak.
- #strong[Bagian II]: graf masalah, engine, sumber daya dan energi, lima PUDAL, milestones, pembelajaran, dan formulasi matematis.
- #strong[Bagian III]: implementasi enam agen, enam learning paths, proyek UAS, repositori, evaluasi, dan agenda penelitian.
- #strong[Bagian IV]: pendalaman enam tema TISE (Learning, Literature Study, Academic Writing, Computational & Data Literacy, Visualization, Problem Solving) sebagai modul, kasus, langkah kerja, rubrik, dan template asesmen.
- #strong[Lampiran]: daftar artefak, templat kasus, istilah, asal bahan dan indeks gambar, serta panduan perangkat dan pembangunan Quarto.

#quote(block: true)[
#strong[Tesis utama:] PUDAL mengendalikan pilihan dan operasi engine yang memanfaatkan sumber daya lingkungan untuk melakukan kerja sehingga sistem dapat menempuh transisi dari A melalui milestones menuju B; pembelajaran dan eksplorasi memperluas serta memperbaiki peta dan kemampuan untuk mencapai tujuan.
]

#strong[Status:] naskah sintesis dan rancangan pedagogis, disusun dari rangkaian diskusi hingga 22 November 2026. Penetapan bobot UAS serta penggunaan resmi di kelas memerlukan persetujuan pengampu mata kuliah.

#heading(level: 2, numbering: none)[Hubungan buku induk dan enam tema]
<hubungan-buku-induk-dan-enam-tema>
Buku ini menggabungkan #strong[rancangan navigasi PUDAL dan Triune Academic Commons] dengan #strong[buku Enam Tema Kompetensi Akademik Berbasis TISE] sebagai Bagian IV. Keberhasilan dibedakan menjadi #strong[hasil kerja] dan #strong[hasil belajar], sehingga AI tidak hanya menyelesaikan tugas, tetapi membantu manusia menjadi lebih mampu. Mulailah dari #link("13-enam-learning-paths.qmd")[peta enam learning paths], kemudian lanjutkan ke #link("tise-six-themes/00-pengantar-enam-tema.qmd")[pengantar Bagian IV].

#part[BAGIAN I — KERANGKA DASAR]
= Mengapa Perjalanan dari A ke B?
<mengapa-perjalanan-dari-a-ke-b>
== Masalah sebagai perubahan keadaan
<masalah-sebagai-perubahan-keadaan>
Persoalan akademik, perjalanan fisik, proyek kelompok, maupun kehidupan profesional dapat dijelaskan sebagai upaya mengubah #strong[keadaan awal] menjadi #strong[keadaan tujuan]. Seseorang berada pada A, membayangkan B, tetapi belum tentu mengetahui jalan menuju B. Bahkan jika rute diketahui, kemampuan, waktu, energi, uang, atau akses terhadap layanan belum tentu mencukupi.

Misalnya mahasiswa menghadapi lembar jawaban kosong (A) dan perlu menghasilkan jawaban yang benar serta dapat dipertanggungjawabkan (B). Antara keduanya ada kegiatan memahami soal, memilih rumus atau metode, mengerjakan, memeriksa, merevisi, dan menyimpulkan. Tiap kegiatan mengubah keadaan pekerjaan. Dengan demikian, penyelesaian tidak cukup dipahami sebagai satu tindakan tunggal; ia merupakan #strong[perjalanan melalui rangkaian keadaan antara].

== Tiga masalah yang berbeda
<tiga-masalah-yang-berbeda>
+ #strong[Masalah pengetahuan:] peta atau rute belum diketahui. Dibutuhkan eksplorasi dan pengembangan representasi persoalan.
+ #strong[Masalah keputusan:] banyak rute tersedia tetapi belum diketahui mana yang layak dan bernilai. Dibutuhkan evaluasi waktu, biaya, risiko, serta hasil.
+ #strong[Masalah kapasitas:] rute dipahami dan dipilih, tetapi belum tersedia kemampuan atau sumber daya untuk menjalankannya. Dibutuhkan engine, suplai, pengembangan skills, atau rute alternatif.

Perbedaan itu menghasilkan kebutuhan terhadap #emph[Orientation, Understanding, Planning, Execution,] dan #emph[Learning] sebagai lima fungsi PUDAL berjenjang.

== Dari jalan ke strategi
<dari-jalan-ke-strategi>
Perjalanan yang sulit dapat dipecah menjadi #strong[stages], masing-masing berakhir pada #strong[milestones] terukur. Milestone bukan hanya tanda kemajuan: ia adalah titik pemeriksaan sumber daya, pergantian engine, perundingan ulang strategi, atau aktivasi siklus pembelajaran. Ketika realitas tidak sesuai rencana, agen perlu melakukan #emph[replanning], bukan memaksakan rute lama.

== Pertanyaan besar buku
<pertanyaan-besar-buku>
Bagaimana tujuan ditentukan? Bagaimana peta masalah dibangun? Bagaimana rute dan engine dipilih? Bagaimana sumber daya luar diperoleh dan dikonversi menjadi kerja? Bagaimana milestone dipakai untuk pengendalian adaptif? Dan bagaimana proses belajar mengubah himpunan rute yang dapat ditempuh? Kelima pertanyaan menuntun keseluruhan pembahasan.

== Membaca persoalan melalui keadaan, tindakan, dan bukti
<membaca-persoalan-melalui-keadaan-tindakan-dan-bukti>
Perubahan keadaan menjadi berguna sebagai model ketika kita menyebut apa yang berubah dan siapa yang menilainya. "Mahasiswa sudah mengerjakan tugas" menyatakan aktivitas, sedangkan "mahasiswa dapat menjelaskan dua alasan dan mempertahankannya dengan sumber" menyatakan kemampuan yang bisa diuji. Perbedaan ini menentukan apakah B benar-benar tercapai. Sebuah berkas selesai tidak selalu berarti kebutuhan pengguna terpenuhi.

Dalam rekayasa sistem, kebutuhan pemangku kepentingan perlu diturunkan menjadi persyaratan dan cara pemeriksaan @nasa2016. Buku ini memakai gagasan keterlacakan itu untuk perjalanan akademik. PUDAL merupakan kerangka usulan proyek yang mengorganisasi pengamatan, pemahaman, pilihan, tindakan, dan pembelajaran; rujukan rekayasa tidak berarti NASA menggunakan atau memvalidasi istilah PUDAL.

Keadaan juga lebih kaya daripada produk. Dua mahasiswa dapat sama-sama mempunyai laporan selesai, tetapi yang satu memahami metode dan yang lain belum. Karena itu, deskripsi keadaan perlu mencakup mutu artefak, kemampuan pelaku, sumber daya yang tersisa, serta kewajiban yang masih terbuka. Jika hanya artefak yang dicatat, biaya tersembunyi dan kebutuhan belajar mudah luput.

== Kasus pengikat: membangun modul Bayes bersama
<kasus-pengikat-membangun-modul-bayes-bersama>
Sepanjang beberapa bab, gunakan kelompok fiktif yang ingin membuat modul Bayes untuk mahasiswa baru. Pada A, kelompok mempunyai infografik awal, beberapa catatan, kemampuan statistik yang beragam, dan waktu 21 hari. B terdiri dari modul yang isinya benar, tutorial yang dapat dijalankan pengguna baru, prompt tutor yang teruji, serta demonstrasi bahwa anggota kelompok memahami konsep tanpa bantuan. Angka jadwal ini skenario perancangan, bukan laporan pelaksanaan kelas.

Masalah pengetahuannya ialah menentukan konsep dan miskonsepsi yang perlu diajarkan. Masalah keputusannya ialah memilih pendekatan penjelasan dan bentuk latihan. Masalah kapasitasnya ialah membuat simulator dan menyunting modul dalam waktu tersedia. Ketiganya tidak dapat diperbaiki dengan tindakan yang sama. Mengulang prompt tidak menutup kekurangan pemahaman; menambah referensi tidak otomatis menyelesaikan pembagian kerja.

Kelompok pertama-tama meminta anggota mengerjakan satu kasus Bayes. Kesalahan penyebut muncul pada sebagian jawaban, sehingga sasaran belajar dipertegas. Kelompok lalu membuat satu contoh lengkap sebelum membangun banyak latihan. Pengguna lain diminta mencoba contoh itu. Ketika pengguna masih salah menafsirkan probabilitas, kelompok memperbaiki representasi frekuensi dan menunda perluasan fitur. Perjalanan ini memperlihatkan bagaimana bukti mengubah urutan tindakan.

== Batas metafora perjalanan
<batas-metafora-perjalanan>
Jalan fisik biasanya mempunyai lokasi dan jarak yang relatif jelas. Pekerjaan akademik dapat mengubah tujuan ketika pemahaman berkembang. Kebutuhan pengguna juga dapat saling bertentangan, dan mutu tidak selalu dapat dipadatkan menjadi satu angka. Oleh sebab itu, graf dan rute dipakai untuk memperjelas hubungan, bukan untuk menganggap semua persoalan mempunyai solusi terpendek yang objektif.

Perencanaan tetap memerlukan penilaian manusia. Sebuah rute cepat yang membuat peserta tidak belajar dapat sesuai untuk pekerjaan administrasi, tetapi gagal untuk tugas pendidikan. Sebaliknya, rute belajar yang sangat panjang dapat melewati tenggat pelayanan pengguna. Model perlu memperlihatkan trade-off tersebut, lalu membantu pihak berwenang memilih dengan alasan yang terbuka.

== Memulai dari kasus pembaca
<memulai-dari-kasus-pembaca>
Ambil satu tugas yang belum selesai. Deskripsikan A dengan bukti yang sudah tersedia, lalu B dengan cara penerimaan yang jelas. Sebut satu hal yang belum diketahui, satu keputusan yang belum dibuat, dan satu kemampuan yang belum cukup. Susun tindakan pertama untuk masing-masing masalah. Jika ketiga tindakan identik, periksa kembali diagnosis Anda.

Pada akhir latihan, pembaca seharusnya dapat menjelaskan mengapa hambatan tertentu memerlukan pencarian informasi, perundingan tujuan, perubahan rute, atau latihan. Keterampilan diagnosis ini menjadi prasyarat penggunaan istilah yang lebih formal pada bab berikutnya.

= TAIDA, Komunikasi, dan Triune Intelligence
<taida-komunikasi-dan-triune-intelligence>
== TAIDA sebagai strategi komunikasi menuju tindakan
<taida-sebagai-strategi-komunikasi-menuju-tindakan>
Dalam KIPP, #strong[TAIDA] digunakan sebagai platform untuk merancang pesan dan perubahan yang hendak dicapai: #strong[Target, Attention, Interest, Desire, Action]. Target menentukan kepada siapa komunikasi diarahkan dan perubahan apa yang diharapkan. Attention memperoleh perhatian; Interest menunjukkan relevansi; Desire membangun motivasi; Action menggerakkan pelaksanaan. TAIDA adalah strategi hubungan manusia menuju aksi, bukan pengganti PUDAL yang menangani navigasi dan pengendalian pekerjaan.

Penerapan TAIDA untuk UAS: sasaran mahasiswa yang ingin menjadi mampu; perhatian dibangun dengan pertanyaan mengapa tugas berharga; minat muncul melalui enam agen yang berguna; hasrat diperkuat dengan portofolio dan kontribusi nyata; aksi diwujudkan melalui pembagian tugas, GitHub, peer review, dan showcase.

== Triune Intelligence
<triune-intelligence>
#strong[Individual Intelligence] adalah kemampuan memahami, memutuskan, bertindak, bertanggung jawab, dan belajar sebagai individu. #strong[Collective Intelligence] muncul dari komunikasi, koordinasi, pembagian pengetahuan, evaluasi silang, dan kolaborasi. #strong[Artificial Intelligence] membantu mencari alternatif, menjelaskan, mengolah, merancang, dan memberi umpan balik. Komunikasi menghubungkan ketiganya agar kekuatan masing-masing saling melengkapi.

AI tidak dianggap otoritas epistemik otomatis. Referensi, hasil analisis, dan keputusan bernilai atau berisiko harus diverifikasi oleh manusia yang bertanggung jawab. Begitu pula kecerdasan kolektif tidak menggantikan kontribusi individual; ia memerlukan akuntabilitas peran.

== Dari domain komunikasi menuju artefak
<dari-domain-komunikasi-menuju-artefak>
Komunikasi dengan diri sendiri mengembangkan refleksi; dengan teman dan keluarga menumbuhkan kepercayaan; dengan rekan profesional melatih koordinasi; pada komunitas membangun aksi bersama; dan pada publik menghasilkan pesan yang dapat dipahami serta diuji. Dalam proyek bersama, komunikasi dipraktikkan pada seluruh domain ini sesuai konteks kasus.

Prinsip pembelajarannya adalah #strong[person-before-message]: mulai dari manusia dan keadaan yang ingin diperbaiki, lalu tentukan isi pesan, tools, dan strategi yang sesuai. Keberhasilan proyek berarti penerima manfaat menjadi lebih mampu, bukan sekadar memperoleh lebih banyak konten.

== Menghubungkan komunikasi dengan perubahan yang bernilai
<menghubungkan-komunikasi-dengan-perubahan-yang-bernilai>
Pesan yang memperoleh perhatian belum tentu menggerakkan tindakan yang tepat. Mahasiswa dapat tertarik pada demo AI, tetapi belum mengetahui bagaimana ia harus memulai atau mengapa kegiatan itu relevan. TAIDA dalam buku ini membantu memisahkan sasaran penerima, cara menarik perhatian, relevansi, motivasi, dan tindakan berikutnya. Kerangka tersebut dipakai sebagai alat desain komunikasi proyek; efektivitasnya pada konteks kelas tetap perlu diperiksa.

Untuk modul Bayes, Target bukan "semua mahasiswa", melainkan peserta yang sudah mengenal persentase tetapi kesulitan menafsirkan probabilitas bersyarat. Attention dapat dibuka dengan dua peluang yang sering tertukar. Interest tumbuh ketika peserta mengenali bahwa perbedaan itu juga muncul pada filter spam. Desire dikembangkan melalui kesempatan menjelaskan kasus dengan benar. Action harus konkret: kerjakan satu soal diagnosis dan bandingkan alasan Anda dengan pembahasan.

Hubungan ini perlu diuji dari respons penerima, bukan hanya niat penyusun. Jika peserta membuka modul tetapi tidak memulai latihan, masalahnya mungkin instruksi awal terlalu berat. Jika peserta menyelesaikan latihan tanpa memahami alasan, ajakan tindakan berhasil secara prosedural tetapi tujuan pendidikan belum tercapai. Data tersebut dikembalikan ke PUDAL untuk memperbaiki materi dan pesan.

== Pembagian kerja antara individu, kelompok, dan AI
<pembagian-kerja-antara-individu-kelompok-dan-ai>
Dalam skenario modul, satu anggota memeriksa perhitungan, anggota lain menguji tutorial, dan anggota lain menyunting penjelasan. AI membantu mengusulkan variasi soal, tetapi setiap soal diperiksa dengan hitung ulang. Kecerdasan individual terlihat dari penalaran dan tanggung jawab anggota; kecerdasan kolektif terlihat dari cara perbedaan penilaian diselesaikan; bantuan artifisial terlihat dari pekerjaan tertentu yang dipercepat atau diperluas.

Kerja kelompok tidak otomatis menghasilkan kecerdasan kolektif. Jika semua anggota menerima keluaran AI yang sama tanpa pemeriksaan, kesalahan bersama justru dapat menguat. Sediakan ruang penilaian awal yang independen, lalu diskusikan perbedaan. Reviewer yang berbeda pendapat diminta menunjukkan bukti, bukan mengikuti anggota yang paling percaya diri. Catatan keputusan menyebut alasan yang akhirnya diterima.

== Commons memerlukan aturan pemeliharaan
<commons-memerlukan-aturan-pemeliharaan>
Academic Commons berarti materi disusun untuk dipakai dan diperbaiki bersama. Portal yang penuh berkas belum tentu menjadi sumber bersama yang sehat apabila tidak ada kurasi, penanggung jawab, dan mekanisme koreksi. Kajian Ostrom tentang tata kelola polisentris menunjukkan pentingnya memperhatikan institusi dan pengaturan yang sesuai konteks @ostrom2009. Penerapannya pada repositori pendidikan merupakan analogi desain buku ini, bukan hasil uji langsung dari kajian tersebut.

Aturan sederhana dapat menetapkan siapa mengusulkan perubahan, siapa meninjau sumber, bagaimana ketidaksepakatan diselesaikan, dan siapa merawat materi setelah mata kuliah berakhir. Keputusan tentang lisensi dan atribusi juga perlu jelas. Materi yang dapat dibaca bebas belum tentu boleh disalin atau diubah tanpa batas.

== Menjaga motivasi tanpa manipulasi
<menjaga-motivasi-tanpa-manipulasi>
Keinginan menggunakan karya sendiri sebagai portofolio merupakan motivasi yang wajar. Namun pesan proyek harus jujur tentang waktu, kesulitan, dan bentuk penilaian. Jangan menjanjikan kompetensi otomatis hanya karena peserta menggunakan AI. Pedoman UNESCO mendukung pendekatan yang berpusat pada manusia @unesco-genai\; dalam konteks ini, peserta perlu memahami pilihan dan konsekuensinya.

Sebagai latihan, susun dua versi undangan belajar: untuk mahasiswa yang khawatir statistik dan untuk mahasiswa yang sudah mampu menghitung tetapi belum dapat menjelaskan. Pertahankan tujuan yang sama, lalu ubah pembukaan, contoh, dan langkah awal sesuai kebutuhan. Uji apakah penerima dapat menyebut apa yang akan dipelajari dan tindakan pertama yang harus dilakukan. Kejelasan itu menjadi ukuran komunikasi yang lebih berguna daripada kesan bahwa pesan terlihat menarik.

= Empat Jenis Artefak dan Empat Cara Belajar
<empat-jenis-artefak-dan-empat-cara-belajar>
#figure([
#box(image("images/artefacts.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Ringkasan 42 artefak pada enam tema KIPP Triune Academic Commons.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-artefacts-1>


== Knowledge --- Learning by Teaching
<knowledge-learning-by-teaching>
Artefak #strong[Knowledge] memuat konsep, kerangka, alasan, contoh, dan batasan. Pembuatnya mempelajari sumber, mengajarkan kembali konsep dengan bahasa yang dapat dipahami pengguna, mengajukan pertanyaan pemahaman, lalu memperbaiki penjelasan dari umpan balik. Karena kualitas pengajaran diuji oleh pemahaman penerima, materi tidak cukup hanya merupakan kompilasi teks.

== Skills --- Learning by Doing
<skills-learning-by-doing>
Artefak #strong[Skills] memuat tutorial yang dapat dijalankan, demonstrasi, masukan--keluaran, cara menguji hasil, kesalahan umum, dan cara memperbaikinya. Skills menyediakan kompetensi transisi dari satu keadaan ke keadaan lain. Tanpa eksekusi demonstratif, daftar langkah belum menjadi bukti keterampilan.

== Prompts --- Learning by Instructing
<prompts-learning-by-instructing>
Artefak #strong[Prompts] adalah spesifikasi instruksi untuk AI: tujuan, konteks, masukan, batasan, kriteria, format hasil, dan kebijakan verifikasi. Prompt bukan jaminan kebenaran; ia perlu diuji dengan kasus sederhana, sulit, dan ambigu. Prompts bekerja melintasi seluruh tahapan PUDAL sebagai mekanisme instruksi dan kontrol, bukan satu fase terpisah.

== Case Study --- Learning by Demonstrating Problem Solving
<case-study-learning-by-demonstrating-problem-solving>
#strong[Case Study] mengikat #emph[Perceive, Understand, Decide, Act, Learn] ke dalam masalah nyata atau simulasi yang diberi label jelas. Kasus dimulai dengan keadaan A, kriteria B, dan kendala sumber daya. Ia mendokumentasikan peta, alternatif rute, keputusan, transisi, evaluasi, serta pembelajaran. Kasus yang matang memperlihatkan demonstrasi lengkap dan tantangan baru agar pengguna dapat menguji kompetensinya sendiri.

== Komposisi dan pengorganisasian
<komposisi-dan-pengorganisasian>
Setiap tema dikembangkan oleh dua kelompok. Masing-masing kelompok membuat satu Knowledge, satu Skill, dan satu Prompt; kedua kelompok bersama-sama menyusun satu Case Study dan satu Learning Path. Dengan demikian satu tema memiliki #strong[2 Knowledge + 2 Skills + 2 Prompts + 1 Case = 7 artefak], dan enam tema memiliki #strong[42 artefak]. Paket agen dan workflow menjadi integrasi di atas artefak tersebut, bukan item tambahan yang dihitung ke dalam 42.

#figure([
#box(image("images/teams.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Pembagian 12 kelompok ke enam tema dan tanggung jawab pembuatan artefak.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-teams-1>


== Mengapa empat artefak harus mempunyai fungsi yang berbeda?
<mengapa-empat-artefak-harus-mempunyai-fungsi-yang-berbeda>
Satu topik dapat ditulis berulang dalam empat berkas tanpa menghasilkan empat manfaat. Knowledge menjawab apa dan mengapa; Skills membantu pengguna melakukan suatu pekerjaan; Prompts memberi spesifikasi bantuan; Case Study menunjukkan bagaimana keputusan dan tindakan bekerja dalam konteks. Perbedaan fungsi ini perlu terlihat pada pengalaman pengguna. Jika semua berkas hanya menjelaskan definisi PUDAL, paketnya belum menyediakan tutorial atau demonstrasi.

Gunakan kasus Bayes sebagai benang pengikat. Knowledge menjelaskan probabilitas bersyarat dan alasan penyebut berubah. Skill mengajarkan pembuatan tabel kontingensi dengan input, langkah, dan pemeriksaan total. Prompt mengarahkan tutor agar mendiagnosis kesalahan sebelum memberi bantuan. Case Study merekam peserta dari jawaban awal keliru sampai mampu menyelesaikan kasus baru. Pembaca dapat berpindah dari satu artefak ke artefak lain sesuai kebutuhannya.

== Kriteria penerimaan yang sesuai fungsi
<kriteria-penerimaan-yang-sesuai-fungsi>
Knowledge diperiksa dari ketepatan konsep, sumber, contoh, dan batasan. Skills diperiksa melalui eksekusi oleh orang lain; penulis tutorial tidak menjadi satu-satunya penguji karena ia sudah mengetahui langkah yang tersirat. Prompts diperiksa terhadap perilaku pada beberapa masukan, termasuk masukan ambigu dan salah. Case Study diperiksa dari keterlacakan perubahan keadaan dan keputusan, bukan panjang narasinya.

Prinsip keselarasan pembelajaran membantu menyamakan bukti dengan kemampuan yang dituju @cmu-alignment. Dalam paket ini, tutorial yang berhasil dijalankan belum membuktikan penguasaan konsep; peserta tetap perlu menjelaskan hasil. Sebaliknya, penjelasan teori yang benar belum menunjukkan bahwa langkah teknis dapat diikuti. Kedua bukti saling melengkapi dan tidak saling menggantikan.

== Satu contoh rantai mutu
<satu-contoh-rantai-mutu>
Misalkan tutorial meminta pengguna menghitung posterior dengan spreadsheet. Knowledge menyatakan prior 1%, sensitivitas 90%, dan positif palsu 5%. Skill harus menuliskan apakah sel menerima #NormalTok("1%"); atau #NormalTok("0.01");, supaya pengguna tidak memasukkan 1 sebagai prevalensi. Prompt yang menghasilkan variasi soal wajib mempertahankan rentang probabilitas yang sah. Case Study kemudian memeriksa bahwa pengguna dapat mengubah parameter dan menafsirkan perubahan.

Kesalahan format input pada Skills dapat membuat Case Study gagal walaupun teori benar. Karena itu reviewer tidak cukup memeriksa setiap berkas secara terpisah. Uji paket dari awal sampai akhir dengan keadaan pengguna yang realistis. Catat titik ketika pengguna perlu menebak atau meminta penjelasan tambahan, lalu pindahkan pengetahuan yang diperlukan ke tempat yang sesuai.

== Mengelola versi, sumber, dan kepemilikan
<mengelola-versi-sumber-dan-kepemilikan>
Setiap artefak memerlukan ID, judul, penanggung jawab, status, versi, prasyarat, dan tautan terkait. Perubahan konsep pada Knowledge harus memicu peninjauan Skills dan Prompts yang bergantung padanya. Jika parameter kasus diganti, perhitungan pembanding dan kunci jawaban ikut diperbarui. Metadata memungkinkan dampak perubahan ini ditelusuri.

Prinsip FAIR membantu memikirkan metadata dan penggunaan ulang sumber digital @fair2016. Pada proyek kelas, penerapannya dapat sederhana: ID stabil, istilah yang konsisten, petunjuk akses, atribusi, dan lisensi yang jelas. FAIR tidak menghapus pembatasan akses atas data sensitif. Materi publik sebaiknya memakai contoh yang memang boleh dibagikan.

== Praktikum audit paket
<praktikum-audit-paket>
Pasangan kelompok menukar satu paket contoh. Reviewer memulai hanya dari halaman masuk, menjalankan satu tutorial, mencoba prompt, dan memeriksa pembahasan kasus. Ia menulis satu kekuatan, satu kegagalan yang dapat direproduksi, serta satu pertanyaan konsep. Penyusun memperbaiki kegagalan lalu meminta reviewer mengulangi langkah yang sama.

Paket diterima ketika pengguna lain dapat memahami tujuan, memperoleh prasyarat, mengerjakan tindakan, dan menilai hasil tanpa bergantung pada penjelasan lisan pembuat. Jumlah 42 artefak tetap penting untuk kelengkapan proyek, tetapi mutu commons ditentukan juga oleh hubungan antarbagiannya dan kemampuan materi tersebut membantu pengguna menjadi lebih mampu.

#part[BAGIAN II — ENGINE NAVIGASI PUDAL]
= PUDAL sebagai Siklus Kendali Kecerdasan
<pudal-sebagai-siklus-kendali-kecerdasan>
== Lima langkah dasar
<lima-langkah-dasar>
#strong[P --- Perceive] mengamati realitas, kondisi awal, perubahan, kebutuhan, bukti dan keterbatasan. #strong[U --- Understand] menafsirkan pengamatan melalui model, pengetahuan, hubungan sebab-akibat dan penjelasan. #strong[D --- Decide] merumuskan pilihan, menimbang nilai, biaya, risiko dan menetapkan keputusan. #strong[A --- Act] mengaktifkan kemampuan dan alat untuk mengubah keadaan. #strong[L --- Learn] menilai hasil tindakan, membandingkan dengan harapan, lalu memperbarui model, keterampilan dan kebijakan keputusan.

Urutan ini merupakan #strong[siklus], bukan pipa linier: pengamatan dapat diperbaiki selama memahami, keputusan dapat ditinjau saat pelaksanaan, dan pembelajaran dapat menyebabkan redefinisi tujuan. Berulangnya putaran adalah ciri sistem adaptif.

== Controller bukan engine
<controller-bukan-engine>
#strong[PUDAL Controller] memilih tindakan dan mengatur perjalanan. #strong[Engine] menyediakan mekanisme yang menggunakan sumber daya untuk melakukan kerja. Modelnya:

$ upright("PUDAL") arrow.r upright("pemilihan engine") arrow.r upright("kerja") arrow.r upright("perubahan keadaan") arrow.r upright("umpan balik PUDAL") . $

Controller dapat berorientasi pada manusia, kolektif, sistem AI, atau kombinasi ketiganya. Engine dapat berupa kekuatan natural, alat instrumental, atau layanan vehicular. PUDAL tidak menciptakan energi hanya melalui keputusan; ia harus mematuhi kendala lingkungan.

== Putaran berjenjang
<putaran-berjenjang>
Siklus yang sama digunakan pada tingkat masalah berbeda: mendefinisikan tujuan, mengembangkan peta, memilih rute, mengeksekusi stage, serta meningkatkan kemampuan. Lima tingkat ini dijelaskan secara terpisah di Bab 8. Tiap tingkat tetap memiliki #emph[Perceive--Understand--Decide--Act--Learn] sendiri.

== Aturan penghentian
<aturan-penghentian>
Siklus berhenti untuk suatu tujuan bila kriteria B terbukti terpenuhi, batas biaya/waktu tercapai, tindakan aman tidak tersedia, atau tujuan ditinjau ulang oleh pemangku keputusan yang berwenang. Tidak semua tugas dapat atau harus dipaksa sampai B; kondisi berhenti merupakan bagian etika dan desain sistem.

== Memisahkan pengamatan dari penafsiran
<memisahkan-pengamatan-dari-penafsiran>
Pada Perceive, kelompok mencatat bahwa empat dari enam pengguna salah memilih penyebut. Pada Understand, kelompok mengajukan penjelasan bahwa pengguna mungkin menukar dua probabilitas bersyarat. Penjelasan ini masih hipotesis. Pengguna dapat pula memahami konsep tetapi membaca simbol secara keliru. Pemisahan fakta dan interpretasi memberi ruang untuk menguji penyebab sebelum bertindak.

Dalam modul Bayes, pengujian sederhana adalah meminta pengguna menerangkan kelompok pembanding dengan kata-kata. Jika penjelasan benar tetapi simbol salah, perbaiki notasi dan latihan membaca. Jika kelompok pembanding juga salah, perbaiki konsep ruang sampel. PUDAL menjadi lebih berguna ketika tiap tahap menghasilkan sesuatu yang dapat dipakai tahap berikutnya, bukan sekadar lima label untuk pekerjaan yang sama.

== Menyusun keputusan yang dapat dijalankan
<menyusun-keputusan-yang-dapat-dijalankan>
Decide perlu menyatakan tindakan, penanggung jawab, batas, dan bukti yang diharapkan. "Perbaiki pemahaman pengguna" belum merupakan keputusan operasional. "Uji penjelasan tabel pada dua pengguna baru sebelum menambah simulator" memberi langkah dan alasan prioritas. Jika hasilnya membaik, kelompok memperoleh alasan untuk mempertahankan representasi tersebut; jika tidak, ia mempunyai dasar untuk mencoba penjelasan lain.

Act harus menghasilkan perubahan atau informasi baru. Menyusun rencana tambahan dapat menjadi tindakan yang sah ketika kekurangannya memang perencanaan, tetapi tidak menggantikan uji materi. Learn kemudian membandingkan hasil dengan dugaan sebelumnya. Perbaikan tidak selalu berarti keberhasilan: mengetahui bahwa pendekatan tertentu tidak membantu juga memperbarui model jika pengujiannya cukup jelas.

== Loop terbuka, loop tertutup, dan mutu pengukuran
<loop-terbuka-loop-tertutup-dan-mutu-pengukuran>
Dalam loop terbuka, kelompok menerbitkan modul sesuai rencana tanpa membaca respons pengguna. Dalam loop tertutup, hasil penggunaan memengaruhi keputusan selanjutnya. Prinsip umpan balik membantu menjelaskan perbedaan ini, tetapi umpan balik yang salah dapat mengarahkan sistem ke tindakan keliru. Banyak klik, misalnya, belum menunjukkan bahwa pembaca memahami Bayes.

NASA membedakan pemeriksaan kesesuaian terhadap persyaratan dan pembuktian kecocokan bagi penggunaan yang dimaksud @nasa2016. Dalam adaptasi akademik, memeriksa rumus merupakan satu jenis verifikasi, sedangkan melihat apakah mahasiswa dapat belajar dari modul merupakan pertanyaan validasi penggunaan. Keduanya perlu bukti yang berbeda. PUDAL menyediakan tempat mencatat keduanya tanpa menganggap hasil satu pengujian berlaku untuk semua tujuan.

== Menghindari putaran yang tidak menghasilkan kemajuan
<menghindari-putaran-yang-tidak-menghasilkan-kemajuan>
Kelompok dapat terjebak meminta AI memperbaiki penjelasan berkali-kali tanpa menguji pengguna. Teks berubah, tetapi tidak ada bukti bahwa keadaan mendekati B. Tetapkan anggaran eksperimen dan aturan eskalasi: sesudah dua revisi dengan pola kegagalan sama, periksa kembali diagnosis atau minta reviewer lain. Angka dua di sini contoh pengendalian kerja yang dapat disesuaikan, bukan ambang universal.

Aturan berhenti juga melindungi sumber daya. Hentikan kegiatan ketika biaya berikutnya tidak sebanding dengan nilai informasi, ketika kebutuhan berubah, atau ketika tidak ada tindakan sah yang tersedia. "Berhenti" tidak selalu berarti gagal; dapat berarti satu tujuan selesai, hipotesis ditolak, atau lingkup perlu dinegosiasikan. Catat statusnya agar orang lain tidak mengira pekerjaan ditinggalkan tanpa alasan.

== Latihan rekonstruksi satu putaran
<latihan-rekonstruksi-satu-putaran>
Pilih satu kesalahan nyata atau sintetis pada artefak. Tulis lima paragraf pendek: bukti pengamatan, dua kemungkinan penjelasan, keputusan yang dipilih beserta alternatifnya, tindakan yang dilakukan, dan perubahan pemahaman sesudah melihat hasil. Jangan mengisi Learn dengan "kami belajar banyak"; sebut asumsi mana yang berubah dan apa konsekuensinya.

Jawaban yang kuat dapat menunjukkan bahwa tindakan awal ternyata tidak tepat. Nilai analitisnya terletak pada kemampuan mengenali ketidakcocokan dan memperbaiki keputusan. Dengan cara ini, PUDAL membantu membangun kebiasaan kerja yang dapat ditinjau, sekaligus menyediakan bahan untuk pemodelan lebih formal pada bab berikutnya.

= Graf Keadaan, Peta Masalah, dan Penemuan Rute
<graf-keadaan-peta-masalah-dan-penemuan-rute>
== Representasi masalah
<representasi-masalah>
Definisikan graf berarah $G =\(V\,E\)$ dengan simpul $v in V$ sebagai #strong[keadaan], bukan selalu lokasi geografis. Sisi $e =\(v_i\,v_j\)$ menyatakan transisi yang mungkin melalui tindakan tertentu. Keadaan awal $s_0 = A$ dan himpunan sasaran $G_(upright(g o a l))$ dapat berupa satu simpul B atau sekumpulan keadaan yang memenuhi syarat.

Simpul antara dapat merepresentasikan draft, kompetensi, dataset tervalidasi, komitmen tim, atau hasil pengujian. Graf perlu memuat prasyarat, dependensi, ancaman, sumber daya, dan ketidakpastian: tidak semua sisi yang dibayangkan dapat langsung dilalui.

== Tiga status sisi
<tiga-status-sisi>
+ #strong[Diketahui dan layak]: transisi didukung bukti dan dapat dijalankan sekarang.
+ #strong[Diketahui tetapi belum layak]: perlu skills, sumber daya, waktu atau akses tambahan.
+ #strong[Hipotesis]: transisi mungkin ada tetapi belum dibuktikan.

Understanding PUDAL bertugas mengungkap dan menguji status tersebut sebelum Planning menganggapnya sebagai opsi. Hal ini krusial ketika AI mengusulkan alternatif yang tampaknya meyakinkan tetapi belum terverifikasi.

== Menyusun peta bertahap
<menyusun-peta-bertahap>
Mulailah dari A dan B, lalu daftar prasyarat hasil B secara mundur dan tindakan yang mungkin dilakukan secara maju. Gabungkan keduanya menjadi peta. Identifikasi simpul penghubung, jalur kritis, kegiatan paralel, dan ketergantungan kemampuan. Cantumkan keyakinan dan sumber bukti pada tiap rute. Peta diperbarui ketika pengguna atau lingkungan berubah.

== Dua graf yang terhubung
<dua-graf-yang-terhubung>
#strong[State--Route Graph] menunjukkan keadaan dan transisinya. #strong[Resource--Energy Graph] menunjukkan sumber daya eksternal, mekanisme akses, konversi, cadangan, dan engine yang dapat memanfaatkannya. Kelayakan rute diperoleh dari hubungan dua graf tersebut. Rute ada secara konseptual belum tentu bisa digunakan bila sumber daya pendukung tidak tersedia di lokasi dan waktu yang tepat.

== Contoh akademik
<contoh-akademik>
$A$: lembar jawaban kosong. $M_1$: pertanyaan dipahami. $M_2$: konsep serta metode dipilih. $M_3$: jawaban awal dihasilkan. $M_4$: hasil diuji. $B$: jawaban benar dan dapat dijelaskan. Jalur samping dapat berupa konsultasi buku, latihan ulang, penggunaan alat hitung, atau meminta bantuan peer reviewer.

== Menentukan tingkat rincian simpul
<menentukan-tingkat-rincian-simpul>
Graf terlalu rinci berubah menjadi daftar semua gerakan kecil, sedangkan graf terlalu kasar menyembunyikan prasyarat penting. Pilih simpul ketika perubahan keadaannya memengaruhi keputusan berikutnya. Untuk modul Bayes, "file dibuka" mungkin tidak perlu menjadi milestone, tetapi "parameter dan jawaban acuan diperiksa" perlu karena tutorial dan prompt bergantung padanya. Tingkat rincian disesuaikan dengan risiko dan tujuan pengguna graf.

Keadaan perlu cukup lengkap untuk menjelaskan transisi. "Draf tersedia" dan "draf tersedia serta telah diperiksa" merupakan dua keadaan berbeda. Jika keduanya digabung, rute menuju publikasi tampak lebih pendek karena pekerjaan pemeriksaan menghilang. Deskripsi simpul yang baik menyebut artefak, status kualitas, dan prasyarat yang sudah terpenuhi.

== Menyusun tabel transisi sebelum menggambar
<menyusun-tabel-transisi-sebelum-menggambar>
Graf dapat mulai dari tabel agar informasi tidak hilang dalam tata letak.

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Dari → ke], [Tindakan], [Prasyarat], [Bukti selesai], [Status],),
  table.hline(),
  [Diagnosis → konsep terpilih], [Analisis jawaban awal], [Soal diagnosis dan respons], [Daftar miskonsepsi], [Layak],
  [Konsep → contoh terverifikasi], [Susun tabel dan hitung ulang], [Parameter disepakati], [Jawaban acuan cocok], [Layak],
  [Contoh → simulator], [Implementasi perhitungan], [Kemampuan kode dan waktu], [Hasil cocok dengan acuan], [Belum layak jika skill kurang],
  [Simulator → transfer], [Latihan variasi dan tes mandiri], [Soal baru tersedia], [Penalaran mandiri benar], [Hipotesis efektivitas],
)
Baris terakhir penting: tersedianya simulator tidak menjamin transfer. Sisi itu memerlukan pengujian pendidikan, sehingga statusnya berbeda dari sisi perhitungan yang dapat diperiksa langsung. Catatan status mencegah peta mengubah dugaan menjadi kepastian.

== Dependensi, jalan alternatif, dan keadaan buntu
<dependensi-jalan-alternatif-dan-keadaan-buntu>
Sebagian pekerjaan dapat paralel setelah konsep disepakati: penyuntingan bahasa dan pengujian kode dapat berjalan bersama. Namun publikasi menunggu keduanya. Jika graf hanya menggambarkan satu rantai, peluang paralel hilang; jika semua kegiatan dianggap paralel, dependensi dilanggar. Gunakan hubungan prasyarat untuk menentukan urutan, kemudian jadwalkan berdasarkan ketersediaan orang dan alat.

Keadaan buntu terjadi ketika tidak ada transisi layak menuju tujuan pada sumber daya saat ini. Kelompok dapat mengurangi lingkup, memperoleh dukungan, belajar, atau merundingkan B. Misalnya simulator interaktif dibatalkan dan diganti tabel variasi yang dapat dijalankan manual. Tujuan memahami pengaruh prior tetap dapat dijaga tanpa mempertahankan seluruh bentuk produk.

== Menghubungkan peta keadaan dengan peta sumber daya
<menghubungkan-peta-keadaan-dengan-peta-sumber-daya>
Sisi "menguji tutorial dengan pengguna baru" memerlukan bukan hanya dokumen, tetapi waktu dan akses pengguna. Jika calon penguji baru tersedia setelah tenggat, sisi tersebut belum layak pada jadwal semula. Hubungkan setiap transisi penting dengan sumber daya yang dibutuhkan dan waktu ketersediaannya. Informasi yang tampak administratif ini dapat menentukan rute lebih kuat daripada kecanggihan alat.

Pendekatan rekayasa sistem menekankan hubungan kebutuhan, rancangan, dan pembuktian @nasa2016. Dalam graf buku ini, hubungan tersebut diterjemahkan menjadi prasyarat serta bukti pada sisi. Ini rancangan representasi yang dapat diuji kegunaannya, bukan klaim bahwa semua masalah sosial dapat direduksi menjadi graf deterministik.

== Memperbarui peta dari pengujian
<memperbarui-peta-dari-pengujian>
Sesudah dua pengguna mencoba tutorial, kelompok mungkin menemukan bahwa prasyarat membaca persentase belum terpenuhi. Tambahkan simpul latihan persentase atau rute bantuan, kemudian catat sumber penemuannya. Jangan sekadar menghapus pengguna tersebut dari evaluasi agar rute lama terlihat berhasil. Peta yang diperbarui menjelaskan untuk siapa rute dapat digunakan.

Sebagai latihan, susun enam sampai sepuluh keadaan untuk tugas Anda, lalu tandai satu sisi hipotesis dan satu sisi yang belum layak. Rancang pengujian murah untuk sisi hipotesis serta tindakan yang membuat sisi kedua layak. Jawaban perlu membedakan memperoleh pengetahuan tentang rute dari memperoleh kemampuan menjalani rute.

= Natural, Instrumental, dan Vehicular Engine
<natural-instrumental-dan-vehicular-engine>
== Tiga sumber kemampuan penggerak
<tiga-sumber-kemampuan-penggerak>
#strong[Natural Engine] menggunakan kemampuan dan tenaga intrinsik pelaku, seperti berjalan kaki, bernalar, membaca atau menghitung sendiri. #strong[Instrumental Engine] menggunakan instrumen yang memperbesar atau memperbaiki efektivitas kemampuan pelaku, seperti sepeda, kalkulator, spreadsheet, atau Python. #strong[Vehicular Engine] mengakses sistem penggerak eksternal yang melakukan sebagian besar kerja yang didelegasikan, seperti mobil, transportasi publik, layanan komputasi, atau layanan AI.

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Aspek], [Natural], [Instrumental], [Vehicular],),
  table.hline(),
  [Penggerak utama], [Diri sendiri], [Diri sendiri dengan instrumen], [Mesin/layanan eksternal],
  [Contoh mobilitas], [Berjalan], [Bersepeda], [Mobil, kereta],
  [Contoh akademik], [Membaca/menghitung manual], [Python, pengelola referensi], [Layanan AI/cloud terdelegasi],
  [Kendala pokok], [Daya/kecakapan/waktu], [Kecakapan mengoperasikan alat], [Akses, keandalan, biaya, kontrol],
  [Tanggung jawab], [Pelaku], [Pelaku], [Tetap perlu pengawasan/persetujuan manusia],
)
== Kategori bersifat fungsional
<kategori-bersifat-fungsional>
Satu perangkat dapat berperan instrumental atau vehicular tergantung penggunaan. AI yang memberi petunjuk langkah sambil mahasiswa bekerja merupakan instrumen belajar; AI yang diberi tugas menghasilkan draf atau analisis lebih otonom berperan sebagai layanan vehicular. Keputusan penggunaan harus sesuai batas integritas akademik.

== Rute campuran
<rute-campuran>
Perjalanan $A arrow.r M_1 arrow.r M_2 arrow.r B$ dapat menggunakan natural pada segmen pertama, instrumental pada segmen kedua, dan vehicular pada segmen akhir. Bahkan satu stage dapat menggabungkan beberapa engine, misalnya mahasiswa menyusun pertanyaan, AI melakukan ekstraksi awal, mahasiswa memvalidasi sumber, lalu perangkat lunak membuat matriks.

== Engine, operator, dan sumber daya
<engine-operator-dan-sumber-daya>
Engine tidak beroperasi di ruang kosong. Harus ada operator, prasyarat keterampilan, sumber daya input, aturan konversi, kapasitas kerja, serta umpan balik. Untuk penggunaan AI, kuota komputasi, listrik, koneksi, data, dan pemeriksaan manusia menjadi bagian kelayakan---meski bukan semuanya setara energi fisik.

== Klasifikasi berdasarkan pekerjaan yang dilakukan
<klasifikasi-berdasarkan-pekerjaan-yang-dilakukan>
Nama perangkat tidak cukup menentukan kategori engine. Spreadsheet yang menghitung sesuai rumus yang dirancang mahasiswa berperan sebagai instrumen. Layanan yang diberi mandat memilih analisis dan menyusun laporan mengerjakan bagian keputusan dan produksi yang lebih luas. Perbedaannya terletak pada fungsi, tingkat delegasi, dan pengawasan. Sebut unit tugasnya sebelum menetapkan kategori agar klasifikasi tidak berubah menjadi perdebatan merek alat.

Pada modul Bayes, peserta menghitung satu contoh sendiri untuk menguasai penyebut. Ia memakai Python untuk memeriksa banyak kombinasi parameter. Ia lalu meminta layanan AI mengusulkan soal transfer, dengan syarat semua soal diperiksa. Natural, instrumental, dan vehicular hadir dalam satu perjalanan. Pembagian ini dirancang untuk memelihara penguasaan konsep sekaligus memanfaatkan alat pada pekerjaan yang sesuai.

== Biaya penuh mencakup pengawasan
<biaya-penuh-mencakup-pengawasan>
Waktu delegasi tidak hanya waktu layanan menghasilkan jawaban. Hitung juga penyiapan input, penjelasan konteks, pemeriksaan, perbaikan, dan perpindahan format. Jika agen menulis contoh Bayes dalam satu menit tetapi kelompok memerlukan satu jam untuk memperbaiki soal yang salah, keuntungan produksi awal dapat hilang. Hal yang sama berlaku pada alat manual yang memerlukan pelatihan sebelum dipakai.

Sebagai ilustrasi, rute manual membutuhkan enam jam. Rute berbantuan membutuhkan satu jam persiapan, satu jam produksi, dua jam verifikasi, dan satu jam revisi: total lima jam. Ia masih menghemat satu jam, tetapi klaim "enam kali lebih cepat" berdasarkan waktu produksi saja tidak benar. Angka-angka ini sintetis untuk menunjukkan cara pencatatan, bukan hasil perbandingan alat.

== Memeriksa kesesuaian engine dengan tujuan belajar
<memeriksa-kesesuaian-engine-dengan-tujuan-belajar>
Jika sasaran belajar adalah menafsirkan probabilitas, mengotomasi perkalian dapat diterima setelah peserta memahami tabel. Jika sasarannya menulis program, menerima seluruh kode tanpa mampu menjelaskan alur tidak cukup. Karena itu, engine dipilih setelah menentukan kemampuan yang akan diuji. Kebijakan bantuan dapat berubah antarstage walaupun peserta dan perangkatnya sama.

Penilaian kemampuan perlu mempertimbangkan pengetahuan awal dan umpan balik. Sintesis #emph[How People Learn II] membahas pembelajaran sebagai proses yang dipengaruhi peserta, konteks, dan pengaturan pembelajaran @hpl2018. Buku ini menerjemahkan perhatian tersebut menjadi diagnosis dan pengurangan bantuan ketika penguasaan meningkat; efektivitas kebijakan spesifiknya masih perlu diuji.

== Mengelola ketergantungan dan rute cadangan
<mengelola-ketergantungan-dan-rute-cadangan>
Engine eksternal dapat tidak tersedia karena koneksi, kuota, perubahan layanan, atau masalah input. Rute cadangan sebaiknya menjaga fungsi minimum. Untuk modul Bayes, simulator dapat diganti lembar perhitungan dan beberapa tabel contoh. Untuk pencarian literatur, metadata yang telah disimpan memungkinkan pembacaan berlanjut ketika layanan pencarian terganggu.

Cadangan tidak perlu menggandakan seluruh sistem. Tentukan keluaran minimum yang tetap harus dihasilkan dan kemampuan inti yang harus dimiliki manusia. Jika tim tidak dapat memeriksa satu hasil tanpa layanan yang sama yang membuatnya, independensi verifikasi lemah. Gunakan hitung manual, sumber primer, atau alat pembanding pada bagian kritis.

== Batas kendali dan latihan pemilihan
<batas-kendali-dan-latihan-pemilihan>
Untuk layanan AI, mandat menyatakan input yang boleh digunakan, tindakan yang boleh dilakukan, batas biaya, format bukti, dan kondisi eskalasi. NIST AI RMF memberi kerangka umum untuk mengelola risiko sistem AI @nist2023\; daftar mandat ini merupakan adaptasi praktis bagi tugas akademik. Skala pengawasan mengikuti dampak dan kesulitan memeriksa hasil.

Pilih dua engine untuk tugas yang sama. Bandingkan biaya penuh, prasyarat keterampilan, mutu yang dapat diperiksa, risiko, serta hasil belajar. Jelaskan kondisi yang akan mengubah pilihan. Keputusan yang matang bersifat bersyarat: engine tertentu sesuai untuk stage dan batas tertentu, bukan pemenang universal untuk semua pekerjaan.

= Energi, Kerja, dan Ekosistem Sumber Daya
<energi-kerja-dan-ekosistem-sumber-daya>
== Mesin empat fungsi
<mesin-empat-fungsi>
Sistem pelaksana kerja memerlukan empat fungsi: #strong[Acquire] memperoleh sumber daya eksternal; #strong[Convert] mengubahnya menjadi bentuk yang bisa digunakan; #strong[Store] menyediakan cadangan; dan #strong[Execute] memobilisasi cadangan untuk pekerjaan. Keempat fungsi dapat berlangsung simultan atau berulang pada setiap stage.

Pada tubuh, makanan dan oksigen mendukung proses metabolik yang menghasilkan bentuk energi kimia tersedia untuk kerja, termasuk ATP; cadangan energi tersebar pada beragam jaringan. Pada mobil, bahan bakar menyediakan energi kimia yang diproses oleh mesin. Pada transportasi berbayar, uang bukan energi fisik tetapi #strong[hak akses/kemampuan membayar] untuk memperoleh layanan yang mengonsumsi energi fisiknya sendiri.

== Mengapa kelimpahan lingkungan relevan
<mengapa-kelimpahan-lingkungan-relevan>
Lingkungan menentukan opsi sumber daya apa yang tersedia di tiap lokasi: makanan/air, listrik, bahan bakar, infrastruktur, uang, data, fasilitas, dan orang yang dapat bekerja sama. Sumber yang #strong[melimpah] memperbesar ruang pilihan, tetapi kelimpahan tidak wajib: yang wajib ialah suplai #strong[cukup, dapat diakses, dapat dikonversi, dan tersedia pada saat diperlukan].

#figure([
#box(image("images/resource.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Peta sumber daya dan komponen yang mendukung portal serta artefak akademik bersama.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-resource>


== Neraca fisik dan neraca kapasitas
<neraca-fisik-dan-neraca-kapasitas>
Untuk satu jenis cadangan energi fisik yang konsisten satuannya, penyederhanaan model:

$ E_(k + 1) = E_k + eta_k Q_k - W_k - L_k . $

$E_k$ cadangan tersedia, $Q_k$ input energi dari luar, $eta_k$ efisiensi penyimpanan efektif, $W_k$ energi yang dipakai untuk kerja, dan $L_k$ kehilangan atau kebutuhan lainnya. Persamaan ini #strong[model konseptual], bukan deskripsi lengkap fisiologi atau termodinamika kendaraan.

Untuk uang, waktu, kuota komputasi, perhatian, dan sumber daya lain, gunakan neraca masing-masing:

$ R_(k + 1)^(\(j\)) = R_k^(\(j\)) + I_k^(\(j\)) - C_k^(\(j\)) . $

Jangan menjumlahkan rupiah dengan joule sebagai besaran yang sama. Pilihan rute harus memenuhi batas tiap komponen vektor sumber daya $upright(bold(R))$.

== Titik suplai dan strategi
<titik-suplai-dan-strategi>
Milestone dapat sekaligus menjadi titik pengisian ulang, pergantian engine, atau negosiasi akses. Penyusunan rute yang hanya meminimalkan jarak tetapi mengabaikan tempat memperoleh suplai dapat menghasilkan perjalanan yang tidak layak. Karena itu, Understanding memetakan sumber dan Planning memeriksa jadwal suplai di sepanjang rute.

== Ekosistem akademik
<ekosistem-akademik>
Natural memerlukan waktu, perhatian, pengalaman, dan daya kognitif; instrumental memerlukan perangkat, kompetensi operasional, dan data; vehicular memerlukan akses platform, biaya komputasi, prosedur verifikasi, dan kebijakan tanggung jawab. Melalui Collective Intelligence, kelompok dapat berbagi pengetahuan, tugas, dan akses tanpa menganggap kontribusi sosial sebagai joule energi fisik.

== Memisahkan dimensi agar neraca bermakna
<memisahkan-dimensi-agar-neraca-bermakna>
Kata energi sering dipakai sehari-hari untuk semangat atau perhatian. Dalam model fisik, energi mempunyai satuan yang dapat diukur seperti joule. Dalam perencanaan akademik, lebih aman mencatat waktu kerja fokus dalam jam, uang dalam rupiah, kapasitas penyimpanan dalam gigabita, dan kuota layanan menurut satuan penyedia. Masing-masing membatasi tindakan dengan cara berbeda.

Waktu kalender juga berbeda dari jam-orang. Dua anggota yang bekerja masing-masing tiga jam menghasilkan enam jam-orang, tetapi dapat memerlukan tiga jam kalender jika tugasnya benar-benar paralel. Jika anggota kedua harus menunggu hasil anggota pertama, durasi bertambah. Perencanaan perlu mencatat kapasitas orang sekaligus dependensi, bukan menjumlahkan semua jam seolah dapat saling menggantikan.

== Contoh neraca proyek dengan cadangan
<contoh-neraca-proyek-dengan-cadangan>
Kelompok modul Bayes mempunyai 30 jam-orang untuk satu pekan. Rencana awal mengalokasikan delapan jam pembacaan, delapan jam tutorial, enam jam pengujian, dan empat jam penyuntingan, sehingga tersisa empat jam cadangan. Ketika pengujian membutuhkan tambahan lima jam, proyek kekurangan satu jam sekalipun pekerjaan lain sesuai estimasi. Kelompok dapat mengurangi fitur, menambah kapasitas yang sah, atau mengubah jadwal.

Cadangan bukan waktu kosong tanpa tujuan. Ia melindungi proyek dari variasi yang wajar. Besarnya dipilih berdasarkan ketidakpastian dan konsekuensi keterlambatan, bukan persentase yang dianggap berlaku untuk semua kasus. Dalam contoh ini, menghapus seluruh pengujian agar jadwal kembali cocok akan melanggar kriteria mutu B.

#table(
  columns: (21.43%, 28.57%, 28.57%, 21.43%),
  align: (auto,right,right,auto,),
  table.header([Sumber daya], [Tersedia], [Kebutuhan rencana], [Hal yang perlu diperiksa],),
  table.hline(),
  [Jam-orang], [30], [26], [Apakah keahlian tersedia pada waktu yang tepat?],
  [Biaya layanan], [Rp100.000], [Rp60.000], [Apakah biaya verifikasi dan pemakaian ulang termasuk?],
  [Penguji pengguna], [3 orang], [2 orang], [Apakah jadwal dan izin partisipasinya jelas?],
)
Tabel merupakan ilustrasi. Kelebihan uang tidak otomatis menutup kekurangan waktu penguji. Pertukaran sumber daya memerlukan mekanisme yang nyata, misalnya membayar layanan yang memang tersedia dan diizinkan. Tanpa mekanisme itu, menjumlahkan semuanya menjadi skor anggaran dapat menghasilkan rute semu.

== Acquire, Convert, Store, Execute dalam kerja pengetahuan
<acquire-convert-store-execute-dalam-kerja-pengetahuan>
Acquire mencakup memperoleh sumber yang sah, akses alat, dan komitmen waktu. Convert mencakup mengekstraksi konsep, membersihkan data, atau mengubah format. Store mencakup penyimpanan dengan metadata dan versi agar dapat ditemukan kembali. Execute menggunakan sumber yang sudah siap untuk analisis, penulisan, atau pengujian. Keempat fungsi ini menjelaskan aliran kerja; istilah konversi informasi tidak berarti pengetahuan berubah menjadi energi fisik.

Kegagalan sering terjadi di antara fungsi. Artikel sudah diunduh tetapi tidak diberi metadata sehingga sulit ditemukan. Dataset tersedia tetapi skema tidak dipahami sehingga belum dapat digunakan. Kuota layanan ada tetapi anggota belum mampu memeriksa output. Kelimpahan input tidak sama dengan kesiapan kerja.

== Menghindari klaim efisiensi yang tidak diukur
<menghindari-klaim-efisiensi-yang-tidak-diukur>
Biaya token, lama eksekusi, dan daya perangkat dapat menjadi indikator berbeda. Jangan menyebut satu sistem lebih hemat energi hanya karena lebih murah atau lebih cepat; klaim energi membutuhkan batas pengukuran dan satuan energi. Demikian pula, beban kognitif tidak dapat disimpulkan dari jumlah klik saja. Tentukan konstruk dan instrumennya sebelum membandingkan.

Praktik komputasi yang terorganisasi membantu menghindari kerja ulang, misalnya melalui skrip, struktur data, dan dokumentasi yang dapat dipakai kembali @wilson2017. Penghematan pada proyek tertentu tetap harus dicatat dari kondisi aktual. Untuk latihan, buat neraca dua stage dengan sumber daya berbeda dan satu gangguan suplai. Tunjukkan sumber daya mana yang menjadi hambatan serta perubahan rute yang mempertahankan mutu minimum.

= Lima Putaran PUDAL Berjenjang
<lima-putaran-pudal-berjenjang>
== Mengapa lima?
<mengapa-lima>
Satu siklus PUDAL tidak harus langsung membawa seseorang dari A menuju B. Siklus dapat bekerja pada tingkat meta: mendefinisikan tujuan, menemukan peta, merencanakan, menjalankan, dan belajar. Karena setiap fungsi sendiri memerlukan pengamatan, pemahaman, keputusan, aksi, dan evaluasi, kita menyebutnya #strong[lima PUDAL].

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Tingkat], [Fungsi], [Pertanyaan], [Output],),
  table.hline(),
  [1 Orientation], [Menetapkan A dan B], [Ke mana, untuk siapa, standar apa?], [Goal Model],
  [2 Understanding], [Menggali peta dan mesin], [Jalan apa yang ada, mungkin, atau belum ditemukan?], [State--Route & Resource Map],
  [3 Planning], [Memilih rute dan milestone], [Mana yang layak, bernilai, dan tepat waktu?], [Resource-Aware Route Plan],
  [4 Execution], [Menjalankan stage], [Apa yang harus dikerjakan sekarang?], [Transisi dan bukti kerja],
  [5 Learning], [Mengubah kemampuan dan strategi], [Apa yang perlu dipelajari agar rute membaik?], [Updated capabilities & policy],
)
== PUDAL 1 --- Orientation
<pudal-1-orientation>
Perceive kondisi A dan pemangku kepentingan; Understand gap terhadap kebutuhan; Decide definisi B dan indikator; Act menyatakan kontrak tujuan; Learn meninjau konsistensi sasaran. Keluaran mencantumkan batas waktu, mutu, ruang lingkup, dan kriteria penghentian.

== PUDAL 2 --- Understanding
<pudal-2-understanding>
Perceive simpul, transisi, dan kekosongan peta; Understand hubungan sebab-akibat serta prasyarat; Decide bagian peta yang perlu dieksplorasi; Act melakukan observasi, simulasi, pencarian, wawancara, dan pengujian; Learn memperbarui status sisi graf serta pilihan engine. #strong[Understanding menemukan pilihan, belum otomatis memilihnya].

== PUDAL 3 --- Planning
<pudal-3-planning>
Perceive sumber daya serta tenggat; Understand alternatif dan biaya; Decide rute, engine campuran, milestones, urutan dan prioritas; Act menyusun jadwal dan pembagian kerja; Learn mengkalibrasi estimasi ketika informasi baru masuk. Planning juga harus menentukan #emph[fallback routes] dan kondisi revisi.

== PUDAL 4 --- Execution
<pudal-4-execution>
Perceive keadaan aktual; Understand selisih terhadap milestone; Decide tindakan lokal dan engine; Act melakukan pekerjaan; Learn mengevaluasi hasil dan memperbarui state. Satu stage dapat memerlukan banyak putaran Execution PUDAL.

== PUDAL 5 --- Learning
<pudal-5-learning>
Perceive celah kompetensi dan potensi optimasi; Understand kemampuan baru yang diperlukan; Decide eksperimen atau jalur belajar; Act belajar, berlatih, menguji alat; Learn mengukur kenaikan kemampuan. Hasilnya kembali ke Understanding/Planning/Execution. Learning bukan hanya retrospeksi pada fase L biasa, tetapi #strong[siklus mandiri untuk investasi kapasitas].

== Hubungan antartingkat
<hubungan-antartingkat>
Urutan 1→2→3→4→5 adalah susunan logis, bukan pelaksanaan kaku. Ketika perencanaan menemukan sisi yang belum diketahui, ia memanggil Understanding. Ketika eksekusi menemukan celah keterampilan, ia memanggil Learning. Ketika sumber daya runtuh, ia kembali ke Planning. Ketika tujuan tidak lagi relevan, ia kembali ke Orientation.

== Membedakan fungsi dan fase agar hierarki tidak membingungkan
<membedakan-fungsi-dan-fase-agar-hierarki-tidak-membingungkan>
Huruf U pada satu putaran PUDAL berarti memahami pengamatan untuk keputusan lokal. Understanding PUDAL berarti fungsi lebih luas yang membangun dan menguji peta masalah. Keduanya berhubungan, tetapi skala objeknya berbeda. Pada Execution, U dapat menafsirkan satu kegagalan hitung; pada Understanding, seluruh putaran dapat dipakai untuk mencari representasi konsep yang sesuai bagi pengguna.

Lima fungsi tidak harus dijalankan sekali dalam urutan kaku. Execution dapat menemukan bahwa tujuan B tidak konsisten sehingga masalah dikembalikan ke Orientation. Learning dapat menambah kemampuan yang membuat Planning memilih rute baru. Hierarki berguna jika memperjelas siapa menangani masalah dan keluaran apa yang dibutuhkan, bukan jika menambah lapisan administrasi tanpa keputusan.

== Contoh satu masalah ditangani pada lima tingkat
<contoh-satu-masalah-ditangani-pada-lima-tingkat>
Dalam proyek modul Bayes, Orientation menyepakati bahwa pengguna harus mampu menjelaskan posterior pada kasus baru. Understanding memeriksa kesulitan pengguna dan pilihan representasi: rumus, tabel, atau frekuensi. Planning memilih tabel sebagai jalur awal, menetapkan reviewer, dan menyisihkan waktu uji. Execution membuat contoh, mencoba pada pengguna, dan memperbaiki kesalahan. Learning melatih anggota yang belum dapat memeriksa perhitungan secara mandiri.

Setiap fungsi tetap mempunyai bukti. Goal Model memuat tujuan dan aturan penerimaan. Peta mencatat alternatif serta status kelayakannya. Rencana menyatakan jadwal, sumber daya, dan rute cadangan. Log eksekusi menunjukkan tindakan serta hasil. Bukti belajar menunjukkan kemampuan baru pada tugas yang tidak sekadar disalin. Keluaran tersebut menjadi antarmuka yang menghubungkan fungsi.

== Kontrak serah terima antarlevel
<kontrak-serah-terima-antarlevel>
Understanding tidak menyerahkan "banyak ide" kepada Planning, tetapi pilihan yang mempunyai prasyarat dan derajat kepastian. Planning tidak menyerahkan "kerjakan secepatnya" kepada Execution, tetapi stage dengan tujuan, batas, dan bukti penerimaan. Execution tidak menyerahkan seluruh log mentah kepada Learning, tetapi pola kegagalan dan diagnosis sementara. Informasi rinci tetap tersedia untuk audit ketika diperlukan.

Kontrak serah terima mencegah dua fungsi menganggap fungsi lain telah memeriksa hal yang sama. Misalnya, planner mengira rumus sudah diperiksa, sedangkan penulis konsep mengira pemeriksaan akan dilakukan saat eksekusi. Kolom status "belum diverifikasi" lebih baik daripada asumsi diam-diam. Tentukan penanggung jawab untuk setiap keputusan penting dan sumber bukti yang digunakannya.

== Aturan eskalasi berdasarkan jenis hambatan
<aturan-eskalasi-berdasarkan-jenis-hambatan>
Jika kode salah membaca persen, Execution memperbaiki implementasi. Jika seluruh pendekatan membutuhkan data yang tidak tersedia, Understanding memperbarui peta dan Planning memilih rute lain. Jika anggota tidak mengetahui cara menguji hasil, Learning menutup kesenjangan tersebut. Jika pengguna sebenarnya membutuhkan tujuan berbeda, Orientation dibuka kembali. Diagnosis ini mengurangi kecenderungan mengulang tahap produksi untuk masalah yang berada di tingkat lain.

Perlu pula batas rekursi. Proyek kecil dapat memakai satu lembar catatan dengan lima fungsi, bukan lima tim atau lima aplikasi. Proyek yang lebih besar memerlukan pemisahan peran lebih tegas. Tingkat formalitas disesuaikan dengan kompleksitas, dampak kesalahan, dan kebutuhan koordinasi.

== Latihan menelusuri satu kegagalan
<latihan-menelusuri-satu-kegagalan>
Gunakan skenario: modul tepat secara hitung, tetapi pengguna baru tidak dapat mengikuti tutorial. Ajukan sedikitnya tiga diagnosis pada tingkat berbeda. Bisa jadi langkah lokal hilang, prasyarat pengguna tidak dipetakan, atau tujuan keterpakaian tidak pernah disepakati. Rancang bukti untuk membedakan diagnosis sebelum memilih perbaikan.

Untuk menguji apakah perbaikan benar-benar membantu belajar, gunakan demonstrasi mandiri dan pengambilan kembali, dengan memperhatikan konteks peserta @hpl2018@roediger2006. Rujukan pembelajaran mendukung perhatian pada bukti penguasaan; pembagian menjadi lima PUDAL tetap merupakan arsitektur konseptual buku ini yang memerlukan pengujian tersendiri.

= Intermediate Goals, Stages, Milestones, dan Replanning
<intermediate-goals-stages-milestones-dan-replanning>
== Perjalanan sulit harus dapat dipecah
<perjalanan-sulit-harus-dapat-dipecah>
Pecah perjalanan besar $A arrow.r B$ menjadi:

$ A = M_0 arrow.r M_1 arrow.r M_2 arrow.r dots.h.c arrow.r M_n = B . $

#strong[Stage] ialah kegiatan/transisi dari $M_i$ menuju $M_(i + 1)$. #strong[Milestone] ialah keadaan terukur yang membuktikan kemajuan. #strong[Checkpoint] ialah saat pemeriksaan, sedangkan #strong[decision gate] ialah keputusan untuk lanjut, perbaiki, ubah engine, belajar, atau berhenti.

== Milestone bukan sekadar tanggal
<milestone-bukan-sekadar-tanggal>
Kriteria milestone perlu menyatakan artefak atau capaian, standar kualitas, bukti verifikasi, penanggung jawab, dan batas waktu. Contoh: bukan 'telah membaca lima paper', melainkan 'matriks sintesis lima paper dengan referensi dan klaim yang dapat ditelusuri'.

== Replanning pada setiap milestone
<replanning-pada-setiap-milestone>
Setelah mencapai $M_i$, agen memeriksa keadaan aktual, anggaran sumber daya, engine yang tersedia, waktu tersisa, rute alternatif, dan celah kemampuan. Bila ada perubahan penting, kebijakan untuk segmen berikutnya $pi_i$ diperbarui. Ini disebut #strong[rolling-horizon planning]: merancang global namun menyesuaikan lokal.

== Hubungan Learning dan milestones
<hubungan-learning-dan-milestones>
Setiap milestone dapat menjadi titik isi ulang sumber daya atau titik investasi belajar. Bila rute selanjutnya membutuhkan skill baru, Understanding mengidentifikasi kesenjangan dan Learning PUDAL menjalankan latihan yang dibutuhkan sebelum Execution melanjutkan.

== Contoh perjalanan 21 hari
<contoh-perjalanan-21-hari>
- #strong[M₀:] kelompok, kasus, dan bahan masih belum terstruktur.
- #strong[M₁ (akhir pekan 1):] kebutuhan pengguna dan dua Knowledge per tema terdefinisi serta ditinjau.
- #strong[M₂ (pekan 2):] dua Skills dan dua Prompts teruji; jalur demonstrasi tersedia.
- #strong[M₃ (pekan 3):] Case Study mendemonstrasikan putaran PUDAL, lengkap dengan evidence dan revisi.
- #strong[B:] agen/learning path dapat digunakan dan diulas mahasiswa lain melalui portal.

Tahap publikasi dan verifikasi dapat paralel pada minggu ketiga. Jadwal harus disesuaikan dengan kondisi kelas; angka di atas merupakan rencana proyek, bukan bukti realisasi.

== Menulis milestone sebagai kontrak penerimaan
<menulis-milestone-sebagai-kontrak-penerimaan>
Milestone yang baik menyatakan keadaan yang telah tersedia bagi tahap berikutnya. "Tutorial ditulis hari Jumat" hanya menyebut kegiatan dan waktu. "Pengguna baru dapat menjalankan contoh sampai jawaban acuan, dengan semua prasyarat tercantum, pada akhir Jumat" menambahkan mutu dan bukti. Kriteria perlu cukup jelas sehingga reviewer dapat memberi keputusan yang konsisten.

Dalam proyek modul Bayes, M1 dapat berupa konsep, parameter, dan jawaban acuan yang sudah diperiksa. M2 berupa tutorial yang dijalankan orang di luar penyusunnya. M3 berupa prompt yang diuji pada masukan benar, salah, dan ambigu. B mengintegrasikan materi dengan kasus transfer serta dokumentasi batasannya. Masing-masing membutuhkan bukti yang berbeda, sehingga satu tangkapan layar portal tidak cukup untuk semuanya.

== Menetapkan checkpoint sebelum risiko membesar
<menetapkan-checkpoint-sebelum-risiko-membesar>
Checkpoint tidak harus menunggu milestone gagal. Jika ketidakpastian terbesar terletak pada pemahaman pengguna, uji satu contoh sebelum menulis sepuluh contoh. Jika terletak pada akses data, periksa izin sebelum menyusun model. Pemeriksaan dini menghindari investasi besar pada asumsi yang belum benar. Frekuensi checkpoint dipilih dari risiko dan biaya pemeriksaan, bukan kebiasaan rapat semata.

Pada checkpoint, bandingkan rencana dengan keadaan aktual. Pisahkan pekerjaan selesai, pekerjaan diterima, dan pekerjaan yang masih menunggu verifikasi. Persentase "90% selesai" tidak banyak membantu jika sisa 10% mencakup pengujian paling tidak pasti. Tampilkan daftar bukti yang sudah ada dan hambatan yang masih terbuka.

== Contoh replanning dengan angka yang jelas
<contoh-replanning-dengan-angka-yang-jelas>
Pada hari ketujuh, kelompok memperkirakan sisa pekerjaan delapan jam tutorial, enam jam simulator, dan enam jam validasi. Kapasitas aktual sampai tenggat tinggal 16 jam-orang. Rencana 20 jam tidak layak. Kelompok mengurangi simulator menjadi tabel variasi yang membutuhkan dua jam, sehingga total menjadi 16 jam. Tujuan konsep, tutorial, dan validasi tetap dijaga, sementara bentuk produk berubah. Angka ini sepenuhnya ilustratif.

Keputusan tersebut perlu ditinjau terhadap B. Jika simulator interaktif merupakan persyaratan wajib yang telah disepakati, pengurangan fitur membutuhkan perubahan lingkup yang sah. Jika ia hanya preferensi, planner dapat mengubah rute sambil mempertahankan tujuan. Pembedaan ini mencegah replanning menjadi pembenaran untuk menurunkan standar secara diam-diam.

== Biaya perubahan dan kestabilan rencana
<biaya-perubahan-dan-kestabilan-rencana>
Rencana yang tidak pernah berubah mengabaikan informasi baru. Rencana yang berubah setiap kali ada ide baru membuat pekerjaan tidak selesai. Catat pemicu perubahan: bukti kegagalan, perubahan sumber daya, kebutuhan pengguna, atau risiko yang melewati batas. Bandingkan manfaat perubahan dengan biaya perpindahan alat, pembelajaran ulang, dan pekerjaan yang harus diulang.

Versi rencana sebaiknya menyimpan alasan, asumsi, dan dampak pada milestone. Sesudah perubahan, pastikan anggota memahami urutan dan tanggung jawab baru. Pergantian file tanpa komunikasi dapat menciptakan dua rencana yang sama-sama dianggap berlaku. Dalam commons, status versi aktif perlu terlihat di halaman masuk proyek.

== Latihan decision gate
<latihan-decision-gate>
Susun empat pilihan pada satu gate: lanjut, perbaiki lokal, ubah rute, atau hentikan/negosiasikan tujuan. Untuk setiap pilihan, tulis bukti yang akan mendukungnya. Misalnya lanjut membutuhkan jawaban acuan dan uji pengguna lolos; perbaikan lokal sesuai bila satu langkah tutorial hilang; perubahan rute sesuai bila alat utama tidak tersedia; penghentian sesuai bila tujuan tidak lagi dibutuhkan.

Kerangka risiko NIST menekankan perlunya mengelola risiko sepanjang penggunaan sistem AI @nist2023. Pada proyek ini, decision gate menjadi salah satu tempat untuk meninjau risiko aktual dan tindak lanjut. Gate berguna jika menghasilkan keputusan dan pemilik tindakan, bukan hanya persetujuan formal tanpa pemeriksaan bukti.

= Learning PUDAL dan Penemuan Rute yang Lebih Optimal
<learning-pudal-dan-penemuan-rute-yang-lebih-optimal>
== Dua jenis belajar
<dua-jenis-belajar>
Fase #strong[Learn] dalam setiap PUDAL memperbaiki keputusan berdasarkan hasil tindakan. Sebaliknya, #strong[Learning PUDAL] merupakan proyek belajar yang eksplisit: meningkatkan Knowledge, Skills, Tools, dan kebijakan keputusan agar suatu transisi menjadi mungkin atau lebih efisien.

== Peta yang diketahui versus kemampuan menjalani
<peta-yang-diketahui-versus-kemampuan-menjalani>
Agen menyimpan $G_t =\(V_t\,E_t\)$ sebagai #strong[peta yang diketahui atau dihipotesiskan]. Ia juga memiliki himpunan sisi yang benar-benar bisa ditempuh, $E_t^(upright(f e a s i b l e)) subset.eq E_t$. Setelah eksplorasi, informasi baru dapat menambah sisi peta. Setelah pembelajaran kemampuan, sebagian sisi yang sebelumnya tidak layak dapat menjadi layak; ini berbeda dari menciptakan jalan fisik baru.

== Lima kegiatan Learning PUDAL
<lima-kegiatan-learning-pudal>
+ #strong[Perceive:] mengidentifikasi tugas yang gagal, lambat, mahal, atau tidak bisa ditempuh.
+ #strong[Understand:] mendiagnosis keterbatasan pengetahuan, skills, tools, atau akses.
+ #strong[Decide:] memilih jalur pembelajaran serta target kompetensi dan biaya pembelajaran.
+ #strong[Act:] latihan, eksperimen, mentoring, prototyping, dan verifikasi.
+ #strong[Learn:] menilai peningkatan kinerja pada tugas baru, lalu memperbarui peta dan kebijakan.

== Nilai belajar versus kecepatan sesaat
<nilai-belajar-versus-kecepatan-sesaat>
Misalnya satu analisis memerlukan 10 jam manual. Belajar Python 4 jam lalu memproses data 3 jam memerlukan total 7 jam (contoh hipotetis). Namun, bila latihan lebih panjang, keputusan belajar masih bisa bernilai karena digunakan untuk banyak tugas berikutnya. #strong[Rute tercepat untuk satu tugas belum tentu rute terbaik untuk pertumbuhan kompetensi jangka panjang.]

== Penemuan peluang
<penemuan-peluang>
Understanding PUDAL mengeksplorasi 'rute apa yang mungkin ada'\; Learning PUDAL mengeksplorasi 'kemampuan apa yang perlu diperoleh agar rute tersebut dapat dipakai'. Keduanya berinteraksi: penemuan rute baru bisa memicu belajar; kemampuan baru dapat mengungkap rute yang sebelumnya tidak terlihat.

== Tanggung jawab epistemik
<tanggung-jawab-epistemik>
AI dapat menyarankan rute atau mengajarkan skill, tetapi klaim 'sudah mampu' harus didukung bukti demonstrasi mandiri, tes pada masalah baru, audit kode, atau validasi sumber. Jangan mengubah model kemampuan hanya berdasarkan rasa percaya diri atau keluaran teks AI.

== Mendiagnosis kesenjangan sebelum memilih bahan belajar
<mendiagnosis-kesenjangan-sebelum-memilih-bahan-belajar>
Kelambatan tidak selalu menandakan kekurangan pengetahuan. Anggota dapat memahami Bayes tetapi belum terbiasa memakai editor; bisa juga menguasai alat tetapi tidak memahami probabilitas. Diagnosis dilakukan dengan meminta demonstrasi kecil dan penjelasan. Jika anggota mampu menghitung manual tetapi gagal menulis kode, latihan implementasi diperlukan. Jika kode berjalan tetapi ia tidak dapat menjelaskan penyebut, latihan konsep lebih mendasar diperlukan.

Learning PUDAL menetapkan kemampuan sasaran dengan bukti dan batas waktu. "Belajar Python" terlalu luas. "Membuat fungsi posterior, memeriksa rentang input, dan mencocokkan empat kasus acuan" cukup spesifik untuk satu proyek. Keterampilan baru kemudian diuji pada parameter berbeda agar keberhasilan tidak hanya berasal dari menyalin contoh.

== Menilai investasi belajar dengan biaya penuh
<menilai-investasi-belajar-dengan-biaya-penuh>
Misalkan satu pekerjaan manual membutuhkan lima jam, sedangkan sesudah belajar alat dapat dikerjakan dua jam. Pelatihan awal memerlukan sembilan jam. Untuk $n$ pekerjaan serupa, rute manual membutuhkan $5 n$ jam dan rute belajar membutuhkan $9 + 2 n$ jam. Keduanya sama pada $n = 3$\; penghematan waktu muncul mulai pekerjaan keempat, dengan asumsi kualitas dan biaya pemeliharaan setara. Ini perhitungan ilustratif, bukan prediksi otomatis bagi setiap pembelajar.

Keputusan belajar tetap dapat bernilai sebelum titik impas waktu jika keterampilan menjadi tujuan pendidikan atau membuka rute penting. Sebaliknya, investasi dapat tidak layak jika tugas jarang berulang dan tenggat sangat dekat. Pertimbangkan pula lupa, perubahan alat, dan kebutuhan pembaruan. Nilai belajar sebaiknya dibahas sebagai profil manfaat, bukan satu angka presisi tanpa dasar.

== Eksplorasi informasi dan latihan kemampuan
<eksplorasi-informasi-dan-latihan-kemampuan>
Eksplorasi mencari tahu apakah rute atau alat cocok. Latihan membuat pelaku mampu memakai rute tersebut. Mencoba tiga pustaka visualisasi selama satu jam dapat memberi informasi tentang kompatibilitas, tetapi belum membuktikan penguasaan salah satunya. Catat hasil kedua kegiatan secara berbeda: pengetahuan tentang pilihan dan bukti kemampuan.

Gunakan eksperimen kecil untuk mengurangi biaya eksplorasi. Sebelum memigrasikan seluruh modul, coba satu halaman dengan rumus, gambar, tabel, dan sitasi. Sebelum memakai tutor, uji satu miskonsepsi yang diketahui. Eksperimen memiliki pertanyaan dan kriteria penghentian. Mencoba alat tanpa pertanyaan dapat berubah menjadi pencarian tanpa akhir.

== Belajar dengan bantuan yang berkurang
<belajar-dengan-bantuan-yang-berkurang>
Mulai dari contoh yang dijelaskan, lanjut ke tugas dengan sebagian petunjuk, lalu tugas baru tanpa bantuan. Pada setiap tahap, peserta menjelaskan alasan dan memeriksa kesalahannya. Umpan balik perlu cukup spesifik untuk mengubah tindakan, misalnya menunjukkan kelompok pembanding yang salah, bukan hanya menyatakan jawaban kurang tepat. Penelitian pembelajaran menekankan peran pengetahuan awal, konteks, dan pengaturan diri @hpl2018.

Praktik mengambil kembali pengetahuan dapat disisipkan sesudah jeda, alih-alih terus membaca ulang contoh @roediger2006. Pada modul Bayes, peserta diminta membangun ulang tabel dari narasi baru. Bukti ini lebih relevan terhadap penguasaan daripada rasa akrab dengan rumus. Jadwal dan bentuk latihan perlu disesuaikan; buku ini tidak menetapkan interval yang berlaku untuk semua materi.

== Mencatat perubahan himpunan tindakan layak
<mencatat-perubahan-himpunan-tindakan-layak>
Sesudah latihan, jangan hanya menambah label "mahir" pada profil. Sebut tindakan yang kini bisa dilakukan: membuat tabel, memvalidasi input, menjelaskan error, atau menelusuri sumber. Perbarui prasyarat sisi graf yang bergantung pada kemampuan tersebut. Jika kemampuan hanya terlihat ketika tutor memberi petunjuk, tandai kondisi bantuannya.

Sebagai latihan, pilih satu sisi graf yang semula belum layak. Susun diagnosis, latihan singkat, demonstrasi baru, dan keputusan pembaruan status. Jawaban yang baik memungkinkan reviewer menyatakan dengan jelas apa yang berubah, atas bukti apa, dan pada kondisi mana kemampuan itu dapat digunakan kembali.

= Model Matematis Resource-Aware Navigation
<model-matematis-resource-aware-navigation>
== State, engine, dan keputusan
<state-engine-dan-keputusan>
Definisikan keadaan lengkap $x_t =\(s_t\,upright(bold(r))_t\,upright(bold(k))_t\,tau_t\)$, dengan $s_t$ keadaan pekerjaan, $upright(bold(r))_t$ vektor cadangan sumber daya, $upright(bold(k))_t$ model kemampuan, dan $tau_t$ waktu tersedia. Tindakan $a_t$ dilaksanakan menggunakan engine $m_t in { N\,I\,V }$ atau suatu kombinasi yang kompatibel. Sistem mengalami transisi:

$ x_(t + 1) = F\(x_t\,a_t\,m_t\,w_t\)\, $

di mana $w_t$ mencakup perubahan lingkungan atau ketidakpastian. Fungsi $F$ bersifat spesifik kasus: untuk tugas akademik, transisinya mungkin perubahan keadaan dokumen; untuk perjalanan fisik, perubahan posisi.

== Rute dan kelayakan
<rute-dan-kelayakan>
Sebuah rute adalah $pi =\(s_0\,e_1\,s_1\,dots.h\,e_n\,s_n\)$ dengan $s_0 = A$ dan $s_n in G_(upright(g o a l))$. Setiap sisi memiliki waktu $t\(e\,m\)$, biaya sumber daya vektor $upright(bold(c))\(e\,m\)$, kualitas yang diharapkan, risiko, dan bukti kelayakan. Rute #strong[layak] bila setiap langkah memenuhi prasyarat kemampuan, suplai dan cadangan nonnegatif, serta tenggat:

$ sum_i t\(e_i\,m_i\)+ T_(upright(b e l a j a r)) + T_(upright(t r a n s i s i)) lt.eq T_max . $

== Neraca sumber daya
<neraca-sumber-daya>
Untuk sumber daya ke-$j$:

$ r_(i + 1)^(\(j\)) = r_i^(\(j\)) + q_i^(\(j\)) - c_i^(\(j\))\,#h(2em) r_i^(\(j\)) gt.eq r_min^(\(j\)) . $

Masukan $q$ bisa berupa pembelian, pengisian, bantuan, atau akses, sesuai jenis sumber daya. Menggunakan uang untuk bahan bakar memerlukan #strong[model pertukaran] antara uang dan volume BBM; uang bukan energi fisik.

== Fungsi tujuan multi-kriteria
<fungsi-tujuan-multi-kriteria>
Contoh fungsi objektif konseptual:

$ J\(pi\,ell\)= alpha T + beta C + gamma R - delta V - lambda Delta K . $

$T$ ialah durasi, $C$ biaya yang dinormalisasi, $R$ risiko, $V$ nilai hasil, $Delta K$ manfaat peningkatan kemampuan, dan $ell$ pilihan pembelajaran. Bobot ditetapkan oleh pengambil keputusan. Karena unit berbeda, perlu normalisasi atau #emph[multi-objective optimization] sebelum digunakan numerik. Batas etika dan mutu sering lebih tepat diperlakukan sebagai kendala keras daripada komponen yang dapat ditukar dengan biaya.

== Kebijakan adaptif
<kebijakan-adaptif>
Pada milestone $i$, kebijakan $pi_i$ memilih stage berikutnya dari keadaan aktual. Mekanisme keputusan dapat berupa aturan, matriks skor, optimasi graf, simulasi, atau evaluasi manusia. Jika estimasi berubah, lakukan #emph[replanning]. Jika informasi kurang, jalankan Understanding; jika skill kurang, jalankan Learning.

== Pseudocode
<pseudocode>
#Skylighting(([#NormalTok("state ← observe()");],
[#NormalTok("goal ← OrientationPUDAL(state)");],
[#NormalTok("map ← UnderstandingPUDAL(state, goal)");],
[#NormalTok("plan ← PlanningPUDAL(map, resources, capabilities, deadline)");],
[],
[#NormalTok("while not accepted(goal, state):");],
[#NormalTok("    next_milestone ← plan.next_milestone()");],
[#NormalTok("    if map_uncertain(next_milestone):");],
[#NormalTok("        map ← UnderstandingPUDAL(state, goal, map)");],
[#NormalTok("    if capability_gap(next_milestone):");],
[#NormalTok("        capabilities ← LearningPUDAL(capabilities, requirements)");],
[#NormalTok("    if not feasible(plan, resources, capabilities):");],
[#NormalTok("        plan ← PlanningPUDAL(map, resources, capabilities, deadline)");],
[#NormalTok("    state, resources, evidence ← ExecutionPUDAL(next_milestone, plan)");],
[#NormalTok("    update_models(evidence)");],
[#NormalTok("    if safety_or_budget_stop(): break");],));
Pseudocode ini skematis; implementasi memerlukan definisi tipe data, kondisi berhenti, dan otorisasi tindakan eksternal.

== Memahami fungsi model sebelum menghitung optimum
<memahami-fungsi-model-sebelum-menghitung-optimum>
Model matematis memaksa penyusun menyebut keadaan, kendala, dan tujuan secara konsisten. Ia tidak membuat nilai yang belum diukur menjadi pasti. Jika mutu, risiko, dan kemampuan hanya perkiraan kasar, keluaran optimasi perlu diperlakukan sebagai bahan analisis skenario. Istilah optimal selalu merujuk pada model, pilihan, data, dan asumsi tertentu.

Bedakan keadaan pekerjaan dari pengamatan. Pengguna mungkin sudah memahami konsep, tetapi satu jawaban salah membuat pengamat menduga sebaliknya. Secara konseptual, tulis $o_t = H\(x_t\,v_t\)$, dengan $o_t$ pengamatan dan $v_t$ ketidakpastian pengukuran. Model keadaan tidak harus diketahui sempurna. Catatan observasi, dugaan, dan keyakinan membantu menjaga ketidakpastian itu terlihat tanpa langsung memerlukan model probabilistik rumit.

== Contoh numerik pemilihan dua rute
<contoh-numerik-pemilihan-dua-rute>
Kelompok mempunyai 12 jam dan anggaran Rp100.000. Rute N membutuhkan 10 jam, tanpa biaya layanan, dengan skor mutu perkiraan 80. Rute V membutuhkan empat jam produksi dan tiga jam verifikasi, biaya Rp80.000, serta skor mutu perkiraan 85. Semua angka hipotetis, dan skor mutu dianggap berada pada rubrik yang sama. Kedua rute memenuhi batas waktu dan uang, tetapi kelayakan akademik masih harus diperiksa.

Gunakan $T' = T\/12$, $C' = C\/100000$, dan $Q' = Q\/100$. Untuk ilustrasi fungsi biaya $J = 0\,4 T' + 0\,2 C' - 0\,4 Q'$, rute N menghasilkan sekitar $0\,0133$ dan rute V sekitar $0\,0533$. Nilai lebih kecil membuat N dipilih pada bobot itu. Jika bobot waktu dinaikkan menjadi 0,7, biaya diturunkan menjadi 0,1, dan mutu menjadi 0,2, N menghasilkan sekitar 0,4233 sedangkan V sekitar 0,3183; pilihan berbalik.

Perhitungan menunjukkan bahwa kecepatan tidak menentukan pemenang sendirian dan bobot menyatakan preferensi. Ia tidak membuktikan N atau V lebih baik secara universal. Jika V melanggar aturan tugas, ia dikeluarkan sebelum skor dihitung. Kendala keras tidak boleh ditukar dengan keuntungan pada komponen lain.

== Menjaga kelayakan pada setiap langkah
<menjaga-kelayakan-pada-setiap-langkah>
Jumlah total sumber daya belum cukup. Misalkan rute membutuhkan Rp80.000 pada stage pertama tetapi dana baru tersedia pada stage kedua. Total pemasukan mungkin memadai, tetapi rute tidak layak pada urutan tersebut. Periksa saldo sebelum dan sesudah setiap transisi serta waktu masuknya suplai. Waktu belajar, verifikasi, dan perpindahan engine dimasukkan sebagai kegiatan nyata.

Untuk sumber daya yang dapat diisi ulang, batasi kapasitas jika relevan: $r_(i + 1)^(\(j\)) lt.eq r_max^(\(j\))$. Untuk kemampuan, hindari asumsi bahwa satu jam latihan selalu meningkatkan skor dengan jumlah yang sama. Perubahan kemampuan dapat bersifat tidak linear dan perlu bukti pengukuran. Formalisasi awal lebih baik sederhana dan jujur daripada rinci dengan parameter yang tidak mempunyai dasar.

== Sensitivitas dan dominasi
<sensitivitas-dan-dominasi>
Sebelum memakai skor berbobot, periksa apakah satu opsi didominasi: opsi lain setidaknya sama baik pada semua dimensi dan lebih baik pada satu dimensi yang relevan. Opsi yang tidak didominasi masih memerlukan keputusan nilai. Jika peringkat berubah ketika bobot sedikit bergeser atau estimasi mutu berubah kecil, laporkan pilihan sebagai sensitif.

Uji skenario terlambat, biaya meningkat, dan mutu lebih rendah daripada dugaan. Tampilkan kondisi ketika rute tidak lagi layak. Hasil ini membantu merancang cadangan dengan lebih langsung daripada satu angka objektif. Untuk pertanyaan dampak pendidikan, estimasi model keputusan tidak menggantikan desain inferensi kausal @cunningham2021.

== Latihan pemeriksaan model
<latihan-pemeriksaan-model>
Hitung ulang kedua fungsi di atas dan ubah waktu verifikasi V dari tiga menjadi enam jam. Rute V kini membutuhkan sepuluh jam dan perlu dibandingkan kembali. Jelaskan variabel yang diukur, yang diperkirakan, dan yang dipilih sebagai preferensi. Model dianggap dapat ditinjau jika pembaca lain dapat mengulang hitungan serta memahami mengapa keputusan berubah.

#part[BAGIAN III — IMPLEMENTASI ACADEMIC COMMONS]
= Dari Model PUDAL menuju Arsitektur Agen Akademik
<dari-model-pudal-menuju-arsitektur-agen-akademik>
== Satu agen, satu learning path
<satu-agen-satu-learning-path>
Enam agen merupakan paket layanan pembelajaran: #emph[Learning, Research, Writing, Coding & Data, Visualization,] dan #emph[Problem-Solving]. Tiap agen mempunyai kemampuan memahami kebutuhan, menggunakan sumber Knowledge/Skills, menjalankan Prompts dan Tools, mendokumentasikan Case Studies, serta melakukan evaluasi. #strong[Agen tidak harus berupa sistem otonom]: prototipe prompt--workflow yang dipandu manusia sudah memadai untuk pilot UAS.

#figure([
#box(image("images/portal.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Sumber daya bersama dalam portal dan bagaimana mahasiswa menggunakan learning paths.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-portal-1>


== Komponen paket agen
<komponen-paket-agen>
Struktur usulan (bukan klaim bahwa semua file sudah dibuat):

#Skylighting(([#NormalTok("agents/<theme>/");],
[#NormalTok("  README.md");],
[#NormalTok("  agent.yaml");],
[#NormalTok("  system-prompt.md");],
[#NormalTok("  workflow-pudal.yaml");],
[#NormalTok("  decision-policy.yaml");],
[#NormalTok("  resources.yaml");],
[#NormalTok("  tools.yaml");],
[#NormalTok("  evaluations/");],));
#NormalTok("agent.yaml"); mendefinisikan tujuan dan kewenangan; #NormalTok("workflow-pudal.yaml"); memetakan lima tingkat; #NormalTok("decision-policy.yaml"); menjelaskan pemilihan natural/instrumental/vehicular; #NormalTok("resources.yaml"); menjelaskan kebutuhan sumber daya; #NormalTok("evaluations/"); memuat kasus uji, rubrik, dan laporan hasil. Knowledge, Skills, dan Prompts yang sudah ada dipautkan, tidak diduplikasi.

== Kerja sama tiga kecerdasan
<kerja-sama-tiga-kecerdasan>
Individual Intelligence menetapkan arah, memahami dan mempertanggungjawabkan hasil. Collective Intelligence memberi peer review, pilihan alternatif, kemampuan tim, serta kurasi bersama. Artificial Intelligence membantu pencarian, eksperimentasi, drafting dan validasi awal. Agen PUDAL harus tetap transparan tentang sumber informasi, ketidakpastian dan pembagian tugas.

== Mekanisme pengendalian
<mekanisme-pengendalian>
Pada tiap tahap: lakukan identifikasi keadaan, bandingkan sasaran milestone, minta rekomendasi engine, cek kendala sumber daya, tampilkan alasan pemilihan rute, laksanakan tindakan dengan otorisasi relevan, kemudian simpan bukti hasil. Jika memerlukan tindakan eksternal berbiaya atau berdampak, minta persetujuan manusia terlebih dahulu.

== Dari enam agen ke orkestrasi
<dari-enam-agen-ke-orkestrasi>
Sebuah pekerjaan penulisan riset dapat memanggil Problem-Solving untuk merumuskan masalah, Research untuk sintesis referensi, Coding & Data untuk analisis, Writing untuk argumentasi, Visualization untuk presentasi, dan Learning untuk menutup kesenjangan kompetensi. Handoff antaragen harus memuat state, tujuan, sumber yang digunakan, verifikasi, dan batas kewenangan.

== Merancang layanan dari tugas pengguna
<merancang-layanan-dari-tugas-pengguna>
Sebelum memilih kerangka agen, tentukan tugas minimum: menerima tujuan, membaca sumber yang diizinkan, mengusulkan langkah, menghasilkan keluaran, dan menyediakan bukti. Learning Agent untuk Bayes dapat berupa workflow terpandu dengan beberapa prompt dan tabel acuan. Otonomi ditambah hanya jika fungsi tambahan memang dibutuhkan dan hasilnya dapat dikendalikan.

Pisahkan komponen perencana, pengambil sumber, pelaksana alat, penyimpan keadaan, dan pemeriksa. Pemisahan ini dapat bersifat logis dalam satu aplikasi; tidak harus ada model berbeda untuk setiap peran. Yang penting ialah mengetahui komponen mana menghasilkan klaim dan komponen mana mengujinya. Meminta model yang sama menyatakan "jawaban saya benar" tidak cukup sebagai verifikasi independen.

== Kontrak masukan, keluaran, dan provenance
<kontrak-masukan-keluaran-dan-provenance>
Masukan agen memuat tujuan, profil prasyarat, sumber yang tersedia, batas bantuan, dan kriteria penerimaan. Keluaran sebaiknya menyertakan hasil, sumber, hal yang belum pasti, pengujian, dan tindakan berikutnya. Jika sumber tidak ditemukan, agen menyatakan keterbatasan tersebut. Mengisi kekosongan dengan referensi yang tampak masuk akal merusak seluruh rantai bukti.

Untuk Research Agent, setiap ekstraksi mengacu pada identitas dokumen dan lokasi bagian. Untuk Coding & Data Agent, keluaran mengacu pada data, skema, versi prosedur, dan hasil eksekusi. Untuk Writing Agent, perubahan klaim dibedakan dari penyuntingan bahasa. Kontrak yang berbeda ini mengikuti karakter tugas, sehingga format tunggal yang terlalu umum dapat kehilangan informasi penting.

== Keamanan sumber dan kewenangan alat
<keamanan-sumber-dan-kewenangan-alat>
Dokumen yang dibaca agen merupakan data untuk ditelaah. Teks di dalamnya yang meminta penghapusan berkas, pengiriman data, atau pengubahan tujuan tidak memperoleh kewenangan hanya karena ada di sumber. Aturan alat berasal dari mandat pengguna dan kebijakan sistem. Pisahkan pembacaan sumber dari eksekusi tindakan, terutama ketika sumber berasal dari Internet atau unggahan pihak lain.

Gunakan kewenangan sesuai tugas, log tindakan, dan lingkungan uji untuk perubahan yang belum diperiksa. Kredensial tidak disimpan dalam prompt atau repositori publik. Batas biaya dan jumlah percobaan mencegah loop alat berjalan tanpa manfaat. NIST AI RMF menyediakan kerangka umum untuk pengelolaan risiko dan tanggung jawab @nist2023\; kontrol teknis ini adalah usulan implementasi untuk konteks buku.

== Handoff yang mempertahankan konteks
<handoff-yang-mempertahankan-konteks>
Research Agent menyerahkan kepada Writing Agent pertanyaan, klaim yang didukung, lokasi bukti, dan batas interpretasi. Writing Agent tidak perlu menerima semua log pencarian jika ringkasan terstruktur cukup, tetapi sumber rinci tetap tersedia. Visualization Agent menerima angka dan satuan yang telah diperiksa, bukan hanya permintaan membuat grafik yang menarik.

Jika agen berikutnya menemukan ketidakcocokan, ia mengembalikan pertanyaan dengan objek yang jelas. Misalnya, "angka 15,38% benar untuk parameter 1%, 90%, dan 95%; narasi terbaru menyebut prevalensi 5%." Handoff yang baik memungkinkan koreksi lokal tanpa mengulang seluruh pekerjaan dan tanpa menyembunyikan perubahan asumsi.

== Evaluasi sebelum memperluas penggunaan
<evaluasi-sebelum-memperluas-penggunaan>
Uji workflow pada kasus normal, miskonsepsi yang diketahui, informasi tidak lengkap, sumber bertentangan, serta layanan alat yang gagal. Catat apakah sistem meminta klarifikasi yang relevan, menyatakan ketidakpastian, dan menghentikan tindakan di luar mandat. Untuk tutor, nilai juga kualitas bantuan: apakah ia memberi petunjuk yang sesuai atau langsung mengerjakan tugas peserta?

Mulai dari mode rekomendasi dengan pemeriksaan manusia. Perluasan kewenangan didasarkan pada bukti perilaku dan dampak yang dapat diterima. Sebagai latihan, tulis satu kontrak agen untuk modul Bayes dan tiga kasus uji dengan hasil yang diharapkan. Spesifikasi dianggap cukup jelas ketika reviewer dapat menilai perilaku yang benar tanpa menebak niat pembuatnya.

= Enam Learning Paths Berbasis PUDAL
<enam-learning-paths-berbasis-pudal>
Setiap #emph[Learning Path] dimulai dari Case Study yang memperlihatkan kebutuhan dan kondisi awal, lalu memanfaatkan Knowledge, Skills, dan Prompts untuk menjalankan PUDAL. Case Study menjadi konteks seluruh siklus, bukan hanya tugas penutup. Setiap tema menyajikan demonstrasi lengkap dan tantangan mandiri untuk menguji transfer kemampuan.

== Tema 01 --- AI for Learning
<tema-01-ai-for-learning>
#strong[Agen:] Learning Agent · #strong[Kelompok:] 01--02 · #strong[Kasus:] Mempelajari Teorema Bayes.

#figure([
#box(image("images/lp1.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Learning Flow Tema 01: AI for Learning, mencakup artefak dan siklus PUDAL.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-lp1-1>


#table(
  columns: 2,
  align: (auto,auto,),
  table.header([PUDAL], [Learning activity],),
  table.hline(),
  [Perceive], [Kesulitan konsep dan hasil pre-test],
  [Understand], [Dasar belajar efektif; metakognisi],
  [Decide], [Pilih penjelasan, contoh, dialog, atau latihan],
  [Act], [Tutor Socratic; latihan; pemeriksa miskonsepsi],
  [Learn], [Post-test tanpa menyalin AI; revisi pembelajaran],
)
#strong[Alur praktik:] Pre-test → Tutor Socratic → Contoh Bayes → Latihan mandiri → Post-test → Revisi. #strong[Keluaran terverifikasi:] Pemahaman konsep dan kemampuan menyelesaikan soal baru. #strong[Strategi engine:] Natural untuk penalaran, argumentasi, dan akuntabilitas; instrumental untuk pengolahan, pencatatan, dan visualisasi; vehicular untuk layanan AI terdelegasi dengan pemeriksaan pengguna. Pilih per stage berdasarkan sumber daya serta kemampuan, tidak otomatis mengutamakan AI. #strong[Milestone:] diagnosis awal → pilihan strategi → demonstrasi kerja → validasi → perbaikan. Bila hasil evaluasi gagal, jalankan ulang Execution PUDAL; bila peta kurang lengkap aktifkan Understanding; bila skill kurang aktifkan Learning.

== Tema 02 --- AI for Literature Research
<tema-02-ai-for-literature-research>
#strong[Agen:] Research Agent · #strong[Kelompok:] 03--04 · #strong[Kasus:] Sintesis lima paper terverifikasi.

#figure([
#box(image("images/lp2.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Learning Flow Tema 02: AI for Literature Research, mencakup artefak dan siklus PUDAL.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-lp2-1>


#table(
  columns: 2,
  align: (auto,auto,),
  table.header([PUDAL], [Learning activity],),
  table.hline(),
  [Perceive], [Rumusan pertanyaan riset, cakupan, kriteria sumber],
  [Understand], [Struktur paper, pembacaan kritis dan strategi pencarian],
  [Decide], [Pilih kata kunci, lima sumber dan metode sintesis],
  [Act], [Cari, baca, ringkas, matriks, bandingkan literatur],
  [Learn], [Periksa kutipan dan klaim terhadap sumber asli],
)
#strong[Alur praktik:] Pertanyaan riset → Cari & seleksi → Baca kritis → Matriks → Sintesis → Verifikasi. #strong[Keluaran terverifikasi:] Matriks lima paper, sintesis kritis, research gap. #strong[Strategi engine:] Natural untuk penalaran, argumentasi, dan akuntabilitas; instrumental untuk pengolahan, pencatatan, dan visualisasi; vehicular untuk layanan AI terdelegasi dengan pemeriksaan pengguna. Pilih per stage berdasarkan sumber daya serta kemampuan, tidak otomatis mengutamakan AI. #strong[Milestone:] diagnosis awal → pilihan strategi → demonstrasi kerja → validasi → perbaikan. Bila hasil evaluasi gagal, jalankan ulang Execution PUDAL; bila peta kurang lengkap aktifkan Understanding; bila skill kurang aktifkan Learning.

== Tema 03 --- AI for Academic Writing
<tema-03-ai-for-academic-writing>
#strong[Agen:] Writing Agent · #strong[Kelompok:] 05--06 · #strong[Kasus:] Memperbaiki esai tentang etika AI.

#figure([
#box(image("images/lp3.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Learning Flow Tema 03: AI for Academic Writing, mencakup artefak dan siklus PUDAL.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-lp3-1>


#table(
  columns: 2,
  align: (auto,auto,),
  table.header([PUDAL], [Learning activity],),
  table.hline(),
  [Perceive], [Tujuan tulisan, audiens, kelemahan draf],
  [Understand], [Struktur argumen, integritas, sitasi],
  [Decide], [Pilih tesis, outline, bukti dan strategi revisi],
  [Act], [Membuat outline, draf dan revisi paragraf],
  [Learn], [Peer review dan verifikasi sitasi],
)
#strong[Alur praktik:] Masalah & audiens → Tesis & outline → Draf → Review → Verifikasi → Revisi. #strong[Keluaran terverifikasi:] Esai akhir, outline, umpan balik, jejak revisi. #strong[Strategi engine:] Natural untuk penalaran, argumentasi, dan akuntabilitas; instrumental untuk pengolahan, pencatatan, dan visualisasi; vehicular untuk layanan AI terdelegasi dengan pemeriksaan pengguna. Pilih per stage berdasarkan sumber daya serta kemampuan, tidak otomatis mengutamakan AI. #strong[Milestone:] diagnosis awal → pilihan strategi → demonstrasi kerja → validasi → perbaikan. Bila hasil evaluasi gagal, jalankan ulang Execution PUDAL; bila peta kurang lengkap aktifkan Understanding; bila skill kurang aktifkan Learning.

== Tema 04 --- AI for Coding & Data Analysis
<tema-04-ai-for-coding-data-analysis>
#strong[Agen:] Coding & Data Agent · #strong[Kelompok:] 07--08 · #strong[Kasus:] Analisis dataset akademik dengan Python.

#figure([
#box(image("images/lp4.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Learning Flow Tema 04: AI for Coding & Data Analysis, mencakup artefak dan siklus PUDAL.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-lp4-1>


#table(
  columns: 2,
  align: (auto,auto,),
  table.header([PUDAL], [Learning activity],),
  table.hline(),
  [Perceive], [Dataset, kualitas dan pertanyaan analisis],
  [Understand], [Workflow coding, debugging, reproduksibilitas],
  [Decide], [Pilih pembersihan, statistik, algoritma dan grafik],
  [Act], [Notebook Python, Pandas, Matplotlib],
  [Learn], [Uji hitung, audit kode, dokumentasi],
)
#strong[Alur praktik:] Pertanyaan → Siapkan data → Notebook → Analisis → Visualisasi → Verifikasi. #strong[Keluaran terverifikasi:] Notebook teruji, grafik, statistik dan interpretasi. #strong[Strategi engine:] Natural untuk penalaran, argumentasi, dan akuntabilitas; instrumental untuk pengolahan, pencatatan, dan visualisasi; vehicular untuk layanan AI terdelegasi dengan pemeriksaan pengguna. Pilih per stage berdasarkan sumber daya serta kemampuan, tidak otomatis mengutamakan AI. #strong[Milestone:] diagnosis awal → pilihan strategi → demonstrasi kerja → validasi → perbaikan. Bila hasil evaluasi gagal, jalankan ulang Execution PUDAL; bila peta kurang lengkap aktifkan Understanding; bila skill kurang aktifkan Learning.

== Tema 05 --- AI for Visualization & Presentation
<tema-05-ai-for-visualization-presentation>
#strong[Agen:] Visualization Agent · #strong[Kelompok:] 09--10 · #strong[Kasus:] Dari paper ke infografik dan presentasi.

#figure([
#box(image("images/lp5.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Learning Flow Tema 05: AI for Visualization & Presentation, mencakup artefak dan siklus PUDAL.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-lp5-1>


#table(
  columns: 2,
  align: (auto,auto,),
  table.header([PUDAL], [Learning activity],),
  table.hline(),
  [Perceive], [Audiens, tujuan, pesan dan karakter data],
  [Understand], [Prinsip visual, akurasi grafik, storytelling],
  [Decide], [Pilih pesan utama, visual dan strategi TAIDA],
  [Act], [Diagram, infografik, lima slide, presentasi lima menit],
  [Learn], [Uji pemahaman audiens, cek distorsi, revisi],
)
#strong[Alur praktik:] Kenali audiens → Baca paper → Pilih pesan → Buat visual → Presentasi → Umpan balik. #strong[Keluaran terverifikasi:] Infografik akurat, lima slide, narasi, evaluasi audiens. #strong[Strategi engine:] Natural untuk penalaran, argumentasi, dan akuntabilitas; instrumental untuk pengolahan, pencatatan, dan visualisasi; vehicular untuk layanan AI terdelegasi dengan pemeriksaan pengguna. Pilih per stage berdasarkan sumber daya serta kemampuan, tidak otomatis mengutamakan AI. #strong[Milestone:] diagnosis awal → pilihan strategi → demonstrasi kerja → validasi → perbaikan. Bila hasil evaluasi gagal, jalankan ulang Execution PUDAL; bila peta kurang lengkap aktifkan Understanding; bila skill kurang aktifkan Learning.

== Tema 06 --- AI for Academic Problem Solving
<tema-06-ai-for-academic-problem-solving>
#strong[Agen:] Problem-Solving Agent · #strong[Kelompok:] 11--12 · #strong[Kasus:] Perbaikan masalah layanan akademik.

#figure([
#box(image("images/lp6.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Learning Flow Tema 06: AI for Academic Problem Solving, mencakup artefak dan siklus PUDAL.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-lp6-1>


#table(
  columns: 2,
  align: (auto,auto,),
  table.header([PUDAL], [Learning activity],),
  table.hline(),
  [Perceive], [Gejala, pengguna, kebutuhan, data awal],
  [Understand], [Problem framing, akar masalah, hubungan sebab-akibat],
  [Decide], [Pilih alternatif berdasar nilai, risiko dan kapasitas],
  [Act], [Peta masalah, decision matrix, rekomendasi],
  [Learn], [Uji skenario dan evaluasi dampak solusi],
)
#strong[Alur praktik:] Kenali masalah → Data → Peta akar → Alternatif → Matriks → Solusi → Evaluasi. #strong[Keluaran terverifikasi:] Peta masalah, opsi, matriks keputusan, rekomendasi teruji. #strong[Strategi engine:] Natural untuk penalaran, argumentasi, dan akuntabilitas; instrumental untuk pengolahan, pencatatan, dan visualisasi; vehicular untuk layanan AI terdelegasi dengan pemeriksaan pengguna. Pilih per stage berdasarkan sumber daya serta kemampuan, tidak otomatis mengutamakan AI. #strong[Milestone:] diagnosis awal → pilihan strategi → demonstrasi kerja → validasi → perbaikan. Bila hasil evaluasi gagal, jalankan ulang Execution PUDAL; bila peta kurang lengkap aktifkan Understanding; bila skill kurang aktifkan Learning.

== Memasuki learning path berdasarkan diagnosis
<memasuki-learning-path-berdasarkan-diagnosis>
Pengguna tidak selalu memulai dari tema pertama. Peserta yang sedang menyusun esai mungkin masuk melalui Writing lalu membutuhkan Research untuk memeriksa bukti. Peserta yang membawa dataset dapat masuk melalui Coding & Data, kemudian membutuhkan Visualization. Halaman masuk perlu menanyakan tujuan dan prasyarat, lalu menyarankan jalur yang relevan. Pengguna tetap dapat melihat alasan saran tersebut dan memilih rute yang sesuai.

Learning path merupakan hubungan aktivitas, sumber, bantuan, dan bukti penguasaan. Daftar tautan belum menjadi jalur belajar jika pengguna tidak tahu kapan berpindah tahap atau bagaimana menilai hasil. Gunakan transisi yang konkret: setelah mampu menjelaskan konsep, lanjut latihan; setelah latihan memenuhi kriteria, coba kasus baru; jika gagal, kembali pada diagnosis yang sesuai.

== Pendalaman Tema 1 dan 2: konsep dan penilaian sumber
<pendalaman-tema-1-dan-2-konsep-dan-penilaian-sumber>
Pada Learning, satu kesalahan Bayes dipakai untuk menentukan bantuan. Peserta yang menukar probabilitas mendapat latihan kelompok pembanding; peserta yang memahami konsep tetapi salah menghitung mendapat pemeriksaan aritmetika. Tantangan mandiri memakai konteks spam agar transfer struktur dapat dinilai. Aktivitas mengambil kembali pengetahuan menjadi salah satu pilihan latihan, dengan dukungan terbatas dari riset retrieval practice @roediger2006.

Pada Literature Research, lima paper merupakan titik mulai praktikum, bukan bukti cakupan lengkap. Pengguna mencatat kata kunci, alasan seleksi, dan lokasi klaim. Tantangan mandiri meminta pengguna menambahkan studi yang tidak sepakat dengan pola awal lalu memperbarui sintesis. PRISMA relevan ketika kegiatan dikembangkan menjadi review sistematis dengan pelaporan yang sesuai @prisma2020.

== Pendalaman Tema 3 dan 4: argumen dan analisis
<pendalaman-tema-3-dan-4-argumen-dan-analisis>
Pada Writing, masukan awal dapat berupa tesis yang terlalu luas. Agen meminta penulis memperjelas lingkup dan alasan sebelum menyunting kalimat. Milestone tercapai ketika setiap klaim penting mempunyai bukti dan hubungan penalaran yang dapat dijelaskan. Tantangan berikutnya adalah menghadapi keberatan kuat, bukan sekadar memperpanjang tulisan. Kerangka argumen membantu memisahkan bukti dari penghubungnya @purdue-toulmin.

Pada Coding & Data, pengguna memulai dengan unit observasi dan pertanyaan. Tutorial memakai data kecil yang dapat diperiksa manual sebelum skala diperbesar. Milestone teknis berupa skrip yang dapat dijalankan ulang; milestone interpretasi berupa penjelasan apa yang tidak dapat disimpulkan. Tantangan mandiri memasukkan duplikasi kunci atau nilai kosong agar pengguna mendiagnosis masalah, bukan hanya menjalankan notebook.

== Pendalaman Tema 5 dan 6: representasi dan negosiasi
<pendalaman-tema-5-dan-6-representasi-dan-negosiasi>
Pada Visualization, pengguna menulis pesan utama dan VKS sebelum membuat layout. Reviewer menelusuri angka ke sumber dan menguji apakah pembaca memahami relasi. Tantangan mandiri mengubah audiens dari teman sekelas menjadi pembaca umum, sehingga pengguna perlu menyederhanakan tanpa mengubah makna. Prinsip representasi ketidakpastian dan warna memberi bahan pemeriksaan @wilke2019.

Pada Problem Solving, pengguna memisahkan gejala, kebutuhan, dan usulan solusi. Matriks keputusan dibuat setelah batas wajib ditentukan. Tantangan mandiri mengubah satu kendala, misalnya akses data hilang atau tenggat dipercepat. Peserta harus memperbarui rute dengan alasan, bukan mempertahankan skor lama. Hasilnya dinilai dari kelayakan dan kemampuan mempertanggungjawabkan trade-off.

== Menghubungkan keenam jalur menjadi satu proyek
<menghubungkan-keenam-jalur-menjadi-satu-proyek>
Satu proyek integratif dapat dimulai dari masalah kesulitan belajar probabilitas. Research memetakan bukti, Learning merancang latihan, Writing menyusun argumentasi desain, Coding & Data menganalisis hasil pilot, Visualization mengomunikasikan temuan, dan Problem Solving mengelola kebutuhan pihak terkait. Urutan ini hanya salah satu kemungkinan; setiap handoff perlu menjaga sumber dan batas klaim.

Untuk latihan, pilih dua tema yang berdekatan lalu tulis apa yang diserahkan dari tema pertama dan apa yang diuji tema kedua. Jika keduanya hanya bertukar berkas tanpa kriteria, perjelas kontraknya. Jalur belajar menjadi bermakna ketika kemajuan dapat terlihat dari kemampuan pengguna, selain dari banyaknya materi yang telah dibuka.

= UAS sebagai Proyek Triune Academic Commons
<uas-sebagai-proyek-triune-academic-commons>
== Tantangan untuk mahasiswa
<tantangan-untuk-mahasiswa>
#strong[Misi 21 hari:] 60+ mahasiswa dalam #strong[12 kelompok] mengembangkan #strong[6 AI Academic Agents], #strong[6 Learning Paths], dan #strong[42 artefak akademik] yang dapat dipakai mahasiswa lain. Nilai proyek bukan hanya dari jumlah berkas, melainkan dari manfaat, kualitas, pengujian, dan kemampuan bekerja sama.

#figure([
#box(image("images/flow.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Alur kerja mahasiswa dari pemahaman kasus, pengembangan artefak, review, hingga publikasi.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-flow-1>


== TAIDA sebagai desain motivasi dan mobilisasi
<taida-sebagai-desain-motivasi-dan-mobilisasi>
- #strong[Target:] mahasiswa sebagai pencipta dan penerima manfaat; perubahan dari konsumen jawaban AI menjadi pelaku yang paham dan mampu.
- #strong[Attention:] karya akademik dapat hidup melampaui akhir semester.
- #strong[Interest:] tiap tema menyediakan alat dan kasus yang relevan dengan pekerjaan nyata.
- #strong[Desire:] ada portofolio GitHub, kompetensi baru, kontribusi kolektif, dan pengakuan berbasis hasil.
- #strong[Action:] bergabung dalam tim, menerima tanggung jawab, menyusun artefak, melakukan review, mempublikasikan bukti.

== Pembagian tugas
<pembagian-tugas>
Tim 01--02 mengembangkan AI for Learning, 03--04 Literature Research, 05--06 Academic Writing, 07--08 Coding & Data, 09--10 Visualization & Presentation, dan 11--12 Problem Solving. Setiap tim menghasilkan Knowledge, Skill, Prompt; dua tim satu tema bersama menghasilkan Case Study dan Learning Path. Pembagian rinci ada pada Lampiran A dan file Excel #NormalTok("data/KIPP_Pembagian_Kelompok_dan_42_Artefak.xlsx");.

== Tiga minggu dengan decision gates
<tiga-minggu-dengan-decision-gates>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Waktu], [Fokus], [Bukti checkpoint],),
  table.hline(),
  [Minggu 1], [Kenali pengguna, rumuskan masalah, Knowledge], [12 Knowledge awal; peta masalah dan tujuan],
  [Minggu 2], [Skills, Prompts, eksperimen], [12 Skills dan 12 Prompts teruji],
  [Minggu 3], [Case Studies, showcase, evaluasi], [6 kasus lengkap, 6 paket agen, perbaikan akhir],
)
== Bukti individual dan kolektif
<bukti-individual-dan-kolektif>
Individu mengumpulkan kontribusi konkret, proses belajar, keputusan yang diambil, ulasan yang diberikan, serta refleksi. Tim membuktikan kualitas tiga artefak. Pasangan tim membuktikan integrasi Case Study dan Learning Path, termasuk keputusan engine, kendala sumber daya, dan satu siklus PUDAL penuh. Review lintas tim diperlukan untuk menilai kemudahan penggunaan dan integritas materi.

== Rubrik usulan, belum ditetapkan
<rubrik-usulan-belum-ditetapkan>
#table(
  columns: 2,
  align: (auto,right,),
  table.header([Dimensi], [Bobot usulan],),
  table.hline(),
  [Komunikasi dan TAIDA], [25%],
  [Kontribusi artefak individual], [25%],
  [Kolaborasi dan peer review], [20%],
  [Learning Path, Case Study, dan agen], [20%],
  [Refleksi serta integritas AI], [10%],
)
Bobot dan kebijakan final mengikuti keputusan resmi pengampu. Tidak ada kewajiban membuat model AI baru atau membeli layanan AI berbayar.

== Memulai proyek dengan kesepakatan kerja
<memulai-proyek-dengan-kesepakatan-kerja>
Pada hari pertama, pasangan kelompok menyepakati pengguna sasaran, kasus, keluaran minimum, dan cara penerimaan. Pembagian tugas sebaiknya mengikuti fungsi dan saling bergantung secara wajar. Satu anggota dapat memegang kurasi sumber, tetapi anggota lain tetap harus memahami sumber utama. Satu anggota memegang integrasi, tetapi tidak menjadi satu-satunya orang yang dapat menjalankan paket.

Tuliskan kontrak kerja yang mencakup jadwal komunikasi, lokasi berkas, aturan perubahan, cara memberi review, dan penyelesaian hambatan. Kesepakatan ini melindungi anggota yang bekerja di waktu berbeda serta mencegah keputusan penting tersimpan hanya dalam percakapan pribadi. Jika anggota menghadapi kendala, tim memperbarui pembagian kerja dan menyimpan alasan.

== Minggu pertama: menguji satu irisan lengkap
<minggu-pertama-menguji-satu-irisan-lengkap>
Daripada menulis seluruh Knowledge lebih dahulu, buat satu irisan kecil dari konsep sampai contoh penggunaan. Untuk tema Bayes, irisan itu mencakup penjelasan penyebut, tutorial tabel, satu prompt tutor, dan satu catatan kasus. Pengguna lain mencoba irisan tersebut. Hasil uji menunjukkan apakah rancangan dasar layak sebelum setiap kelompok memperluas artefaknya.

Gate minggu pertama memeriksa pertanyaan pengguna, kebenaran konsep inti, keterlacakan sumber, dan kelayakan rencana. Draf yang panjang tetapi belum menjawab pengguna tidak otomatis lolos. Jika kebutuhan terlalu luas, kurangi lingkup saat biaya perubahan masih rendah. Tetapkan pemilik tindakan untuk kekurangan yang ditemukan.

== Minggu kedua: pengujian antarpenyusun
<minggu-kedua-pengujian-antarpenyusun>
Setiap tutorial dijalankan anggota yang tidak menulisnya. Setiap prompt dicoba pada masukan yang tidak dipakai saat pengembangan. Knowledge diperiksa oleh pembaca yang diminta menerangkan ulang konsep. Uji ini mengungkap asumsi tersirat dan variasi perilaku AI. Catat versi alat atau layanan ketika relevan, karena keluaran dapat berubah.

Jangan menunggu semua berkas selesai untuk integrasi. Hubungkan artefak sejak awal melalui ID dan prasyarat. Jika tutorial mengacu pada istilah yang tidak ada di Knowledge, perbaiki hubungan tersebut. Jika prompt mengasumsikan dataset yang tidak boleh dibagikan, sediakan alternatif yang sah atau ubah lingkup demonstrasi.

== Minggu ketiga: membuktikan hasil dan kontribusi
<minggu-ketiga-membuktikan-hasil-dan-kontribusi>
Showcase menampilkan satu perjalanan pengguna dari A sampai bukti B. Presentasi perlu menunjukkan keputusan yang berubah setelah pengujian, selain produk akhir. Reviewer memilih satu klaim, satu langkah tutorial, dan satu perilaku prompt untuk diperiksa. Demonstrasi yang gagal tidak ditutupi dengan video lama; jelaskan versi, penyebab, dan perbaikan yang masih diperlukan.

Kontribusi individual dapat berupa analisis sumber, perbaikan tutorial, diagnosis bug, review yang mengubah rancangan, atau penjelasan konsep. Bukti volume seperti jumlah commit dipakai sebagai petunjuk proses, bukan ukuran tunggal mutu. Minta setiap anggota mempertahankan satu keputusan penting dan mengerjakan tantangan pendek yang relevan.

== Menilai tanpa menghilangkan tujuan komunikasi
<menilai-tanpa-menghilangkan-tujuan-komunikasi>
Mata kuliah KIPP memerlukan bukti komunikasi: memahami penerima, membuat pesan yang relevan, mendengarkan umpan balik, serta berkoordinasi secara bertanggung jawab. Produk AI menjadi konteks praktik keterampilan tersebut. Tujuan dan asesmen perlu selaras @cmu-alignment, sehingga kecanggihan teknis tidak boleh menggantikan seluruh penilaian komunikasi.

Bobot pada bab ini tetap usulan dan tidak mengubah ketentuan resmi. Tim perlu merujuk arahan pengampu untuk keputusan penilaian. Sebagai latihan perencanaan, susun daftar pekerjaan wajib, pekerjaan tambahan, dan pekerjaan yang dapat dibatalkan jika kapasitas turun. Jelaskan bukti minimum yang tetap dijaga. Kejelasan ini membantu proyek selesai dengan mutu yang dapat diperiksa tanpa menggantungkan keberhasilan pada penambahan jam kerja di akhir.

= Repositori, Portal, dan Workflow Kolaboratif
<repositori-portal-dan-workflow-kolaboratif>
== Satu portal, satu repositori bersama
<satu-portal-satu-repositori-bersama>
Portal proyek disimpan di repositori publik #link("https://github.com/azral1962/kipp-triune-academic-commons")[azral1962/kipp-triune-academic-commons], dengan branch utama #NormalTok("main");. Repositori ini menjadi sumber bersama untuk beranda portal, enam tema, katalog 42 artefak, enam learning path, panduan proyek, dan otomatisasi penerbitan. Mahasiswa mengerjakan sumber yang tersedia melalui Issue dan Pull Request; forum akademik menggunakan GitHub Discussions.

Uraian implementasi pada bab ini mengacu pada pemeriksaan #strong[23 November 2026], terhadap commit #link("https://github.com/azral1962/kipp-triune-academic-commons/tree/c591a6a2dd1084063b049189d20e34a0ad3dda94")[#NormalTok("c591a6a");]. Saat diperiksa, seluruh 42 artefak masih berstatus #NormalTok("draft"); dan memiliki penanda #NormalTok("[ISI]");\; enam learning path juga masih berupa kerangka. Karena itu, jumlah berkas menunjukkan kesiapan wadah kerja, belum membuktikan penyelesaian materi akademik. Lingkup pilot, aturan kontribusi, dan keadaan awal dijelaskan dalam #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/README.md")[README portal].

#figure([
#box(image("images/repository.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Contoh struktur portal dan repositori, termasuk penomoran artefak.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-repository-1>


== Penomoran artefak
<penomoran-artefak>
Repositori menggunakan dua penanda yang saling melengkapi: #strong[ID tetap], seperti #NormalTok("P-R01");, dan #strong[kode hierarkis TT.JJ.NN], seperti #NormalTok("02.03.01");. TT menyatakan tema, JJ menyatakan jenis (01 Knowledge, 02 Skills, 03 AI Prompts, 04 Case Studies), dan NN menyatakan urutan. ID tetap dipakai untuk melacak tugas, diskusi, dan kontribusi; kode hierarkis menjelaskan susunan artefak. Keduanya tetap disimpan pada metadata dan registri.

Contoh nyata adalah #strong[Critical Paper Reader], milik Tim 03: ID #NormalTok("P-R01");, kode #NormalTok("02.03.01");, dan path #NormalTok("topics/02-literature-research/03-ai-prompts/02-03-01-p-r01.qmd");. ID tersebut tidak diganti menjadi kode numerik. Standar serta aturan pemindahan berkas tersedia pada #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/docs/INDEX-CODING-STANDARD.md")[standar indeks repositori].

== Struktur folder repositori portal
<struktur-folder-repositori-portal>
#Skylighting(([#NormalTok("kipp-triune-academic-commons/");],
[#NormalTok("  README.md");],
[#NormalTok("  CONTRIBUTING.md");],
[#NormalTok("  PROJECT_CHARTER.md");],
[#NormalTok("  GOVERNANCE.md");],
[#NormalTok("  QUALITY_GATE.md");],
[#NormalTok("  LICENSE-DECISION.md");],
[#NormalTok("  _quarto.yml");],
[#NormalTok("  index.qmd");],
[#NormalTok("  catalog.qmd");],
[#NormalTok("  ARTIFACT_REGISTER.csv");],
[#NormalTok("  portal/");],
[#NormalTok("    index.html");],
[#NormalTok("    assets/");],
[#NormalTok("      app.js");],
[#NormalTok("      style.css");],
[#NormalTok("  topics/");],
[#NormalTok("    01-ai-learning/");],
[#NormalTok("      01-knowledge/");],
[#NormalTok("      02-skills/");],
[#NormalTok("      03-ai-prompts/");],
[#NormalTok("      04-case-studies/");],
[#NormalTok("    02-literature-research/");],
[#NormalTok("    03-academic-writing/");],
[#NormalTok("    04-coding-data/");],
[#NormalTok("    05-visualization-presentation/");],
[#NormalTok("    06-academic-problem-solving/");],
[#NormalTok("  learning-paths/");],
[#NormalTok("  forum/");],
[#NormalTok("  docs/                     # panduan proyek dan Git/GitHub");],
[#NormalTok("  templates/");],
[#NormalTok("  assessments/");],
[#NormalTok("  governance/");],
[#NormalTok("  datasets/");],
[#NormalTok("  notebooks/");],
[#NormalTok("  visuals/");],
[#NormalTok("  scripts/");],
[#NormalTok("    check_artifacts.py");],
[#NormalTok("    check_portal.py");],
[#NormalTok("    build_catalog.py");],
[#NormalTok("    build_portal.py");],
[#NormalTok("  .github/");],
[#NormalTok("    CODEOWNERS");],
[#NormalTok("    ISSUE_TEMPLATE/");],
[#NormalTok("    pull_request_template.md");],
[#NormalTok("    workflows/");],
[#NormalTok("      validate.yml");],
[#NormalTok("      publish.yml");],
[#NormalTok("  _site/                    # dihasilkan oleh Quarto");],
[#NormalTok("  _public/                  # paket akhir hasil build portal");],));
Folder tema dan jenis sudah memakai penomoran pada struktur di atas. #NormalTok("_site/"); dan #NormalTok("_public/"); merupakan keluaran build, bukan tempat mahasiswa mengisi materi. Folder #NormalTok("agents/"); belum ada pada versi yang diperiksa; gagasan enam agen pada rancangan proyek tidak boleh dibaca sebagai enam implementasi perangkat lunak yang sudah tersedia.

Setiap tema memiliki tujuh artefak: dua Knowledge, dua Skills, dua Prompts, dan satu Case Study. Pasangan Tim 01--02 sampai Tim 11--12 mengembangkan enam tema secara berurutan. Pembagian ID, prioritas, dan penanggung jawab dibaca dari #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/ARTIFACT_REGISTER.csv")[ARTIFACT\_REGISTER.csv]\; daftar asli dalam buku tetap menjadi jejak historis, sedangkan pekerjaan portal mengikuti registri portal terkini.

== Kolaborasi GitHub: dari tugas sampai artefak terverifikasi
<kolaborasi-github-dari-tugas-sampai-artefak-terverifikasi>
#figure([
#box(image("images/github.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Panduan penggunaan Git dan GitHub untuk pengembangan serta review artefak.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-github-1>


#strong[Issue → Branch → Edit dan Uji → Commit → Push → Pull Request → Peer Review lintas tim → Revisi → Merge → Publish.] Issue menyatakan tujuan dan kriteria penerimaan; PR membuktikan perubahan serta pengujian; reviewer memeriksa isi, referensi, dan keterpakaian. Dalam konvensi metadata repositori, hasil yang sudah melewati review serta uji dicatat sebagai #NormalTok("reviewed");. Istilah #emph[terverifikasi] pada pembahasan mutu menjelaskan proses pemeriksaan, bukan nilai metadata baru bernama #NormalTok("verified");.

Dalam Academic Commons, alur tersebut menghubungkan pekerjaan 12 kelompok dengan mutu 42 artefak. Satu perubahan sebaiknya cukup kecil untuk diperiksa secara utuh. Langkah di bawah menerapkan #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/CONTRIBUTING.md")[panduan kontribusi portal] dengan contoh #NormalTok("P-R01");. Nomor Issue pada contoh tetap ilustratif. Panduan mahasiswa yang lebih rinci tersedia di #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/docs/student-workflow.md")[docs/student-workflow.md], sedangkan pola branch mengikuti #link("https://docs.github.com/en/get-started/using-github/github-flow")[GitHub flow].

=== Memahami Git, GitHub, dan istilah dasarnya
<memahami-git-github-dan-istilah-dasarnya>
#strong[Git] mencatat versi berkas dan riwayat perubahan pada komputer. #strong[GitHub] menyediakan tempat menyimpan repositori secara daring, membahas pekerjaan, meninjau perubahan, dan menerbitkan portal. Menyimpan berkas di komputer belum berarti perubahan tersebut sudah tersedia bagi anggota lain.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Istilah], [Arti praktis dalam proyek],),
  table.hline(),
  [Repository atau repositori], [Wadah sumber portal, artefak, registri, dan riwayat perubahan],
  [Clone], [Membuat salinan lokal repositori beserta riwayat Git],
  [Branch], [Jalur kerja untuk mengembangkan perubahan sebelum digabung],
  [Commit], [Rekaman perubahan terpilih dengan pesan dan identitas penulis],
  [Push], [Mengirim commit lokal ke repositori daring],
  [Pull], [Mengambil dan mengintegrasikan perubahan dari repositori daring],
  [Issue], [Catatan masalah atau tugas, beserta pembahasan dan kriteria penerimaannya],
  [Pull Request atau PR], [Usulan menggabungkan perubahan antarbranch untuk ditinjau],
  [Merge], [Menggabungkan perubahan suatu branch ke branch tujuan],
  [Fork], [Salinan repositori di akun lain untuk kontribusi tanpa akses tulis ke repositori asal],
)
Branch utama portal bernama #NormalTok("main");. Mengunggah berkas, menggabungkan PR, dan menerbitkan portal adalah tiga kejadian berbeda; keberhasilan salah satunya tidak membuktikan dua lainnya berhasil. Discussions digunakan untuk pertanyaan atau pembahasan akademik, Issues untuk pekerjaan konkret, dan PR untuk perubahan berkas yang akan diintegrasikan.

=== Persiapan akun, repositori, dan pembagian peran
<persiapan-akun-repositori-dan-pembagian-peran>
Gunakan repositori #NormalTok("azral1962/kipp-triune-academic-commons"); yang sudah tersedia. Koordinator mengatur akses anggota, mengisi #NormalTok("governance/team-roster.csv");, dan mencatat keputusan dalam #NormalTok("governance/decision-log.md");. #NormalTok("PROJECT_CHARTER.md"); masih ditandai draf dan #NormalTok("LICENSE-DECISION.md"); menyatakan lisensi belum dipilih pada versi yang diperiksa. Pengampu dan perwakilan mahasiswa perlu mengesahkan kesepakatan proyek serta hak publikasi karya.

Setiap anggota perlu dapat masuk ke GitHub, menerima undangan akses, menemukan repositori, dan membuka Issue. Aktifkan autentikasi dua faktor serta simpan kode pemulihan dengan aman. Jalur lokal memerlukan Git, editor, Python 3.10 atau lebih baru, serta Quarto untuk preview lengkap; workflow CI memakai Python 3.12. GitHub Desktop dapat menjadi pilihan antarmuka grafis. Akses Git melalui HTTPS menggunakan mekanisme kredensial seperti token atau pengelola kredensial; kata sandi akun bukan pengganti token untuk operasi Git. Alternatifnya adalah SSH. Ikuti #link("https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-authentication-to-github")[dokumentasi autentikasi GitHub] sesuai metode yang dipilih.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Peran kerja], [Tanggung jawab utama],),
  table.hline(),
  [Koordinator repositori], [Mengatur akses, aturan branch, dan penyelesaian hambatan integrasi],
  [Kontributor], [Mengembangkan sumber, menguji perubahan, dan menanggapi review],
  [Reviewer lintas kelompok], [Memeriksa ketepatan isi dan mencoba artefak dari sudut pengguna],
  [Integrator/pengelola rilis], [Memastikan perubahan yang diterima dapat dibangun dan diterbitkan bersama],
)
Peran kerja ini tidak otomatis sama dengan nama tingkat izin GitHub. Berikan hak akses sesuai kebutuhan; seluruh anggota tidak perlu menjadi administrator. Kontributor sebaiknya tidak menjadi satu-satunya penilai perubahan sendiri. Sepakati minimal satu reviewer dari luar penyusun artefak sebelum merge.

#NormalTok("README.md");, #NormalTok("CONTRIBUTING.md");, #NormalTok("GOVERNANCE.md");, dan #NormalTok("QUALITY_GATE.md"); sudah tersedia sebagai panduan kerja. Aturan kontribusi menggunakan pola branch #NormalTok("tim-XX/ID-deskripsi"); dan meminta satu reviewer dari tim lain. #NormalTok(".github/CODEOWNERS"); masih berisi contoh akun yang dikomentari; keberadaannya belum berarti reviewer otomatis telah ditetapkan. Pengelola perlu memeriksa akun pemilik, izin, serta kewajiban review pada pengaturan branch. Mekanisme pembatasannya dijelaskan dalam #link("https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches")[aturan protected branches].

=== Merumuskan pekerjaan melalui Issue
<merumuskan-pekerjaan-melalui-issue>
Di repositori, buka #strong[Issues → New issue]. Cari dahulu apakah masalah yang sama sudah dilaporkan. Pilih formulir #strong[Tugas artefak], yang disediakan dalam #NormalTok(".github/ISSUE_TEMPLATE/artifact-task.yml");. Formulir meminta ID artefak, tim, sasaran pengguna dan ukuran sukses, serta pekerjaan dan bukti uji. Untuk laporan masalah mutu, tersedia formulir #NormalTok("quality-report.yml");. Contoh pengisian tugas berikut memakai artefak yang benar-benar tersedia; isi pekerjaan merupakan rancangan latihan.

#Skylighting(([#NormalTok("Judul: [P-R01 | 02.03.01] Isi dan uji Critical Paper Reader");],
[],
[#NormalTok("Masalah pengguna:");],
[#NormalTok("Mahasiswa memerlukan bantuan membaca paper tanpa menerima sumber karangan AI.");],
[],
[#NormalTok("Lingkup perubahan:");],
[#NormalTok("Isi prompt, contoh aktual, pengujian, batasan, dan catatan review.");],
[],
[#NormalTok("Lokasi:");],
[#NormalTok("topics/02-literature-research/03-ai-prompts/02-03-01-p-r01.qmd");],
[],
[#NormalTok("Kriteria penerimaan:");],
[#NormalTok("- [ ] Tujuan, pengguna, dan bahan masukan prompt dinyatakan.");],
[#NormalTok("- [ ] Dua contoh normal dan satu contoh bermasalah dicoba.");],
[#NormalTok("- [ ] Klaim keluaran diperiksa terhadap paper sumber.");],
[#NormalTok("- [ ] Reviewer lintas tim dan pengguna uji memberi umpan balik.");],
[#NormalTok("- [ ] Halaman dapat dirender dan tautan terkait berfungsi.");],
[],
[#NormalTok("Tim penanggung jawab: Tim 03; tetapkan satu anggota koordinator tugas");],
[#NormalTok("Reviewer: anggota dari kelompok lain");],
[#NormalTok("Bukti yang diminta: input-output aktual, sumber, catatan uji, dan hasil render");],));
Formulir tugas mencantumkan label #NormalTok("artifact");\; pengelola memastikan label tersebut tersedia. Label tambahan, milestone minggu 1--3, dan papan Projects dapat disepakati untuk koordinasi. Jika dipakai, kolom seperti #strong[Direncanakan → Dikerjakan → Direview → Perlu revisi → Diterima] merupakan alat perencanaan tim. Kolom itu tidak otomatis mengubah nilai #NormalTok("status"); pada YAML dan CSV.

=== Jalur pemula: menyunting melalui browser
<jalur-pemula-menyunting-melalui-browser>
Untuk koreksi teks singkat, anggota yang memiliki akses tulis dapat bekerja tanpa memasang Git lokal:

+ Buka repositori dan pastikan branch awal adalah #NormalTok("main"); yang terbaru.
+ Buat branch dengan nama yang menjelaskan tugas, misalnya #NormalTok("tim-03/P-R01-critical-reader");.
+ Pada branch tersebut, buka #NormalTok("topics/02-literature-research/03-ai-prompts/02-03-01-p-r01.qmd"); dan pilih penyuntingan. Isi bagian #NormalTok("[ISI]");, pertahankan metadata, lalu periksa diff, yaitu perbandingan sebelum dan sesudah perubahan.
+ Simpan sebagai commit pada branch kerja dengan pesan yang spesifik, misalnya #NormalTok("docs(P-R01): isi dan uji Critical Paper Reader");.
+ Buka PR menuju #NormalTok("main");, hubungkan Issue, dan minta review. Jika belum siap, gunakan draft PR.
+ Jika reviewer meminta revisi, sunting dan commit kembali pada branch yang sama agar PR memuat revisi tersebut.

Jika tidak memiliki akses tulis, gunakan fork sesuai kebijakan pengelola, lalu ajukan PR dari branch pada fork ke repositori asal. Pemilihan branch sumber dan tujuan dijelaskan dalam #link("https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-a-pull-request")[panduan membuat Pull Request].

Pratinjau Markdown di GitHub belum membuktikan bahwa sitasi, penomoran gambar, dan navigasi Quarto bekerja. Untuk perubahan melalui browser, minta anggota yang mempunyai lingkungan lokal atau pipeline otomatis melakukan render sebelum PR diterima.

=== Jalur GitHub Desktop
<jalur-github-desktop>
Panduan portal juga menyediakan jalur tanpa perintah terminal. Di GitHub Desktop, pilih #strong[File → Clone repository] untuk repositori proyek, perbarui #NormalTok("main"); melalui #strong[Fetch origin/Pull origin], lalu buat branch lewat #strong[Current Branch → New Branch]. Sunting #NormalTok(".qmd"); pada editor, periksa perubahan di Desktop, tulis pesan commit, kemudian pilih #strong[Publish branch] atau #strong[Push origin]. Lanjutkan melalui #strong[Preview Pull Request/Create Pull Request]. Revisi tetap dikirim dari branch PR yang sama; render dan pemeriksaan Python dilakukan oleh anggota yang menyiapkan lingkungan lokal.

=== Jalur lokal: clone, branch, commit, dan push
<jalur-lokal-clone-branch-commit-dan-push>
Jalur lokal cocok untuk perubahan banyak berkas, gambar, atau contoh yang perlu dijalankan. Contoh berikut menggunakan terminal PowerShell dan akses tulis ke repositori portal. Jalankan di salinan #strong[repo portal], yang terpisah dari repo sumber buku ini.

Tetapkan identitas commit sekali pada komputer yang digunakan. Alamat surel dapat memakai alamat privat #NormalTok("noreply"); yang disediakan dalam pengaturan akun GitHub.

#Skylighting(([#NormalTok("git config ");#OperatorTok("--");#NormalTok("global user");#OperatorTok(".");#FunctionTok("name");#NormalTok(" ");#StringTok("\"Nama Mahasiswa\"");],
[#NormalTok("git config ");#OperatorTok("--");#NormalTok("global user");#OperatorTok(".");#FunctionTok("email");#NormalTok(" ");#StringTok("\"ALAMAT-EMAIL-COMMIT\"");],
[#NormalTok("git clone https");#OperatorTok("://");#NormalTok("github");#OperatorTok(".");#FunctionTok("com");#OperatorTok("/");#NormalTok("azral1962");#OperatorTok("/");#NormalTok("kipp-triune-academic-commons");#OperatorTok(".");#FunctionTok("git");],
[#FunctionTok("cd");#NormalTok(" kipp-triune-academic-commons");],
[#NormalTok("git status");],));
#NormalTok("clone"); cukup dilakukan sekali untuk satu salinan lokal. Pada pekerjaan berikutnya, masuk ke folder repositori yang sudah ada. Sebelum memulai tugas baru, pastikan #NormalTok("git status"); menunjukkan tidak ada perubahan lokal yang belum diselesaikan, kemudian perbarui #NormalTok("main"); dan buat branch:

#Skylighting(([#NormalTok("git ");#ControlFlowTok("switch");#NormalTok(" main");],
[#NormalTok("git pull ");#OperatorTok("--");#NormalTok("ff-only origin main");],
[#NormalTok("git ");#ControlFlowTok("switch");#NormalTok(" ");#OperatorTok("-");#NormalTok("c tim-03");#OperatorTok("/");#NormalTok("P-R01-critical-reader");],));
Sunting sumber #NormalTok("P-R01"); yang ditunjuk registri. Pertahankan #NormalTok("id");, #NormalTok("index_code");, #NormalTok("type");, #NormalTok("theme");, #NormalTok("owner");, dan #NormalTok("priority");\; jelaskan bantuan AI pada #NormalTok("ai_usage");. Saat artefak belum disetujui, pertahankan #NormalTok("status: draft");. Setelah menyimpan, jalankan pemeriksaan yang tersedia:

#Skylighting(([#NormalTok("git status");],
[#NormalTok("git ");#FunctionTok("diff");],
[#NormalTok("python scripts");#OperatorTok("/");#NormalTok("check_artifacts");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("python scripts");#OperatorTok("/");#NormalTok("check_portal");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("python scripts");#OperatorTok("/");#NormalTok("build_catalog");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("git ");#FunctionTok("diff");#NormalTok(" ");#OperatorTok("--");#NormalTok(" catalog");#OperatorTok(".");#FunctionTok("qmd");],
[#NormalTok("quarto render");],));
Periksa halaman hasil di #NormalTok("_site/");\; untuk menguji beranda bersama seluruh materi, ikuti langkah perakitan #NormalTok("_public/"); pada bagian penerbitan. Periksa sumber, contoh keluaran AI, tautan, dan navigasi. Perintah render tidak otomatis menguji kebenaran isi atau kegunaan prompt. Jika satu perintah gagal, perbaiki kegagalannya sebelum menganggap rangkaian pemeriksaan selesai.

Pilih hanya berkas yang terkait tugas. Untuk contoh #NormalTok("P-R01");, gunakan path yang benar-benar ada pada repo portal:

#Skylighting(([#NormalTok("git add topics");#OperatorTok("/");#DecValTok("02");#OperatorTok("-");#NormalTok("literature-research");#OperatorTok("/");#DecValTok("03");#OperatorTok("-");#NormalTok("ai-prompts");#OperatorTok("/");#DecValTok("02");#OperatorTok("-");#DecValTok("03");#OperatorTok("-");#DecValTok("01");#OperatorTok("-");#NormalTok("p-r01");#OperatorTok(".");#FunctionTok("qmd");],
[#NormalTok("git ");#FunctionTok("diff");#NormalTok(" ");#OperatorTok("--");#NormalTok("staged");],
[#NormalTok("git commit ");#OperatorTok("-");#NormalTok("m ");#StringTok("\"docs(P-R01): isi dan uji Critical Paper Reader\"");],
[#NormalTok("git push ");#OperatorTok("-");#NormalTok("u origin tim-03");#OperatorTok("/");#NormalTok("P-R01-critical-reader");],));
#NormalTok("git add"); memilih perubahan yang akan direkam; #NormalTok("git diff --staged"); memeriksa pilihan itu sebelum commit. Jika status atau data registri berubah dengan persetujuan koordinator, sertakan pula #NormalTok("ARTIFACT_REGISTER.csv"); dan hasil pembaruan #NormalTok("catalog.qmd");. #NormalTok("_site/"); serta #NormalTok("_public/"); dihasilkan ulang untuk penerbitan. #NormalTok("push"); mengirim branch kerja; perubahan belum masuk #NormalTok("main"); sampai PR digabung.

=== Menulis Pull Request yang dapat diperiksa
<menulis-pull-request-yang-dapat-diperiksa>
Di GitHub, pilih #strong[Compare & pull request], atau buat PR dari menu #strong[Pull requests]. Pastikan #strong[base] adalah #NormalTok("main"); dan #strong[compare] adalah branch kerja. Template #NormalTok(".github/pull_request_template.md"); sudah meminta ID, tim, prioritas, pemeriksaan mutu, temuan, dan tautan terkait. Lengkapi template tersebut dengan bukti yang konkret, misalnya:

#Skylighting(([#NormalTok("Artefak: P-R01 | 02.03.01 | Critical Paper Reader");],
[#NormalTok("Tim pembuat: Tim 03");],
[#NormalTok("Prioritas: P1");],
[],
[#NormalTok("Masalah dan perubahan:");],
[#NormalTok("Kerangka awal belum memuat contoh penggunaan dan hasil uji.");],
[#NormalTok("PR mengisi prompt, dua uji normal, satu uji bermasalah, dan batasan.");],
[],
[#NormalTok("Artefak dan berkas:");],
[#NormalTok("Cantumkan ID registri, path sumber, dan halaman yang terdampak.");],
[],
[#NormalTok("Pemeriksaan:");],
[#NormalTok("- [ ] check_artifacts.py dan check_portal.py berhasil.");],
[#NormalTok("- [ ] Katalog diperbarui bila data registri berubah.");],
[#NormalTok("- [ ] Render HTML berhasil; perintah dan versi Quarto dicatat.");],
[#NormalTok("- [ ] Klaim keluaran diperiksa terhadap paper sumber.");],
[#NormalTok("- [ ] Tautan, gambar, sitasi, dan tampilan diperiksa.");],
[#NormalTok("- [ ] Uji pembaca dicatat, termasuk kekurangan yang ditemukan.");],
[],
[#NormalTok("Bukti:");],
[#NormalTok("Cantumkan tautan preview atau lokasi catatan hasil uji.");],
[],
[#NormalTok("Keterbatasan:");],
[#NormalTok("Tuliskan hal yang belum diuji atau masih membutuhkan tindak lanjut.");],
[],
[#NormalTok("Closes #27");],));
Ganti #NormalTok("#27"); dengan Issue sebenarnya. Kata kunci #NormalTok("Closes"); dapat menutup Issue terkait ketika PR masuk ke branch default; gunakan #NormalTok("Refs #27"); jika PR baru menyelesaikan sebagian pekerjaan. Jangan mencentang pemeriksaan yang belum dijalankan. Bedakan hasil yang diamati dari rencana pengujian.

=== Melakukan peer review, revisi, dan merge
<melakukan-peer-review-revisi-dan-merge>
Reviewer membaca tujuan Issue, memeriksa #strong[Files changed], lalu mencoba hasil perubahan. Untuk artefak akademik, gunakan checklist berikut sebagai bukti penerimaan:

- #strong[Ketepatan:] konsep, angka, contoh, dan kesimpulan konsisten.
- #strong[Sumber:] rujukan dapat ditelusuri dan mendukung klaim yang dibuat.
- #strong[Keterpakaian:] langkah dapat diikuti pembaca yang tidak ikut menyusunnya.
- #strong[Integrasi:] ID, registri, prasyarat, dan tautan antarartefak sesuai.
- #strong[Tampilan:] rumus, tabel, gambar, dan navigasi terbaca pada halaman hasil.
- #strong[Integritas:] hak penggunaan materi jelas dan bantuan AI diungkap sesuai ketentuan kelas.

Komentar review menyebut lokasi, masalah, dan hasil yang diharapkan, misalnya: "Pada contoh keluaran P-R01, simpulan ini belum dirujuk ke bagian paper. Tunjukkan bagian sumber atau tandai klaim sebagai belum terverifikasi." Pisahkan koreksi yang harus diselesaikan dari saran pengayaan. Gunakan #NormalTok("templates/peer-review.md"); dan #NormalTok("templates/user-test.md"); untuk menyimpan bukti. Kontributor memperbaiki branch yang sama; reviewer memeriksa revisi sebelum menyatakan persetujuan.

Koordinator melakukan merge setelah kriteria penerimaan, review lintas tim, uji pengguna, dan pemeriksaan yang diwajibkan terpenuhi. Perubahan status mengikuti prosedur YAML--CSV--katalog pada bagian registri. Sesudah merge, perbarui salinan lokal dengan #NormalTok("git switch main"); lalu #NormalTok("git pull --ff-only origin main");. Catat tautan PR pada bagian peer review artefak dan laporan kontribusi; registri saat ini tidak mempunyai kolom khusus URL PR.

=== Menyinkronkan pekerjaan dan menyelesaikan konflik
<menyinkronkan-pekerjaan-dan-menyelesaikan-konflik>
Konflik dapat terjadi ketika dua branch mengubah bagian berkas yang sama. Kurangi risikonya dengan pembagian lingkup, PR berukuran kecil, dan pembaruan dari #NormalTok("main");. Sebelum sinkronisasi, selesaikan atau simpan perubahan lokal dan periksa #NormalTok("git status");. Pada branch kerja, integrasikan versi terbaru:

#Skylighting(([#NormalTok("git ");#ControlFlowTok("switch");#NormalTok(" tim-03");#OperatorTok("/");#NormalTok("P-R01-critical-reader");],
[#NormalTok("git fetch origin");],
[#NormalTok("git merge origin");#OperatorTok("/");#NormalTok("main");],));
Jika Git melaporkan konflik, buka berkas yang disebut oleh #NormalTok("git status");. Kenali tiga penanda berikut:

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Penanda dalam berkas], [Makna pada contoh merge ini],),
  table.hline(),
  [#NormalTok("<<<<<<< HEAD");], [Awal bagian isi dari branch kerja],
  [#NormalTok("=======");], [Pemisah antara isi branch kerja dan isi dari #NormalTok("main");],
  [#NormalTok(">>>>>>> origin/main");], [Akhir bagian isi dari #NormalTok("main"); yang sedang digabungkan],
)
Diskusikan makna perubahan dengan penyusunnya, susun isi akhir yang benar, lalu hapus seluruh penanda konflik. Jangan sekadar memilih satu sisi jika kedua sisi memuat informasi penting. Setelah itu, pilih berkas yang telah diselesaikan dengan #NormalTok("git add NAMA-BERKAS");, jalankan render dan pemeriksaan isi, selesaikan merge dengan #NormalTok("git commit");, lalu #NormalTok("git push");. Jika perlu membatalkan proses merge yang sedang berkonflik untuk meninjau ulang, gunakan #NormalTok("git merge --abort");. Langkah teknisnya tersedia dalam #link("https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/resolving-a-merge-conflict-using-the-command-line")[panduan penyelesaian konflik GitHub].

Jika #NormalTok("push"); ditolak karena branch daring telah berubah, ambil dan periksa perubahan rekan sebelum mengintegrasikannya. Hindari #NormalTok("push --force"); pada branch bersama. Untuk keluaran HTML yang berkonflik, selesaikan sumber lebih dahulu lalu render ulang agar hasil mengikuti sumber yang telah disepakati.

=== Menjaga berkas, data, dan bukti kontribusi
<menjaga-berkas-data-dan-bukti-kontribusi>
Simpan sumber, gambar yang diperlukan, bibliografi, dan data yang boleh dibagikan. Gunakan #NormalTok(".gitignore"); untuk berkas sementara, lingkungan lokal, atau kredensial seperti #NormalTok(".env");. Berkas yang sudah dilacak Git tetap terlacak meskipun kemudian dimasukkan ke #NormalTok(".gitignore");\; periksa riwayat dan daftar perubahan sebelum mengunggah.

Jangan menaruh token, kata sandi, data pribadi mahasiswa, atau dokumen berlisensi terbatas di repositori publik. Jika token terlanjur terbuka, segera cabut atau rotasi token tersebut; menghapusnya dari versi terbaru saja tidak menghapus riwayat. Untuk materi pihak ketiga, catat sumber dan izin penggunaan. Lisensi repositori tidak otomatis memberikan hak atas seluruh materi yang dikutip.

Kontribusi individu ditunjukkan melalui Issue, commit yang bermakna, review, hasil uji, dan refleksi keputusan. Banyaknya commit bukan ukuran tunggal kualitas. Jika anggota mengerjakan analisis atau uji pengguna secara bersama, catat nama, tugas, serta buktinya dalam PR atau laporan agar pekerjaan yang tidak berupa penulisan berkas tetap terlihat.

=== Latihan satu siklus dan diagnosis masalah umum
<latihan-satu-siklus-dan-diagnosis-masalah-umum>
Sebagai latihan awal, setiap anggota memilih satu koreksi kecil, membuka Issue, membuat branch, mengajukan PR, dan memberi review pada PR anggota lain. Latihan selesai setelah koreksi diterima dan tampak pada portal yang diterbitkan. Bukti minimum berupa tautan Issue, PR, catatan review/uji, serta alamat halaman hasil.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Gejala], [Pemeriksaan dan tindak lanjut],),
  table.hline(),
  [Repositori tidak dapat diakses], [Periksa akun yang aktif, URL, undangan, dan izin akses],
  [Perubahan tidak terlihat di GitHub], [Periksa apakah berkas sudah disimpan, di-commit, dan di-push ke branch yang benar],
  [PR tidak menampilkan perubahan], [Periksa base/compare dan apakah commit sudah ada di branch sumber],
  [Pemeriksaan otomatis gagal], [Baca log pada tab Actions, perbaiki penyebab, lalu commit revisi],
  [PR sudah merge tetapi portal masih lama], [Periksa hasil render, sumber penerbitan Pages, dan status deployment],
  [Halaman lokal baik tetapi tautan publik rusak], [Periksa huruf besar/kecil nama berkas, path relatif, dan keberadaan aset pada hasil terbitan],
)
Panduan ini berfokus pada pola kerja yang dapat dipraktikkan. Nama menu, ketersediaan fitur, dan kebijakan akses dapat berubah; periksa dokumentasi resmi yang ditautkan ketika menyiapkan repositori kelas.

== Panduan pengguna portal
<panduan-pengguna-portal>
#figure([
#box(image("images/portal.png", width: 100.0%))
], caption: figure.caption(
position: bottom, 
[
Navigasi portal akademik untuk memilih tema, menelusuri artefak, dan menjalankan learning path.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-portal-2>


Beranda bersumber dari #NormalTok("portal/index.html");. Katalog interaktif pada beranda membaca data registri yang dibentuk saat build, dengan pencarian dan filter tema, prioritas, serta jenis artefak. Tautan katalog membuka materi Quarto pada #NormalTok("/learn/topics/.../*.html");. Enam learning path tersedia melalui #NormalTok("/learn/learning-paths/index.html");, dan panduan Git/GitHub melalui #NormalTok("/learn/docs/student-workflow.html");. Path tersebut berada di bawah akar situs proyek; alamat situs final mengikuti URL yang ditampilkan GitHub Pages.

Pengguna sebaiknya mulai dari pertanyaan atau kasus, lalu memilih tema dan learning path. Knowledge memberi landasan, Skills memandu praktik, Prompts membantu eksplorasi, dan Cases mengintegrasikan penerapan. Halaman forum memberikan petunjuk; diskusi aktual dilakukan di GitHub Discussions. Berkas di #NormalTok("/repository/"); adalah salinan dokumen sumber untuk diunduh, dibentuk saat build dari repositori yang sama.

Karena materi masih draf pada versi yang diperiksa, pembaca perlu memperhatikan bagian yang belum terisi sebelum memakai isinya. #NormalTok("portal/assets/app.js"); saat ini menampilkan keterangan katalog "seluruhnya berstatus draf" secara tetap. Ketika status artefak mulai berubah, pengelola perlu menyesuaikan keterangan tersebut dengan data registri agar tampilan tidak tertinggal dari sumber.

== Membangun dan menerbitkan portal yang sebenarnya
<membangun-dan-menerbitkan-portal-yang-sebenarnya>
Portal memakai proyek Quarto #NormalTok("website"); dengan #NormalTok("output-dir: _site");. Beranda akhir bersumber dari HTML pada #NormalTok("portal/");\; halaman materi dirender dengan Quarto. #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/docs/integration-architecture.md")[Arsitektur integrasi portal] menghubungkan kedua bagian tersebut melalui perakitan berikut:

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Tahap], [Sumber atau perintah], [Hasil],),
  table.hline(),
  [Membentuk katalog Quarto], [#NormalTok("python scripts/build_catalog.py");], [#NormalTok("catalog.qmd"); dari registri CSV],
  [Merender materi belajar], [#NormalTok("quarto render");], [Halaman HTML di #NormalTok("_site/");],
  [Merakit portal terpadu], [#NormalTok("python scripts/build_portal.py");], [Paket situs di #NormalTok("_public/");],
  [Menyediakan beranda dan aset], [#NormalTok("portal/"); serta registri CSV], [#NormalTok("_public/index.html");, CSS/JS, #NormalTok("assets/artifacts.json");, dan #NormalTok("assets/artifacts-data.js");],
  [Menyertakan materi dan dokumen], [#NormalTok("_site/"); serta dokumen sumber terpilih], [#NormalTok("_public/learn/"); dan #NormalTok("_public/repository/");],
  [Menerbitkan], [Workflow #NormalTok("publish.yml");], [Artefak #NormalTok("_public/"); dikirim ke GitHub Pages],
)
=== Preview lengkap pada komputer
<preview-lengkap-pada-komputer>
Sesudah clone dan memasang prasyarat, jalankan perintah berikut dari akar repo portal. Hentikan rangkaian dan perbaiki masalah jika salah satu pemeriksaan gagal.

#Skylighting(([#NormalTok("python scripts");#OperatorTok("/");#NormalTok("check_artifacts");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("python scripts");#OperatorTok("/");#NormalTok("check_portal");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("python scripts");#OperatorTok("/");#NormalTok("build_catalog");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("quarto render");],
[#NormalTok("python scripts");#OperatorTok("/");#NormalTok("build_portal");#OperatorTok(".");#FunctionTok("py");],
[#NormalTok("python ");#OperatorTok("-");#NormalTok("m http");#OperatorTok(".");#FunctionTok("server");#NormalTok(" ");#DecValTok("8000");#NormalTok(" ");#OperatorTok("--");#NormalTok("directory _public");],));
Buka #NormalTok("http://localhost:8000/");, lalu coba katalog, satu artefak, satu learning path, dan satu unduhan dokumen. Hentikan server dengan #NormalTok("Ctrl+C");. #NormalTok("build_portal.py"); membentuk ulang folder #NormalTok("_public/");\; simpan perubahan pada sumber agar tidak hilang saat build berikutnya. Folder #NormalTok("_site/"); dan #NormalTok("_public/"); tidak perlu di-commit sebagai sumber kontribusi.

Jika Quarto belum tersedia, #NormalTok("python scripts/build_portal.py --allow-missing-quarto"); dapat dipakai untuk preview terbatas beranda. Tanpa hasil render Quarto yang valid, materi belajar belum tersedia lengkap. Mode tersebut bukan bukti bahwa paket siap dipublikasikan.

=== Pemeriksaan PR yang sudah tersedia
<pemeriksaan-pr-yang-sudah-tersedia>
Workflow #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/.github/workflows/validate.yml")[\.github/workflows/validate.yml], bernama #strong[Validate source artifacts], berjalan pada #NormalTok("push"); dan #NormalTok("pull_request");. Workflow menggunakan Python 3.12 untuk:

+ Menjalankan #NormalTok("scripts/check_artifacts.py"); terhadap struktur dan metadata artefak.
+ Menjalankan #NormalTok("scripts/build_catalog.py");, lalu #NormalTok("git diff --exit-code -- catalog.qmd"); untuk memastikan katalog yang di-commit sesuai registri.
+ Menjalankan #NormalTok("scripts/check_portal.py"); untuk memeriksa pengikatan data katalog dan path sumber portal.

Workflow PR tersebut #strong[belum menjalankan #NormalTok("quarto render");]. Karena itu, status pemeriksaan berhasil belum membuktikan seluruh halaman dapat dirender atau tampil dengan benar. Penulis atau koordinator perlu memberikan bukti render lokal sebelum merge. Penambahan render ke pemeriksaan PR dapat menjadi pengembangan berikutnya; fitur itu belum menjadi perilaku workflow saat bab ini diperbarui.

=== Publikasi setelah merge ke main
<publikasi-setelah-merge-ke-main>
Workflow #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/.github/workflows/publish.yml")[\.github/workflows/publish.yml], bernama #strong[Publish unified KIPP portal], berjalan pada #NormalTok("push"); ke #NormalTok("main"); dan dapat dijalankan manual melalui #NormalTok("workflow_dispatch");. Job #NormalTok("build"); menyiapkan Python dan Quarto, memvalidasi artefak, membentuk katalog, menjalankan #NormalTok("quarto render");, lalu merakit #NormalTok("_public/");. Setelah konfigurasi Pages berhasil, folder #NormalTok("_public/"); diunggah sebagai artefak. Job #NormalTok("deploy"); menerbitkannya melalui lingkungan #NormalTok("github-pages");.

Koordinator perlu mengatur #strong[Settings → Pages → Build and deployment → Source → GitHub Actions] sesuai rancangan ini. Pilihan branch dengan folder #NormalTok("/docs"); tidak mengikuti alur build portal yang tersedia. Pengaturan sumber Pages dijelaskan dalam #link("https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site")[dokumentasi GitHub Pages]\; integrasi Quarto tersedia pada #link("https://quarto.org/docs/publishing/github-pages.html")[panduan Quarto untuk GitHub Pages].

Sesudah merge, periksa workflow bernama #strong[Publish unified KIPP portal], keberhasilan job #NormalTok("deploy");, URL keluaran, dan isi halaman publik. Periksa beranda serta satu halaman #NormalTok("/learn/");\; keberhasilan beranda saja belum membuktikan materi Quarto ikut terbit.

=== Catatan keadaan publikasi saat pemeriksaan
<catatan-keadaan-publikasi-saat-pemeriksaan>
Riwayat Actions yang tersedia pada 23 November 2026 memuat tiga proses dari commit yang diperiksa:

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Proses pada 17 November 2026], [Hasil tercatat], [Makna pemeriksaan],),
  table.hline(),
  [#link("https://github.com/azral1962/kipp-triune-academic-commons/actions/runs/44003700715")[Validate source artifacts]], [Berhasil], [Pemeriksaan struktur, katalog, dan pengikatan portal lulus],
  [#link("https://github.com/azral1962/kipp-triune-academic-commons/actions/runs/44003700872")[Publish unified KIPP portal]], [Gagal], [Validasi, render, dan perakitan berhasil; #NormalTok("actions/configure-pages"); gagal dengan pesan #NormalTok("Not Found");, sehingga deploy terpadu tidak dijalankan],
  [#link("https://github.com/azral1962/kipp-triune-academic-commons/actions/runs/44004372496")[pages build and deployment]], [Berhasil], [Proses Pages lain berhasil sesudahnya; hasil ini tidak membuktikan workflow publikasi terpadu sudah berhasil dijalankan ulang],
)
Pesan kegagalan meminta pemeriksaan apakah Pages sudah aktif dan menggunakan GitHub Actions. Tindak lanjut koordinator adalah memeriksa pengaturan Pages, menjalankan ulang workflow publikasi terpadu setelah konfigurasi sesuai, lalu memeriksa hasil publik. Catatan ini merekam keadaan saat pemeriksaan, bukan menyatakan bahwa situs pasti masih gagal atau konfigurasi sekarang sudah benar.

=== Membedakan portal proyek dan buku ini
<membedakan-portal-proyek-dan-buku-ini>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Aspek], [Repo portal proyek], [Repo buku gabungan ini],),
  table.hline(),
  [Jenis Quarto], [#NormalTok("website");], [#NormalTok("book");],
  [Hasil render], [#NormalTok("_site/");], [#NormalTok("docs/");],
  [Paket situs akhir], [#NormalTok("_public/");, dirakit oleh skrip], [Hasil buku berada di #NormalTok("docs/");],
  [Fungsi folder #NormalTok("docs/");], [Panduan dan dokumentasi sumber portal], [Hasil render HTML buku],
  [Sumber perubahan kontribusi], [Artefak di #NormalTok("topics/"); dan sumber portal terkait], [Bab dan lampiran #NormalTok(".qmd"); buku],
)
Contoh Git pada bab ini ditujukan ke repo portal. Perubahan naskah buku tetap dilakukan pada repo buku, kemudian dirender dengan konfigurasi buku. Pemisahan konteks ini mencegah mahasiswa mencari #NormalTok("15-implementasi-teknis.qmd"); di repo portal atau menganggap #NormalTok("docs/"); portal sebagai hasil render.

== Registri, metadata, dan perubahan status
<registri-metadata-dan-perubahan-status>
#NormalTok("ARTIFACT_REGISTER.csv"); merupakan sumber utama katalog. Kolomnya adalah #NormalTok("id");, #NormalTok("theme_slug");, #NormalTok("theme_title");, #NormalTok("type");, #NormalTok("title");, #NormalTok("owner");, #NormalTok("priority");, #NormalTok("status");, #NormalTok("file");, #NormalTok("index_code");, #NormalTok("theme_code");, dan #NormalTok("artifact_type_code");. Nilai prioritas awal adalah P0 untuk Knowledge, P1 untuk Skills dan Prompts, serta P2 untuk Cases. Prioritas membantu mengatur urutan kerja; prioritas tidak menyatakan bahwa materi telah selesai.

Setiap artefak memiliki metadata yang harus konsisten dengan registri. Contoh awal nyata pada #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/topics/02-literature-research/03-ai-prompts/02-03-01-p-r01.qmd")[P-R01]:

#Skylighting(([#PreprocessorTok("---");],
[#FunctionTok("title");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"Critical Paper Reader\"");],
[#FunctionTok("id");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"P-R01\"");],
[#FunctionTok("index_code");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"02.03.01\"");],
[#FunctionTok("type");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"prompts\"");],
[#FunctionTok("theme");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"research\"");],
[#FunctionTok("owner");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"Tim 03\"");],
[#FunctionTok("priority");#KeywordTok(":");#AttributeTok(" P1");],
[#FunctionTok("status");#KeywordTok(":");#AttributeTok(" draft");],
[#FunctionTok("ai_usage");#KeywordTok(":");#AttributeTok(" ");#StringTok("\"Belum diisi; wajib dijelaskan sebelum review\"");],
[#PreprocessorTok("---");],));
#link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/docs/change-status.md")[Panduan perubahan status] menetapkan konvensi berikut. Makna kerja di tabel menjelaskan penerapannya bersama aturan kontribusi dan quality gate.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Nilai metadata], [Penggunaan dalam proses],),
  table.hline(),
  [#NormalTok("draft");], [Isi awal atau pekerjaan yang belum memenuhi kriteria penerimaan],
  [#NormalTok("in-review");], [Sedang diajukan untuk peninjauan],
  [#NormalTok("needs-revision");], [Memerlukan perbaikan berdasarkan temuan review atau uji],
  [#NormalTok("reviewed");], [Bukti review lintas tim, uji pengguna, dan tindak lanjut telah dicatat serta disetujui],
)
Sesudah penerimaan disetujui, ubah status pada #strong[YAML artefak dan baris CSV dengan ID yang sama], melalui koordinasi pengelola registri. Jalankan #NormalTok("python scripts/check_artifacts.py"); dan #NormalTok("python scripts/build_catalog.py");, periksa diff, lalu sertakan artefak, CSV, dan #NormalTok("catalog.qmd"); yang berubah dalam PR. Jika kontributor belum berwenang mengubah registri, minta koordinator menyiapkan perubahan tersebut pada proses review. Jangan menambahkan kolom baru atau mengganti ID untuk memperbarui status.

Nilai #NormalTok("reviewed"); menyatakan penerimaan prosedur internal pilot, bukan sertifikasi kebenaran ilmiah. Bukti uji dan komentar reviewer disimpan pada bagian artefak serta PR, bukan digantikan oleh status saja. README memakai istilah umum "Verified"; untuk nilai yang ditulis ke YAML dan CSV, ikuti #NormalTok("docs/change-status.md"); dan #NormalTok("CONTRIBUTING.md"); agar konsisten.

== Memisahkan sumber dan hasil terbitan
<memisahkan-sumber-dan-hasil-terbitan>
Sumber #NormalTok(".qmd");, gambar, referensi, dan data yang boleh dibagikan merupakan input penerbitan. Pada repo portal, #NormalTok("catalog.qmd"); dibentuk dari CSV, halaman Quarto di #NormalTok("_site/"); dibentuk dari sumber, dan #NormalTok("_public/"); dirakit untuk publikasi. Perbaiki sumber lalu jalankan generator yang sesuai agar perubahan tidak hilang pada build berikutnya. Pada repo buku ini, hasil render berada di #NormalTok("docs/");\; struktur proyek buku dijelaskan dalam dokumentasi Quarto @quarto-book.

Simpan informasi lingkungan yang cukup untuk menjalankan contoh: bahasa, dependensi, versi penting, dan cara memperoleh data. Contoh yang hanya ilustratif diberi penanda tidak dieksekusi; contoh yang disebut telah diuji perlu benar-benar dijalankan pada input yang dicatat. Praktik ini membantu membedakan materi pengantar dari hasil komputasi yang dapat direproduksi @wilson2017.

== Contoh alur review satu perubahan
<contoh-alur-review-satu-perubahan>
Sebagai simulasi, Tim 03 mengisi artefak #NormalTok("P-R01 — Critical Paper Reader");. Issue menetapkan bahwa prompt harus membantu membaca paper tanpa mengarang sumber. Kontributor mengisi kerangka pada branch #NormalTok("tim-03/P-R01-critical-reader");, mencoba dua masukan normal dan satu masukan bermasalah, lalu menyimpan input-output aktual serta hasil pemeriksaan terhadap sumber paper. Artefak tetap berstatus #NormalTok("draft"); selama bukti penerimaan belum lengkap.

Reviewer dari tim lain mencoba prompt dan menandai klaim yang tidak didukung paper. Kontributor merevisi instruksi, mengulang contoh yang gagal, dan memperbarui catatan uji. Sesudah kriteria #NormalTok("QUALITY_GATE.md"); terpenuhi, perubahan status dikoordinasikan pada YAML dan CSV, katalog dibentuk ulang, dan bukti dicantumkan dalam PR. Koordinator memeriksa hasil CI, bukti render, dan persetujuan review sebelum merge.

Workflow publikasi kemudian membangun #NormalTok("_site/");, merakit #NormalTok("_public/");, dan mencoba deploy ke Pages. Pengelola memeriksa keluaran publik serta halaman artefak. Simulasi ini menunjukkan proses yang perlu dijalankan mahasiswa; contoh ini bukan klaim bahwa P-R01 sudah terisi atau telah lulus review pada commit yang diperiksa.

== Pemeriksaan otomatis dan batasnya
<pemeriksaan-otomatis-dan-batasnya>
Pemeriksaan yang sudah tersedia mempunyai lingkup tertentu. #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/scripts/check_artifacts.py")[check\_artifacts.py] memeriksa jumlah 42 entri, keunikan ID, keberadaan berkas, kesesuaian metadata tertentu dengan CSV, bentuk kode hierarkis dan nama berkas, tautan dari indeks tema serta learning path, dan keberadaan judul bagian wajib. #link("https://github.com/azral1962/kipp-triune-academic-commons/blob/main/scripts/check_portal.py")[check\_portal.py] memeriksa berkas portal, penyertaan aset manifest, pola tautan menuju materi Quarto, dan keberadaan path artefak.

Kedua skrip tersebut bukan pemeriksaan menyeluruh semua tautan situs atau seluruh aturan metadata. Keduanya juga tidak membuktikan bahwa penanda #NormalTok("[ISI]"); sudah dilengkapi, sitasi mendukung klaim, prompt menghasilkan jawaban benar, atau pengguna dapat mengikuti tutorial. Hal ini menjelaskan mengapa pemeriksaan struktur dapat lulus ketika semua artefak masih draf. Pemeriksaan substansi tetap menggunakan #NormalTok("QUALITY_GATE.md");, review lintas tim, dan uji pengguna.

Pisahkan tiga bukti: #strong[struktur valid], #strong[materi diterima], dan #strong[publikasi berhasil]. Status CI PR hanya mendukung bukti yang benar-benar diuji; persetujuan manusia harus didukung catatan review; deployment harus dibuktikan dengan hasil workflow dan halaman publik. Untuk penilaian, catat commit atau versi yang dipakai bersama tautan PR dan hasil uji agar karya dapat ditelusuri pada keadaan yang sama.

== Merawat portal setelah tenggat
<merawat-portal-setelah-tenggat>
Tentukan pemilik pemeliharaan, cara melaporkan kesalahan, dan masa tinjau sumber yang mudah berubah. Tutorial layanan daring lebih cepat kedaluwarsa daripada penjelasan dasar probabilitas. Penandaan tanggal pemeriksaan membantu pengguna menilai apakah langkah teknis masih sesuai. Jika suatu materi perlu diarsipkan, catat keputusan dan alasannya tanpa menghapus sejarah. Penambahan nilai status metadata untuk arsip memerlukan kesepakatan baru; konvensi saat ini tetap memakai empat nilai pada panduan perubahan status.

Sebagai latihan, pilih satu artefak dan lakukan audit dari registri sampai halaman hasil. Periksa identitas, lokasi, sumber, tampilan, serta bukti penerimaan. Lalu simulasikan pemindahan file dan jelaskan apa yang perlu diperbarui. Tujuannya agar struktur repositori mendukung pengguna dan reviewer, bukan hanya terlihat teratur bagi penyusunnya.

= Evaluasi Kinerja, Validasi, dan Agenda Riset
<evaluasi-kinerja-validasi-dan-agenda-riset>
== Indikator proses dan hasil
<indikator-proses-dan-hasil>
Sebuah engine navigasi dinilai dari #emph[goal attainment] (apakah B tercapai), waktu, biaya sumber daya, kualitas, risiko, kontribusi tiap engine, serta perkembangan kompetensi. Untuk akademik, indikator tambahan meliputi ketepatan sitasi, reproduksibilitas analisis, pemahaman konseptual, dan hasil uji mandiri pada tugas baru.

== Evaluasi di setiap milestone
<evaluasi-di-setiap-milestone>
Milestone memerlukan: keadaan aktual, kesesuaian terhadap acceptance criteria, saldo tiap sumber daya, bukti kerja, keputusan selanjutnya, dan hal yang dipelajari. Jika gagal, klasifikasikan penyebab: kesalahan peta, kesalahan strategi, kurang kemampuan, kurang sumber daya, kegagalan engine, atau perubahan tujuan. Klasifikasi ini menentukan PUDAL mana yang diaktifkan berikutnya.

== Uji perbandingan rute
<uji-perbandingan-rute>
Dalam pilot akademik, satu kasus dapat diselesaikan melalui natural, instrumental, dan vehicular, lalu dibandingkan pada waktu, mutu, biaya, ketergantungan, kemampuan transfer, dan ketepatan hasil. Perbandingan harus memiliki masukan setara serta definisi yang jelas mengenai kerja yang didelegasikan dan kerja verifikasi manusia.

== Agenda penelitian yang terbuka
<agenda-penelitian-yang-terbuka>
+ Formalisasi hubungan #emph[State--Route Graph] dan #emph[Resource--Energy Graph] pada domain kognitif dan sosial.
+ Pengukuran peningkatan himpunan tindakan yang layak sesudah Learning PUDAL.
+ Kebijakan pemilihan #emph[mixed engines] dengan biaya, mutu, risiko, serta nilai pembelajaran.
+ Strategi #emph[rolling-horizon replanning] pada milestones yang tidak pasti.
+ Desain agen yang mampu menjelaskan alasan rute, memberi sumber dan meminta persetujuan manusia.
+ Evaluasi kecerdasan kolektif: bagaimana koordinasi dan pembagian kerja meningkatkan kelayakan mencapai B.

== Batasan model
<batasan-model>
Istilah engine dan energi diperluas secara analogis dalam konteks sosial serta akademik. Perlu pemisahan eksplisit antara energi fisik yang diukur dalam joule dengan uang, perhatian, kemampuan, waktu, dan akses. Fungsi tujuan serta angka ilustratif di dalam buku bukan hasil eksperimen. Klaim optimalitas hanya dapat dibuat setelah kendala, fungsi nilai, dan data terukur ditetapkan.

== Memisahkan pertanyaan kelayakan, efektivitas, dan mekanisme
<memisahkan-pertanyaan-kelayakan-efektivitas-dan-mekanisme>
Kelayakan bertanya apakah workflow dapat dijalankan dalam kondisi kelas. Efektivitas bertanya apakah hasilnya lebih baik daripada pembanding tertentu. Mekanisme bertanya bagian mana yang menjelaskan perubahan. Ketiga pertanyaan memerlukan bukti berbeda. Pilot yang berhasil menerbitkan enam learning paths memberi informasi kelayakan, tetapi belum membuktikan bahwa lima PUDAL meningkatkan kemampuan lebih baik daripada pendekatan lain.

Nyatakan unit penelitian: individu, kelompok, kelas, atau artefak. Jika perlakuan diberikan pada tingkat kelompok, ketergantungan antaranggota perlu diperhatikan. Jika skor produk tim dipakai sebagai hasil individual, penafsiran dapat keliru. Persetujuan, aturan penggunaan data, dan peran penilai ditetapkan sebelum pengumpulan.

== Desain pembanding yang sesuai pertanyaan
<desain-pembanding-yang-sesuai-pertanyaan>
Untuk mengevaluasi rute adaptif, pembanding dapat berupa bantuan tetap dengan akses materi dan waktu yang sebanding. Catat apa yang berbeda: aturan pemilihan bantuan, jenis petunjuk, atau kemampuan alat. Jika semua komponen berubah sekaligus, perbedaan hasil sulit dikaitkan dengan satu mekanisme. Desain bertahap dapat lebih informatif daripada perbandingan paket besar yang tidak jelas.

Pengacakan dapat membantu membentuk pembanding, tetapi pelaksanaan perlu memeriksa ketidakpatuhan, kontaminasi, dan kehilangan peserta. Pada desain crossover, belajar pada tahap pertama dapat terbawa ke tahap kedua sehingga urutan memengaruhi hasil. Pertimbangan inferensi kausal menuntut asumsi pembanding dijelaskan, bukan disembunyikan di balik metode statistik @cunningham2021.

== Mengukur hasil tugas dan kemampuan secara terpisah
<mengukur-hasil-tugas-dan-kemampuan-secara-terpisah>
Mutu produk dapat dinilai dengan rubrik yang tidak memperlihatkan kelompok perlakuan kepada penilai ketika memungkinkan. Kemampuan diukur melalui tugas mandiri baru, penjelasan, dan tes tertunda yang sesuai. Kepercayaan diri dicatat terpisah dari akurasi. Peserta yang lebih yakin tetapi lebih sering salah membutuhkan intervensi berbeda dari peserta yang benar tetapi kurang yakin.

Jika metrik utama banyak, tentukan prioritas sebelum melihat hasil. Laporkan variasi, ketidakpastian, dan konteks, bukan hanya rerata. Hasil yang menguntungkan pada kecepatan tetapi merugikan transfer perlu ditampilkan sebagai trade-off. Skor gabungan dapat menyembunyikan hasil pendidikan yang paling penting.

== Menguji bagian model melalui studi yang lebih kecil
<menguji-bagian-model-melalui-studi-yang-lebih-kecil>
Agenda pertama dapat menguji apakah kartu keadaan dan milestone meningkatkan kesepakatan reviewer tentang status proyek. Agenda kedua menguji apakah pencatatan prasyarat mengurangi transisi yang ternyata tidak layak. Agenda ketiga membandingkan bantuan tetap dengan bantuan yang berkurang berdasarkan demonstrasi. Setiap studi menargetkan komponen, sehingga kegagalan dapat memberi diagnosis yang lebih jelas.

Studi ablasi dapat menghilangkan satu komponen dengan mempertahankan komponen lain, misalnya rute adaptif tanpa tes transfer atau workflow tanpa checkpoint. Namun perubahan tersebut tetap harus mempertimbangkan tujuan pendidikan dan kelayakan etis. Hasil tidak boleh digeneralisasi melebihi tugas dan populasi yang diuji.

== Preregistrasi, data, dan pelaporan hasil negatif
<preregistrasi-data-dan-pelaporan-hasil-negatif>
Simpan pertanyaan, metrik utama, aturan eksklusi, dan rencana analisis sebelum pengujian konfirmatori. Perubahan yang diperlukan selama studi tetap dapat dilakukan, tetapi diberi alasan dan dibedakan dari rencana awal. Sediakan data atau contoh sintetis sesuai izin, serta kode dan metadata yang memungkinkan pemeriksaan. Prinsip FAIR membantu mengatur penggunaan ulang tanpa mengharuskan data sensitif dibuka @fair2016.

Hasil negatif tetap bernilai jika menunjukkan rute tidak bekerja pada kondisi tertentu atau biaya koordinasi melebihi manfaat. Catat kesalahan peta, strategi, kapasitas, dan pengukuran secara terpisah. Sebagai latihan, susun satu pertanyaan efektivitas dan satu pertanyaan mekanisme untuk kasus Bayes. Tentukan hasil yang akan membuat Anda menolak dugaan awal, bukan hanya hasil yang Anda harapkan.

#part[BAGIAN IV — ENAM TEMA KOMPETENSI AKADEMIK TISE]
= Pengantar Enam Tema Kompetensi Akademik Berbasis TISE
<pengantar-enam-tema-kompetensi-akademik-berbasis-tise>
#block[
#callout(
body: 
[
Bab ini membuka #strong[Bagian IV] dari buku #emph[PUDAL: Navigasi Cerdas, Engine, dan Pembelajaran Adaptif]. Bagian I--II menjelaskan kerangka TAIDA, Triune Intelligence, PUDAL, graf keadaan, rute, sumber daya, dan mesin kerja. Bagian III merancang #emph[Triune Academic Commons] dan enam jalur pembelajaran. Bagian IV ini memperluas keenam jalur tersebut menjadi #strong[modul operasional]: kasus, kontrak A→B, sasaran antara, pilihan kerja mandiri/chatbot/agen, bukti hasil tugas, bukti hasil belajar, dan rubrik. Lihat #link(<enam-learning-paths-berbasis-pudal>)[Enam Learning Paths Berbasis PUDAL] sebagai peta penghubung.

]
, 
title: 
[
Posisi dalam buku gabungan
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#block[
#callout(
body: 
[
Buku ini adalah #strong[edisi pengembangan awal], disusun dari rangkaian diskusi tentang enam tema proyek akademik TISE. Angka-angka simulasi merupakan contoh pembelajaran, bukan bukti penelitian lapangan. Infografik adalah ilustrasi pendukung; rumus dan angka sebaiknya dirujuk pada tabel serta teks yang telah diperiksa.

]
, 
title: 
[
Status naskah
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
#figure([
#box(image("tise-six-themes/images/tema-0-pola-dasar.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-cover>


== Orientasi buku
<orientasi-buku>
Buku ini menempatkan penggunaan Artificial Intelligence (AI) sebagai bagian dari rekayasa pembelajaran dan pekerjaan akademik. Titik awalnya bukan teknologi yang akan dipakai, melainkan #strong[perubahan keadaan] yang ingin dicapai oleh peserta. Setiap tugas diberi kondisi awal $A$, kondisi tujuan $B$, sasaran antara, alternatif rute, sumber daya, instrumen, metrik, dan bukti keberhasilan.

Pembelajaran dirancang melalui tiga pendekatan yang dapat ditempuh secara berurutan maupun dipilih secara adaptif:

+ #strong[Alamiah/mandiri:] peserta membaca, mencoba, berpikir, menggambar, menghitung, dan menguji dengan kemampuannya sendiri.
+ #strong[Chatbot sebagai instrumen:] peserta tetap memimpin, sementara dialog AI memperkuat pemahaman, memberikan petunjuk, mengkritik, dan membantu perbaikan.
+ #strong[Agen AI sebagai kendaraan:] peserta mendelegasikan subpekerjaan yang terdefinisi, memanfaatkan orkestrasi alat, lalu memvalidasi hasil dan mempertanggungjawabkannya.

Dua keluaran dicatat secara terpisah: #strong[hasil pekerjaan] dan #strong[hasil belajar]. Sistem dapat membantu mengerjakan tugas tanpa otomatis meningkatkan kompetensi. Oleh karena itu pembelajaran mandiri, retensi, dan transfer perlu diuji tanpa bantuan AI.

== Enam tema yang saling berhubungan
<enam-tema-yang-saling-berhubungan>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Tema], [Nama yang disepakati], [Kasus utama], [Produk],),
  table.hline(),
  [1], [#strong[Learning]], [Probabilitas bersyarat, Bayes, penyakit langka], [Jawaban, penjelasan konsep, asesmen mandiri],
  [2], [Literature Study], [Penggunaan AI yang tepat dalam dunia akademik], [Laporan State of the Art lima lapisan],
  [3], [Academic Writing], [AI yang etis dalam dunia akademik dan ruang publik], [Esai ilmiah argumentatif],
  [4], [Computational & Data Literacy], [Penggunaan AI dan kemampuan kognitif mahasiswa], [Dataset terolah, notebook, analisis/simulasi],
  [5], [Visualization / Visual Knowledge Engineering], [Visualisasi AI akademik dan paper-to-visual], [Diagram, infografik, slide],
  [6], [Problem Solving], [Aspirasi mahasiswa, standar pendidikan, tuntutan industri], [Solusi multipihak dan evaluasi],
)
#strong[Catatan terminologi:] Tema 1 dengan sengaja bernama #emph[Learning], bukan #emph[Problem Solving]. Penyelesaian soal Bayes merupakan #strong[kasus untuk mengukur belajar]. #emph[Problem Solving] yang menyatukan berbagai kompetensi menjadi Tema 6.

== Cara membaca dan menggunakan
<cara-membaca-dan-menggunakan>
Bab 1 membahas kerangka bersama. Bab 2--7 dapat dipakai sebagai modul praktikum, masing-masing dengan kontrak tugas, proses, kasus, instrumen, dan rubrik. Bab 8 menjelaskan program implementasi serta evaluasi, sedangkan Bab 9 berisi template yang dapat disalin. Lampiran mencatat perangkat lunak dan cara membangun buku.

Tujuan buku bukan menggantikan nalar mahasiswa dengan jawaban AI, melainkan membuat penggunaan AI #strong[terencana, dapat diperiksa, beretika, dan meningkatkan kecakapan manusia].

= Kerangka Bersama: Rekayasa Perjalanan Tugas
<kerangka-bersama-rekayasa-perjalanan-tugas>
== Perjalanan keadaan $A arrow.r B$
<perjalanan-keadaan-arightarrow-b>
Rancangan setiap tema diawali dengan definisi entitas dan keadaannya. Misalkan suatu tugas $cal(T)$ direpresentasikan sebagai

$ cal(T) =\(A\,B\,S\,R\,C\,E\,Q\)\, $

dengan $A$ keadaan awal, $B$ keadaan tujuan, $S$ sasaran antara, $R$ alternatif rute, $C$ kapasitas dan sumber daya, $E$ usaha/energi, dan $Q$ kualitas serta kriteria keberhasilan. Untuk setiap rute perlu ditentukan tindakan, prasyarat, risiko, biaya, keluaran, dan cara memeriksa kebenarannya.

#block[
#callout(
body: 
[
Penyelesaian cepat dapat membantu pekerjaan rutin, tetapi tidak selalu baik untuk tugas belajar yang mensyaratkan usaha penalaran. Rute dipilih berdasarkan tujuan; efisiensi bukan satu-satunya sasaran.

]
, 
title: 
[
Kualitas tidak hanya berarti cepat
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
== Tiga moda: alamiah, chatbot, agen
<tiga-moda-alamiah-chatbot-agen>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Moda], [Penanggung jawab utama], [Kekuatan], [Risiko yang harus dikendalikan],),
  table.hline(),
  [Alamiah], [Manusia], [Eksplorasi dan pembentukan keterampilan], [Beban tinggi, kebuntuan],
  [Chatbot], [Manusia], [Dialog, scaffolding, umpan balik], [Jawaban keliru dan ketergantungan],
  [Agen AI], [Manusia memberi mandat; agen mengeksekusi subkerja], [Otomasi, orkestrasi, skala], [Salah tindakan, data, atribusi, otorisasi],
)
Moda itu dapat dipilih bergantian. Peserta yang kesulitan dapat memperoleh bantuan tambahan; peserta yang semakin mampu perlu berlatih tanpa bantuan (#emph[fading assistance]).

== Sasaran antara dan PUDAL
<sasaran-antara-dan-pudal>
#figure([
#box(image("tise-six-themes/images/diagrams/01-kerangka-tise-1.svg", height: 150mm))
], caption: figure.caption(
position: bottom, 
[
Diagram alur; label dan hubungan mengikuti definisi sumber.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


PUDAL (#emph[Perceive--Understand--Decide--Act--Learn]) adalah loop operasional: mengamati keadaan, menafsirkan kebutuhan, memilih tindakan, melaksanakan, dan memutakhirkan pemahaman. Sementara itu Q-Cycle bekerja pada persoalan rekayasa yang lebih mendasar: Q1 problem/misi, Q2 fungsi, Q3 arsitektur, Q4 realisasi, lalu bukti yang dapat memperbaiki Q1.

== Arsitektur lima lapisan
<arsitektur-lima-lapisan>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Lapisan], [Pertanyaan penuntun], [Objek yang dicatat],),
  table.hline(),
  [L5 Ekosistem], [Siapa yang dilayani, untuk nilai apa?], [Stakeholder, misi, norma, kondisi, keberlanjutan],
  [L4 Rute & kendaraan], [Bagaimana berpindah dari A ke B?], [Strategi, sasaran antara, layanan/kendaraan],
  [L3 Arsitektur kendaraan], [Kendaraan tersusun dari apa?], [Subsistem, komponen, antarmuka, peran],
  [L2 Mesin / engine], [Mekanisme apa yang menghasilkan perubahan?], [Transformasi, algoritma, kontrol, siklus],
  [L1 Energi & teknologi], [Apa yang memungkinkan mekanisme bekerja?], [Tenaga, waktu, data, komputasi, pengetahuan, instrumen],
)
Untuk sistem digital, #strong[data dan pengetahuan bukan energi termodinamika]. Keduanya adalah sumber daya informasi yang menggerakkan keputusan melalui mekanisme komputasional dan manusia.

== Dua keluaran dan kontrak evaluasi
<dua-keluaran-dan-kontrak-evaluasi>
Hasil tugas $O_T$ dan hasil belajar $O_L$ harus dinilai terpisah. $O_T$ dapat berupa jawaban benar, esai, notebook, gambar, atau solusi; $O_L$ berupa peningkatan pemahaman, keterampilan, retensi, transfer, kemampuan menjelaskan, dan kemandirian.

Sebuah #emph[Evaluation Contract] menjelaskan: populasi, baseline, metrik primer dan sekunder, instrumen, protokol uji, kriteria lolos, dan batas klaim. Perlu membedakan indikator observasional dari klaim kausal. Instrumen yang belum tervalidasi diberi status eksploratoris.

== Contoh kartu perjalanan tugas
<contoh-kartu-perjalanan-tugas>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Field], [Contoh isian],),
  table.hline(),
  [A], [Belum memahami teorema Bayes],
  [B], [Mampu menyelesaikan kasus baru tanpa AI],
  [Sasaran antara], [Mengerti kondisional; memahami prevalensi; membuat tabel; menghitung; menerapkan],
  [Rute], [Mandiri → chatbot tutor → agen simulator bila diperlukan],
  [Alat], [Kertas, kalkulator, Python, AI],
  [Verifikasi], [Soal transfer tanpa AI, penjelasan konsep, perhitungan yang benar],
)
== Tata kelola AI akademik
<tata-kelola-ai-akademik>
Pemakaian AI perlu sesuai aturan tugas atau institusi, menjaga privasi, transparansi penggunaan, atribusi sumber, dan verifikasi. Tugas yang melarang bantuan AI harus dikerjakan tanpa bantuan tersebut; laporan penggunaan AI tidak mengesahkan pelanggaran aturan. Interaksi sensitif tidak semestinya dikirim ke model publik tanpa dasar izin dan perlindungan yang memadai.

== Mengubah tugas yang kabur menjadi perjalanan yang dapat diperiksa
<mengubah-tugas-yang-kabur-menjadi-perjalanan-yang-dapat-diperiksa>
Kalimat "buat laporan yang baik" belum cukup untuk mengarahkan pekerjaan. Kata #emph[baik] dapat berarti rapi bagi penulis, argumentatif bagi dosen, dan berguna bagi pembaca. Karena itu, penetapan B dimulai dengan percakapan tentang pengguna dan bukti penerimaan. Untuk laporan studi literatur, misalnya, B dapat dinyatakan sebagai naskah yang menjawab satu pertanyaan, membandingkan metode dari sumber yang dapat ditelusuri, serta membedakan temuan penulis sumber dari interpretasi penyusun. Jumlah halaman menjadi batas produksi, sedangkan kualitas argumen menjadi kriteria hasil.

Keadaan A juga perlu dibuktikan. Mahasiswa yang menyatakan "belum memahami statistik" mungkin sebenarnya sudah dapat menghitung rata-rata, tetapi belum memahami sampling. Diagnosis singkat berupa satu soal dan penjelasan lisan menghasilkan peta kebutuhan yang lebih berguna daripada label kemampuan umum. Dari diagnosis tersebut, sasaran antara disusun untuk menutup kesenjangan tertentu. Jika kesenjangannya penafsiran, menambah latihan menghitung saja tidak memadai.

Pembedaan tujuan, kegiatan, dan bukti ini sejalan dengan prinsip keselarasan pembelajaran: asesmen perlu menguji kemampuan yang menjadi tujuan, dan kegiatan memberi kesempatan melatihnya @cmu-alignment. Dalam rancangan TISE, prinsip tersebut diterjemahkan menjadi hubungan eksplisit A--B--rute--bukti. Terjemahan ini merupakan pilihan desain buku, bukan nama lain dari teori keselarasan.

== Contoh lengkap: menilai penggunaan AI untuk sebuah laporan
<contoh-lengkap-menilai-penggunaan-ai-untuk-sebuah-laporan>
Nadia diminta menyusun laporan tentang penggunaan tutor AI di kelas pengantar. Ia mempunyai tiga artikel, tenggat satu minggu, dan pengalaman membaca metode penelitian yang masih terbatas. Tujuan pekerjaannya menghasilkan sintesis yang dapat dipertanggungjawabkan. Tujuan belajarnya mampu menjelaskan mengapa hasil dari dua penelitian belum tentu dapat dibandingkan langsung. Dua tujuan ini menentukan pembagian pekerjaan.

Pada tahap pertama Nadia membaca abstrak dan metode sendiri, lalu mencatat pertanyaan tentang peserta, tugas, dan ukuran hasil. Chatbot kemudian diminta menjelaskan istilah yang belum dipahami berdasarkan potongan sumber yang ia berikan. Setelah Nadia dapat mengisi satu kartu artikel dengan benar, agen boleh membantu menata kartu lain ke dalam matriks. Nadia tetap memeriksa setiap sel terhadap sumber. Dengan urutan ini, delegasi mengikuti pemahaman minimum yang diperlukan untuk mengawasi hasil.

Misalkan matriks selesai lebih cepat, tetapi Nadia masih menyamakan skor tugas berbantuan dengan kemampuan tanpa bantuan. Produk awal dapat dinilai cukup rapi, sementara hasil belajarnya belum mencapai B. Tindakan berikutnya adalah latihan membandingkan desain penelitian, bukan langsung memperindah laporan. Sebaliknya, apabila Nadia sudah memahami metode tetapi kesulitan mengatur daftar pustaka, penggunaan alat pengelola referensi dapat mengurangi pekerjaan administratif tanpa menggantikan sasaran belajar utama.

== Ketidakpastian dan keputusan bantuan
<ketidakpastian-dan-keputusan-bantuan>
Pemilihan moda memerlukan tiga pertanyaan: apakah kegiatan merupakan sasaran latihan, apakah keluaran dapat diperiksa, dan apa akibat kesalahannya? Untuk latihan konsep dasar, bantuan berupa pertanyaan lebih sesuai daripada jawaban lengkap. Untuk penataan metadata yang dapat diperiksa, delegasi lebih luas mungkin masuk akal. Untuk keputusan yang memengaruhi orang lain, perlu ada penanggung jawab dan batas kewenangan yang jelas. Pedoman UNESCO menempatkan kepentingan manusia dan tujuan pendidikan sebagai pertimbangan penggunaan AI @unesco-genai\; rincian aturan bantuan di sini merupakan rancangan operasional buku.

Simpan alasan pergantian moda dalam kalimat yang konkret. "Memakai agen karena lebih canggih" tidak membantu evaluasi. "Mendelegasikan pengurutan metadata setelah semua DOI diperiksa karena kegiatan itu bukan target asesmen" menjelaskan keputusan dan memungkinkan orang lain meninjaunya. Jika data tidak lengkap, catat apa yang belum diketahui dan bagaimana kekurangan itu memengaruhi keputusan.

== Latihan analitis dan umpan balik
<latihan-analitis-dan-umpan-balik>
Pilih satu tugas yang sedang Anda kerjakan. Tulis dua definisi B: produk yang diterima pengguna dan kemampuan yang harus Anda tunjukkan sendiri. Lalu pilih satu kegiatan yang layak didelegasikan dan satu kegiatan yang perlu dilatih mandiri. Jelaskan perbedaannya dengan merujuk pada tujuan dan cara verifikasi.

Jawaban yang baik tidak harus memilih lebih sedikit AI. Jawaban perlu menunjukkan kesesuaian antara bantuan dan tujuan. Jika mahasiswa mendelegasikan seluruh analisis tetapi mengaku belajar analisis, bukti yang diperlukan adalah demonstrasi pada data baru tanpa delegasi. Jika buktinya belum tersedia, status hasil belajar tetap belum diketahui. Ketelitian menyatakan status inilah yang membuat kerangka perjalanan berguna dalam pendidikan.

= Tema 1 --- Learning: Probabilitas Bersyarat dan Bayes
<tema-1-learning-probabilitas-bersyarat-dan-bayes>
#figure([
#box(image("tise-six-themes/images/tema-1-learning-bayes.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-t1>


== Kontrak pembelajaran
<kontrak-pembelajaran>
#strong[Titik A:] belum dapat membedakan $P\(D divides +\)$ dari $P\(+ divides D\)$ atau menafsirkan hasil tes penyakit langka. #strong[Titik B:] mampu menghitung posterior, menjelaskan penyebabnya, menguji kewajaran jawaban, serta menerapkan pada soal baru tanpa bantuan.

Sasaran antara: (S1) probabilitas bersyarat; (S2) prior, likelihood, evidence, posterior; (S3) tabel populasi; (S4) #emph[base-rate fallacy]\; (S5) transfer. Contoh ini menggunakan #strong[parameter hipotetis untuk belajar], bukan estimasi klinis.

== Kasus inti: hasil tes positif penyakit langka
<kasus-inti-hasil-tes-positif-penyakit-langka>
Misalkan prevalensi penyakit $P\(D\)= 0\,01$, sensitivitas $P\(+ divides D\)= 0\,90$, dan spesifisitas $P\(- divides not D\)= 0\,95$. Maka peluang positif palsu $P\(+ divides not D\)= 0\,05$.

#table(
  columns: 4,
  align: (auto,right,right,right,),
  table.header([Kelompok dari 10.000 orang], [Tes positif], [Tes negatif], [Total],),
  table.hline(),
  [Sakit], [90], [10], [100],
  [Sehat], [495], [9.405], [9.900],
  [#strong[Total]], [#strong[585]], [#strong[9.415]], [#strong[10.000]],
)
Dengan Teorema Bayes:

$ P\(D divides +\)= frac(P\(+ divides D\)P\(D\), P\(+ divides D\)P\(D\)+ P\(+ divides not D\)P\(not D\)) = frac(0.90 dot.op 0.01, 0.90 dot.op 0.01 + 0.05 dot.op 0.99) approx 0.1538 . $

Hasilnya #strong[15,38%]: dari 585 orang yang positif, sekitar 90 benar-benar sakit. Sensitivitas 90% tidak sama dengan probabilitas sakit setelah positif. Prevalensi rendah menyebabkan kelompok sehat yang besar menghasilkan lebih banyak positif palsu, inilah konteks kekeliruan #emph[base-rate fallacy].

== Tiga pendekatan belajar
<tiga-pendekatan-belajar>
#strong[Alamiah:] peserta menggambar tabel $2 times 2$, menurunkan rumus, menghitung dengan kertas dan kalkulator, lalu menjelaskan dengan kata-kata sendiri.

#strong[Chatbot sebagai instrumen:] peserta meminta tutor Socratic memberikan satu pertanyaan sekaligus, petunjuk bertahap, dan evaluasi alasan #strong[tanpa langsung membocorkan jawaban].

#strong[Agen sebagai kendaraan:] peserta memberi agen mandat terbatas untuk membangun simulator variasi prevalensi/sensitivitas/spesifisitas, menyusun grafik dan latihan, sementara peserta wajib menafsirkan serta memvalidasi.

#block[
#callout(
body: 
[
Ajarkan probabilitas bersyarat dan Teorema Bayes melalui kasus penyakit langka. Tanyakan satu hal pada satu waktu; minta saya membuat tabel dari 10.000 orang; berikan petunjuk saat saya buntu; uji pemahaman dengan kasus baru tanpa langsung memberikan jawaban.

]
, 
title: 
[
Contoh prompt tutor
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]
== Variasi dan eksperimen kecil
<variasi-dan-eksperimen-kecil>
Tahan sensitivitas dan spesifisitas tetap, ubah prevalensi dari 0,1% ke 1%, 5%, dan 10%. Amati perubahan posterior dan jelaskan mengapa. Ketika metrik input berubah, periksa kembali apakah kasus masih mempunyai definisi populasi yang sama.

#block[
#Skylighting(([#KeywordTok("def");#NormalTok(" posterior(prevalensi, sensitivitas");#OperatorTok("=");#FloatTok(".90");#NormalTok(", spesifisitas");#OperatorTok("=");#FloatTok(".95");#NormalTok("):");],
[#NormalTok("    fpr ");#OperatorTok("=");#NormalTok(" ");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" spesifisitas");],
[#NormalTok("    ");#ControlFlowTok("return");#NormalTok(" sensitivitas ");#OperatorTok("*");#NormalTok(" prevalensi ");#OperatorTok("/");#NormalTok(" (");],
[#NormalTok("        sensitivitas ");#OperatorTok("*");#NormalTok(" prevalensi ");#OperatorTok("+");#NormalTok(" fpr ");#OperatorTok("*");#NormalTok(" (");#DecValTok("1");#NormalTok(" ");#OperatorTok("-");#NormalTok(" prevalensi)");],
[#NormalTok("    )");],
[],
[#ControlFlowTok("for");#NormalTok(" p ");#KeywordTok("in");#NormalTok(" [");#FloatTok(".001");#NormalTok(", ");#FloatTok(".01");#NormalTok(", ");#FloatTok(".05");#NormalTok(", ");#FloatTok(".10");#NormalTok("]:");],
[#NormalTok("    ");#BuiltInTok("print");#NormalTok("(");#SpecialStringTok("f\"Prevalensi ");#SpecialCharTok("{");#DecValTok("100");#OperatorTok("*");#NormalTok("p");#SpecialCharTok(":.1f}");#SpecialStringTok("% -> posterior ");#SpecialCharTok("{");#DecValTok("100");#OperatorTok("*");#NormalTok("posterior(p)");#SpecialCharTok(":.2f}");#SpecialStringTok("%\"");#NormalTok(")");],));
]
== Rubrik hasil tugas dan belajar
<rubrik-hasil-tugas-dan-belajar>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Aspek], [Bukti],),
  table.hline(),
  [Akurasi], [Tabel dan hasil probabilitas benar],
  [Pemahaman], [Mampu membedakan $P\(D divides +\)$ dan $P\(+ divides D\)$],
  [Penalaran], [Mampu menerangkan pengaruh prevalensi],
  [Transfer], [Menyelesaikan kasus baru tanpa AI],
  [Kemandirian], [Mampu mendeteksi kesalahan chatbot/agen],
)
#strong[Produk:] lembar jawaban, perhitungan, tabel dan/atau simulator, jurnal bantuan AI, serta tes transfer mandiri. Nilai kognitif tidak disamakan dengan kecepatan menghasilkan angka.

== Mengapa penyebut berubah ketika kita menerima informasi baru?
<mengapa-penyebut-berubah-ketika-kita-menerima-informasi-baru>
Probabilitas bersyarat dapat dimulai dari gagasan menyaring ruang kemungkinan. Dalam populasi 10.000 orang, pertanyaan "berapa peluang seseorang sakit?" memakai seluruh populasi sebagai penyebut. Setelah diketahui hasil tesnya positif, pertanyaannya berubah: dari kelompok yang positif, berapa yang sakit? Informasi positif memperkecil kelompok pembanding menjadi 585 orang. Karena itu penyebutnya bukan lagi 10.000 dan bukan pula 100 orang sakit. Buku statistik OpenStax menjelaskan penggunaan tabel kontingensi untuk membaca probabilitas bersyarat @openstax-stat\; kasus dan parameter di bab ini merupakan ilustrasi tersendiri.

Penurunan rumus membantu menghubungkan tabel dengan simbol. Berdasarkan definisi, $P\(D divides +\)= P\(D inter +\)\/P\(+\)$. Irisan $P\(D inter +\)$ dapat ditulis sebagai $P\(+ divides D\)P\(D\)$. Sementara itu, kejadian positif terbagi menjadi dua bagian yang saling lepas: positif pada orang sakit dan positif pada orang sehat. Menjumlahkan keduanya menghasilkan penyebut pada rumus Bayes. Setiap suku dengan demikian mempunyai arti populasi, bukan sekadar posisi dalam persamaan.

== Membandingkan beberapa prior dengan perhitungan lengkap
<membandingkan-beberapa-prior-dengan-perhitungan-lengkap>
Dengan sensitivitas 0,90 dan spesifisitas 0,95 yang sama, perubahan prevalensi menghasilkan nilai berikut. Angka ini hasil perhitungan parameter hipotetis, bukan data kesehatan.

#table(
  columns: (20%, 26.67%, 26.67%, 26.67%),
  align: (auto,right,right,right,),
  table.header([Prevalensi], [Positif benar per 10.000], [Positif palsu per 10.000], [Peluang sakit jika positif],),
  table.hline(),
  [0,1%], [9], [499,5], [1,77%],
  [1%], [90], [495], [15,38%],
  [5%], [450], [475], [48,65%],
  [10%], [900], [450], [66,67%],
)
Nilai pecahan orang pada baris pertama menyatakan frekuensi harapan, bukan jumlah aktual dalam satu sampel. Jika ingin seluruh entri bilangan bulat, gunakan populasi pembanding 100.000. Tabel menunjukkan bahwa kualitas sebuah tes dan komposisi populasi sama-sama memengaruhi penafsiran hasil. Perbandingan ini menahan parameter tes tetap; pada penerapan nyata asumsi tersebut perlu diperiksa.

Representasi lain memakai odds. Prior odds pada prevalensi 1% adalah $0\,01\/0\,99 = 1\/99$. Likelihood ratio positif adalah $0\,90\/0\,05 = 18$. Posterior odds menjadi $18\/99$, lalu dikonversi menjadi probabilitas $18\/\(18 + 99\)= 15\,38 %$. Cara ini bermanfaat untuk melihat bagaimana bukti mengubah keyakinan relatif, tetapi mahasiswa tetap perlu memahami asal pembilang dan penyebut.

== Merancang dialog tutor yang benar-benar mendiagnosis
<merancang-dialog-tutor-yang-benar-benar-mendiagnosis>
Tutor sebaiknya memulai dari pertanyaan "kelompok mana yang menjadi penyebut?" Jika peserta menjawab "orang sakit", tutor dapat meminta peserta membaca ulang bagian setelah tanda kondisi. Kesalahan itu menunjukkan pertukaran $P\(D divides +\)$ dan $P\(+ divides D\)$, sehingga memberikan rumus tambahan belum tentu memperbaiki pemahaman. Jika penyebut sudah benar tetapi hitungan salah, bantuan dapat beralih ke aritmetika.

Sesudah contoh selesai, peserta menutup penjelasan lalu merekonstruksi tabel. Studi Roediger dan Karpicke menunjukkan bahwa pada tugas mempelajari teks yang mereka uji, praktik mengingat kembali memberi keuntungan retensi pada tes tertunda dibandingkan membaca ulang @roediger2006. Rancangan latihan Bayes di sini memakai prinsip mencoba mengambil kembali pengetahuan; studi tersebut tidak secara langsung menguji tutor AI atau membuktikan efektivitas seluruh modul ini.

== Soal transfer beserta pembahasan
<soal-transfer-beserta-pembahasan>
Sebuah filter pesan menerima 2% spam. Ia menandai 95% spam, tetapi juga menandai 4% pesan bukan spam. Dari 10.000 pesan terdapat 200 spam; 190 ditandai. Dari 9.800 bukan spam, 392 ditandai. Jadi hanya $190\/\(190 + 392\)= 32\,65 %$ pesan bertanda yang merupakan spam. Jawaban 95% keliru karena menjawab peluang ditandai jika spam, bukan peluang spam jika ditandai.

Untuk latihan berikutnya, ubah proporsi spam menjadi 20% sambil mempertahankan parameter filter. Hasilnya $1.900\/\(1.900 + 320\)= 85\,59 %$. Peserta perlu menjelaskan perubahan ini melalui banyaknya pesan dari kedua kelompok, bukan hanya mengutip rumus. Dua hasil tersebut memperlihatkan transfer struktur penalaran dari tes hipotetis ke penyaringan pesan.

== Kesalahan lanjutan dan batas model
<kesalahan-lanjutan-dan-batas-model>
Dua hasil positif berturut-turut tidak otomatis berarti likelihood ratio boleh dikuadratkan. Perkalian tersebut memerlukan asumsi tentang ketergantungan kedua pengukuran setelah kondisi sebenarnya diketahui. Menguji ulang objek dengan alat dan prosedur identik dapat menghasilkan kesalahan yang berkaitan. Dalam latihan, nyatakan asumsi independensi bersyarat sebelum menghitung. Pada akhir modul, peserta dianggap memahami model jika mampu menyebutkan informasi yang belum tersedia, selain menghitung jawaban yang tersedia.

= Tema 2 --- Literature Study dan State of the Art Lima Lapisan
<tema-2-literature-study-dan-state-of-the-art-lima-lapisan>
#figure([
#box(image("tise-six-themes/images/tema-2-studi-literatur.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-t2>


== Kontrak tugas
<kontrak-tugas>
#strong[A:] peneliti mempunyai topik tetapi belum mengetahui peta pengetahuan terkini, solusi sebelumnya, bukti, dan celah yang penting. #strong[B:] laporan #emph[State of the Art] (SoTA) yang berisi #strong[lima bagian utama---L5 hingga L1---masing-masing dengan peluang perbaikan dan metrik untuk membuktikan pendekatan baru]. Sintesis lintas lapisan menghubungkan kelimanya dan dapat menurunkan satu atau lebih proposal.

== Delapan sasaran antara
<delapan-sasaran-antara>
S1 merumuskan tema; S2 memilih artikel; S3 merekonstruksi perjalanan riset A→B; S4 mengekstraksi instrumen serta metrik pengukuran; S5 memetakan dan membandingkan pada lima lapisan; S6 mengidentifikasi gap; S7 mengusulkan rute/arsitektur/mesin/teknologi baru; S8 menyusun kontrak evaluasi serta laporan SoTA.

== Research Journey Card
<research-journey-card>
Setiap artikel menjadi sebuah kartu yang dapat dilacak ke halaman/section sumber.

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Field], [Pertanyaan ekstraksi],),
  table.hline(),
  [Identitas & bukti], [Judul, DOI, tahun, bagian/halaman, jenis studi],
  [A], [Keadaan atau masalah awal penulis],
  [B], [Kinerja/keadaan tujuan yang dinyatakan],
  [Sasaran antara], [Tahapan, fungsi, asumsi, batasan],
  [Rute], [Metodologi dan strategi],
  [Kendaraan], [Sistem/artefak yang dibangun],
  [Mesin], [Mekanisme atau algoritma pemrosesan],
  [Teknologi & sumber daya], [Dataset, instrumen, komputasi, waktu, keahlian],
  [Metrik/protokol], [Apa diukur, dengan apa dan bagaimana],
  [Hasil], [Bukti dan keterbatasannya],
  [Peluang], [Kelemahan/gap, dibedakan dari spekulasi pembaca],
)
Klaim #strong[penulis artikel] dan #strong[interpretasi penelaah] sebaiknya disimpan pada kolom terpisah.

== Lima bagian wajib laporan SoTA
<lima-bagian-wajib-laporan-sota>
=== L5 --- Ekosistem
<l5-ekosistem>
Uraikan siapa stakeholder, tata kelola, tujuan, kebutuhan, nilai, dan keberlanjutan. Untuk AI akademik, unsur utamanya meliputi mahasiswa, pendidik, peneliti, institusi, penerbit, masyarakat dan regulator. #strong[Peluang:] tata kelola yang mempertahankan integritas, otonomi, akses, dan pertumbuhan kemampuan.

=== L4 --- Rute dan kendaraan
<l4-rute-dan-kendaraan>
Rekonstruksi strategi menyelesaikan aktivitas: belajar mandiri, chatbot tutor, agen AI, penelusuran sumber, pelatihan, dan evaluasi. #strong[Peluang:] memilih rute adaptif menurut kapasitas, energi, waktu, risiko, dan capaian belajar.

=== L3 --- Arsitektur kendaraan
<l3-arsitektur-kendaraan>
Bandingkan desain platform, workflow, retrieval, izin, penyimpanan konteks, pemeriksa dan evaluator. #strong[Peluang:] platform multi-agen dengan pelacakan sumber, rubrik, penilaian tanpa AI, dan tata kelola pengguna.

=== L2 --- Mesin
<l2-mesin>
Bandingkan mekanisme retrieval, reasoning, feedback, teaching-back, active recall, scaffolding, fading assistance, dan pengendalian kesalahan. #strong[Peluang:] #emph[adaptive co-learning engine] yang mengatur bantuan dan menuntut bukti peningkatan kompetensi.

=== L1 --- Energi dan teknologi
<l1-energi-dan-teknologi>
Bandingkan LLM, penyimpanan dataset, API, model lokal, komputasi, energi fisik, biaya dan keahlian. #strong[Peluang:] konfigurasi lebih hemat, privat, dapat diaudit, serta mudah direproduksi.

== Research Comparison Matrix dan kontrak evaluasi
<research-comparison-matrix-dan-kontrak-evaluasi>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Layer], [Yang dibandingkan], [Contoh metrik (harus disesuaikan kasus)],),
  table.hline(),
  [L5], [Kebijakan dan nilai antar-stakeholder], [Kompetensi, akses, keadilan, integritas],
  [L4], [Rute dan kinerja tugas], [Mutu keluaran, waktu, retensi, transfer],
  [L3], [Arsitektur platform], [Kegagalan, auditabilitas, interoperabilitas],
  [L2], [Mesin pembelajaran/AI], [Umpan balik benar, ketergantungan, learning gain],
  [L1], [Teknologi dan sumber daya], [Latensi, biaya, konsumsi energi, privasi],
)
Metrik merupakan #strong[apa] yang diukur, instrumen merupakan #strong[dengan apa], dan protokol merupakan #strong[bagaimana]. Perbandingan metode hanya valid bila data, ukuran, kondisi dan baseline cukup sebanding atau perbedaannya dijelaskan.

== Kasus: penggunaan AI yang tepat di dunia akademik
<kasus-penggunaan-ai-yang-tepat-di-dunia-akademik>
#strong[Pertanyaan penelitian:] dapatkah sistem yang mengadaptasi tiga rute (mandiri, chatbot, agen) menghasilkan kualitas tugas yang tinggi #strong[sekaligus] meningkatkan kompetensi mandiri dibandingkan pemberian bantuan AI tetap?

Kandidat inovasi meliputi L5 tata kelola akademik, L4 route selection, L3 platform akademik multi-agen, L2 mesin scaffolding, dan L1 stack AI yang efisien. Semua adalah #strong[hipotesis peluang], bukan klaim gap yang sudah dibuktikan; kebaruan memerlukan penelusuran literatur dan validasi tambahan.

Untuk praktik SoTA, mulai dari lima artikel inti, lalu perluas ke studi yang mewakili metode dan kontroversi. Untuk SLR formal, gunakan protokol pencarian serta inklusi--eksklusi yang transparan dan standar pelaporan yang relevan (misalnya PRISMA 2020). Jangan menganggap ukuran korpus tertentu sebagai syarat universal.

== Tiga pendekatan
<tiga-pendekatan>
- #strong[Alamiah:] pencarian, pembacaan kritis, pengisian kartu, sintesis, dan perumusan gap mandiri.
- #strong[Chatbot:] membantu membaca bagian sukar, menguji interpretasi, menyusun perbandingan, mengkritisi hipotesis dengan referensi yang diperiksa.
- #strong[Agen:] menjalankan pencarian dan penyaringan sumber yang diizinkan, mengisi kartu dengan provenance, membangun matriks dan draf laporan---peneliti tetap mengaudit klaim.

== Produk akhir
<produk-akhir>
Laporan lima bab analitis L5--L1, daftar artikel terpilih, seluruh Research Journey Cards, Research Comparison Matrix, daftar gap beserta derajat kepastian, dan Research Evaluation Contract untuk pendekatan baru.

#strong[Rujukan pendukung:] kerangka kompetensi AI UNESCO dan #emph[Ethics of AI Recommendation], tinjauan riset pendidikan, serta sumber asli studi yang dipilih; lihat #link("references.qmd")[Referensi].

== Dari topik luas ke pertanyaan yang dapat ditelusuri
<dari-topik-luas-ke-pertanyaan-yang-dapat-ditelusuri>
"AI dalam pendidikan" terlalu luas untuk menjadi satu tugas penelaahan. Mulailah dengan populasi, bentuk bantuan, pembanding, dan hasil. Contoh pertanyaan yang lebih terarah adalah: pada mahasiswa pengantar statistika, bagaimana tutor berbasis dialog dibandingkan pemberian jawaban langsung dalam mendukung transfer tanpa bantuan? Rumusan ini menentukan istilah pencarian dan data yang perlu diekstraksi. Ia juga mencegah artikel tentang kepuasan pengguna diperlakukan sebagai jawaban langsung tentang transfer.

Susun kelompok istilah untuk konsep yang sama, misalnya #NormalTok("generative AI OR large language model");, #NormalTok("tutoring OR scaffolding");, dan #NormalTok("transfer OR retention");. Hubungkan kelompok dengan AND, kemudian sesuaikan sintaks terhadap basis data yang digunakan. Catat tanggal, basis data, string persis, dan pembatasan bahasa atau tahun. Hasil pencarian yang sedikit dapat berarti topiknya sempit, istilahnya tidak cocok, atau indeksnya terbatas; ketiga kemungkinan perlu dibedakan sebelum menyatakan tidak ada penelitian.

== Menyeleksi tanpa mengubah aturan mengikuti hasil
<menyeleksi-tanpa-mengubah-aturan-mengikuti-hasil>
Untuk praktikum, tentukan lebih dahulu bahwa studi harus mendeskripsikan peserta, intervensi, dan hasil belajar yang relevan. Artikel opini masih dapat dipakai untuk konteks kebijakan, tetapi tidak dikelompokkan sebagai eksperimen efektivitas. Seleksi dilakukan dari judul dan abstrak menuju teks penuh, dengan alasan eksklusi yang dapat ditinjau. Dua pembaca dapat menguji beberapa artikel bersama untuk menyamakan pengertian kriteria sebelum membagi pekerjaan.

PRISMA 2020 menyediakan pedoman pelaporan review sistematis beserta daftar periksa dan diagram alir @prisma2020. Memakai diagram tersebut tidak dengan sendirinya menjadikan pencarian lengkap atau studi berkualitas. Untuk SoTA kelas, jelaskan bahwa pencarian bersifat terarah dan terbatas apabila memang demikian. Transparansi cakupan lebih bernilai daripada memakai label SLR tanpa protokol yang memadai.

== Menilai bukti sebelum menyusun matriks lima lapisan
<menilai-bukti-sebelum-menyusun-matriks-lima-lapisan>
Satu artikel dapat mempunyai arsitektur sistem yang menarik tetapi evaluasi pendidikan yang lemah. Karena itu, nilai kontribusi konseptual, kecukupan metode, dan kekuatan klaim secara terpisah. Periksa siapa pesertanya, bagaimana pembanding dibentuk, kapan hasil diukur, apakah bantuan tetap tersedia saat tes, dan apakah peserta keluar dari studi. Sampel kecil tidak otomatis tidak berguna, tetapi estimasi dan generalisasinya perlu dibatasi.

Pertimbangkan dua studi hipotetis. Studi A membandingkan nilai latihan ketika peserta masih memakai chatbot. Studi B mengukur soal baru seminggu setelah chatbot dihentikan. Keduanya dapat relevan untuk L4 rute belajar, tetapi hasilnya menjawab pertanyaan berbeda. Matriks yang menggabungkan kedua skor menjadi satu peringkat "AI terbaik" menghilangkan perbedaan penting. Tulis jenis hasil pada kolom tersendiri sebelum membandingkan besar peningkatannya.

== Contoh sintesis lintas lapisan
<contoh-sintesis-lintas-lapisan>
Misalkan beberapa studi terpilih menunjukkan keluaran tugas yang baik, tetapi hanya sebagian melaporkan tes mandiri. Pada L5, persoalannya adalah nilai pendidikan yang ingin dijaga. Pada L4, pertanyaannya kapan bantuan dihentikan. Pada L3, sistem perlu mampu mencatat jenis bantuan. Pada L2, mekanismenya dapat berupa petunjuk bertahap. Pada L1, platform harus memungkinkan pencatatan tersebut dengan biaya dan perlindungan data yang sesuai. Hubungan lintas lapisan menghasilkan kebutuhan desain yang dapat ditelusuri dari masalah pendidikan sampai implementasi.

Sintesis yang hati-hati berbunyi: "Dalam korpus yang ditelaah, evaluasi transfer tanpa bantuan belum dilaporkan secara konsisten." Pernyataan "belum ada penelitian tentang transfer" jauh lebih luas dan membutuhkan pencarian tambahan. Kandidat kebaruan kemudian dirumuskan sebagai desain yang akan diuji, disertai kemungkinan bahwa pendekatan serupa telah dikembangkan dengan istilah berbeda.

== Praktikum membaca satu sumber bersama
<praktikum-membaca-satu-sumber-bersama>
Gunakan artikel Roediger dan Karpicke @roediger2006 untuk berlatih membedakan pertanyaan, kondisi pembanding, dan waktu pengukuran. Kartu perjalanan harus menyatakan bahwa studi tersebut meneliti pengambilan kembali dari ingatan pada bahan teks, bukan AI generatif. Ketika peserta mengusulkan tutor yang memakai retrieval practice, tandai hubungan itu sebagai penerapan konseptual yang masih perlu diuji. Latihan ini menguji apakah penelaah mampu memakai sumber tanpa memperluas klaimnya.

Produk akhir perlu mempunyai satu paragraf sintesis untuk setiap pertanyaan penting, bukan satu paragraf ringkasan untuk setiap artikel. Setiap paragraf menyebut pola persamaan, perbedaan yang menjelaskannya, dan implikasi yang masih terbuka. Reviewer kemudian memilih dua klaim utama dan menelusurinya sampai lokasi sumber. Jika jalur tersebut putus, perbaiki pencatatan sebelum menambah jumlah artikel.

= Tema 3 --- Academic Writing: Esai Berbasis Gagasan dan Bukti
<tema-3-academic-writing-esai-berbasis-gagasan-dan-bukti>
#figure([
#box(image("tise-six-themes/images/tema-3-academic-writing.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-t3>


== Kontrak tugas
<kontrak-tugas-1>
#strong[A:] penulis memiliki pendapat awal tanpa tesis tajam, argumen terstruktur, dan bukti ilmiah yang memadai. #strong[B:] esai argumentatif yang mempunyai tesis jelas, bukti terverifikasi, penalaran, argumen tandingan, sintesis, sitasi, dan pengungkapan penggunaan AI sesuai aturan.

#strong[Kasus:] #emph[penggunaan AI secara etis di dunia akademik dan ruang publik].

Contoh gagasan awal: "AI harus digunakan secara etis." Contoh tesis yang dapat diperdebatkan: "Pemanfaatan AI tidak cukup dievaluasi melalui efisiensi; ia perlu dinilai pula melalui penguatan kompetensi, otonomi manusia, akuntabilitas, dan pencegahan kerugian sosial."

== Sasaran antara S1--S7
<sasaran-antara-s1s7>
+ Kenali isu, pembaca, tujuan esai dan batas argumen.
+ Rumuskan tesis yang jelas, penting, dapat diperdebatkan dan mungkin didukung bukti.
+ Kumpulkan literatur, data, kebijakan, bukti dan argumen tandingan.
+ Buat #emph[argument map]: klaim, alasan, bukti, asumsi penghubung (#emph[warrant]), batasan, dan rebuttal.
+ Susun kerangka, #emph[topic sentences], dan draf paragraf yang koheren.
+ Periksa logika, sitasi, akurasi, keaslian, serta relevansi bukti; revisi.
+ Finalisasi, deklarasikan bantuan AI, pertahankan argumen secara mandiri.

== Mesin argumentasi
<mesin-argumentasi>
#figure([
#box(image("tise-six-themes/images/diagrams/04-tema3-writing-1.svg", height: 150mm))
], caption: figure.caption(
position: bottom, 
[
Diagram alur; label dan hubungan mengikuti definisi sumber.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


Klaim penting harus ditopang oleh sumber yang relevan; penulis harus #strong[menjelaskan hubungan] antara sumber dan klaim. Sitasi palsu, angka yang tidak dapat ditemukan dan pernyataan lebih kuat daripada bukti merupakan kegagalan mutu.

== Contoh struktur esai
<contoh-struktur-esai>
#strong[Judul:] #emph[AI yang Bertanggung Jawab: dari Produktivitas ke Penguatan Kapabilitas Manusia di Dunia Akademik dan Ruang Publik].

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Bagian], [Klaim atau topic sentence], [Bukti yang perlu dicari],),
  table.hline(),
  [Pendahuluan], [AI mengubah pembelajaran, penelitian dan layanan publik], [Kajian dampak dan pedoman],
  [Argumen 1], [Efisiensi bukan satu-satunya hasil yang bernilai], [Studi kognitif, kerja dan pembelajaran],
  [Argumen 2], [Integritas akademik menuntut tanggung jawab penulis], [Kebijakan ilmiah, etika sitasi],
  [Argumen 3], [Ruang publik menuntut tata kelola, fairness dan privasi], [Etika AI dan tata kelola risiko],
  [Argumen 4], [Bantuan AI perlu disesuaikan dengan tujuan dan kompetensi], [Scaffolding, human--AI collaboration],
  [Tandingan], [Otomasi penuh mungkin lebih hemat untuk beberapa tugas], [Bukti produktivitas dan risiko],
  [Sintesis], [AI perlu membantu manusia menjadi lebih mampu], [Argumen terintegrasi],
)
#strong[Contoh paragraf argumen yang dirancang:] Pemakaian AI untuk menyelesaikan aktivitas akademik sebaiknya bergantung pada fungsi aktivitas tersebut. Jika tujuan utamanya latihan penalaran, jawaban instan dapat mengurangi kesempatan berlatih; jika tugas bersifat administratif, otomasi dapat membebaskan waktu untuk aktivitas kognitif lebih penting. Karena itu aturan perlu membedakan tujuan belajar, tingkat kompetensi dan risiko pekerjaan. Paragraf akhir wajib diberi rujukan empiris yang sepadan sebelum dianggap siap publikasi.

== Tiga pendekatan dan instrumen
<tiga-pendekatan-dan-instrumen>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Moda], [Pekerjaan peserta], [Fungsi AI],),
  table.hline(),
  [Alamiah], [Rumuskan tesis, baca, tulis, revisi], [Tidak diperlukan],
  [Chatbot], [Diskusikan tesis, uji klaim, minta kritik], [Tutor dan editor, bukan pemilik argumen],
  [Agen], [Minta penelusuran sumber, audit konsistensi, formatting], [Delegasi terbatas; semua klaim diverifikasi],
)
== Rubrik contoh
<rubrik-contoh>
#table(
  columns: 2,
  align: (auto,right,),
  table.header([Kriteria], [Bobot],),
  table.hline(),
  [Tesis], [15%],
  [Argumentasi dan penalaran], [20%],
  [Mutu dan verifikasi bukti], [20%],
  [Argumen tandingan], [10%],
  [Struktur dan koherensi], [15%],
  [Bahasa akademik], [10%],
  [Sitasi, transparansi AI dan integritas], [10%],
)
Selain skor esai, peserta menghadapi tanya jawab tanpa AI, menilai kritik, serta menulis paragraf baru. Kesalahan integritas serius ditangani dengan kebijakan tersendiri, bukan hanya pengurangan nilai biasa.

== Produk
<produk>
Esai akhir, matriks klaim--bukti--sumber, peta argumen, histori revisi, deklarasi bantuan AI, serta rekaman asesmen pemahaman penulis.

== Mengembangkan tesis melalui pertanyaan yang dapat diperdebatkan
<mengembangkan-tesis-melalui-pertanyaan-yang-dapat-diperdebatkan>
Esai akademik berkembang ketika penulis menemukan persoalan yang mempunyai lebih dari satu jawaban masuk akal. Pernyataan "AI memiliki manfaat dan risiko" hanya membuka topik. Pertanyaan "kapan bantuan AI dapat dibenarkan dalam tugas yang bertujuan melatih penalaran?" menghasilkan kebutuhan untuk menetapkan kriteria dan menghadapi keberatan. Tesis kemudian menyatakan jawaban sementara, beserta lingkupnya: jenis tugas, kelompok pengguna, dan kondisi penggunaan.

Sebelum mencari kutipan pendukung, tulis alasan yang membuat Anda percaya pada tesis tersebut. Misalnya, tujuan latihan memerlukan peserta melakukan sebagian kerja kognitif, sedangkan tujuan produksi memungkinkan pembagian kerja lebih luas. Kedua alasan itu tidak membuktikan dampak AI, tetapi memperjelas bagian argumen yang bersifat normatif. Bukti empiris diperlukan untuk klaim tentang akibat penggunaan, sementara alasan etis diperlukan untuk menjelaskan mengapa akibat tertentu dinilai penting.

== Membuat hubungan bukti dan klaim terlihat
<membuat-hubungan-bukti-dan-klaim-terlihat>
Kerangka Toulmin membedakan klaim, dasar bukti, penghubung penalaran, dukungan atas penghubung, pembatas, dan sanggahan @purdue-toulmin. Dalam praktik menulis, bagian yang paling sering hilang adalah penghubung: mengapa sumber tertentu relevan bagi tesis? Artikel yang membuktikan perbaikan retensi melalui pengujian ingatan tidak langsung membuktikan semua penggunaan AI merugikan pembelajaran. Penulis perlu menjelaskan kondisi apa yang mungkin mengurangi atau memperbesar kesempatan mengingat kembali.

Pertimbangkan paragraf berikut sebagai contoh argumentasi, bukan laporan eksperimen baru. "Tugas pembelajaran perlu menyisakan kesempatan bagi peserta untuk mencoba mengambil kembali pengetahuannya. Penelitian tentang retrieval practice memberi alasan untuk memperhatikan kegiatan itu @roediger2006. Karena itu, pada latihan yang menargetkan penguasaan konsep, tutor AI dapat dirancang menunda jawaban lengkap sampai peserta mengajukan upaya sendiri. Usulan tersebut tetap memerlukan evaluasi pada konteks dan peserta yang bersangkutan." Paragraf ini bergerak dari prinsip, bukti terbatas, implikasi desain, menuju batas klaim.

Bandingkan dengan "penelitian membuktikan AI membuat mahasiswa malas." Versi kedua mengubah objek yang diteliti, menambah penilaian karakter, dan menyatakan sebab-akibat yang tidak didukung sumber. Kesalahan tersebut tidak dapat diperbaiki hanya dengan menambah sitasi di akhir kalimat.

== Mengolah argumen tandingan secara adil
<mengolah-argumen-tandingan-secara-adil>
Keberatan yang kuat terhadap pembatasan AI ialah bahwa bantuan dapat membuka akses bagi mahasiswa yang sebelumnya kesulitan memahami materi. Penulis perlu menerima kemungkinan manfaat tersebut, lalu memperjelas tesis. Kebijakan yang hanya mengurangi bantuan tanpa memperhatikan kebutuhan peserta dapat menghambat pembelajaran. Alternatif yang layak diperdebatkan adalah menyesuaikan bentuk bantuan dan menyediakan cara menunjukkan kompetensi yang setara.

Argumen tandingan mengubah tesis menjadi lebih tepat: bantuan dikendalikan menurut tujuan dan kebutuhan, dengan bukti penguasaan yang sesuai. Pedoman UNESCO dapat menjadi konteks bagi pembahasan pendekatan yang berpusat pada manusia @unesco-genai. Pedoman tersebut merupakan rujukan normatif, sehingga jangan menyebutnya eksperimen yang membuktikan kenaikan nilai mahasiswa.

== Revisi dalam tiga lintasan
<revisi-dalam-tiga-lintasan>
Pada lintasan pertama, periksa struktur besar. Setiap bagian perlu menjawab pertanyaan yang membuat tesis maju. Paragraf sejarah AI yang panjang dapat dipotong jika tidak membantu masalah yang dibahas. Buat #emph[reverse outline] dengan menuliskan fungsi setiap paragraf setelah draf selesai. Jika tiga paragraf mempunyai fungsi identik, gabungkan atau bedakan perannya.

Pada lintasan kedua, audit klaim. Tandai pernyataan empiris, konseptual, normatif, dan hipotetis. Periksa sumber untuk pernyataan empiris, konsistensi definisi untuk konsep, alasan nilai untuk norma, serta label untuk ilustrasi. Pada lintasan ketiga, perbaiki kalimat, transisi, istilah, dan sitasi. Urutan ini mencegah waktu habis memperhalus paragraf yang akhirnya dihapus.

== Latihan revisi dengan kriteria penerimaan
<latihan-revisi-dengan-kriteria-penerimaan>
Revisi kalimat "semua universitas harus menggunakan agen AI karena mahasiswa menjadi lebih pintar." Mulailah dengan mempertanyakan siapa yang dimaksud, bentuk penggunaan, arti "lebih pintar", dan bukti kausalnya. Versi yang dapat dipertanggungjawabkan sebagai usulan adalah: "Program studi dapat menguji tutor AI dalam pilot terbatas, dengan mutu tugas dan transfer tanpa bantuan sebagai hasil yang dinilai terpisah." Kalimat itu belum menjadi kesimpulan penelitian, tetapi sudah mempunyai tindakan, lingkup, dan cara pemeriksaan.

Sertakan satu contoh revisi Anda sendiri dalam portofolio: kalimat awal, diagnosis masalah, sumber yang diperiksa, kalimat baru, dan alasan perubahannya. Uji lisan kemudian meminta penulis menjelaskan keputusan tersebut. Dengan begitu, kejelasan prosa dan kepemilikan argumen dapat dinilai bersama.

= Tema 4 --- Computational and Data Literacy
<tema-4-computational-and-data-literacy>
#figure([
#box(image("tise-six-themes/images/tema-4-komputasi-data.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-t4>


== Data sebagai cara melihat dunia
<data-sebagai-cara-melihat-dunia>
Tema ini membangun kemampuan memandang fenomena melalui representasi pengukuran. Proses epistemiknya adalah

$ upright("Fenomena") arrow.r upright("Pengukuran") arrow.r upright("Data") arrow.r upright("Model") arrow.r upright("Bukti") arrow.r upright("Pengetahuan") . $

#strong[A:] mahasiswa mempunyai pertanyaan dan akses data tetapi belum mampu memeriksa makna variabel, mempersiapkan data, menganalisis, melakukan simulasi, atau menilai klaim. #strong[B:] mahasiswa membuat analisis yang dapat direproduksi dan dapat menjelaskan hubungan antara realitas, data, model serta keterbatasan inferensinya.

== Kasus: AI dan kemampuan kognitif mahasiswa
<kasus-ai-dan-kemampuan-kognitif-mahasiswa>
#strong[Pertanyaan eksploratoris:] apakah intensitas dan cara mahasiswa menggunakan AI berhubungan dengan hasil akademik dan indikator penalaran? #strong[Pertanyaan kausal yang lebih kuat:] apakah strategi AI tertentu menyebabkan peningkatan kemampuan kognitif yang bertahan tanpa AI?

Nilai ujian, jumlah percakapan, atau frekuensi penggunaan AI #strong[bukan pengukuran langsung tunggal] atas kemampuan kognitif. Dibutuhkan tes konsep, kualitas penalaran, transfer, retensi, kemampuan tanpa AI, atau instrumen lain yang tervalidasi.

== Delapan sasaran antara
<delapan-sasaran-antara-1>
S1 rumuskan pertanyaan dan definisi variabel; S2 cari dataset dan baca lisensinya; S3 periksa unit observasi, skala dan data dictionary; S4 bersihkan dan gabungkan data; S5 EDA; S6 model dan simulasi; S7 validasi dan interpretasi; S8 laporan serta notebook reproduktif.

== Sumber dataset dan kecocokan
<sumber-dataset-dan-kecocokan>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([Sumber], [Tipe data], [Bisa dipakai untuk], [Keterbatasan],),
  table.hline(),
  [#link("https://huggingface.co/datasets/wmcnicho/StudyChat")[StudyChat (Hugging Face)]], [Dialog mahasiswa dengan tutor AI], [Strategi bertanya, pola percakapan], [Interaksi tidak otomatis mengukur peningkatan kognitif],
  [#link("https://huggingface.co/datasets/aiboxlab/edu-interactions")[EDU Interactions]], [Interaksi dan nilai akademik], [Analisis relasional penggunaan AI--nilai], [Bersifat observasional, akses dan skema perlu diperiksa],
  [#link("https://www.kaggle.com/competitions/map-charting-student-math-misunderstandings")[MAP Student Math Misunderstandings (Kaggle)]], [Jawaban/miskonsepsi matematis], [Analisis kualitas penalaran], [Tidak mengukur efek penggunaan AI secara langsung],
)
Periksa kembali lisensi, nama file, izin, serta versi dataset ketika praktikum dimulai. Tidak semua dataset mengizinkan pengunduhan atau redistribusi tanpa syarat. #strong[Buku tidak menyertakan data mentah berlisensi pihak ketiga.]

== Pipeline data
<pipeline-data>
#figure([
#box(image("tise-six-themes/images/diagrams/05-tema4-data-1.svg", height: 150mm))
], caption: figure.caption(
position: bottom, 
[
Diagram alur; label dan hubungan mengikuti definisi sumber.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


Unit analisis perlu ditentukan terlebih dahulu. Misalnya jika satu mahasiswa memiliki banyak interaksi pada satu mata kuliah, agregasikan per mahasiswa--mata kuliah sebelum bergabung dengan tabel nilai satu baris per unit. Perbedaan level agregasi dapat menyebabkan #emph[many-to-many join] yang salah.

#block[
#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("from");#NormalTok(" scipy.stats ");#ImportTok("import");#NormalTok(" spearmanr");],
[],
[#CommentTok("# Contoh mengandaikan CSV sudah diunduh sesuai izin dataset.");],
[#NormalTok("grades ");#OperatorTok("=");#NormalTok(" pd.read_csv(");#StringTok("\"grades.csv\"");#NormalTok(")");],
[#NormalTok("interaction ");#OperatorTok("=");#NormalTok(" pd.read_csv(");#StringTok("\"interactions.csv\"");#NormalTok(")");],
[#BuiltInTok("print");#NormalTok("(grades.columns.tolist(), interaction.columns.tolist())");],
[#CommentTok("# Verifikasi nama kolom terhadap data dictionary sebelum mengubah kode.");],
[#NormalTok("keys ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"id_aluno\"");#NormalTok(", ");#StringTok("\"disciplina\"");#NormalTok("]");],
[#NormalTok("usage ");#OperatorTok("=");#NormalTok(" interaction.groupby(keys, as_index");#OperatorTok("=");#VariableTok("False");#NormalTok(")[");#StringTok("\"qtd_mensagensaluno\"");#NormalTok("].");#BuiltInTok("sum");#NormalTok("()");],
[#ControlFlowTok("assert");#NormalTok(" ");#KeywordTok("not");#NormalTok(" usage.duplicated(keys).");#BuiltInTok("any");#NormalTok("()");],
[#ControlFlowTok("assert");#NormalTok(" ");#KeywordTok("not");#NormalTok(" grades.duplicated(keys).");#BuiltInTok("any");#NormalTok("()");],
[#NormalTok("df ");#OperatorTok("=");#NormalTok(" grades.merge(usage, on");#OperatorTok("=");#NormalTok("keys, how");#OperatorTok("=");#StringTok("\"left\"");#NormalTok(", validate");#OperatorTok("=");#StringTok("\"one_to_one\"");#NormalTok(")");],
[#CommentTok("# Periksa makna NaN: tidak ada interaksi atau informasi tidak tercatat?");],
[#BuiltInTok("print");#NormalTok("(df.isna().");#BuiltInTok("sum");#NormalTok("())");],
[#NormalTok("clean ");#OperatorTok("=");#NormalTok(" df.dropna(subset");#OperatorTok("=");#NormalTok("[");#StringTok("\"nota_final\"");#NormalTok(", ");#StringTok("\"qtd_mensagensaluno\"");#NormalTok("])");],
[#BuiltInTok("print");#NormalTok("(spearmanr(clean[");#StringTok("\"qtd_mensagensaluno\"");#NormalTok("], clean[");#StringTok("\"nota_final\"");#NormalTok("]))");],));
]
#strong[Penting:] skrip tersebut adalah pola kerja untuk disesuaikan, belum hasil yang dijalankan dan diverifikasi terhadap versi dataset spesifik. Korelasi tidak membuktikan kausalitas; kemampuan awal, intensitas tugas, motivasi, dan seleksi penggunaan AI dapat menjadi pengganggu (#emph[confounders]).

== Pengukuran kemampuan kognitif
<pengukuran-kemampuan-kognitif>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Konstruk], [Indikator/instrumen], [Catatan validitas],),
  table.hline(),
  [Pemahaman], [Tes konsep tanpa AI], [Butir mewakili konsep yang dilatih],
  [Penalaran], [Rubrik argumentasi], [Penilai harus konsisten],
  [Transfer], [Soal baru], [Tidak sekadar mengulang soal latihan],
  [Retensi], [Tes tertunda], [Waktu dan tingkat kesulitan setara],
  [Metakognisi], [Estimasi yakin vs kinerja], [Bedakan kalibrasi dari rasa percaya diri],
  [Otonomi], [Kinerja saat bantuan dihentikan], [Ukur di luar lingkungan AI],
)
== Desain eksperimen lanjutan
<desain-eksperimen-lanjutan>
Bandingkan G1 mandiri, G2 chatbot, G3 agen, G4 AI adaptif. Gunakan pretest, posttest, tes tertunda, dan soal transfer; kelompok harus sebanding. Jika memungkinkan, lakukan randomisasi dan cegah kebocoran antara kelompok. Nilai simulasi, bila digunakan untuk belajar pemodelan, #strong[harus diberi label simulasi] dan tidak boleh ditafsirkan sebagai temuan nyata.

== Produk dan rubrik
<produk-dan-rubrik>
Dataset beserta provenance, notebook pembersihan dan EDA, model/simulasi, grafik, interpretasi, pemeriksaan asumsi, laporan, dan jurnal bantuan AI.

#table(
  columns: 2,
  align: (auto,right,),
  table.header([Komponen], [Bobot],),
  table.hline(),
  [Pemahaman data dan pengukuran], [20%],
  [Persiapan data], [15%],
  [Analisis dan model], [20%],
  [Validasi dan interpretasi], [20%],
  [Reproduksibilitas dan komunikasi], [15%],
  [Refleksi AI dan kemandirian], [10%],
)
== Mendefinisikan observasi sebelum menulis kode
<mendefinisikan-observasi-sebelum-menulis-kode>
Data bukan salinan realitas yang bebas keputusan. Ketika satu baris disebut "penggunaan AI mahasiswa", peneliti perlu menentukan apakah baris itu sesi, pesan, hari, mata kuliah, atau individu. Seratus pesan dari satu orang tidak sama dengan seratus mahasiswa. Mengabaikan unit observasi dapat membuat hasil tampak jauh lebih pasti daripada informasi yang sebenarnya tersedia.

Buat kamus data sebelum analisis: nama variabel, definisi, satuan, tipe, nilai yang diizinkan, makna kosong, sumber, dan waktu pengukuran. Untuk frekuensi penggunaan, angka nol perlu dibedakan dari data yang tidak tercatat. Untuk skor penalaran, dokumentasikan tugas dan rubrik yang menghasilkannya. Definisi ini menentukan apakah operasi seperti menjumlahkan, merata-ratakan, atau menggabungkan tabel masuk akal.

== Contoh kecil yang memperlihatkan masalah perancu
<contoh-kecil-yang-memperlihatkan-masalah-perancu>
Tabel berikut sepenuhnya sintetis dan hanya dipakai untuk menjelaskan analisis. Skor adalah angka ilustrasi pada skala 0--100.

#table(
  columns: 4,
  align: (auto,auto,right,right,),
  table.header([Mahasiswa], [Kemampuan awal], [Pesan AI], [Skor akhir],),
  table.hline(),
  [A], [Rendah], [20], [60],
  [B], [Rendah], [40], [65],
  [C], [Tinggi], [5], [85],
  [D], [Tinggi], [10], [90],
)
Pada keseluruhan tabel, mahasiswa yang lebih sering memakai AI cenderung mempunyai skor akhir lebih rendah. Namun di dalam setiap kategori kemampuan awal, pemakai yang lebih banyak justru mempunyai skor lebih tinggi. Contoh ini tidak membuktikan manfaat maupun kerugian AI. Ia menunjukkan bahwa hubungan agregat dapat berubah ketika komposisi kelompok diperhatikan. Kemampuan awal dapat memengaruhi penggunaan dan hasil sekaligus.

Dalam inferensi kausal, pertanyaan utamanya bukan hanya apakah dua kolom bergerak bersama, melainkan bagaimana kelompok pembanding dapat mewakili keadaan tanpa perlakuan. Cunningham memberikan pengantar metode dan asumsi untuk pertanyaan sebab-akibat @cunningham2021. Untuk praktikum ini, tuliskan jalur yang diduga menghubungkan kemampuan awal, penggunaan AI, motivasi, dan skor sebelum memilih model statistik. Menambahkan banyak variabel ke regresi tidak otomatis menyelesaikan bias; pemilihan penyesuaian harus sesuai pertanyaan dan urutan waktunya.

== Pembersihan sebagai keputusan ilmiah
<pembersihan-sebagai-keputusan-ilmiah>
Jangan menghapus baris hanya karena nilainya mengganggu grafik. Periksa apakah nilai itu kesalahan input, pengukuran yang sah, atau kasus di luar populasi penelitian. Setiap aturan pembersihan dicatat dalam log beserta banyaknya baris yang terpengaruh. Simpan data mentah agar keputusan dapat ditinjau ulang. Praktik komputasi ilmiah yang baik menekankan pengorganisasian data, skrip, dan riwayat perubahan yang dapat dipahami kolaborator @wilson2017.

Setelah penggabungan tabel, periksa jumlah baris, keunikan kunci, dan kecocokan total yang seharusnya tetap. Jika tabel nilai mempunyai 80 mahasiswa tetapi hasil gabungan menjadi 480 baris, analisis harus berhenti sampai kardinalitas hubungan dipahami. Banyak baris dapat sah untuk analisis per pesan, tetapi tidak boleh langsung digunakan sebagai 480 observasi individu yang independen.

== Validasi model dan pelaporan ketidakpastian
<validasi-model-dan-pelaporan-ketidakpastian>
Jika tujuannya prediksi, pisahkan data pelatihan dan pengujian pada unit yang sesuai. Pesan dari mahasiswa yang sama tidak sebaiknya tersebar ke dua bagian ketika targetnya memprediksi pada mahasiswa baru, karena model mungkin mengenali ciri orang tersebut. Pemrosesan yang belajar dari data, seperti imputasi berbasis rata-rata, harus dipasang pada data pelatihan terlebih dahulu. Ini mengurangi kebocoran informasi dari pengujian.

Jika tujuannya membandingkan kelompok, tampilkan ukuran sampel, sebaran, besar perbedaan, dan ketidakpastian yang sesuai desain. Hasil yang tidak menunjukkan perbedaan jelas bukan bukti bahwa kedua strategi identik. Pertimbangkan apakah studi cukup informatif untuk mendeteksi perubahan yang bernilai secara pendidikan. Hindari menerjemahkan setiap angka desimal menjadi kesimpulan praktis.

== Latihan yang dapat direproduksi
<latihan-yang-dapat-direproduksi>
Gunakan tabel sintetis di atas untuk membuat scatterplot, kemudian beri penanda kemampuan awal. Jelaskan mengapa dua pembacaan dapat muncul. Tambahkan satu observasi sintetis dengan penggunaan AI tinggi dan kemampuan awal tinggi, lalu periksa apakah kesimpulan agregat berubah. Simpan seluruh versi data dan sebutkan bahwa perubahan tersebut merupakan eksperimen pemodelan.

Laporan akhir harus memisahkan apa yang dihitung, bagaimana hitungan diperoleh, dan apa yang dapat disimpulkan. Reproduksibilitas berarti orang lain dapat menghasilkan hitungan yang sama dari input dan prosedur yang sama. Validitas berarti hitungan tersebut benar-benar mendukung pertanyaan yang diajukan. Notebook yang berjalan tanpa kesalahan belum menjamin keduanya sekaligus.

= Tema 5 --- Visualization: Visual Knowledge Engineering
<tema-5-visualization-visual-knowledge-engineering>
#figure([
#box(image("tise-six-themes/images/tema-5-visualisasi.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-t5>


== Mengapa pengetahuan perlu divisualisasikan?
<mengapa-pengetahuan-perlu-divisualisasikan>
Pengetahuan dari gagasan, narasi, persamaan, atau data sering memuat banyak relasi. Visualisasi menyajikan #strong[proyeksi terpilih] ke bidang dua dimensi sehingga entitas, arah hubungan, proses, dan pola lebih mudah terlihat. Ini bukan berarti semua pengetahuan wajib direduksi ke dua dimensi; daftar satu dimensi, visual berlapis, dan interaksi juga berguna bila sesuai tujuan.

#strong[A:] mahasiswa memiliki gagasan tetapi belum dapat memodelkan dan memilih notasi visual yang cocok. #strong[B:] mahasiswa mampu membuat diagram yang benar, dapat diedit, dapat dipahami orang lain, dan sesuai struktur pengetahuan.

== Tiga keluarga dan satu pelengkap
<tiga-keluarga-dan-satu-pelengkap>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Keluarga], [Apa yang diperlihatkan], [Bahasa visual],),
  table.hline(),
  [Struktural], [Entitas, relasi, hierarki, ontologi], [Concept map, knowledge graph, UML class/component],
  [Temporal/fungsional], [Langkah, waktu, perubahan keadaan, keputusan], [Flowchart, timeline, state machine],
  [Struktur + proses], [Aktor dan interaksi sepanjang pekerjaan], [BPMN swimlane, UML sequence],
  [Kuantitatif], [Besaran, distribusi, perubahan], [Scatterplot, histogram, line chart, heatmap],
)
Bahasa visual dipilih berdasarkan pertanyaan, bukan berdasarkan perangkat lunak yang paling populer. UML merupakan bahasa/model notasi; draw.io adalah editor; Mermaid/Graphviz merupakan notasi dan perender teks; Python lazim dipakai untuk grafik numerik.

== Langkah pekerjaan S1--S7
<langkah-pekerjaan-s1s7>
S1 tentukan gagasan, pembaca, dan tujuan; S2 ekstraksi entitas/atribut/relasi/peristiwa; S3 tentukan perspektif; S4 pilih notasi dan semantik simbol; S5 gambar atau hasilkan dari teks; S6 periksa makna serta keterbacaan; S7 gunakan untuk penjelasan, diskusi, dan revisi.

== Kasus 1: AI yang tepat dalam dunia akademik
<kasus-1-ai-yang-tepat-dalam-dunia-akademik>
Satu sistem dapat dilihat dari beberapa perspektif.

#strong[Struktur/ontologi:] mahasiswa, dosen, tugas, AI, kebijakan, capaian belajar, hasil karya, dan hubungan antarentitas.

#figure([
#box(image("tise-six-themes/images/diagrams/06-tema5-visualisasi-1.svg", width: 85.0%))
], caption: figure.caption(
position: bottom, 
[
Diagram alur; label dan hubungan mengikuti definisi sumber.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


#strong[Proses:] mahasiswa mencoba sendiri, memperoleh petunjuk, dan hanya jika perlu mendelegasikan subpekerjaan yang sah; hasil ditinjau dan kompetensi diuji ulang.

#figure([
#box(image("tise-six-themes/images/diagrams/06-tema5-visualisasi-2.svg", height: 150mm))
], caption: figure.caption(
position: bottom, 
[
Diagram alur; label dan hubungan mengikuti definisi sumber.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


#strong[Interaksi:] sequence diagram menekankan kronologi pesan antara mahasiswa, chatbot, agen, dan pemeriksa. Diagram tersebut berfungsi berbeda dari peta struktur.

== Kasus 2: dari satu makalah jurnal menjadi tiga produk
<kasus-2-dari-satu-makalah-jurnal-menjadi-tiga-produk>
#strong[A:] makalah PDF dengan masalah, teori, metode, data, hasil dan kesimpulan. #strong[B:] #emph[Scientific Visual Communication Package] yang terdiri dari diagram konseptual/proses, infografik satu halaman, dan presentasi 6--10 slide.

Sasaran S1 baca paper; S2 ekstrak pengetahuan; S3 rekonstruksi perjalanan A→B, rute, kendaraan, mesin, teknologi; S4 tentukan satu atau beberapa pesan utama; S5 pilih bahasa visual; S6 buat produk; S7 verifikasi pada paper asli; S8 uji pemahaman audiens dan revisi.

#strong[Visual Knowledge Specification (VKS)] yang harus dibuat sebelum layout:

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Elemen paper], [Terjemahan visual], [Bukti sumber],),
  table.hline(),
  [Masalah → tujuan], [A→B], [Halaman dan paragraf],
  [Teori & definisi], [Peta konsep/ontologi], [Kutipan dan definisi],
  [Arsitektur], [Block diagram], [Diagram/teks metode],
  [Langkah eksperimen], [Flowchart], [Prosedur asli],
  [Hasil angka], [Grafik / tabel], [Data hasil yang valid],
  [Keterbatasan], [Catatan visual], [Discussion / limitations],
)
=== Contoh pembacaan paper TISE 1.0
<contoh-pembacaan-paper-tise-1.0>
Ringkasan proyek pada naskah awal mengaitkan TISE 1.0 dengan misi stakeholder, Resource--Mission--Output--Value, pertukaran PSKVE, pasar Mission/Bond/Share, PUDAL, dan multi-agent digital twin. Teks lengkap makalah tidak tersedia dalam direktori kerja saat edisi ini dikembangkan; karena itu uraian ini merupakan konteks proyek yang perlu diperiksa pada makalah asli sebelum dijadikan sumber tugas. Untuk praktikum langsung, gunakan artikel terbuka yang tersedia, misalnya Wilson dkk. @wilson2017, dan ekstrak pertanyaan, rekomendasi, contoh, serta batasannya dari sumber tersebut.

Untuk #strong[diagram], prioritaskan arsitektur konsep dan hubungan mekanismenya. Untuk #strong[infografik], tonjolkan masalah, konsep, komponen, bukti, keterbatasan. Untuk #strong[slide], rangkai cerita dari konteks, A→B, kontribusi, arsitektur, eksperimen, hasil, sampai implikasi dan keterbatasan. Angka pada hasil visual #strong[harus berasal dari paper], bukan dihasilkan ulang oleh AI.

== Aplikasi dan integrasi AI
<aplikasi-dan-integrasi-ai>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Perangkat], [Fungsi],),
  table.hline(),
  [#link("https://www.drawio.com/")[draw.io / diagrams.net]], [Menggambar serta mengedit diagram visual],
  [#link("https://mermaid.js.org/")[Mermaid]], [Flowchart/sequence/state dari kode teks],
  [#link("https://plantuml.com/")[PlantUML]], [Diagram UML berbasis bahasa teks],
  [#link("https://graphviz.org/")[Graphviz]], [Layout graf bahasa DOT],
  [#link("https://www.tldraw.com/")[tldraw]], [Sketsa bebas/kanvas kolaboratif],
  [#link("https://www.canva.com/")[Canva], #link("https://www.figma.com/")[Figma]], [Infografik dan desain presentasi],
  [Python Matplotlib/Plotly], [Grafik hasil data yang dapat direproduksi],
  [Quarto], [Menggabungkan teks, kode, gambar dan hasil ilmiah],
)
Secara umum, teks → diagram dapat dikerjakan dengan menulis Mermaid atau PlantUML, lalu ditempelkan ke editor yang mendukung. AI dapat menghasilkan teks notasi tersebut. Integrasi MCP memungkinkan asisten berinteraksi dengan aplikasi diagram #strong[jika] konektor tersedia dan pengguna memberinya izin; ketersediaan dan mekanisme login bergantung lingkungan, bukan syarat bawaan semua editor. Untuk draw.io, lihat #link("https://www.drawio.com/")[dokumentasi resmi].

== Tiga moda dan asesmen
<tiga-moda-dan-asesmen>
#strong[Alamiah:] sketsa di kertas atau editor. #strong[Chatbot:] minta saran visual dan kode diagram, tetap tinjau isinya. #strong[Agen:] delegasi konstruksi beberapa diagram, transformasi layout, dan pemeriksaan awal, lalu revisi oleh manusia.

#table(
  columns: 2,
  align: (auto,right,),
  table.header([Aspek], [Bobot],),
  table.hline(),
  [Ketepatan konsep dan sumber], [25%],
  [Pemilihan bahasa visual], [15%],
  [Ketepatan hubungan/proses], [20%],
  [Keterbacaan], [15%],
  [Penjelasan tanpa AI], [15%],
  [Validasi, dokumentasi dan etika], [10%],
)
#strong[Produk:] portofolio peta konsep, diagram struktural dan proses, infografik, slide, VKS, jejak validasi, dan refleksi penggunaan AI.

== Menetapkan kalimat yang harus dapat dibaca dari gambar
<menetapkan-kalimat-yang-harus-dapat-dibaca-dari-gambar>
Sebelum membuka editor, tuliskan satu kalimat tentang apa yang harus dipahami audiens. Kalimat "sistem ini mempunyai empat komponen yang saling bertukar informasi" membutuhkan gambar struktur. Kalimat "permohonan diperiksa sebelum disetujui" membutuhkan proses dan keputusan. Kalimat "skor berubah dari waktu ke waktu" membutuhkan grafik kuantitatif. Mencampur ketiganya dalam satu gambar sering membuat pembaca tidak mengetahui makna panah dan posisi.

Spesifikasi visual juga menentukan hal yang sengaja disederhanakan. Peta komponen dapat menghilangkan rincian algoritma, asalkan tidak menghapus hubungan yang diperlukan untuk memahami sistem. Setiap penyederhanaan mempunyai biaya: gambar lebih ringan, tetapi sebagian pertanyaan tidak dapat dijawab darinya. Nyatakan lingkup gambar pada judul atau keterangan agar audiens tidak menafsirkan kelengkapan yang tidak dimaksudkan.

== Semantik panah dan konsistensi representasi
<semantik-panah-dan-konsistensi-representasi>
Dalam peta konsep, panah berlabel "menggunakan" berarti relasi penggunaan. Dalam flowchart, panah biasanya menyatakan perpindahan kendali. Dalam grafik kausal, panah merupakan klaim tentang pengaruh. Bentuk yang sama tidak berarti makna yang sama. Karena itu, VKS perlu memuat kamus simbol dan aturan pembacaan. Jika satu diagram memerlukan lebih dari satu jenis relasi, bedakan dengan label dan legenda yang jelas.

Ambil contoh penggunaan AI dalam kelas. Hubungan "dosen menilai tugas" tidak boleh digambar seolah-olah "dosen menyebabkan mutu tinggi" tanpa dukungan. Demikian pula, garis antara frekuensi chatbot dan nilai bukan bukti sebab-akibat. Gambar mempunyai tanggung jawab epistemik yang sama dengan kalimat: ia perlu membedakan hubungan yang diamati, mekanisme yang diusulkan, dan hasil yang telah diuji.

== Mengomunikasikan angka tanpa menyembunyikan ketidakpastian
<mengomunikasikan-angka-tanpa-menyembunyikan-ketidakpastian>
Misalkan dua kelompok sintetis mempunyai rerata 72 dan 76. Dua batang dapat membuat selisih terlihat tegas, tetapi tidak memperlihatkan sebaran, ukuran sampel, atau variasi. Pilihan titik individual, boxplot, atau interval dapat memberi informasi tambahan, sesuai tujuan dan karakter data. Jika memakai error bar, jelaskan apakah ia menyatakan simpangan baku, standard error, atau interval kepercayaan; ketiganya tidak mempunyai arti yang sama.

Wilke membahas bagaimana pilihan representasi ketidakpastian memengaruhi penafsiran pembaca @wilke2019. Untuk praktik, sediakan tabel sumber di dekat visual agar pembaca dapat memeriksa angka. Periksa juga sumbu, satuan, titik nol, transformasi, dan pembulatan. Sumbu terpotong tidak selalu salah, tetapi harus jelas dan tidak mengubah kesan besar perbedaan secara menyesatkan.

Warna perlu mempunyai fungsi. Gunakan satu warna untuk satu makna yang konsisten, dan hindari menjadikan warna satu-satunya pembeda kategori. Label, bentuk, atau pola membantu pembaca yang mempunyai keterbatasan penglihatan warna maupun yang mencetak hitam-putih. Jika semua komponen diberi warna cerah berbeda, tidak ada penekanan yang membantu audiens menemukan pesan utama.

== Prosedur paper-to-visual yang dapat diaudit
<prosedur-paper-to-visual-yang-dapat-diaudit>
Mulailah dengan tabel ekstraksi: pertanyaan studi, populasi, metode, hasil utama, dan keterbatasan. Untuk setiap angka, tulis lokasi tabel atau paragraf asal. Kemudian tentukan apakah angka akan dipakai apa adanya atau dihitung ulang. Jika menghitung persentase dari tabel, simpan rumus dan penyebutnya. Jangan menggambar selisih persen sebagai selisih poin persentase tanpa penjelasan.

Setelah sketsa jadi, lakukan audit dua arah. Dari gambar menuju sumber, periksa asal setiap klaim. Dari sumber menuju gambar, periksa apakah keterbatasan penting terhapus. Misalnya, hasil simulasi tidak boleh tampil sebagai keberhasilan lapangan. Gambar yang menyatakan hubungan antarvariabel juga tidak boleh menghilangkan kondisi eksperimen yang membuat hubungan itu berlaku.

== Uji pembaca dan latihan revisi
<uji-pembaca-dan-latihan-revisi>
Berikan visual kepada pembaca yang belum mengetahui materinya. Minta ia menjelaskan pesan, urutan proses, dan satu batas kesimpulan. Catat bagian yang dibaca salah tanpa terlebih dahulu mengarahkannya. Jika pembaca mengikuti panah dalam urutan keliru, masalahnya mungkin tata letak atau label, bukan kurangnya pengetahuan pembaca. Revisi lalu uji kembali dengan pertanyaan yang sama.

Sebagai latihan, ambil satu gambar yang mempunyai sedikitnya lima relasi. Tulis seluruh relasi dalam kalimat. Jika kalimatnya ambigu, perbaiki model sebelum memperbaiki warna. Jika kalimat sudah tepat tetapi pembaca masih salah memahami, perbaiki penyajiannya. Perbedaan diagnosis ini membantu peserta memisahkan kesalahan pengetahuan dari kesalahan komunikasi visual.

= Tema 6 --- Problem Solving: Mahasiswa, Akademik, dan Industri
<tema-6-problem-solving-mahasiswa-akademik-dan-industri>
#figure([
#box(image("tise-six-themes/images/tema-6-problem-solving.png", width: 100.0%))
], caption: figure.caption(
separator: "", 
position: bottom, 
[
#block[
]
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)
<fig-t6>


== Satu kasus, tiga misi yang tidak selalu selaras
<satu-kasus-tiga-misi-yang-tidak-selalu-selaras>
Tema 6 menjadi tugas integratif dari Tema 1--5. Persoalannya bukan soal dengan satu angka benar, melainkan menyelaraskan #strong[aspirasi dan kemandirian mahasiswa], #strong[kewajiban mutu/kurikulum/akreditasi program studi], serta #strong[kebutuhan kompetensi dan produktivitas industri].

#strong[A:] potensi mahasiswa, capaian pembelajaran lulusan (CPL), dan tuntutan kerja berada dalam sistem yang belum selaras. #strong[B:] rute belajar dan proyek personal yang bermakna, memenuhi CPL dan aturan akademik, serta menghasilkan kompetensi/portofolio kerja yang dapat diuji---dengan dampak etis dan berkelanjutan.

Generasi Z tidak boleh diperlakukan sebagai kelompok homogen. Profil aspirasi harus berasal dari diagnosis peserta, bukan stereotip generasi.

== Stakeholder dan persyaratan
<stakeholder-dan-persyaratan>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Pihak], [Misi / kepentingan], [Bukti yang dibutuhkan],),
  table.hline(),
  [Mahasiswa], [Ekspresi diri, kreativitas, kompetensi, otonomi], [Portofolio, refleksi, tes mandiri, kebebasan memilih],
  [Program studi], [CPL, integritas, standar akademik, akreditasi], [Matriks CPL--aktivitas--asesmen, rubrik, audit],
  [Industri], [Kompetensi, adaptabilitas, kolaborasi, mutu kerja], [Tugas kerja autentik, dokumentasi dan evaluasi mitra],
)
Persyaratan standar wajib dipisahkan dari preferensi yang bisa dinegosiasikan. AI tidak boleh mengesahkan pemenuhan akreditasi atau merekrut seseorang tanpa otorisasi manusia yang berwenang.

== Sasaran antara S1--S8
<sasaran-antara-s1s8>
+ Definisikan masalah dan ketiga stakeholder.
+ Ukur aspirasi, kompetensi, kapasitas dan energi mahasiswa.
+ Petakan CPL, batasan program dan kebutuhan industri.
+ Susun alternatif rute/proyek yang berbeda.
+ Evaluasi alternatif menurut banyak tujuan dan batas keras.
+ Laksanakan proyek melalui moda bantuan yang disetujui.
+ Uji CPL, mutu pekerjaan, serta kemampuan tanpa AI.
+ Refleksi dan perbaiki rute.

== Empat rute penyelesaian
<empat-rute-penyelesaian>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Alternatif], [Kelebihan], [Risiko],),
  table.hline(),
  [R1 Kurikulum konvensional], [Standar yang jelas, relatif mudah distandarkan], [Kurang sesuai minat individu],
  [R2 Proyek pilihan mahasiswa], [Motivasi, ekspresi diri], [CPL dapat tidak tercakup],
  [R3 Tantangan industri], [Keaslian pekerjaan, relevansi], [Ruang eksplorasi personal terbatas],
  [R4 TISE adaptif berbantuan AI], [Mencari keselarasan ketiganya], [Butuh data, tata kelola dan validasi kuat],
)
R4 adalah #strong[kandidat], bukan pemenang yang telah dibuktikan. Penilaian memakai kendala wajib terlebih dahulu, kemudian membandingkan solusi layak menurut mutu, risiko, biaya, otonomi, dan kompetensi kerja.

== Ilustrasi mahasiswa fiktif
<ilustrasi-mahasiswa-fiktif>
Dewa, seorang mahasiswa teknologi informasi, berminat pada konten kreatif, narasi, desain dan AI. Program studi memerlukan bukti pemrograman, data, rekayasa perangkat lunak, komunikasi, kerja tim dan etika; mitra industri ingin produk yang diuji dan didokumentasikan.

#strong[Usulan proyek integratif:] #emph[AI-Assisted Creative Learning Platform] yang membantu pengguna mengubah materi kuliah menjadi penjelasan, visualisasi dan latihan interaktif terverifikasi. Produk ini memberi ruang kreativitas Dewa, artefak untuk asesmen CPL, dan demonstrasi kemampuan pengembangan produk. Kesesuaiannya #strong[tidak otomatis]: pengajar dan industri harus memeriksa bukti aktual.

#figure([
#box(image("tise-six-themes/images/diagrams/07-tema6-problem-solving-1.svg", width: 85.0%))
], caption: figure.caption(
position: bottom, 
[
Diagram alur; label dan hubungan mengikuti definisi sumber.
]), 
kind: "quarto-float-fig", 
supplement: "Gambar", 
)


== Peran AI di tiga moda
<peran-ai-di-tiga-moda>
#strong[Alamiah:] dialog stakeholder, brainstorming, merancang proyek, menghitung trade-off. #strong[Chatbot:] menguji asumsi, menyusun matriks kompetensi, menilai argumen dan opsi. #strong[Agen:] dengan persetujuan dan izin, mengolah peta kompetensi, simulasi jadwal serta skenario, menyiapkan draf proyek dan dokumentasi; keputusan tetap dikendalikan manusia.

== Metrik yang memenuhi ketiga kepentingan
<metrik-yang-memenuhi-ketiga-kepentingan>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([Kelompok], [Ukuran yang diusulkan],),
  table.hline(),
  [Mahasiswa], [Otonomi, motivasi, kreativitas, pengetahuan dan transfer mandiri],
  [Akademik], [Cakupan dan pencapaian CPL, validitas asesmen, integritas, efisiensi],
  [Industri], [Kualitas produk, keterampilan autentik, kolaborasi, adaptabilitas],
  [Lintas kelompok], [Biaya, waktu, akses adil, privasi, keselamatan, keberlanjutan],
)
Untuk menghindari #emph[false equivalence] antarskor, tampilkan profil multidimensi dan syarat minimum. Suatu solusi tidak menjadi layak hanya karena skor kelompok lain menutup pelanggaran standar wajib.

== Rancangan pembandingan dan produk akhir
<rancangan-pembandingan-dan-produk-akhir>
Bandingkan R1--R4 melalui kelompok atau proyek yang sebanding, pretest, posttest, evaluasi CPL, asesmen mitra, produk kerja nyata, serta tes transfer tanpa AI. Laporan harus menjelaskan perbedaan konteks dan keterbatasan inferensi kausal.

#strong[Produk:] peta masalah A--B, kebutuhan/kendala stakeholder, matriks konflik, alternatif rute, rancangan proyek, prototipe/simulasi, pemetaan CPL, asesmen multi-pihak, refleksi dan jejak bantuan AI.

#table(
  columns: 2,
  align: (auto,right,),
  table.header([Rubrik], [Bobot],),
  table.hline(),
  [Masalah dan stakeholder], [20%],
  [Kebutuhan, kapasitas, konflik], [15%],
  [Alternatif serta rancangan], [20%],
  [Pemanfaatan AI dan implementasi], [15%],
  [Evaluasi dan validasi], [20%],
  [Etika, refleksi, kemandirian], [10%],
)
== Mendengarkan kebutuhan sebelum menawarkan platform
<mendengarkan-kebutuhan-sebelum-menawarkan-platform>
Persoalan multipihak sering dimulai dengan usulan solusi: "buat aplikasi agar mahasiswa siap kerja." Usulan itu perlu dibuka kembali menjadi kebutuhan. Mahasiswa mungkin membutuhkan kesempatan mencoba peran, dosen membutuhkan bukti kompetensi, dan industri membutuhkan demonstrasi kerja pada batas waktu tertentu. Aplikasi merupakan salah satu kemungkinan sarana. Wawancara singkat, observasi pekerjaan, dan contoh kegagalan yang dialami tiap pihak membantu menemukan masalah yang benar-benar akan ditangani.

Dalam kasus Dewa, dosen meminta demonstrasi pemrograman mandiri, sedangkan Dewa ingin menghasilkan konten kreatif dan mitra meminta produk yang stabil. Tiga kebutuhan tersebut dapat ditampung dalam proyek yang sama apabila pembagian kerjanya jelas. Namun, jika seluruh kode diserahkan kepada agen tanpa pemahaman, portofolio yang terlihat menarik belum membuktikan kompetensi pemrograman. Karena itu, proses perundingan harus menentukan bagian mana yang menjadi produk tim dan bagian mana yang menjadi bukti kemampuan individu.

== Menyaring kelayakan sebelum memberi skor
<menyaring-kelayakan-sebelum-memberi-skor>
Tentukan batas keras terlebih dahulu: aturan akademik, keamanan data, waktu, biaya maksimum, dan capaian minimum. Kandidat yang melanggar batas ini tidak masuk pembobotan preferensi. Setelah itu barulah nilai kesesuaian minat, manfaat mitra, peluang belajar, dan keterpeliharaan. Analisis keputusan dalam rekayasa sistem membantu menata perbandingan alternatif dan bukti pemenuhan kebutuhan @nasa2016. Adaptasi untuk proyek mahasiswa di sini memakai skala sederhana agar asumsi dapat dibahas.

Contoh berikut memakai skor hipotetis 1--5; semua opsi diasumsikan telah melewati batas keras. Bobot minat 0,30, cakupan kompetensi 0,40, dan manfaat mitra 0,30.

#table(
  columns: 5,
  align: (auto,right,right,right,right,),
  table.header([Proyek], [Minat], [Kompetensi], [Manfaat mitra], [Skor berbobot],),
  table.hline(),
  [Portofolio kreatif pribadi], [5], [3], [2], [3,30],
  [Analitik kebutuhan mitra], [3], [5], [4], [4,10],
  [Platform belajar kreatif], [5], [4], [4], [4,30],
)
Platform belajar unggul pada bobot tersebut, tetapi hasilnya bergantung pada penilaian dan bobot yang dipilih. Jika manfaat mitra diberi bobot 0,60, kompetensi 0,30, dan minat 0,10, analitik memperoleh 4,20 sedangkan platform 4,10. Perubahan pemenang menunjukkan perlunya percakapan tentang prioritas, bukan alasan untuk menyembunyikan bobot. Tidak ada angka dalam tabel ini yang merupakan evaluasi proyek nyata.

== Memecah proyek menjadi bukti yang dapat diuji
<memecah-proyek-menjadi-bukti-yang-dapat-diuji>
Untuk platform Dewa, milestone pertama dapat berupa satu materi yang diubah menjadi penjelasan dan latihan yang telah diperiksa dosen. Milestone kedua berupa prototipe yang bisa dipakai pengguna baru tanpa penjelasan pengembang. Milestone ketiga berupa demonstrasi bahwa Dewa dapat menjelaskan dan memperbaiki bagian kode yang dipilih reviewer. Ketiga milestone menilai objek berbeda: ketepatan isi, keterpakaian produk, dan kompetensi individu.

Sertakan skenario gagal. Apa yang terjadi jika materi sumber tidak cukup, AI menghasilkan soal salah, atau pengguna mengira penjelasan sebagai sumber resmi? Jawaban desain dapat berupa penanda status sumber, pemeriksaan contoh soal, dan jalur pelaporan kesalahan. Setiap tindakan membutuhkan penanggung jawab. Daftar risiko yang tidak mengubah proses kerja tidak banyak membantu.

== Mengelola konflik tanpa menyerahkan nilai kepada AI
<mengelola-konflik-tanpa-menyerahkan-nilai-kepada-ai>
AI dapat merangkum aspirasi dan menyusun alternatif, tetapi tidak menentukan nilai siapa yang harus didahulukan. Jika mitra meminta penggunaan data pelanggan yang tidak tersedia izinnya, tingginya manfaat bisnis tidak menghapus kendala akses. Jika Dewa menginginkan desain kreatif yang menyisakan sedikit waktu untuk cakupan kompetensi, tim dapat mengurangi fitur atau mengubah lingkup demonstrasi. Keputusan demikian memerlukan perundingan manusia yang mencatat alasan dan konsekuensi.

Tinjauan proyek perlu memperlihatkan kelompok mana yang menanggung biaya dan menerima manfaat. Solusi yang menghemat waktu pengelola dengan membebani pengguna tambahan pekerjaan belum tentu perbaikan keseluruhan. Gunakan profil hasil per pihak, lalu diskusikan trade-off secara terbuka.

== Latihan keputusan dan evaluasi setelah pelaksanaan
<latihan-keputusan-dan-evaluasi-setelah-pelaksanaan>
Pilih satu opsi dalam tabel dan ubah satu asumsi: waktu berkurang setengah, data mitra tidak tersedia, atau kompetensi awal peserta lebih rendah. Susun rute pengganti beserta hasil yang tetap harus dijaga. Jawaban yang baik menyebut apa yang dikurangi, bukti yang masih tersedia, dan alasan rute baru layak.

Sesudah proyek selesai, bandingkan keputusan awal dengan kondisi aktual. Jika produk diterima tetapi peserta gagal menjelaskan metode, nyatakan kedua hasil tersebut secara terpisah. Jika kompetensi meningkat tetapi produk belum stabil, proyek dapat mempunyai nilai pendidikan sekaligus membutuhkan perbaikan teknis. Evaluasi multidimensi membuat hasil seperti ini terlihat dan menjadi dasar rute berikutnya.

= Implementasi Program dan Evaluasi Lintas Tema
<implementasi-program-dan-evaluasi-lintas-tema>
== Arsitektur program
<arsitektur-program>
Enam tema disusun sebagai perjalanan kompetensi, bukan enam pulau yang tidak berhubungan. #strong[Learning] melatih penguasaan konsep; #strong[Literature Study] memetakan pengetahuan; #strong[Academic Writing] mempertahankan gagasan; #strong[Computational Literacy] mengolah bukti; #strong[Visualization] membangun representasi bersama; #strong[Problem Solving] mengintegrasikannya pada persoalan multipihak.

== Urutan pelaksanaan yang diusulkan
<urutan-pelaksanaan-yang-diusulkan>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Tahap], [Kegiatan pembelajaran], [Bukti],),
  table.hline(),
  [Diagnosis], [Profil awal, A/B, kapasitas dan kebutuhan], [Pretest dan Task Journey Card],
  [Praktik mandiri], [Kinerja awal tanpa AI], [Draf dan catatan kesulitan],
  [Tutor chatbot], [Petunjuk dan umpan balik], [Riwayat bantuan yang relevan],
  [Delegasi agen], [Subtugas dengan batasan jelas], [Produk, jejak alat dan verifikasi],
  [Validasi], [Rubrik, tes tanpa AI, audit sumber], [Skor tugas serta kompetensi],
  [Refleksi dan transfer], [Tantangan baru, bantuan berkurang], [Retensi dan transfer],
)
== Evidence model
<evidence-model>
Pisahkan #strong[kinerja tugas] dari #strong[pembelajaran]. Gunakan skor rubrik, waktu, biaya dan kesalahan untuk hasil tugas; gunakan pre/post, tes tertunda, transfer, penalaran tanpa AI dan kemampuan memperbaiki kesalahan untuk pembelajaran. Jangan memberi skor tunggal yang menyembunyikan kegagalan pada salah satu dimensi.

== Matriks ringkasan portofolio
<matriks-ringkasan-portofolio>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Tema], [Bukti hasil], [Bukti pembelajaran],),
  table.hline(),
  [1], [Perhitungan Bayes dan tabel benar], [Menjelaskan dan menjawab kasus baru],
  [2], [SoTA lima lapisan dan gap berbukti], [Menafsirkan serta mengkritik artikel],
  [3], [Esai dan matriks klaim--bukti], [Mempertahankan tesis tanpa AI],
  [4], [Notebook, model, laporan], [Memperbaiki analisis dan menjelaskan batas inferensi],
  [5], [Diagram, infografik, slide], [Memilih notasi, mengkritik diagram salah],
  [6], [Solusi dan evaluasi multi-pihak], [Transfer lintas domain, negosiasi alasan],
)
== Kecakapan AI yang perlu dibiasakan
<kecakapan-ai-yang-perlu-dibiasakan>
+ Tulis tujuan dan batas mandat sebelum meminta AI bekerja.
+ Pisahkan sumber primer dari ringkasan/interpretasi AI.
+ Simpan provenance untuk angka, kutipan dan data.
+ Periksa hasil pada sumber atau eksperimen yang dapat diulang.
+ Hentikan otomatisasi yang melanggar kebijakan akademik, privasi atau izin pemilik data.
+ Gunakan #emph[teach-back] dan tes tanpa bantuan untuk membedakan output dan belajar.
+ Kurangi bantuan setelah kemampuan meningkat.

== Usulan metode evaluasi program
<usulan-metode-evaluasi-program>
Penelitian implementasi dapat membandingkan tiga moda serta pendekatan adaptif dengan desain yang sebanding; pada beberapa tugas desain #emph[within-subject] atau crossover lebih masuk akal, pada tugas lain pengacakan kelompok diperlukan. Pilihan desain bergantung pada efek urutan, kontaminasi, ketersediaan alat, dan persetujuan partisipan.

Indikator utama: kualitas produk, kemampuan mandiri, retensi, transfer. Indikator sekunder: waktu, biaya, kepercayaan yang terkalibrasi, beban kognitif, integritas, dan kepuasan. Evaluasi tidak boleh mengklaim #emph[AI meningkatkan kognisi] jika hanya mengamati korelasi frekuensi penggunaan dengan nilai.

== Tahap pengembangan platform TISE
<tahap-pengembangan-platform-tise>
Mulai dari template manual dan notebook; lanjutkan chatbot yang dibatasi sumber dan rubrik; baru berikutnya gunakan agen dengan peran #emph[planner, tutor, executor, critic, assessor]. Pada tahap awal agen hanya merekomendasikan keputusan (#emph[shadow mode]); tindakan eksternal memerlukan izin, audit dan mekanisme pembatalan.

== Merancang satu siklus perkuliahan yang realistis
<merancang-satu-siklus-perkuliahan-yang-realistis>
Implementasi dimulai dari jumlah pertemuan, kemampuan awal, fasilitas, dan aturan mata kuliah. Keenam tema tidak harus diberi waktu sama. Kelas yang sudah terbiasa menulis kode mungkin memerlukan lebih banyak latihan membaca hasil penelitian; kelas dengan latar belakang beragam mungkin perlu pengantar data sebelum analisis. Diagnosis awal menentukan penyesuaian ini, sementara keluaran minimum menjaga arah program tetap sama.

Sebagai skenario rancangan, satu tema dapat memakai tiga pertemuan: diagnosis dan contoh terbimbing, praktik dengan bantuan yang dicatat, lalu demonstrasi mandiri dan refleksi. Tugas lintas tema dikerjakan sesudah peserta mempunyai prasyarat. Jadwal tersebut bukan resep yang telah diuji untuk semua kelas; dosen perlu menilai beban kerja dan memberi ruang revisi.

Prinsip keselarasan tujuan, kegiatan, dan asesmen @cmu-alignment membantu memeriksa setiap pertemuan. Jika tujuan menyebut "mengkritik klaim kausal", kegiatan harus memberi contoh klaim yang perlu dikritik dan asesmen harus meminta alasan kritik. Mengganti asesmen itu dengan kuis istilah hanya mengukur sebagian prasyaratnya.

== Mengubah rubrik menjadi keputusan penilaian
<mengubah-rubrik-menjadi-keputusan-penilaian>
Rubrik perlu mendeskripsikan perilaku yang terlihat. Untuk ketepatan sumber, tingkat awal berarti klaim utama belum dapat dilacak; tingkat berkembang berarti sumber tersedia tetapi hubungan dengan klaim masih lemah; tingkat memadai berarti klaim dan lokasi bukti cocok; tingkat kuat berarti penulis juga menjelaskan keterbatasan dan perbedaan bukti. Deskripsi seperti "sangat baik" tanpa indikator sulit dipakai oleh dua penilai secara konsisten.

Sebelum menilai seluruh portofolio, dua penilai dapat mencoba beberapa contoh yang sama. Bahas perbedaan skor dengan merujuk pada bukti, lalu perjelas deskripsi rubrik. Jika satu penilai mengutamakan bahasa dan yang lain mengutamakan metode, keduanya perlu kembali pada tujuan tugas. Simpan contoh jangkar untuk menunjukkan batas antartingkat.

== Bukti individual di dalam kerja kolaboratif
<bukti-individual-di-dalam-kerja-kolaboratif>
Produk tim perlu dilengkapi demonstrasi individu. Pilih satu bagian penting secara acak untuk dijelaskan, minta peserta memperbaiki kesalahan kecil, atau berikan kasus baru yang strukturnya serupa. Bentuk ini menilai pemahaman dengan lebih langsung daripada menghitung jumlah pesan atau commit. Jejak kontribusi tetap berguna untuk menelusuri proses, tetapi kualitas kontribusi tidak selalu sebanding dengan volumenya.

Gunakan ledger bantuan AI secukupnya: tujuan bantuan, bagian yang dihasilkan, pemeriksaan yang dilakukan, dan pelajaran yang diperoleh. Tidak semua percakapan pribadi harus dikumpulkan. Jika riwayat diperlukan untuk asesmen, jelaskan tujuan, akses, dan masa penyimpanannya. Peserta juga perlu mengetahui bentuk bantuan yang dibolehkan pada setiap tahap.

== Membaca hasil pilot tanpa klaim berlebihan
<membaca-hasil-pilot-tanpa-klaim-berlebihan>
Misalkan pada pilot sintetis rerata kelas naik dari 55 menjadi 70. Perubahan itu dapat mencerminkan latihan, pengajaran, perbedaan soal, bantuan AI, atau gabungannya. Pretest--posttest satu kelompok tidak cukup memisahkan pengaruh tersebut. Kelompok pembanding dan penetapan perlakuan yang jelas memperkuat interpretasi, tetapi masih perlu pemeriksaan perbedaan awal, kontaminasi, dan peserta yang tidak menyelesaikan studi @cunningham2021.

Untuk pilot kecil, pertanyaan kelayakan sering lebih tepat: apakah peserta memahami instruksi, apakah waktu cukup, apakah instrumen membedakan tingkat kemampuan, dan apakah log dapat digunakan? Temuan seperti "sebagian besar peserta tidak memahami tes transfer" mengarahkan revisi instrumen sebelum penelitian efektivitas yang lebih besar. Jangan mengubah pilot kelayakan menjadi klaim peningkatan kognitif universal.

== Akses yang adil dan siklus perbaikan program
<akses-yang-adil-dan-siklus-perbaikan-program>
Sediakan jalur yang tidak bergantung pada akun premium, misalnya materi cetak, contoh percakapan yang disediakan pengajar, atau alat lokal yang tersedia. Kesetaraan tidak selalu berarti semua peserta memakai alat identik; yang perlu dijaga ialah kesempatan mencapai tujuan dan menunjukkan kompetensi dengan standar yang sama. Pedoman UNESCO memberi konteks bagi perhatian terhadap akses dan kepentingan peserta @unesco-genai.

Pada akhir siklus, pilih perbaikan yang ditopang bukti. Jika peserta sudah dapat menghitung tetapi belum menafsirkan, ubah kegiatan interpretasi. Jika penilai tidak sepakat, perbaiki rubrik. Jika tugas terlalu berat, kurangi cakupan sebelum mengurangi mutu pemeriksaan. Catatan keputusan ini membuat implementasi berikutnya berkembang dari pengalaman yang dapat ditelusuri.

= Template Kerja dan Formulir Praktikum
<template-kerja-dan-formulir-praktikum>
Di bawah ini disediakan format yang dapat disalin untuk tugas baru.

== Template A --- Task Journey Card
<template-a-task-journey-card>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Komponen], [Isian peserta],),
  table.hline(),
  [Tema dan pertanyaan], […],
  [Titik A], […],
  [Titik B dan kondisi lulus], […],
  [Sasaran antara S1--Sn], […],
  [Rute alamiah], […],
  [Instrumen chatbot], […],
  [Delegasi agen dan batas mandat], […],
  [Kapasitas, energi, waktu, sumber daya], […],
  [Risiko dan tata kelola], […],
  [Hasil pekerjaan dan bukti], […],
  [Hasil belajar dan bukti], […],
)
== Template B --- Research Journey Card (Tema 2)
<template-b-research-journey-card-tema-2>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([Elemen], [Bukti artikel], [Interpretasi peserta],),
  table.hline(),
  [DOI, penulis, tahun], […], […],
  [A / masalah awal], […], […],
  [B / target], […], […],
  [Rute dan sasaran antara], […], […],
  [L5 Ekosistem], […], […],
  [L4 Rute dan kendaraan], […], […],
  [L3 Arsitektur], […], […],
  [L2 Mesin], […], […],
  [L1 Energi dan teknologi], […], […],
  [Metrik, instrumen, protokol], […], […],
  [Hasil dan keterbatasan], […], […],
  [Kandidat gap (belum terverifikasi?)], […], […],
)
== Template C --- Research Evaluation Contract
<template-c-research-evaluation-contract>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([Komponen], [Definisi],),
  table.hline(),
  [Pertanyaan penelitian], […],
  [Baseline pembanding], […],
  [Metrik utama], […],
  [Metrik sekunder], […],
  [Instrumen pengukuran], […],
  [Dataset/populasi dan izin], […],
  [Kondisi/skenario uji], […],
  [Ambang keberhasilan dan batas minimum], […],
  [Ketidakpastian serta analisis statistik], […],
  [Keterbatasan klaim], […],
)
== Template D --- Matriks klaim dan bukti (Tema 3)
<template-d-matriks-klaim-dan-bukti-tema-3>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Klaim], [Bukti utama], [Mengapa mendukung], [Keberatan dan batasan], [Status verifikasi],),
  table.hline(),
  […], […], […], […], […],
)
== Template E --- Visual Knowledge Specification (Tema 5)
<template-e-visual-knowledge-specification-tema-5>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Elemen visual], [Semantik], [Bukti sumber], [Bentuk/notasi], [Sudah dicek?],),
  table.hline(),
  […], […], […], […], […],
)
== Template F --- AI Assistance Ledger
<template-f-ai-assistance-ledger>
#table(
  columns: (14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%),
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([Waktu], [Tujuan], [Moda], [Instruksi/delegasi], [Keluaran], [Verifikasi manusia], [Pembelajaran],),
  table.hline(),
  […], […], […], […], […], […], […],
)
== Template G --- Refleksi
<template-g-refleksi>
Tuliskan: (1) apa yang awalnya tidak dapat saya lakukan; (2) apa yang sekarang dapat saya lakukan tanpa AI; (3) pekerjaan apa yang saya delegasikan, dan mengapa; (4) jawaban AI mana yang saya koreksi; (5) bagaimana saya memastikan integritas karya; (6) apa rute berikutnya untuk memperbaiki kompetensi saya.

== Menggunakan formulir sebagai alat berpikir
<menggunakan-formulir-sebagai-alat-berpikir>
Template berguna ketika membantu peserta menemukan informasi yang belum jelas. Ia kehilangan fungsi jika setiap kolom diisi kalimat umum hanya agar tampak lengkap. Mulailah dari satu kasus, isi bagian yang benar-benar diketahui, lalu tandai pertanyaan yang membutuhkan diagnosis atau pencarian sumber. Keterangan "belum diketahui; akan diperiksa melalui pretest" lebih informatif daripada "kemampuan cukup baik" tanpa bukti.

Formulir perlu saling terhubung. Tujuan B pada Task Journey Card harus cocok dengan metrik dalam Evaluation Contract. Klaim esai perlu menunjuk pada Research Journey Card atau sumber lain yang tercatat. Elemen dalam VKS harus mengacu pada angka atau hubungan yang telah diperiksa. Ledger bantuan menghubungkan penggunaan AI dengan perubahan artefak. Keterhubungan ini memungkinkan reviewer mengikuti satu kesimpulan dari tujuan sampai bukti.

== Contoh pengisian lintas formulir
<contoh-pengisian-lintas-formulir>
Ambil kasus pembelajaran Bayes. Pada Template A, A ditulis "peserta menggunakan 90% sebagai peluang sakit setelah positif pada soal diagnosis awal." B ditulis "peserta menentukan penyebut yang benar dan menyelesaikan kasus baru tanpa petunjuk." Pernyataan tersebut lebih operasional daripada "memahami Bayes" karena menunjuk perilaku yang dapat diamati.

Pada Template C, instrumen berupa dua soal ekuivalen dengan konteks berbeda dan permintaan menjelaskan penyebut. Metrik utama adalah ketepatan penalaran, sedangkan waktu dicatat sebagai indikator tambahan. Ambang ilustratif dapat mensyaratkan penyebut, tabel, dan penafsiran benar; ambang ini harus ditetapkan pengajar sebelum pemeriksaan, bukan dipilih setelah melihat hasil. Prinsip keselarasan membantu menjaga hubungan tujuan dan instrumen @cmu-alignment.

Pada Template F, satu baris dapat berbunyi: "meminta petunjuk tentang ruang sampel; chatbot bertanya siapa yang termasuk kelompok positif; peserta memperbaiki tabel; diperiksa dengan hitung ulang manual." Bagian pembelajaran menyebut perubahan yang dialami peserta, bukan kualitas bahasa jawaban chatbot. Pada Template G, peserta menjelaskan mengapa ia semula memilih penyebut keliru dan bagaimana kesalahan itu dapat dikenali pada kasus spam.

== Contoh matriks klaim--bukti yang telah diisi
<contoh-matriks-klaimbukti-yang-telah-diisi>
#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([Klaim], [Bukti], [Hubungan penalaran], [Batasan], [Status],),
  table.hline(),
  [Tes berbantuan belum cukup membuktikan kemandirian], [Peserta menyelesaikan latihan dengan petunjuk tetapi belum mengerjakan soal transfer], [Kondisi bantuan berbeda dari kompetensi yang ingin disimpulkan], [Ini diagnosis satu kegiatan, bukan efek kausal AI], [Perlu tes mandiri],
  [Pada parameter Bayes bab ini, posterior positif 15,38%], [90 positif benar dan 495 positif palsu], [Penyebut berisi seluruh hasil positif], [Parameter hipotetis], [Hitungan diperiksa],
)
Tabel menunjukkan bahwa status verifikasi dapat berbeda antarjenis klaim. Sebuah hitungan dapat sudah diperiksa, sementara kesimpulan tentang kemampuan masih memerlukan pengukuran. Hindari satu tanda centang global untuk seluruh laporan apabila komponennya mempunyai dasar bukti berbeda.

== Mengelola versi dan perubahan keputusan
<mengelola-versi-dan-perubahan-keputusan>
Berikan identitas kasus, tanggal, penyusun, dan nomor versi pada paket formulir. Ketika tujuan berubah, catat alasan dan dampaknya pada rubrik, jadwal, serta produk. Jangan mengganti B diam-diam agar hasil yang sudah ada tampak berhasil. Pembaruan yang sah menunjukkan perubahan kebutuhan atau bukti, sekaligus mempertahankan jejak definisi sebelumnya.

Pisahkan data sumber, olahan, dan laporan. Jika informasi sensitif tidak dapat dibagikan, sediakan deskripsi akses dan contoh sintetis yang cukup untuk memahami prosedur. Prinsip FAIR membantu memikirkan ketercarian, akses, interoperabilitas, dan penggunaan ulang @fair2016\; FAIR tidak mengharuskan setiap data menjadi publik. Struktur pencatatan harus sesuai izin dan kebutuhan audit.

== Latihan review berpasangan
<latihan-review-berpasangan>
Tukar paket formulir dengan rekan. Reviewer memilih satu klaim hasil, mencari bukti, memeriksa kecocokannya dengan B, lalu menyebut informasi yang hilang. Penyusun memperbaiki satu hubungan yang putus sebelum menambah uraian baru. Kegiatan selesai ketika reviewer dapat menjelaskan mengapa hasil dinilai tercapai atau belum tercapai tanpa meminta penjelasan tambahan dari penyusun.

Kesalahan yang sering muncul adalah menyebut alat sebagai tujuan, frekuensi kegiatan sebagai kompetensi, dan prompt sebagai bukti kebenaran. Perbaikannya selalu kembali ke perubahan keadaan yang dapat diamati. Template yang matang menyimpan keputusan dan bukti yang membuat pekerjaan dapat dilanjutkan orang lain, sekaligus memberi peserta bahan untuk memahami perkembangan kemampuannya sendiri.

= Referensi dan Sumber Pengembangan
<referensi-dan-sumber-pengembangan>
== Literatur dan kerangka proyek
<literatur-dan-kerangka-proyek>
Buku ini disusun berdasarkan diskusi proyek mengenai enam tema dan dokumen TISE berikut yang disediakan sebagai materi proyek:

- Langi, A. Z. R. (2026). #emph[TISE 1.0: A Sustainability-Constrained Model for Mission-Oriented Ecosystems Under Changing Conditions.]
- Langi, A. Z. R. (2026). #emph[TISE 2.0: Co-Learning Mission-Oriented Ecosystems with a Capability-Gated Learning Index.]
- Langi, A. Z. R. (2026). #emph[TISE 3.0: A Governed Startup Creator for Mission-Oriented Ecosystems.]
- Langi, A. Z. R. (2026). #emph[TISE, the Q-Cycle, and the Digital-Twin Research Method: A Conceptual Explanation and Ongoing Research Agenda.]
- Langi, A. Z. R. #emph[Rekayasa Cerdas Multi-Kawasan: Kompilasi] (kumpulan naskah, termasuk metafora transportasi, instrumen, dan engine).

== Dokumentasi dan sumber eksternal yang dapat diperiksa
<dokumentasi-dan-sumber-eksternal-yang-dapat-diperiksa>
- #link("https://quarto.org/docs/books/")[Quarto: Creating a Book] --- struktur dan format proyek buku.
- #link("https://quarto.org/docs/extensions/listing-formats.html")[Quarto: Extension Formats Listing] --- katalog ekstensi format; bukan satu template buku.
- #link("https://quarto.org/docs/websites/website-listings.html")[Quarto: Document Listings] --- bila ingin membangun katalog modul lanjutan.
- #link("https://unesdoc.unesco.org/ark:/48223/pf0000386693")[UNESCO: Guidance for generative AI in education and research] --- landasan penggunaan AI secara human-centered.
- #link("https://www.unesco.org/en/artificial-intelligence/recommendation-ethics")[UNESCO: Recommendation on the Ethics of Artificial Intelligence] --- prinsip hak, privasi, keadilan, dan tata kelola.
- #link("https://www.nist.gov/itl/ai-risk-management-framework")[NIST AI Risk Management Framework] --- pendekatan penilaian risiko.
- #link("https://www.prisma-statement.org/prisma-2020-statement")[PRISMA 2020 Statement] --- pelaporan review sistematis.
- #link("https://huggingface.co/datasets/wmcnicho/StudyChat")[Hugging Face: StudyChat] --- interaksi mahasiswa dengan tutor berbasis AI.
- #link("https://huggingface.co/datasets/aiboxlab/edu-interactions")[Hugging Face: EDU Interactions] --- contoh dataset interaksi pendidikan.
- #link("https://www.kaggle.com/competitions/map-charting-student-math-misunderstandings")[Kaggle: MAP --- Charting Student Math Misunderstandings] --- analisis miskonsepsi matematis.
- #link("https://www.drawio.com/")[draw.io], #link("https://mermaid.js.org/")[Mermaid], #link("https://graphviz.org/")[Graphviz] --- visualisasi dan pemodelan diagram.

#block[
#callout(
body: 
[
Daftar sumber ini merupakan titik awal serta rujukan dokumentasi, #strong[bukan] bibliografi komprehensif hasil pencarian SLR. Ketika digunakan sebagai buku ajar resmi atau diterbitkan, referensi pernyataan empiris, izin reproduksi materi, dan akurasi seluruh metadata sumber perlu diverifikasi kembali.

]
, 
title: 
[
Catatan akademik
]
, 
background_color: 
rgb("#fcefdc")
, 
icon_color: 
rgb("#EB9113")
, 
icon: 
fa-exclamation-triangle()
, 
body_background_color: 
white
)
]
= Penutup: Sistem Cerdas yang Mencerdaskan
<penutup-sistem-cerdas-yang-mencerdaskan>
Sebuah perjalanan dari A ke B memerlukan lebih dari sekadar harapan. Kita perlu mengenali A dan B, membangun peta, memilih rute, mengidentifikasi kebutuhan sumber daya, lalu menggerakkan engine sepanjang stages hingga milestones terpenuhi. #strong[PUDAL] mengendalikan proses tersebut dengan mengamati, memahami, memutuskan, bertindak, dan belajar secara berulang.

Lima fungsi PUDAL memberikan pembagian tugas yang eksplisit. #strong[Orientation] menentukan tujuan. #strong[Understanding] mengembangkan peta dan menguji rute yang belum diketahui. #strong[Planning] memilih rute, engine, sumber daya, dan milestones. #strong[Execution] menjalankan tindakan. #strong[Learning] berinvestasi pada kemampuan agar rute baru dapat ditemukan atau ditempuh dengan lebih baik.

Sumber daya lingkungan memengaruhi rute yang layak. Natural, Instrumental, dan Vehicular Engine menyediakan mekanisme pengerjaan yang berbeda, sehingga strategi terbaik sering berupa kombinasi, bukan pemilihan satu moda secara mutlak. Pilihan juga harus menjaga nilai pembelajaran: penyelesaian tercepat hari ini bukan selalu hasil pendidikan terbaik.

Dalam #strong[Triune Academic Commons], rancangan ini menghubungkan kecerdasan individual, kolektif, dan artifisial. Mahasiswa tidak hanya memanfaatkan AI untuk menghasilkan jawaban, melainkan belajar memetakan persoalan, memilih strategi yang bertanggung jawab, mendemonstrasikan hasil, dan meningkatkan kemampuan dirinya maupun komunitasnya.

#quote(block: true)[
#strong[Prinsip penutup:] sistem cerdas tidak hanya mengantar manusia mencapai tujuan; sistem cerdas yang baik membantu manusia memahami perjalanan, memperluas pilihan rute, serta menjadi lebih mampu merancang dan menempuh perjalanan berikutnya.
]

== Menilai kembali perjalanan dari artefak menuju kemampuan
<menilai-kembali-perjalanan-dari-artefak-menuju-kemampuan>
Sesudah modul Bayes selesai, kelompok masih perlu bertanya apakah pengguna memperoleh kemampuan yang dimaksud. Ketepatan rumus, kelancaran portal, dan banyaknya latihan merupakan kondisi yang membantu, tetapi tidak otomatis membuktikan penguasaan. Satu pengguna yang dapat menyelesaikan kasus baru dengan alasan yang benar memberi bukti berbeda dari seratus pembukaan halaman. Keduanya dapat dicatat tanpa disamakan.

Perjalanan kelompok juga menghasilkan pembelajaran. Anggota dapat menjadi lebih mampu menilai sumber, menguji tutorial, menyusun mandat AI, dan menjelaskan trade-off. Pengetahuan tersebut perlu diekstraksi dari log dan keputusan agar dapat dipakai pada proyek lain. Jika pengalaman hanya disimpan sebagai produk akhir, alasan perubahan dan pelajaran dari kegagalan mudah hilang.

== Empat tanggung jawab yang terus berjalan
<empat-tanggung-jawab-yang-terus-berjalan>
Tanggung jawab epistemik menjaga hubungan klaim dengan bukti. Tanggung jawab pedagogis menjaga kesempatan peserta untuk belajar dan menunjukkan penguasaan. Tanggung jawab operasional memastikan tindakan sesuai sumber daya dan kewenangan. Tanggung jawab sosial memperhatikan siapa yang menerima manfaat, menanggung beban, dan dapat ikut menggunakan commons. Keempatnya tidak selesai hanya karena tugas telah dinilai.

Dalam praktik, tanggung jawab itu dapat berbenturan. Mempercepat produksi dapat mengurangi waktu verifikasi; menambah fitur dapat mengurangi akses bagi pengguna dengan perangkat sederhana. PUDAL membantu membuat benturan terlihat dan meninjau pilihan dari keadaan aktual. Kerangka ini tidak menggantikan penilaian nilai oleh pihak yang bertanggung jawab.

== Membawa model ke konteks baru dengan hati-hati
<membawa-model-ke-konteks-baru-dengan-hati-hati>
Pembaca dapat mencoba pendekatan A--B dan milestone pada penelitian, layanan kampus, atau proyek profesional. Mulailah dari satu kasus kecil dan bandingkan dengan cara kerja yang biasa dipakai. Periksa apakah pencatatan menambah kejelasan atau justru beban yang tidak berguna. Sederhanakan komponen yang tidak membantu keputusan, sambil mempertahankan keterlacakan tujuan, tindakan, dan bukti.

Jangan menganggap keberhasilan pada satu modul sebagai validasi umum. Model sosial dan pendidikan bergantung pada peserta, konteks, serta tujuan. Prinsip evaluasi dan penyesuaian merupakan bagian yang dapat dibawa, sedangkan bobot, jadwal, dan instrumen perlu diperiksa kembali. Bukti lokal menjadi dasar memperluas penggunaan secara bertahap.

== Agenda setelah membaca
<agenda-setelah-membaca>
Pilih satu persoalan yang cukup kecil untuk diselesaikan, tetapi cukup nyata untuk mengandung ketidakpastian. Nyatakan A dan B, petakan dua rute, pilih engine dengan biaya penuh, tentukan satu milestone, lalu jalankan satu putaran. Sesudahnya, tulis apa yang berubah pada pekerjaan dan pada kemampuan Anda. Mintalah orang lain memeriksa satu klaim utama.

Jika hasilnya tidak sesuai harapan, gunakan perbedaan itu sebagai informasi. Mungkin tujuan belum jelas, peta salah, kapasitas kurang, atau pengukuran tidak cocok. Kesediaan membedakan penyebab lebih bernilai daripada mempertahankan istilah. PUDAL layak dipertahankan sejauh ia membantu pengguna memahami dan memperbaiki keputusan.

Commons yang hidup menyediakan jalur koreksi dan pemeliharaan, sehingga mahasiswa berikutnya dapat melanjutkan dari bahan yang lebih baik. Kajian tata kelola bersama memberi alasan untuk memperhatikan aturan dan tanggung jawab, bukan hanya keterbukaan akses @ostrom2009. Dalam konteks buku ini, tujuan akhirnya ialah menghubungkan hasil yang berguna dengan manusia yang semakin mampu merancang, memeriksa, dan mempertanggungjawabkan perjalanan berikutnya.

#show: appendices.with("Lampiran", hide-parent: true)
#heading(level: 1, numbering: none)[Lampiran]
= Register 42 Artefak
<register-42-artefak>
Tabel ini diturunkan dari #NormalTok("data/ARTIFACT_REGISTER_asli.csv"); pada repositori KIPP yang tersedia. Kode baru #strong[TT.JJ.NN] disandingkan dengan kode asli untuk menghindari hilangnya jejak. Judul bersifat rencana pengembangan, bukan pernyataan bahwa semua artefak telah rampung.

#table(
  columns: (14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%, 14.29%),
  align: (auto,auto,auto,auto,auto,auto,auto,),
  table.header([Kode baru], [ID asal], [Tema], [Jenis], [Judul], [Penanggung jawab], [Prioritas],),
  table.hline(),
  [01.01.01], [K-L01], [AI for Learning], [knowledge], [Prinsip belajar efektif menggunakan AI], [Tim 01], [P0],
  [01.01.02], [K-L02], [AI for Learning], [knowledge], [Metakognisi, belajar aktif, dan uji pemahaman], [Tim 02], [P0],
  [01.02.01], [S-L01], [AI for Learning], [skills], [Belajar satu konsep sulit dengan bantuan AI], [Tim 01], [P1],
  [01.02.02], [S-L02], [AI for Learning], [skills], [Membuat latihan, kuis, dan umpan balik formatif], [Tim 02], [P1],
  [01.03.01], [P-L01], [AI for Learning], [prompts], [Socratic AI Tutor], [Tim 01], [P1],
  [01.03.02], [P-L02], [AI for Learning], [prompts], [Penguji pemahaman dan miskonsepsi], [Tim 02], [P1],
  [01.04.01], [C-L01], [AI for Learning], [cases], [Mengukur peningkatan pemahaman satu konsep], [Tim 01+02], [P2],
  [02.01.01], [K-R01], [AI for Literature Research], [knowledge], [Struktur paper dan pembacaan kritis], [Tim 03], [P0],
  [02.01.02], [K-R02], [AI for Literature Research], [knowledge], [Strategi penelusuran dan validasi sumber], [Tim 04], [P0],
  [02.02.01], [S-R01], [AI for Literature Research], [skills], [Membaca dan meringkas paper berbantuan AI], [Tim 03], [P1],
  [02.02.02], [S-R02], [AI for Literature Research], [skills], [Matriks literatur dan identifikasi research gap], [Tim 04], [P1],
  [02.03.01], [P-R01], [AI for Literature Research], [prompts], [Critical Paper Reader], [Tim 03], [P1],
  [02.03.02], [P-R02], [AI for Literature Research], [prompts], [Literature Comparison and Synthesis], [Tim 04], [P1],
  [02.04.01], [C-R01], [AI for Literature Research], [cases], [Sintesis lima paper yang terverifikasi], [Tim 03+04], [P2],
  [03.01.01], [K-W01], [AI for Academic Writing], [knowledge], [Struktur karya ilmiah dan argumentasi], [Tim 05], [P0],
  [03.01.02], [K-W02], [AI for Academic Writing], [knowledge], [Integritas akademik, sitasi, dan atribusi AI], [Tim 06], [P0],
  [03.02.01], [S-W01], [AI for Academic Writing], [skills], [Membuat outline dari pertanyaan penelitian], [Tim 05], [P1],
  [03.02.02], [S-W02], [AI for Academic Writing], [skills], [Revisi paragraf, koherensi, dan argumentasi], [Tim 06], [P1],
  [03.03.01], [P-W01], [AI for Academic Writing], [prompts], [Academic Outline Coach], [Tim 05], [P1],
  [03.03.02], [P-W02], [AI for Academic Writing], [prompts], [Critical Writing Reviewer], [Tim 06], [P1],
  [03.04.01], [C-W01], [AI for Academic Writing], [cases], [Revisi draf dengan jejak perbaikan], [Tim 05+06], [P2],
  [04.01.01], [K-C01], [AI for Coding & Data Analysis], [knowledge], [Pemrograman berbantuan AI dan debugging], [Tim 07], [P0],
  [04.01.02], [K-C02], [AI for Coding & Data Analysis], [knowledge], [Analisis data, validasi, dan reproduksibilitas], [Tim 08], [P0],
  [04.02.01], [S-C01], [AI for Coding & Data Analysis], [skills], [Notebook Python dari masalah ke pengujian], [Tim 07], [P1],
  [04.02.02], [S-C02], [AI for Coding & Data Analysis], [skills], [Notebook Pandas dan Matplotlib], [Tim 08], [P1],
  [04.03.01], [P-C01], [AI for Coding & Data Analysis], [prompts], [Coding Tutor and Debugging Assistant], [Tim 07], [P1],
  [04.03.02], [P-C02], [AI for Coding & Data Analysis], [prompts], [Data Analysis and Result Verification], [Tim 08], [P1],
  [04.04.01], [C-C01], [AI for Coding & Data Analysis], [cases], [Analisis dataset akademik dengan verifikasi], [Tim 07+08], [P2],
  [05.01.01], [K-V01], [AI for Visualization & Presentation], [knowledge], [Prinsip komunikasi visual ilmiah], [Tim 09], [P0],
  [05.01.02], [K-V02], [AI for Visualization & Presentation], [knowledge], [Presentasi akademik, storytelling, dan TAIDA], [Tim 10], [P0],
  [05.02.01], [S-V01], [AI for Visualization & Presentation], [skills], [Diagram konsep dan grafik yang benar], [Tim 09], [P1],
  [05.02.02], [S-V02], [AI for Visualization & Presentation], [skills], [Presentasi akademik lima menit], [Tim 10], [P1],
  [05.03.01], [P-V01], [AI for Visualization & Presentation], [prompts], [Scientific Visual Designer], [Tim 09], [P1],
  [05.03.02], [P-V02], [AI for Visualization & Presentation], [prompts], [Academic Presentation Coach], [Tim 10], [P1],
  [05.04.01], [C-V01], [AI for Visualization & Presentation], [cases], [Paper menjadi infografik dan presentasi akurat], [Tim 09+10], [P2],
  [06.01.01], [K-P01], [AI for Academic Problem Solving], [knowledge], [Problem framing dan identifikasi kebutuhan], [Tim 11], [P0],
  [06.01.02], [K-P02], [AI for Academic Problem Solving], [knowledge], [Alternatif solusi, keputusan, dan evaluasi nilai], [Tim 12], [P0],
  [06.02.01], [S-P01], [AI for Academic Problem Solving], [skills], [Analisis masalah berbantuan AI], [Tim 11], [P1],
  [06.02.02], [S-P02], [AI for Academic Problem Solving], [skills], [Decision matrix, simulasi, dan risiko], [Tim 12], [P1],
  [06.03.01], [P-P01], [AI for Academic Problem Solving], [prompts], [Problem Framing and Root Cause Analyst], [Tim 11], [P1],
  [06.03.02], [P-P02], [AI for Academic Problem Solving], [prompts], [Solution Critic and Decision Support], [Tim 12], [P1],
  [06.04.01], [C-P01], [AI for Academic Problem Solving], [cases], [Solusi untuk masalah nyata kehidupan akademik], [Tim 11+12], [P2],
)
#strong[Catatan:] jika penamaan folder/kode di repositori berbeda dari rancangan pada bab implementasi, gunakan register sebagai referensi migrasi. Setiap baris harus mempunyai tautan konten dan rekaman review yang dapat diperbarui.

== Cara memeriksa kelengkapan register
<cara-memeriksa-kelengkapan-register>
Setiap tema seharusnya mempunyai dua Knowledge, dua Skills, dua Prompts, dan satu Case Study. Periksa jumlah per jenis dan per tema, bukan hanya total 42. Total yang benar masih dapat menyembunyikan satu tema kekurangan artefak dan tema lain mempunyai duplikasi. ID baru dan ID asal perlu unik dalam fungsinya serta mempunyai pasangan yang dapat ditelusuri.

Tambahkan path sumber, versi, status review, bukti uji, dan tanggal pembaruan pada registri operasional. Lampiran ini memuat rencana artefak dari bahan proyek; ia tidak menggantikan registri aktif yang membuktikan status implementasi. Perubahan judul diperbolehkan jika identitas dan alasan perubahan tetap tercatat.

== Contoh penerimaan satu artefak
<contoh-penerimaan-satu-artefak>
Untuk #NormalTok("01.02.01");, reviewer memeriksa bahwa tutorial mempunyai tujuan, prasyarat, input, langkah, hasil yang diharapkan, dan cara mendeteksi kesalahan. Ia lalu menjalankan satu contoh tanpa bantuan penyusun. Status diterima diberikan setelah kegagalan yang ditemukan diperbaiki atau batas penggunaannya dinyatakan secara jelas.

Jika tutorial belum diuji, gunakan status draf atau menunggu pengujian. Kejujuran status membantu pasangan kelompok merencanakan integrasi. Artefak yang belum diterima tidak harus dihapus; ia tetap berguna sebagai pekerjaan terbuka dengan penanggung jawab dan tindakan berikutnya.

= Templat Case Study PUDAL
<templat-case-study-pudal>
== Identitas dan kebutuhan
<identitas-dan-kebutuhan>
#strong[Tema:] … #strong[Tim:] … #strong[Pengguna:] … #strong[Tanggal:] … #strong[Kasus:] …

#strong[Keadaan A:] deskripsikan kondisi awal dan bukti. #strong[Keadaan B:] hasil akhir dan acceptance criteria. #strong[Tenggat:] … #strong[Batas etika, akses, dan mutu:] …

== Orientation PUDAL
<orientation-pudal>
Apa tujuan? Siapa yang diuntungkan? Apa indikator keberhasilan yang dapat diuji? Apa kondisi berhenti atau eskalasi?

== Understanding PUDAL
<understanding-pudal>
Gambarkan graf keadaan yang diketahui. Catat tujuan antara, transisi, rute yang terverifikasi, rute yang belum layak, dan hipotesis. Buat tabel sumber daya: jenis, lokasi, ketersediaan, akses, serta engine yang dapat menggunakan.

== Planning PUDAL
<planning-pudal>
#table(
  columns: (12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%, 12.5%),
  align: (auto,auto,auto,auto,auto,auto,auto,auto,),
  table.header([Stage], [Dari → Ke], [Engine], [Prasyarat], [Waktu], [Sumber daya], [Risiko], [Bukti milestone],),
  table.hline(),
  [1], [A → M1], […], […], […], […], […], […],
  [2], [M1 → M2], […], […], […], […], […], […],
  [n], [Mn → B], […], […], […], […], […], […],
)
Bandingkan setidaknya dua rute bila tersedia. Jelaskan mengapa rute dan kombinasi engine dipilih.

== Execution PUDAL
<execution-pudal>
Untuk tiap stage: tuliskan pengamatan aktual, analisis gap, keputusan tindakan, catatan kerja, bukti hasil, dan perubahan strategi. Pertahankan log pengujian serta referensi sumber.

== Learning PUDAL
<learning-pudal>
Apa capability gap yang ditemukan? Apa yang dipelajari? Bagaimana penguasaan dibuktikan pada masalah baru? Apakah peta rute, pilihan engine, atau strategi berubah?

== Validasi dan refleksi
<validasi-dan-refleksi>
Periksa apakah B tercapai; perbandingan waktu/biaya aktual terhadap rencana; audit integritas; peer-review; perbaikan; dan kontribusi individual serta kolektif. Dokumentasikan hal yang gagal secara transparan.

== Contoh singkat pengisian kasus Bayes
<contoh-singkat-pengisian-kasus-bayes>
#strong[Konteks:] kelompok ingin membantu mahasiswa memahami peluang setelah menerima informasi baru. #strong[A:] pengguna menukar sensitivitas dan posterior. #strong[B:] pengguna dapat menentukan kelompok pembanding dan menyelesaikan kasus spam tanpa petunjuk. #strong[Batas:] waktu latihan 45 menit, tanpa data pribadi, dan penggunaan tutor hanya pada tahap latihan. Angka waktu merupakan rancangan contoh.

Orientation menyepakati tujuan konsep dan tes mandiri. Understanding memetakan miskonsepsi melalui jawaban serta penjelasan pengguna. Planning memilih tabel frekuensi lebih dahulu, kemudian rumus dan soal transfer. Execution menjalankan urutan tersebut sambil mencatat bantuan yang diberikan. Learning memeriksa apakah kemampuan bertahan ketika konteks berubah dan petunjuk dihilangkan.

Jika jawaban awal memakai 90% sebagai posterior, simpan alasan pengguna, bukan hanya tanda salah. Sesudah latihan, minta ia menerangkan mengapa penyebut adalah semua hasil positif. Tes berikutnya menggunakan filter spam dengan parameter berbeda. Perubahan penjelasan menjadi bukti belajar yang lebih relevan daripada jumlah putaran percakapan.

== Menulis refleksi yang dapat ditindaklanjuti
<menulis-refleksi-yang-dapat-ditindaklanjuti>
Refleksi menyebut dugaan awal, hasil yang diamati, dan keputusan yang berubah. Contoh: "Kami mengira penjelasan rumus cukup; pengguna tetap memilih penyebut salah; kami menambahkan tabel dan menguji kembali pada pengguna baru." Pernyataan ini memungkinkan reviewer mengikuti alasan revisi. Kalimat "AI sangat membantu" perlu dilengkapi pekerjaan yang dibantu, biaya pemeriksaan, dan hal yang tetap belum dapat dilakukan mandiri.

Pada penutupan kasus, tandai apakah B tercapai, belum tercapai, atau belum dapat dinilai. Jelaskan bukti dan kekurangan informasi untuk status tersebut. Jangan mengganti tujuan semula hanya agar kasus tampak berhasil. Jika tujuan berubah secara sah, simpan versi sebelumnya dan alasan perubahannya.

= Glosarium
<glosarium>
#strong[A / B:] keadaan awal dan keadaan tujuan.

#strong[Acquire--Convert--Store--Execute:] empat fungsi konseptual pengelolaan sumber daya untuk kerja.

#strong[Case Study:] kasus yang menempatkan Knowledge, Skills, Prompts dalam satu demonstrasi PUDAL.

#strong[Decision gate:] titik keputusan sesudah evaluasi untuk melanjutkan, mengubah, belajar, atau berhenti.

#strong[Engine:] mekanisme pelaksanaan kerja yang mengubah sumber daya menjadi transisi keadaan.

#strong[Goal Model:] representasi tujuan dan kriteria keberhasilan.

#strong[Instrumental Engine:] kemampuan intrinsik yang diperbesar dengan instrumen.

#strong[Learning Path:] alur belajar dari masalah hingga demonstrasi dan evaluasi kompetensi.

#strong[Milestone:] keadaan antara yang memiliki kriteria penerimaan terukur.

#strong[Mixed Engine:] penggunaan kombinasi engine natural, instrumental dan vehicular.

#strong[Natural Engine:] pelaksanaan kerja oleh kemampuan dan tenaga intrinsik.

#strong[PUDAL:] Perceive, Understand, Decide, Act, Learn.

#strong[PUDAL-1/2/3/4/5:] Orientation, Understanding, Planning, Execution, Learning.

#strong[Resource--Energy Graph:] peta sumber daya, akses, konversi dan suplai.

#strong[Rolling-horizon replanning:] memperbarui rencana tahap berikut berdasarkan keadaan aktual setiap checkpoint.

#strong[Stage:] segmen proses di antara dua milestone.

#strong[State--Route Graph:] representasi keadaan dan transisi antar-keadaan.

#strong[TAIDA:] Target, Attention, Interest, Desire, Action.

#strong[Triune Intelligence:] Individual, Collective, Artificial Intelligence yang saling mendukung.

#strong[Understanding PUDAL:] eksplorasi yang membangun peta termasuk rute yang belum diketahui.

#strong[Vehicular Engine:] layanan/mesin eksternal yang mengerjakan bagian utama pekerjaan terdelegasi.

== Pembedaan istilah yang sering tertukar
<pembedaan-istilah-yang-sering-tertukar>
#strong[Aktivitas dan keadaan:] membaca lima artikel adalah aktivitas; matriks sintesis yang dapat ditelusuri adalah keadaan hasil. Aktivitas tidak otomatis menjamin keadaan yang diinginkan.

#strong[Bukti dan klaim:] klaim menyatakan sesuatu yang ingin diterima; bukti memberi dasar untuk memeriksanya. Kualitas dasar itu bergantung pada metode, kecocokan dengan klaim, dan keterlacakan sumber.

#strong[Verifikasi dan validasi:] dalam adaptasi buku ini, verifikasi memeriksa kesesuaian terhadap spesifikasi, sedangkan validasi menilai kecocokan bagi penggunaan yang dimaksud. Rumus dapat benar sementara tutorial belum membantu pengguna sasaran.

#strong[Kelayakan dan optimalitas:] rute layak memenuhi kendala; rute optimal terbaik menurut model dan fungsi tujuan tertentu. Pilihan yang mendapat skor tertinggi belum tentu layak jika melanggar batas wajib.

#strong[Hasil tugas dan hasil belajar:] hasil tugas adalah mutu keluaran pekerjaan; hasil belajar adalah perubahan kemampuan yang perlu bukti tersendiri. Keluaran bagus dengan bantuan tidak otomatis membuktikan kemampuan mandiri.

#strong[Sumber daya dan energi fisik:] sumber daya mencakup waktu, uang, data, akses, kemampuan, dan energi. Hanya besaran energi fisik yang dicatat dalam satuan energi; komponen lain memakai satuan dan neracanya sendiri.

#strong[Hipotesis dan temuan:] hipotesis adalah dugaan yang dapat diuji; temuan merupakan hasil pengamatan atau analisis dengan metode yang dinyatakan. Usulan desain perlu ditandai sampai bukti pengujiannya tersedia.

= Sumber Bahan, Dokumentasi Visual, dan Catatan Editorial
<sumber-bahan-dokumentasi-visual-dan-catatan-editorial>
== Asal materi
<asal-materi>
Naskah disusun dari percakapan proyek KIPP yang mengembangkan: enam learning paths, empat artefak, TAIDA, PUDAL, graf A--B, tiga engine, sumber daya dan energi, hierarki lima PUDAL, intermediate destinations, dan milestones. Bahan yang tersedia sebagai berkas pendamping: #NormalTok("data/Petunjuk_UAS_KIPP.qmd");, #NormalTok("data/ARTIFACT_REGISTER_asli.csv");, dan #NormalTok("data/KIPP_Pembagian_Kelompok_dan_42_Artefak.xlsx");.

== Indeks gambar hasil percakapan
<indeks-gambar-hasil-percakapan>
#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([Gambar], [Lokasi di buku], [Nama berkas],),
  table.hline(),
  [Ringkasan enam learning paths], [Prakata], [#NormalTok("images/overview.png");],
  [Ringkasan 42 artefak], [Bab 3], [#NormalTok("images/artefacts.png");],
  [Pembagian tim], [Bab 3], [#NormalTok("images/teams.png");],
  [Ekosistem sumber daya], [Bab 7], [#NormalTok("images/resource.png");],
  [Portal dan sumber belajar], [Bab 12], [#NormalTok("images/portal.png");],
  [Learning Flow Tema 1--6], [Bab 13, masing-masing tema], [#NormalTok("images/lp1.png"); s.d. #NormalTok("images/lp6.png");],
  [Workflow mahasiswa], [Bab 14], [#NormalTok("images/flow.png");],
  [Struktur repositori], [Bab 15], [#NormalTok("images/repository.png");],
  [Panduan GitHub], [Bab 15], [#NormalTok("images/github.png");],
)
== Hal yang perlu diverifikasi sebelum publikasi akademik
<hal-yang-perlu-diverifikasi-sebelum-publikasi-akademik>
+ Persamaan, fungsi tujuan, dan klasifikasi engine adalah #strong[model konseptual usulan], belum divalidasi eksperimen.
+ Enam gambar Learning Flow merupakan ilustrasi yang dibuat selama percakapan; teks pada gambar harus diperiksa ulang ketika digunakan sebagai rujukan penilaian resmi.
+ Registri dan judul tugas berasal dari bahan proyek, dan status aktual tiap artefak perlu disinkronkan dengan repositori yang aktif.
+ Bobot penilaian UAS merupakan rancangan untuk pengesahan, bukan ketentuan resmi.
+ Uang, waktu, dan kapasitas kognitif adalah sumber daya dalam analogi kerja; hanya energi fisik yang memiliki unit joule.

== Rujukan teknis Quarto
<rujukan-teknis-quarto>
- #link("https://quarto.org/docs/books/")[Creating a Book --- Quarto]
- #link("https://quarto.org/docs/books/book-structure.html")[Book Structure --- Quarto]

Buku mengikuti struktur resmi #NormalTok("project: type: book");, file wajib #NormalTok("index.qmd");, daftar bab pada #NormalTok("_quarto.yml");, dan folder keluaran #NormalTok("_book/"); setelah dirender. Rujukan Quarto menjelaskan #strong[format penerbitan], bukan sumber empiris bagi kerangka PUDAL.

== Landasan literatur edisi pengembangan
<landasan-literatur-edisi-pengembangan>
Literatur pembelajaran dipakai untuk membahas diagnosis, pengaturan diri, dan latihan mengingat kembali @hpl2018@roediger2006. Sumber statistik mendukung pembacaan tabel probabilitas @openstax-stat. Literatur argumentasi dan visualisasi membantu membedakan klaim, penalaran, representasi, serta ketidakpastian @purdue-toulmin@wilke2019. Pembahasan tersebut tidak menjadi bukti langsung efektivitas seluruh arsitektur PUDAL.

Dokumentasi rekayasa sistem, tata kelola risiko, dan pedoman AI menjadi bahan pembandingan desain @nasa2016@nist2023@unesco-genai. Sumber tentang komputasi ilmiah dan FAIR mendukung pengorganisasian bukti serta penggunaan ulang @wilson2017@fair2016. Penilaian kausal, pelaporan review, dan tata kelola bersama mempunyai landasan tersendiri @cunningham2021@prisma2020@ostrom2009.

Tanggal pemeriksaan sumber daring untuk pengembangan ini adalah 22 November 2026. Utamakan tahun terbit sumber pada sitasi, bukan tahun akses. Dokumentasi perangkat dapat berubah; langkah implementasi perlu diperiksa terhadap versi yang dipakai. Buku terbuka ditautkan sebagai bahan baca, tanpa menyalin bab atau gambar berlisensi pihak lain.

== Cara mengaudit satu klaim
<cara-mengaudit-satu-klaim>
Pilih klaim, temukan sitasi, lalu periksa apakah sumber membahas objek, populasi, dan hasil yang sama. Jika buku menerapkan prinsip pada kasus baru, hubungan itu harus dinyatakan sebagai penerapan atau hipotesis. Periksa pula apakah angka berasal dari pengukuran, perhitungan parameter, atau ilustrasi. Ketiga asal angka mempunyai batas kesimpulan yang berbeda.

Gambar proyek dipertahankan sebagai dokumentasi visual awal. Jika label gambar berbeda dari penjelasan yang diperbarui, gunakan teks dan perhitungan terverifikasi sebagai dasar, lalu catat kebutuhan revisi aset. Sumber eksternal tidak dipakai untuk mengklaim bahwa gambar proyek merupakan model ilmiah tervalidasi.

= Lampiran: Menjalankan dan Mengembangkan Buku
<lampiran-menjalankan-dan-mengembangkan-buku>
== Persyaratan
<persyaratan>
Instal Quarto dari #link("https://quarto.org/docs/get-started/")[quarto.org]. Proyek ini menggunakan #strong[format buku bawaan] Quarto; tidak memerlukan ekstensi eksternal untuk HTML maupun EPUB. Dokumen #NormalTok(".qmd");, aset gambar, CSS, serta file pengaturan disertakan.

== Render
<render>
Dari folder proyek:

#Skylighting(([#ExtensionTok("quarto");#NormalTok(" preview");],
[#ExtensionTok("quarto");#NormalTok(" render ");#AttributeTok("--to");#NormalTok(" html");],
[#ExtensionTok("quarto");#NormalTok(" render ");#AttributeTok("--to");#NormalTok(" epub");],
[#ExtensionTok("quarto");#NormalTok(" render ");#AttributeTok("--to");#NormalTok(" typst");],));
PDF edisi ini dibuat melalui #NormalTok("quarto render --to typst");, menggunakan mesin Typst bawaan Quarto. Alternatif LaTeX tersedia melalui #NormalTok("quarto render --to pdf"); jika sistem menyediakan XeLaTeX. Diagram buku memakai aset vektor SVG/PDF dengan sumber Mermaid dan DOT yang dapat diedit di #NormalTok("images/diagrams/");, sehingga hasil cetak tidak memerlukan proses screenshot browser.

== Pilihan ekstensi
<pilihan-ekstensi>
Tautan katalog ekstensi format yang menjadi awal permintaan adalah #link("https://quarto.org/docs/extensions/listing-formats.html")[Quarto Extensions --- Custom Formats]. Beberapa ekstensi memiliki dukungan untuk buku, tetapi memerlukan instalasi, kompatibilitas versi dan lisensi yang perlu diperiksa. Edisi ini memilih buku bawaan agar portabel. Setelah instalasi Quarto tersedia, pembaca dapat mengganti tema atau memasang ekstensi dengan mengikuti petunjuk masing-masing.

== Struktur direktori
<struktur-direktori>
#Skylighting(([#NormalTok("tise-six-themes-book/");],
[#NormalTok("├── _quarto.yml");],
[#NormalTok("├── index.qmd");],
[#NormalTok("├── 01-kerangka-tise.qmd");],
[#NormalTok("├── 02-tema1-learning.qmd");],
[#NormalTok("├── 03-tema2-literature.qmd");],
[#NormalTok("├── 04-tema3-writing.qmd");],
[#NormalTok("├── 05-tema4-data.qmd");],
[#NormalTok("├── 06-tema5-visualisasi.qmd");],
[#NormalTok("├── 07-tema6-problem-solving.qmd");],
[#NormalTok("├── 08-implementasi-asesmen.qmd");],
[#NormalTok("├── 09-template-kerja.qmd");],
[#NormalTok("├── references.qmd");],
[#NormalTok("├── appendix-tools.qmd");],
[#NormalTok("├── images/");],
[#NormalTok("├── styles/");],
[#NormalTok("└── templates/");],));
== Infografik
<infografik>
Seluruh gambar infografik Tema 0--6 disertakan sebagai PNG dan diletakkan pada awal pembahasan masing-masing tema. Gambar dibuat sebagai alat bantu komunikasi; #strong[angka, label, serta hubungan dalam infografik perlu diperiksa terhadap naskah] bila digunakan untuk pengajaran formal.

== Integritas data dan versi
<integritas-data-dan-versi>
Jangan membagikan dataset yang tidak diizinkan lisensinya. Simpan sumber data, versi, tanggal unduh, langkah transformasi, dan konfigurasi analisis; untuk publikasi ilmiah, pisahkan ilustrasi atau data simulasi dari hasil pengukuran nyata.

== Pemeriksaan sebelum membagikan hasil render
<pemeriksaan-sebelum-membagikan-hasil-render>
Periksa daftar isi, tautan antarbab, tampilan rumus, lebar tabel, keterangan gambar, dan bibliografi pada format yang akan dibagikan. HTML yang terlihat baik belum menjamin PDF mempunyai pemenggalan halaman yang baik. Setelah mengubah isi, bangun ulang format keluaran agar pembaca tidak menerima versi lama.

Contoh Python di buku ditandai #NormalTok("eval: false"); ketika merupakan pola yang membutuhkan input atau penyesuaian. Status itu berarti kode ditampilkan dan tidak dijalankan oleh Quarto; jangan menafsirkan hasil render sebagai bukti eksekusi analisis dataset. Jika contoh akan dijalankan, siapkan data yang sah, dependensi, dan pemeriksaan hasil secara terpisah.

== Menambah bab tanpa memutus keterlacakan
<menambah-bab-tanpa-memutus-keterlacakan>
Buat sumber #NormalTok(".qmd");, daftarkan pada #NormalTok("_quarto.yml");, lalu gunakan ID gambar dan kunci sitasi yang unik. Tambahkan metadata sumber pada #NormalTok("references.bib"); dan sitasi pada klaim yang memerlukannya. Jangan menambahkan daftar pustaka yang tidak terkait pembahasan hanya untuk memperpanjang referensi.

Saat merevisi angka contoh, periksa seluruh tempat pemakaiannya: narasi, persamaan, tabel, soal, dan kunci. Simpan catatan perubahan yang memengaruhi hasil atau penafsiran. Pemeliharaan buku merupakan bagian dari mutu ilmiah karena pembaca perlu mengetahui bahwa contoh dan bukti tetap selaras pada versi yang dibagikan.

#bibliography(("tise-six-themes/references.bib"))

