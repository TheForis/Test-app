import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/file_entry.dart';
import 'backend_factory_stub.dart'
    if (dart.library.io) 'backend_factory_io.dart'
    if (dart.library.js_interop) 'backend_factory_web.dart';

/// A starting point shown in the drawer / browser (Internal storage, Downloads...).
class StorageLocation {
  const StorageLocation({required this.name, required this.path, required this.icon, this.isRoot = false});

  final String name;
  final String path;
  final IconData icon;
  final bool isRoot;
}

enum AccessState { granted, denied, permanentlyDenied }

/// Everything the UI needs from a file system. Implemented by [IoStorageBackend]
/// on Android/iOS and by [MemoryStorageBackend] on the web (where browsers do
/// not expose the device's file system).
abstract class StorageBackend {
  static StorageBackend create() => createPlatformBackend();

  /// True when files live on a real device file system.
  bool get isDeviceStorage;

  /// True where the user can pick files from outside the app (web, iOS).
  bool get supportsImport;

  /// True on Android, where APK files can be installed.
  bool get canInstallApps;

  Future<AccessState> checkAccess();
  Future<AccessState> requestAccess();
  Future<void> openAccessSettings();

  Future<String> rootPath();
  Future<List<StorageLocation>> locations();

  Future<List<FileEntry>> list(String directory, {bool showHidden = false});

  /// Walks the whole storage and returns every file (not folders).
  Future<List<FileEntry>> scanAll({bool showHidden = false});

  Future<FileEntry?> stat(String path);
  Future<Uint8List> readBytes(String path);
  Future<void> writeBytes(String path, Uint8List bytes);
  Future<void> createFolder(String parent, String name);
  Future<void> delete(FileEntry entry);
  Future<FileEntry> rename(FileEntry entry, String newName);
  Future<FileEntry> copy(FileEntry entry, String targetDirectory);
  Future<FileEntry> move(FileEntry entry, String targetDirectory);

  /// Extracts [archive] into a new folder next to it and returns that folder's path.
  Future<String> extract(FileEntry archive);

  /// Lets the user pick files and copies them into [targetDirectory].
  /// Returns the number of imported files.
  Future<int> importFiles(String targetDirectory);

  String join(String a, String b);
  String parentOf(String path);
  String nameOf(String path);
}
