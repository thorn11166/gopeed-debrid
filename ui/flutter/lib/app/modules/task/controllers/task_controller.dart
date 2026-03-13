import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:gopeed/api/model/task.dart';

class TaskController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final tabIndex = 0.obs;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final selectTask = Rx<Task?>(null);
  late final TabController tabController;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      tabIndex.value = tabController.index;
    });
    if (kIsWeb) {
      BrowserContextMenu.disableContextMenu();
    }
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
    if (kIsWeb) {
      BrowserContextMenu.enableContextMenu();
    }
  }

  /// Switch to the Downloading tab (index 0) programmatically.
  void showDownloadingTab() {
    tabController.animateTo(0);
  }
}
