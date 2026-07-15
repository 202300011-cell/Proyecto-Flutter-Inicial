import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class LocalFileService {
  LocalFileService._();
  static final LocalFileService instance = LocalFileService._();

  static const _notesKey = 'columna_local_notes';

  Future<String> readText(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_notesKey) ?? '';
  }

  Future<void> writeText(String filename, String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, content);
  }

  Future<void> appendText(String filename, String content) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_notesKey) ?? '';
    await prefs.setString(_notesKey, '$existing\n$content');
  }
}
