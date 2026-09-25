import 'package:flutter/material.dart';

/// High level buckets used for the home cards, filters and icons.
enum FileCategory {
  image('Images', Icons.image_rounded, [Color(0xFF7F5AF0), Color(0xFFB794F6)]),
  video('Videos', Icons.movie_rounded, [Color(0xFFEF4565), Color(0xFFFF8BA7)]),
  audio('Audio', Icons.music_note_rounded, [Color(0xFFFF8906), Color(0xFFFFC46B)]),
  document('Documents', Icons.description_rounded, [Color(0xFF3DA9FC), Color(0xFF90CDF4)]),
  apk('Apps (APK)', Icons.android_rounded, [Color(0xFF2CB67D), Color(0xFF7BE0AD)]),
  archive('Archives', Icons.folder_zip_rounded, [Color(0xFFE53170), Color(0xFFF687B3)]),
  other('Other', Icons.insert_drive_file_rounded, [Color(0xFF64748B), Color(0xFF94A3B8)]);

  const FileCategory(this.label, this.icon, this.gradient);

  final String label;
  final IconData icon;
  final List<Color> gradient;

  Color get color => gradient.first;

  static const _image = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'svg',
    'ico',
    'tif',
    'tiff',
    'avif',
  };
  static const _video = {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', 'flv', 'wmv', 'm4v', 'mpeg', 'mpg', 'ts'};
  static const _audio = {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'opus', 'wma', 'amr', 'mid', 'midi'};
  static const _document = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'odt',
    'ods',
    'odp',
    'rtf',
    'txt',
    'md',
    'csv',
    'json',
    'xml',
    'html',
    'htm',
    'log',
    'epub',
    'yaml',
    'yml',
    'ini',
    'conf',
  };
  static const _apk = {'apk', 'apks', 'xapk', 'apkm'};
  static const _archive = {'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'bz2', 'tbz2', 'xz', 'txz', 'jar'};

  static FileCategory fromExtension(String ext) {
    final e = ext.toLowerCase();
    if (_image.contains(e)) return image;
    if (_video.contains(e)) return video;
    if (_audio.contains(e)) return audio;
    if (_document.contains(e)) return document;
    if (_apk.contains(e)) return apk;
    if (_archive.contains(e)) return archive;
    return other;
  }
}
