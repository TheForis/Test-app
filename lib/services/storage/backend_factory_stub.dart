import 'memory_backend.dart';
import 'storage_backend.dart';

StorageBackend createPlatformBackend() => MemoryStorageBackend();
