import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:columna/app.dart';
import 'package:columna/models/user_profile.dart';
import 'package:columna/services/api_service.dart';
import 'package:columna/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('registering a user persists and allows login', () async {
    await DatabaseService.instance.clearAll();

    final createdId = await DatabaseService.instance.createUser(
      UserProfile(
        name: 'Ana García',
        email: 'ana@gmail.com',
        password: '123456',
        accountType: 'Personal',
        createdAt: DateTime.now(),
      ),
    );

    expect(createdId, greaterThan(0));

    final user = await DatabaseService.instance.login('ana@gmail.com', '123456');
    expect(user, isNotNull);
    expect(user!.email, 'ana@gmail.com');
    expect(user.name, 'Ana García');
  });

  test('duplicate email registration is rejected', () async {
    await DatabaseService.instance.clearAll();

    await DatabaseService.instance.createUser(
      UserProfile(
        name: 'Ana García',
        email: 'ana@gmail.com',
        password: '123456',
        accountType: 'Personal',
        createdAt: DateTime.now(),
      ),
    );

    expect(
      () => DatabaseService.instance.createUser(
        UserProfile(
          name: 'Otra Persona',
          email: 'ana@gmail.com',
          password: '654321',
          accountType: 'Trabajo',
          createdAt: DateTime.now(),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('ApiService parses a remote post payload', () {
    final post = ApiService.parsePost({
      'id': 1,
      'userId': 7,
      'title': 'Hola desde la API',
      'body': 'Contenido de ejemplo',
    });

    expect(post.id, 1);
    expect(post.title, 'Hola desde la API');
    expect(post.body, 'Contenido de ejemplo');
  });

  testWidgets('home screen shows the notification settings entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyHomePage(
          user: UserProfile(
            name: 'Ana García',
            email: 'ana@gmail.com',
            password: '123456',
            accountType: 'Personal',
            createdAt: DateTime.now(),
          ),
          themeValue: 0.2,
          skyColor: const Color(0xFF87CEEB),
          onThemeChanged: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
