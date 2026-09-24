import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  static const _androidChannelId = 'work_im_messages_v2';
  static const _androidChannelName = '工作消息';
  static const _androidChannelDescription = '企业沟通消息通知';
  static const _androidChannel = AndroidNotificationChannel(
    _androidChannelId,
    _androidChannelName,
    description: _androidChannelDescription,
    importance: Importance.max,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _notificationsEnabled = true;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings: settings);
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    _notificationsEnabled =
        await androidPlugin?.requestNotificationsPermission() ?? true;
    _initialized = true;
  }

  Future<bool> showMessage({
    required String title,
    required String body,
  }) async {
    await init();
    if (!_notificationsEnabled) return false;
    const android = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      ticker: '新消息',
    );
    const darwin = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: darwin);
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: details,
    );
    return true;
  }
}
