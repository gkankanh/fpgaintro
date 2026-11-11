// ===========================================================================
//  style.typ — typography and components for the course book.
//
//  Typst renders SVG as VECTOR graphics, so every diagram in this book is
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

// ------------------------------------------------------------------ callouts
// Three kinds, matching the lesson READMEs so the book and the repository
// read as one thing.

#let callout(title, body, col: accent, sym: none) = block(
  width: 100%,
  inset: (x: 11pt, y: 9pt),
  radius: 3pt,
  fill: col.lighten(94%),
  stroke: (left: 2.5pt + col),
  [
    #text(fill: col, weight: "bold", size: 9.5pt)[
      #if sym != none [#sym ~] #title
    ]
    #v(-4pt)
    #set text(size: 9.8pt)
    #body
  ],
)

#let why(body)   = callout("WHY THIS MATTERS", body, col: accent)
#let watch(body) = callout("WATCH OUT", body, col: warm)
#let found(body) = callout("A BUG THIS COURSE ACTUALLY HIT", body, col: bad)

// -------------------------------------------------------------------- goals
// Every lesson chapter opens with these, so a reader can see at a glance
// what the lesson is for before reading any of it.

#let goals(concept: "", build: "", board: "", needs: "", items) = block(
  width: 100%,
  inset: (x: 12pt, y: 11pt),
  radius: 3pt,
  fill: panel,
  stroke: 0.5pt + rule-col,
  [
    #grid(
      columns: (auto, 1fr),
      row-gutter: 5pt,
      column-gutter: 9pt,
      text(size: 9pt, fill: mute, weight: "bold")[CONCEPT],
      text(size: 10pt)[#concept],
      text(size: 9pt, fill: mute, weight: "bold")[YOU BUILD],
      text(size: 10pt)[#build],
      text(size: 9pt, fill: mute, weight: "bold")[NEEDS],
      text(size: 10pt)[#needs],
    )
    #v(3pt)
    #line(length: 100%, stroke: 0.5pt + rule-col)
    #v(1pt)
    #text(size: 9pt, fill: mute, weight: "bold")[LEARNING GOALS]
    #v(-3pt)
    #set text(size: 9.8pt)
    #items
  ],
)

// --------------------------------------------------------------- measurement
// The course's method is to measure rather than assert, so measured results
// get their own visual treatment.

#let measured(title, body) = block(
  width: 100%,
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
#let ttable(..args) = {
  set text(size: 9.5pt)
  table(
    stroke: (x, y) => (
      top: if y == 0 { 0.8pt + ink } else if y == 1 { 0.5pt + rule-col } else { 0pt },
      bottom: 0pt, left: 0pt, right: 0pt,
    ),
    inset: (x: 7pt, y: 5pt),
    ..args,
  )
}


// ----------------------------------------------------------------- planned
// Lessons 14-17 have settled scope but are not yet written. Saying so
// prominently is better than letting a reader discover it at the repository.

#let planned = block(
  width: 100%,
  inset: (x: 11pt, y: 8pt),
  radius: 3pt,
  fill: rgb("#fff8e6"),
  stroke: (left: 2.5pt + warm),
  [
    #text(fill: warm, weight: "bold", size: 9.5pt)[NOT YET BUILT]
    #v(-4pt)
    #set text(size: 9.8pt)
    The scope, ordering and theory of this lesson are settled, and the chapter
    below is the plan. The code and the measured results are not here yet --
    lessons are built in order, and this book reports only numbers that were
    actually measured. Nothing in this chapter is a measurement.
  ],
)
