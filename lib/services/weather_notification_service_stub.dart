
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;
bool _permissionGranted = false;

Future<bool> requestNotificationPermission() async {
  try {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    if (!_initialized) {
      await _notifications.initialize(settings);
      _initialized = true;
    }

    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    _permissionGranted =
        await androidImplementation?.requestNotificationsPermission() ??
            false;

    return _permissionGranted;
  } catch (e) {
    return false;
  }
}

bool get notificationPermissionGranted => _permissionGranted;

Future<void> showNotification(
  String title,
  String message,
  String tag,
) async {
  try {
    if (!_initialized || !_permissionGranted) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'weathergpt_alerts',
      'Weather Alerts',
      channelDescription: 'Important weather alerts from WeatherGPT',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _notifications.show(
      tag.hashCode & 0x7fffffff,
      title,
      message,
      details,
    );
  } catch (_) {
    // Notification delivery may be unavailable.
  }
}
