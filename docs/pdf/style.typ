// ===========================================================================
//  style.typ — typography and components, shared by both documents:
//
//      book.typ    From Gates to a RISC-V CPU   — the concepts
//      tools.typ   Tools and Workflow           — installing, building, deploying
//
//  Typst renders SVG as VECTOR graphics, so every diagram is
//  resolution-independent: zoom to 1600% and the lines stay sharp. The
//  figures are generated from the repository's theme-aware originals by
//  tools/svg-flatten.py, which resolves the CSS custom properties that
//  Typst's renderer does not support.
// ===========================================================================

#let ink      = rgb("#1f2328")
#let mute     = rgb("#57606a")
#let accent   = rgb("#0a4f9e")
#let warm     = rgb("#8a5a00")
#let good     = rgb("#1a7f37")
#let bad      = rgb("#b42318")
#let panel    = rgb("#f6f8fa")
#let rule-col = rgb("#d0d7de")

// ------------------------------------------------------------------ preamble
// Both documents share one page and type setup, so they read as one pair.
// `parts` switches on the part-divider machinery the book uses.

#let preamble(body) = {
  set page(
    paper: "a4",
    margin: (inside: 26mm, outside: 20mm, top: 22mm, bottom: 22mm),
    numbering: "1",
    number-align: center,
  )
  set text(font: ("Libertinus Serif",), size: 10.5pt, lang: "en", fill: ink)
  set par(justify: true, leading: 0.62em, first-line-indent: 0pt, spacing: 0.9em)

  show raw: set text(font: ("JetBrainsMono NFM", "DejaVu Sans Mono"), size: 9pt)
  show raw.where(block: true): it => block(
    width: 100%, fill: panel, inset: (x: 9pt, y: 8pt), radius: 3pt,
    stroke: 0.5pt + rule-col, breakable: true, it,
  )
  show link: it => text(fill: accent, it)

  set heading(numbering: none)
  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    block(above: 18pt, below: 14pt)[
      #set text(size: 21pt, weight: "bold")
      #it.body
    ]
  }
  show heading.where(level: 2): it => block(above: 16pt, below: 7pt)[
    #set text(size: 13.5pt, weight: "bold"); #it.body
  ]
  show heading.where(level: 3): it => block(above: 12pt, below: 5pt)[
    #set text(size: 11pt, weight: "bold", fill: mute); #it.body
  ]
  show heading.where(level: 4): it => block(above: 10pt, below: 4pt)[
    #set text(size: 10.5pt, weight: "bold", style: "italic"); #it.body
  ]
  show figure.caption: it => text(size: 9pt, fill: mute)[#it.body]

  body
}

// --------------------------------------------------------------- part pages
// The course is four stages long and the book is five parts long; a reader
// who knows which part they are in needs the lesson number much less. One
// page per part, deliberately sparse, so the structure is visible when
// flicking through on paper as well as in the outline pane.

// A part page carries the part's own contents, one line per chapter with a
// gloss, because a divider holding nothing but a title is a page the reader
// turns past. `items` is a list of (chapter, what it is about) pairs.
#let part(label, title, items, blurb) = {
  pagebreak(weak: true)
  // Part pages are not headings, so the book's contents stays one line per
  // chapter; the label below carries the grouping instead.
  v(20mm)
  block[
    #text(size: 10pt, fill: mute, weight: "bold", tracking: 1.2pt)[#upper(label)]
    #v(2mm)
    #text(size: 26pt, weight: "bold")[#title]
    #v(4mm)
    #line(length: 46mm, stroke: 1.5pt + accent)
    #v(5mm)
    #block(width: 90%)[#set text(size: 11pt, fill: mute); #blurb]
  ]
  v(10mm)
  block(width: 100%)[
    #set text(size: 9.5pt)
    #table(
      stroke: (x, y) => (top: if y == 0 { 0pt } else { 0.5pt + rule-col },
                         bottom: 0pt, left: 0pt, right: 0pt),
      inset: (x: 0pt, y: 7pt),
      columns: (auto, 1fr),
      column-gutter: 10pt,
      ..items.map(((name, gloss)) => (
        text(weight: "bold")[#name],
        text(fill: mute)[#gloss],
      )).flatten(),
    )
  ]
  pagebreak(weak: true)
}

// ------------------------------------------------------------------ asides
// Earlier drafts set these off as boxed callouts -- eighty of them, each a
// mini-essay, and a reader learns to skip a box they have seen eighty times.
// So a warning now reads as part of the paragraph it belongs to, with a bold
// lead-in to make it findable, and an explanation of why something matters is
// simply prose. Nothing is lost but the frame.

#let watch(body)  = block(above: 10pt, below: 10pt)[
  #text(weight: "bold")[Watch out.] #body
]
#let why(body)    = block(above: 10pt, below: 10pt)[#body]
#let found(body)  = block(above: 10pt, below: 10pt)[
  #text(weight: "bold", fill: bad)[A bug this course hit.] #body
]

