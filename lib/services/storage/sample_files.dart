import 'dart:convert';
import 'dart:typed_data';

/// Demo content for the web build, so a first-time visitor sees how every
/// viewer works before importing their own files.

const welcomeText = '''Welcome to Burrow!

On the web the browser keeps your device's folders private, so this
workspace lives in memory. Use the "Import" button to bring files in,
then browse, search, sort, filter, preview and unzip them.

On Android the app browses your whole storage and installs APK files.
On iOS it manages the files in the app's folder (visible in the Files app).
''';

const sampleMarkdown = '''# Notes

* Sort by **name**, **date** or **size**
* Filter by images, videos, documents, APKs or archives
* Pull down on the home screen to refresh recent files
''';

const sampleJson =
    '{\n  "app": "Burrow",\n  "platforms": ["android", "ios", "web"],\n  "features": ["search", "sort", "filter", "unzip", "pdf", "apk"]\n}\n';

/// Builds a small, valid single-page PDF with a correct cross-reference table.
Uint8List buildSamplePdf() {
  const content =
      'BT /F1 28 Tf 72 740 Td (Burrow) Tj ET\n'
      'BT /F1 14 Tf 72 700 Td (This PDF is rendered by the built-in viewer.) Tj ET\n'
      'BT /F1 14 Tf 72 676 Td (Pinch or scroll to zoom. Works on Android, iOS and web.) Tj ET\n';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R '
        '/Resources << /Font << /F1 5 0 R >> >> >>',
    '<< /Length ${content.length} >>\nstream\n${content}endstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buffer.length);
    buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = buffer.length;
  buffer.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    buffer.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  buffer.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return Uint8List.fromList(latin1.encode(buffer.toString()));
}

/// A 96x96 24-bit BMP gradient.
Uint8List buildSampleBitmap() {
  const w = 96, h = 96;
  const rowSize = w * 3; // 288, already 4-byte aligned
  const dataSize = rowSize * h;
  final bytes = ByteData(54 + dataSize);
  bytes.setUint8(0, 0x42);
  bytes.setUint8(1, 0x4D);
  bytes.setUint32(2, 54 + dataSize, Endian.little);
  bytes.setUint32(10, 54, Endian.little);
  bytes.setUint32(14, 40, Endian.little);
  bytes.setInt32(18, w, Endian.little);
  bytes.setInt32(22, h, Endian.little);
  bytes.setUint16(26, 1, Endian.little);
  bytes.setUint16(28, 24, Endian.little);
  bytes.setUint32(34, dataSize, Endian.little);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = 54 + y * rowSize + x * 3;
      bytes.setUint8(o, 240 - x); // blue
      bytes.setUint8(o + 1, 90 + y); // green
      bytes.setUint8(o + 2, 127 + x); // red
    }
  }
  return bytes.buffer.asUint8List();
}
