import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notifications_service.dart';

export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationsService.instance.initialize();
  runApp(const MyApp());
}