// --------------------------------------------------------------- measurement
// Measured results keep their box. They are the one thing in the book that is
// not argument, and the reason the course is worth doing rather than reading.

// `breakable: false` for the same reason `ttable` sets it: the box holds a
// label, a command and a table, and when it splits the label is stranded at
// the bottom of one page with the numbers alone at the top of the next --
// which is what put lesson 03's `seq_top` header on page 16 and its table on
// page 17. A box taller than a page must opt back in, or it overflows the
// bottom margin.
#let measured(title, body, breakable: false) = block(
  width: 100%,
  breakable: breakable,
  inset: (x: 11pt, y: 9pt),
  radius: 3pt,
  fill: good.lighten(95%),
  stroke: (left: 2.5pt + good),
  [
    #text(fill: good, weight: "bold", size: 9.5pt)[MEASURED ~ #title]
    #v(-4pt)
    #set text(size: 9.8pt)
    #body
  ],
)

// ------------------------------------------------------------------- figures
//
// PATHS ARE ROOT-RELATIVE, with a leading slash: "/figures/foo.svg".
//
// Typst resolves a relative path against the file where the `image()` call
// literally appears -- which is THIS file, not the chapter that called `fig`.
// So "../figures/x.svg" written in a chapter would be resolved from
// docs/pdf/, land on docs/figures/, and be rejected as outside the project
// root. A leading slash means "from the project root" and is unambiguous
// wherever the call is written.
#let fig(path, caption, width: 100%) = figure(
  image(path, width: width),
  caption: caption,
)

// ------------------------------------------------------------------- tables
// `breakable: false` by default, because a table that splits across a page
// boundary tends to strand its last row at the top of an otherwise empty page
// -- which is what it looked like, in an earlier build, when the glossary left
// one definition alone on page 7 and the command reference left
// `tools/mkpdf.sh` alone on page 86. Typst has no widow control for table
// rows, so the fix is to move the whole table rather than break it badly.
// A table too tall for one page must opt back in with `breakable: true`,
// or it will overflow the bottom margin.
#let ttable(breakable: false, ..args) = block(breakable: breakable, {
  set text(size: 9.5pt)
  table(
    stroke: (x, y) => (
      top: if y == 0 { 0.8pt + ink } else if y == 1 { 0.5pt + rule-col } else { 0pt },
      bottom: 0pt, left: 0pt, right: 0pt,
    ),
    inset: (x: 7pt, y: 5pt),
    ..args,
  )
})


// ---------------------------------------------------------------- cost
// Every lesson reports what it cost in the SAME shape, because a reader
// comparing lesson 06 against lesson 13 should not have to compare two table
// formats as well. One block per module: the exact command that produces the
// numbers, then a two-column table of the chip's own primitives in a fixed
// order. The primitives are glossed once, in "What an FPGA is", and never
// again -- repeating the glossary in fourteen lessons would be noise.
//
//   #cost("uart_rx — the receiver", (LUT4: 53, TRELLIS_FF: 33, CCU2C: 4),
//         cmd: "make synth M=uart_rx")[
//     Optional commentary on the numbers.
//   ]
//
// A row appears only if the design uses that primitive. The order never
// changes, so two lessons' tables line up by eye.

#let cell-order = (
  "LUT4", "TRELLIS_FF", "CCU2C", "PFUMX", "L6MUX21",
  "TRELLIS_DPR16X4", "DP16KD", "MULT18X18D", "EHXPLLL",
)

// 1765 -> "1,765"
#let num(n) = {
  let s = str(n)
  if s.len() > 3 { s.slice(0, s.len() - 3) + "," + s.slice(s.len() - 3) } else { s }
}

// The 85F's capacity, for the share-of-the-part line.
#let PART-LUT4 = 83640

#let cost(title, counts, cmd: "make synth", share: false, body) = measured(title)[
  #block(above: 11pt, below: 8pt)[#raw(cmd, block: false)]
  #ttable(
    columns: (1fr, auto),
    [*resource*], [*count*],
    ..{
      let rows = ()
      for key in cell-order {
        if key in counts {
          rows.push[#raw(key)]
          rows.push(align(right)[#num(counts.at(key))])
        }
      }
      rows
    },
  )
  #if share and "LUT4" in counts [
    #v(2pt)
    #text(size: 9pt, fill: mute)[
      #num(counts.at("LUT4")) of the 85F's #num(PART-LUT4) LUT4 —
      #{
        let pc = counts.at("LUT4") / PART-LUT4 * 100
        if pc < 0.01 [less than 0.01%] else [#calc.round(pc, digits: 2)%]
      } of the part.
    ]
  ]
  #if body != none [#v(3pt) #body]
]
