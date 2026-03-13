import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/api.dart';
import '../../api/model/task.dart';
import '../../util/util.dart';
import '../modules/app/controllers/app_controller.dart';

class NotificationService extends GetxService {
  Timer? _timer;
  final Map<String, Status> _previousStatus = {};

  final AppController appController = Get.find<AppController>();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void onInit() {
    super.onInit();
    _initNotifications();
    _startPolling();
  }

  Future<void> _initNotifications() async {
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final LinuxInitializationSettings initializationSettingsLinux =
        LinuxInitializationSettings(
      defaultActionName: 'Open notification',
      defaultIcon: AssetsLinuxIcon('assets/icon/icon.png'),
    );

    String? windowsIconPath;
    try {
      if (Util.isWindows()) {
        final byteData = await rootBundle.load('assets/icon/icon.ico');
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/notification_icon.ico');
        await file.writeAsBytes(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        windowsIconPath = file.path;
      }
    } catch (e) {
      // Ignore
    }

    final WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
      appName: 'Gopeed',
      appUserModelId: 'com.gopeed.gopeed',
      guid: '3c1bf3f4-3d91-4eaa-a33f-8705e71cf1ce', // unique guid
      iconPath: windowsIconPath,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: initializationSettingsWindows,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Request Android 13+ notification permission
    if (Util.isAndroid()) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final config = appController.downloaderConfig.value;
        // On desktop, respect the desktopNotification toggle.
        // On mobile, always show debrid cache-complete notifications.
        final desktopNotificationsEnabled =
            Util.isDesktop() && config.extra.desktopNotification;
        final mobileNotificationsEnabled = Util.isMobile();
        if (!desktopNotificationsEnabled && !mobileNotificationsEnabled) {
          return;
        }

        final tasks = await getTasks([
          Status.ready,
          Status.running,
          Status.pause,
          Status.wait,
          Status.error,
          Status.done,
          Status.resolving,
        ]);

        for (var task in tasks) {
          final prevStatus = _previousStatus[task.id];
          final currentStatus = task.status;

          if (prevStatus != null && prevStatus != currentStatus) {
            if (currentStatus == Status.done) {
              _showNotification(
                title: 'notificationTaskDone'.tr,
                body: task.name,
              );
            } else if (currentStatus == Status.error) {
              _showNotification(
                title: 'notificationTaskError'.tr,
                body: task.name,
              );
            } else if (prevStatus == Status.resolving &&
                (currentStatus == Status.running ||
                    currentStatus == Status.ready ||
                    currentStatus == Status.wait)) {
              // Debrid finished caching — download is starting.
              _showNotification(
                title: 'notificationDebridCached'.tr,
                body: task.name,
              );
            }
          }
          _previousStatus[task.id] = currentStatus;
        }

        // Clean up deleted tasks from map
        final currentTaskIds = tasks.map((t) => t.id).toSet();
        _previousStatus
            .removeWhere((id, status) => !currentTaskIds.contains(id));
      } catch (e) {
        // Ignored
      }
    });
  }

  int _notificationId = 0;

  Future<void> _showNotification(
      {required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'gopeed_debrid',
      'Gopeed Downloads',
      channelDescription: 'Download progress and debrid cache notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      id: _notificationId++,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
