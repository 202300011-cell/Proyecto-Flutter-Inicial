import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalFileService {
  LocalFileService._();
  static final LocalFileService instance = LocalFileService._();

  Future<Directory> get _appDirectory async {
    if (kIsWeb) {
      throw UnsupportedError('La lectura/escritura de archivos no está disponible en la web.');
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<File> _localFile(String filename) async {
    final directory = await _appDirectory;
    final path = p.join(directory.path, filename);
    return File(path);
  }

  Future<String> readText(String filename) async {
    final file = await _localFile(filename);
    return await file.exists() ? await file.readAsString() : '';
  }

  Future<void> writeText(String filename, String content) async {
    final file = await _localFile(filename);
    await file.writeAsString(content, flush: true);
  }

  Future<void> appendText(String filename, String content) async {
    final file = await _localFile(filename);
    await file.writeAsString(content, mode: FileMode.append, flush: true);
  }
}
