import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'database_service.dart';

final DatabaseServiceImpl databaseServiceImpl = DatabaseServiceWeb();

class DatabaseServiceWeb implements DatabaseServiceImpl {
  static const _usersKey = 'columna_users';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<List<UserProfile>> _loadUsers() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_usersKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final List<dynamic> list = jsonDecode(jsonString) as List<dynamic>;
    return list.map((item) => UserProfile.fromMap(Map<String, Object?>.from(item as Map))).toList();
  }

  Future<void> _saveUsers(List<UserProfile> users) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(users.map((user) => user.toMap()).toList());
    await prefs.setString(_usersKey, jsonString);
  }

  @override
  Future<int> createUser(UserProfile user) async {
    final users = await _loadUsers();
    if (users.any((u) => u.email == user.email)) {
      throw StateError('Ya existe un usuario con este correo.');
    }
    final nextId = users.isEmpty ? 1 : (users.map((u) => u.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    final newUser = UserProfile(
      id: nextId,
      name: user.name,
      email: user.email,
      password: user.password,
      accountType: user.accountType,
      createdAt: user.createdAt,
    );
    users.add(newUser);
    await _saveUsers(users);
    return nextId;
  }

  @override
  Future<UserProfile?> getUserByEmail(String email) async {
    final users = await _loadUsers();
    for (final user in users) {
      if (user.email == email) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<UserProfile?> login(String email, String password) async {
    final users = await _loadUsers();
    UserProfile? user;
    for (final u in users) {
      if (u.email == email && u.password == password) {
        user = u;
        break;
      }
    }
    if (user == null) return null;
    final updatedUser = UserProfile(
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      accountType: user.accountType,
      createdAt: user.createdAt,
      lastLoginAt: DateTime.now(),
    );
    final updatedUsers = users.map((u) => u.id == updatedUser.id ? updatedUser : u).toList();
    await _saveUsers(updatedUsers);
    return updatedUser;
  }

  @override
  Future<List<UserProfile>> getAllUsers() async {
    return await _loadUsers();
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_usersKey);
  }
}
