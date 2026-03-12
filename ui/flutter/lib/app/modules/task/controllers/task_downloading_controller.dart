import '../../../../api/model/task.dart';
import 'task_list_controller.dart';

class TaskDownloadingController extends TaskListController {
  TaskDownloadingController()
      : super([
          Status.ready,
          Status.running,
          Status.pause,
          Status.wait,
          Status.error,
          Status.resolving,
        ], (a, b) {
          // resolving tasks float to the top alongside running tasks
          final aActive = a.status == Status.running || a.status == Status.resolving;
          final bActive = b.status == Status.running || b.status == Status.resolving;
          if (aActive && !bActive) return -1;
          if (!aActive && bActive) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
}
