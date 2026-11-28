
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> requestNotificationPermission() async {
  try {
    if (web.Notification.permission == 'granted') {
      return true;
    }

    final permission =
        await web.Notification.requestPermission().toDart;

    return permission.toDart == 'granted';
  } catch (_) {
    return false;
  }
}

bool get notificationPermissionGranted {
  try {
    return web.Notification.permission == 'granted';
  } catch (_) {
    return false;
  }
}

void showNotification(
  String title,
  String message,
  String tag,
) {
  try {
    if (!notificationPermissionGranted) return;

    web.Notification(
      title,
      web.NotificationOptions(
        body: message,
        tag: tag,
      ),
    );
  } catch (_) {
    // Browser notifications may be unavailable or blocked.
  }
}
