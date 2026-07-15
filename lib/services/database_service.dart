import '../models/user_profile.dart';
import 'database_service_io.dart' if (dart.library.html) 'database_service_web.dart';

abstract class DatabaseServiceImpl {
  Future<int> createUser(UserProfile user);
  Future<UserProfile?> getUserByEmail(String email);
  Future<UserProfile?> login(String email, String password);
  Future<List<UserProfile>> getAllUsers();
  Future<void> clearAll();
}

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  final DatabaseServiceImpl _impl = databaseServiceImpl;

  Future<int> createUser(UserProfile user) => _impl.createUser(user);
  Future<UserProfile?> getUserByEmail(String email) => _impl.getUserByEmail(email);
  Future<UserProfile?> login(String email, String password) => _impl.login(email, password);
  Future<List<UserProfile>> getAllUsers() => _impl.getAllUsers();
  Future<void> clearAll() => _impl.clearAll();
}
