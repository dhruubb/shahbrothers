import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the local demo database is stored.
abstract class LocalPersistence {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// JSON file in the app's documents directory (survives restarts).
class FileLocalPersistence implements LocalPersistence {
  FileLocalPersistence({this.fileName = 'shah_brothers_demo_db.json'});

  final String fileName;
  File? _file;

  Future<File> _target() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<String?> read() async {
    final f = await _target();
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  @override
  Future<void> write(String data) async {
    final f = await _target();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(data, flush: true);
    await tmp.rename(f.path); // atomic replace
  }

  @override
  Future<void> clear() async {
    final f = await _target();
    if (await f.exists()) await f.delete();
  }
}

/// In-memory store for tests.
class MemoryLocalPersistence implements LocalPersistence {
  String? data;
  int writes = 0;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String d) async {
    data = d;
    writes++;
  }

  @override
  Future<void> clear() async => data = null;
}
