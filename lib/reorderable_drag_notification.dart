import 'package:flutter/widgets.dart';

class ReorderableDragNotification extends Notification {
  final bool isParentScrollable;

  ReorderableDragNotification(this.isParentScrollable);
}
