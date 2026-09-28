import 'file_category.dart';

/// A file or folder, independent of where it is stored (disk or memory).
class FileEntry {
  const FileEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;

  String get extension {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  FileCategory get category => isDirectory ? FileCategory.other : FileCategory.fromExtension(extension);

  bool get isHidden => name.startsWith('.');

  bool get isPdf => extension == 'pdf';
  bool get isApk => extension == 'apk';

  static const _textExtensions = {
    'txt',
    'md',
    'csv',
    'json',
    'xml',
    'html',
    'htm',
    'log',
    'yaml',
    'yml',
    'ini',
    'conf',
    'dart',
    'js',
    'ts',
    'css',
    'java',
    'kt',
    'py',
    'c',
    'cpp',
    'h',
    'swift',
    'sh',
    'properties',
    'gradle',
    'sql',
    'srt',
    'env',
    'toml',
    'rtf',
  };
  bool get isText => _textExtensions.contains(extension);

  static const _viewableImages = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'ico'};
  bool get isViewableImage => _viewableImages.contains(extension);

  /// Formats the built-in players handle on Android, iOS and modern browsers.
  /// Others (AVI, WMV, FLV...) open in another app. A file that still can't
  /// be decoded on a given device shows "Open with another app".
  static const _playableVideos = {'mp4', 'm4v', 'mov', 'webm', 'mkv', '3gp'};
  static const _playableAudio = {'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'oga', 'opus'};
  bool get isPlayableVideo => _playableVideos.contains(extension);
  bool get isPlayableAudio => _playableAudio.contains(extension);

  /// Archives we can list and extract ourselves.
  bool get isExtractable {
    final n = name.toLowerCase();
    return n.endsWith('.zip') ||
        n.endsWith('.jar') ||
        n.endsWith('.tar') ||
        n.endsWith('.tar.gz') ||
        n.endsWith('.tgz') ||
        n.endsWith('.tar.bz2') ||
        n.endsWith('.tbz2') ||
        n.endsWith('.tar.xz') ||
        n.endsWith('.txz') ||
        n.endsWith('.gz') ||
        n.endsWith('.bz2') ||
        n.endsWith('.xz');
  }

  @override
  bool operator ==(Object other) => other is FileEntry && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
