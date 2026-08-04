/// Cleans text before it goes into a PDF. The `pdf` package's default
/// fonts don't reliably render "smart" typography — em/en dashes, curly
/// quotes, middle dots — they render as blank boxes instead. Zetra and
/// Arbiter's AI-generated text commonly uses these characters, so this
/// runs on every piece of dynamic text before it hits a PDF widget.
String pdfSafe(String input) {
  return input
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('·', '-')
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('…', '...');
}
