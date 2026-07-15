import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/user_profile.dart';
import 'database_service.dart';

final DatabaseServiceImpl databaseServiceImpl = DatabaseServiceIo();

class DatabaseServiceIo implements DatabaseServiceImpl {
  static Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'columna.db');
    final directory = Directory(p.dirname(path));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        accountType TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        lastLoginAt TEXT
      )
    ''');
  }

  @override
  Future<int> createUser(UserProfile user) async {
    final existing = await getUserByEmail(user.email);
    if (existing != null) {
      throw StateError('Ya existe un usuario con este correo.');
    }
    final db = await _db;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  @override
  Future<UserProfile?> getUserByEmail(String email) async {
    final db = await _db;
    final result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isEmpty) return null;
    return UserProfile.fromMap(result.first);
  }

  @override
  Future<UserProfile?> login(String email, String password) async {
    final db = await _db;
    final result = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (result.isEmpty) return null;

    final user = UserProfile.fromMap(result.first);
    await db.update(
      'users',
      {'lastLoginAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return user;
  }

  @override
  Future<List<UserProfile>> getAllUsers() async {
    final db = await _db;
    final result = await db.query('users', orderBy: 'createdAt DESC');
    return result.map((row) => UserProfile.fromMap(row)).toList();
  }

  @override
  Future<void> clearAll() async {
    final db = await _db;
    await db.delete('users');
  }
}
