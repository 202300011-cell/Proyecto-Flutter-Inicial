import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
  NotificationsService._();

  static final NotificationsService instance = NotificationsService._();

  static const _channelId = 'columna_channel';
  static const _channelName = 'Columna';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInitializationSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidInitializationSettings);

    try {
      await _plugin.initialize(settings: initializationSettings);
    } catch (_) {
      // Ignored; the app will still continue and the notification call can be retried.
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Notificaciones del sistema para la app Columna',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> showNotification({required String title, required String body}) async {
    await initialize();
    final permissionGranted = await requestPermissionIfNeeded();
    if (!permissionGranted) {
      return false;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Notificaciones del sistema para la app Columna',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);
      await _plugin.show(
        id: 0,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
