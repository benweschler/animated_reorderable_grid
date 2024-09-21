import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'animation_controller_manager.dart';
import 'map_notifier.dart';
import 'reorderable_drag_notification.dart';
import 'utils.dart';

typedef ReorderItemProxyDecorator = Widget Function(
    Widget child, int index, Animation<double> animation);

const _kReorderAnimationCurve = Curves.easeOutQuint;

//TODO: rename variables named n
//TODO: change to multiple files to allow for private members?
class AnimatedReorderableGrid extends StatefulWidget {
  /// The number of items.
  final int length;

  /// The number of items in the cross axis.
  final int crossAxisCount;

  //TODO: add documentation to parameters
  final bool buildDefaultDragDetectors;
  final IndexedWidgetBuilder itemBuilder;
  final double rowHeight;
  final IndexedWidgetBuilder? rowBuilder;
  final List<(int row, int count)>? overriddenRowCounts;

  /// A header row to show before the rows of the grid containing reorderable
  /// items.
  ///
  /// If null, no header will appear before the grid.
  final Widget? header;

  /// A footer row to show after the rows of the grid containing reorderable
  /// items.
  ///
  /// If null, no footer will appear before the grid.
  final Widget? footer;

  /// A [Widget] that is overlaid on top of the rows of the grid, including the
  /// header and footer, if present.
  ///
  /// If null, no overlay will appear over the grid.
  final Widget? overlay;
  final ReorderItemProxyDecorator? proxyDecorator;
  final Object Function(int) keyBuilder;
  final ReorderCallback onReorder;

  /// Whether this is the primary scroll view associated with the parent
  /// PrimaryScrollController. See the 'primary' parameter of any built-in
  /// [Scrollable] widget for more information.
  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final double autoScrollerVelocityScalar;

  const AnimatedReorderableGrid({
    super.key,
    required this.length,
    required this.crossAxisCount,
    this.buildDefaultDragDetectors = true,
    required this.itemBuilder,
    required this.rowHeight,
    this.rowBuilder,
    this.overriddenRowCounts,
    this.header,
    this.footer,
    this.overlay,
    this.proxyDecorator,
    required this.keyBuilder,
    required this.onReorder,
    this.primary,
    this.physics,
    this.controller,
    double? autoScrollerVelocityScalar,
  }) : autoScrollerVelocityScalar =
            autoScrollerVelocityScalar ?? _kDefaultAutoScrollVelocityScalar;

  // An eyeballed value for a smooth scrolling experience.
  // This is the default velocity scalar used for SliverReorderableList.
  static const double _kDefaultAutoScrollVelocityScalar = 50;

  Widget _defaultRowBuilder() {
    return SizedBox.fromSize(size: Size.fromHeight(rowHeight));
  }

  Widget _defaultProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        elevation: lerpDouble(0, 8, animation.value)!,
        animationDuration: Duration.zero,
        color: Colors.transparent,
        child: child,
      ),
      child: child,
    );
  }

  @override
  State<AnimatedReorderableGrid> createState() =>
      _AnimatedReorderableGridState();
}

class _AnimatedReorderableGridState extends State<AnimatedReorderableGrid> {
  bool _isScrollable = true;

  bool _onReorderDrag(ReorderableDragNotification notification) {
    if (_isScrollable == notification.isParentScrollable) return true;

    setState(() => _isScrollable = notification.isParentScrollable);
    return true;
  }

  Widget _itemBuilder(BuildContext context, int index) {
    final item = widget.itemBuilder(context, index);

    return widget.buildDefaultDragDetectors
        ? ReorderableGridDragListener(index: index, child: item)
        : item;
  }

  @override
  Widget build(BuildContext context) {
    final int numRows = _numRows(
      widget.length,
      widget.overriddenRowCounts,
      widget.crossAxisCount,
    );

    return SingleChildScrollView(
      primary: widget.primary,
      physics:
          _isScrollable ? widget.physics : const NeverScrollableScrollPhysics(),
      controller: widget.controller,
      child: Stack(
        children: [
          Column(
            children: [
              if (widget.header != null) widget.header!,
              SizedBox(
                height: numRows * widget.rowHeight,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        for (int i = 0; i < numRows; i++)
                          widget.rowBuilder?.call(context, i) ??
                              widget._defaultRowBuilder(),
                      ],
                    ),
                    NotificationListener<ReorderableDragNotification>(
                      onNotification: _onReorderDrag,
                      child: _ReorderableGridBase(
                        length: widget.length,
                        crossAxisCount: widget.crossAxisCount,
                        rowHeight: widget.rowHeight,
                        overriddenRowCounts: widget.overriddenRowCounts,
                        itemBuilder: _itemBuilder,
                        proxyDecorator: widget.proxyDecorator ??
                            widget._defaultProxyDecorator,
                        autoScrollerVelocityScalar:
                            widget.autoScrollerVelocityScalar,
                        keyBuilder: widget.keyBuilder,
                        onReorder: widget.onReorder,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.footer != null) widget.footer!,
            ],
          ),
          if (widget.overlay != null)
            // Ensure that the overlay does not block gestures on the grid.
            Positioned.fill(
              child: IgnorePointer(
                child: widget.overlay!,
              ),
            ),
        ],
      ),
    );
  }
}

class _ReorderableGridBase extends StatefulWidget {
  final int length;
  final int crossAxisCount;
  final double rowHeight;
  final List<(int row, int count)>? overriddenRowCounts;
  final IndexedWidgetBuilder itemBuilder;
  final ReorderItemProxyDecorator proxyDecorator;
  final double autoScrollerVelocityScalar;
  final Object Function(int) keyBuilder;
  final ReorderCallback onReorder;

  const _ReorderableGridBase({
    required this.length,
    required this.crossAxisCount,
    required this.rowHeight,
    this.overriddenRowCounts,
    required this.itemBuilder,
    required this.proxyDecorator,
    required this.autoScrollerVelocityScalar,
    required this.keyBuilder,
    required this.onReorder,
  }) : assert(crossAxisCount > 0);

  @override
  State<_ReorderableGridBase> createState() => _ReorderableGridBaseState();

  static _ReorderableGridBaseState? maybeOf(context) {
    return context.findAncestorStateOfType<_ReorderableGridBaseState>();
  }
}

class _ReorderableGridBaseState extends State<_ReorderableGridBase>
    with TickerProviderStateMixin {
  _DragInfo? _dragInfo;
  int? _collisionIndex;
  Offset? _collisionDefaultCenter;
  OverlayEntry? _overlayEntry;
  MultiDragGestureRecognizer? _recognizer;
  int? _recognizerPointer;

  final Map<int, _ReorderableItemState> _items = {};

  /// The global offsets of each item due to being repositioned by a collision
  /// with the dragged item. Keys are the indices corresponding to each item.
  late final MapNotifier<int, Offset> _repositionOffsets = MapNotifier({
    for (int i = 0; i < widget.length; i++) i: Offset.zero,
  });

  final _repositionAnimationControllers = AnimationControllerManager<int>();

  late List<(int, int)> _overriddenRowBoundingIndices;

  @override
  void initState() {
    super.initState();

    if (widget.overriddenRowCounts == null) {
      _overriddenRowBoundingIndices = List.empty(growable: false);
    } else {
      _overriddenRowBoundingIndices = _precomputeBoundingIndices(
        widget.overriddenRowCounts!,
        widget.crossAxisCount,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _ReorderableGridBase oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.overriddenRowCounts == null) return;

    if (oldWidget.overriddenRowCounts != widget.overriddenRowCounts) {
      setState(() {
        _overriddenRowBoundingIndices = _precomputeBoundingIndices(
          widget.overriddenRowCounts!,
          widget.crossAxisCount,
        );
      });
    }
  }

  @override
  void dispose() {
    _repositionAnimationControllers.clear();
    super.dispose();
  }

  int _getCrossAxisCount(int row) {
    if (widget.overriddenRowCounts == null) return widget.crossAxisCount;

    final n = recordBinarySearch(
      widget.overriddenRowCounts!,
      row,
      transformer: (rowCount) => rowCount.$1,
    );
    return n >= 0 ? widget.overriddenRowCounts![n].$2 : widget.crossAxisCount;
  }

  int _getRowFromPosition(double y) {
    final numRows = _numRows(
      widget.length,
      widget.overriddenRowCounts,
      widget.crossAxisCount,
    );
    return max(y ~/ widget.rowHeight, 0).clamp(0, numRows - 1);
  }

  /// Get the center of a item in its default position.
  Offset _getDefaultCenter({
    required int index,
    required Size size,
    required double rowHeight,
  }) {
    final int row, column, crossAxisCount;
    if (widget.overriddenRowCounts?.isNotEmpty ?? false) {
      (row, column) = _getGridPosition(
        index: index,
        boundingIndices: _overriddenRowBoundingIndices,
        defaultCrossAxis: widget.crossAxisCount,
      );

      // If the item is in an overridden row, use the length of that row for the
      // cross axis count rather than the default value.
      final n = recordBinarySearch(
        widget.overriddenRowCounts!,
        row,
        transformer: (rowCount) => rowCount.$1,
      );
      crossAxisCount =
          n >= 0 ? widget.overriddenRowCounts![n].$2 : widget.crossAxisCount;
    } else {
      row = index ~/ widget.crossAxisCount;
      column = index % widget.crossAxisCount;
      crossAxisCount = widget.crossAxisCount;
    }

    final xPos = size.width / crossAxisCount * (1 / 2 + column);
    final yPos = rowHeight * (1 / 2 + row);
    return Offset(xPos, yPos);
  }

  /// Gets the row and column of the item at [index] when the cross axis count of
  /// at least one row was overridden from the provided default value.
  ///
  /// [boundingIndices] is a list of the initial and terminal indices of each
  /// overridden row, and must not be empty.
  (int row, int column) _getGridPosition({
    required int index,
    required List<(int, int)> boundingIndices,
    required int defaultCrossAxis,
  }) {
    if (boundingIndices.isEmpty) {
      throw ArgumentError(
        'At least one row must be overridden in order to call getGridPosition(), so boundingIndices must not be empty.',
        'boundingIndices',
      );
    }

    final n = binarySearchLEQ(boundingIndices, index,
        transformer: (element) => element.$2);

    final int row;
    final int column;
    if (n < 0) {
      row = index ~/ defaultCrossAxis;
      column = index % defaultCrossAxis;
    }
    // The LEQ index terminates an overridden row.
    else if (n > 0 && boundingIndices[n - 1].$1 == boundingIndices[n].$1) {
      // If the item is at the terminating index of a row
      if (index == boundingIndices[n].$2) {
        row = boundingIndices[n].$1;
        // The number of columns in an overridden row is the difference between
        // the terminating and initial indices.
        column = boundingIndices[n].$2 - boundingIndices[n - 1].$2;
      }
      // Else the item is in between overridden rows
      else {
        final interveningRows =
            ((index - boundingIndices[n].$2) / defaultCrossAxis).ceil();
        row = boundingIndices[n].$1 + interveningRows;
        // Column is calculated using the difference between the index and the
        // first index after the last terminating index, i.e. zero-based indexing
        // starting after the last overridden row.
        column = (index - (boundingIndices[n].$2 + 1)) % defaultCrossAxis;
      }
    }
    // Else the LEQ index is the initial index in an overridden row, and the item
    // is in an overridden row.
    else {
      row = boundingIndices[n].$1;
      final columnsInRow =
          boundingIndices[n + 1].$2 - boundingIndices[n].$2 + 1;
      column = (index - boundingIndices[n].$2) % columnsInRow;
    }

    return (row, column);
  }

  List<(int, int)> _precomputeBoundingIndices(
    List<(int, int)> overriddenRowCounts,
    int defaultCrossAxis,
  ) {
    final List<(int, int)> boundingIndices =
        List.filled(overriddenRowCounts.length * 2, (0, 0));
    for (int i = 0; i < overriddenRowCounts.length; i++) {
      final count = overriddenRowCounts[i];
      final int initial;
      if (i == 0) {
        initial = defaultCrossAxis * count.$1;
      } else {
        final int intermediaryRows =
            count.$1 - overriddenRowCounts[i - 1].$1 - 1;
        initial = boundingIndices[2 * i - 1].$2 +
            defaultCrossAxis * intermediaryRows +
            1;
      }

      boundingIndices[2 * i] = (count.$1, initial);
      boundingIndices[2 * i + 1] = (count.$1, initial + count.$2 - 1);
    }

    return boundingIndices;
  }

  void _registerItem(int index, _ReorderableItemState item) {
    _items[index] = item;
  }

  //TODO: doesn't account for unfilled last row
  List<int> _getIndicesInRow(int row) {
    final defaultIndices = List.generate(
      widget.crossAxisCount,
      (i) => row * widget.crossAxisCount + i,
    );

    if (widget.overriddenRowCounts == null) return defaultIndices;

    final n = binarySearchLEQ(
      widget.overriddenRowCounts!,
      row,
      transformer: (rowCount) => rowCount.$1,
    );

    // The row is before any overridden row.
    if (n < 0) {
      return defaultIndices;
    }
    // The row is an overridden row.
    else if (widget.overriddenRowCounts![n].$1 == row) {
      return List.generate(
        widget.overriddenRowCounts![n].$2,
        (i) => _overriddenRowBoundingIndices[2 * n].$2 + i,
      );
    }

    //TODO: not very clean
    // Else the row is after an overridden row.
    final int terminatingIndex;
    if (n > 0 &&
        _overriddenRowBoundingIndices[2 * n - 1].$1 ==
            _overriddenRowBoundingIndices[2 * n].$1) {
      terminatingIndex = _overriddenRowBoundingIndices[n].$2;
    } else {
      terminatingIndex = _overriddenRowBoundingIndices[2 * n + 1].$2;
    }

    // The number of rows between this row and the last overridden row.
    final interveningRows = row - widget.overriddenRowCounts![n].$1 - 1;

    return List.generate(
      widget.crossAxisCount,
      (i) => terminatingIndex + 1 + interveningRows * widget.crossAxisCount + i,
    );
  }

  void _unregisterItem(int index, _ReorderableItemState item) {
    // Ensure that items can't unregister items that aren't themselves. This is
    // required when two items unregister and re-register themselves when they
    // are swapped and both of their indices change. The first item will
    // unregister its old index and register its new index, but then the second
    // item will try to unregister its old index, which is now occupied by the
    // other swapped item (and not itself).
    if (_items[index] == item) {
      _items.remove(index);
    }
  }

  Future<void> _animateReposition(
    int index,
    Offset target,
    Direction direction,
  ) async {
    final repositionOffset = _repositionOffsets[index]!;
    // If there is no reposition controller, create it. This is the case if the
    // reposition was not animated forward, but needs to be animated in reverse,
    // which happens when a dragged item is released without swapping positions.
    // This is because when a dragged item is dropped without a collision, its
    // drag offset is converted to a reposition offset, which then causes the
    // item to be flagged as an extraneous reposition and animated back to its
    // default position.
    final AnimationController controller;
    if (_repositionAnimationControllers.containsKey(index)) {
      // Retain previously created animation controllers for a given index to
      // avoid having dangling controllers without a reference after reassigning
      // a new controller to that index.
      controller = _repositionAnimationControllers.get(index)!;

      // Redundant calls to animate forward or back while an animation is
      // already progressing in that direction will cause the animation to
      // progressively speed up or slow down.
      if (direction == Direction.forward &&
          (controller.status == AnimationStatus.forward ||
              controller.status == AnimationStatus.completed)) return;
      if (direction == Direction.reverse &&
          (controller.status == AnimationStatus.reverse ||
              controller.status == AnimationStatus.dismissed)) return;
    } else {
      controller = _createPositionAnimationController(
        position: repositionOffset,
        target: target,
        direction: direction,
      );
      _repositionAnimationControllers.set(index, controller);
    }

    // Implementation of the animation curve can't be done using a chained
    // CurveTween since the curve is traversed in reverse when the animation is
    // run in reverse.
    final offsetAnimation = Tween(
      begin: direction == Direction.forward ? repositionOffset : target,
      end: direction == Direction.forward ? target : repositionOffset,
    ).animate(controller);

    offsetAnimation
        .addListener(() => _repositionOffsets[index] = offsetAnimation.value);

    if (direction == Direction.forward) {
      await controller.animateTo(1, curve: _kReorderAnimationCurve);
    } else {
      int reverseDurationMs = _getScaledAnimationDuration(
        (_repositionOffsets[index]!.distance),
      ).inMilliseconds;

      // Using .then to de-register the controller (which disposes it) rather than
      // awaiting the completion of reverse() and then de-registering ensures that
      // if the direction of animation is changed before the animation completes,
      // the TickerFuture returned by animateBack() never completes and the
      // controller is not disposed while the new direction is still animating.
      await controller
          .animateBack(
            0,
            curve: _kReorderAnimationCurve,
            duration: Duration(milliseconds: reverseDurationMs),
          )
          .then((_) => _repositionAnimationControllers.remove(index));
    }
  }

  AnimationController _createPositionAnimationController({
    required Offset position,
    required Offset target,
    required Direction direction,
  }) {
    // The displacement between the current Offset and the target Offset.
    final displacement = Offset(
      target.dx - position.dx,
      target.dy - position.dy,
    );

    final controller = AnimationController(
      vsync: this,
      duration: _getScaledAnimationDuration(displacement.distance),
      value: direction == Direction.forward ? 0 : 1,
    );

    return controller;
  }

  /// Calculate the duration of a item animating between positions.
  ///
  /// This is scaled to a longer duration for animations between larger
  /// distances, which creates a more natural look and feel. This approximates
  /// standardizing the speed at which any item animates, rather than animating
  /// for a constant duration.
  Duration _getScaledAnimationDuration(double distance) {
    // The duration for the shortest distance traveled by an animating item,
    // which is the height of a row.
    const defaultDuration = 400;
    // The factor that the duration exponentially scales by as distance
    // increases.
    const scalar = 1 / 4;
    final milliseconds = (defaultDuration /
            pow(widget.rowHeight, scalar) *
            pow(distance, scalar))
        .floor();

    return Duration(milliseconds: milliseconds);
  }

  /// Initiate the dragging of the item at [index] that was started with
  /// the pointer down [event].
  ///
  /// The given [recognizer] will be used to recognize and start the drag
  /// item tracking and lead to either an item reorder, or a canceled drag.
  ///
  /// Most applications will not use this directly, but will wrap the item
  /// (or part of the item, like a drag handle) in either a
  /// [ReorderableDragStartListener] or [ReorderableDelayedDragStartListener]
  /// which call this method when they detect the gesture that triggers a drag
  /// start.
  void startItemDragReorder({
    required int index,
    required PointerDownEvent event,
    required MultiDragGestureRecognizer recognizer,
  }) {
    assert(0 <= index && index < widget.length);
    if (_dragInfo != null) {
      return;
    } else if (_recognizer != null && _recognizerPointer != event.pointer) {
      _recognizer!.dispose();
      _recognizer = null;
      _recognizerPointer = null;
    }

    if (_items.containsKey(index)) {
      final drag = dragStart(index);
      _recognizer = recognizer
        //TODO: bad. onStart is called immediately only because calling dragStart early disables scrolling of the parent scrollview and removes it from the GestureArena. If onStart is not called immediately and the user doesn't drag (only taps), the drag is never reset.
        ..onStart = ((_) => drag)
        ..addPointer(event);
      _recognizerPointer = event.pointer;
    } else {
      throw Exception('Attempting to start a drag on a non-visible item');
    }
  }

  Drag? dragStart(int index) {
    _setParentScrollability(false);

    _dragInfo ??= _DragInfo(
      item: _items[index]!,
      defaultCenter: _getDefaultCenter(
        index: index,
        size: context.size!,
        rowHeight: widget.rowHeight,
      ),
      proxyDecorator: widget.proxyDecorator,
      tickerProvider: this,
    );
    _dragInfo!.startDrag();

    _items[index]!.dragging = true;

    // Insert the overlay entry that displays the item proxy while dragging.
    final OverlayState overlay = Overlay.of(context, debugRequiredFor: widget);
    assert(_overlayEntry == null);
    final itemChild = widget.itemBuilder(context, index);
    final proxyChild = _dragInfo!.createProxy(itemChild);
    _overlayEntry = OverlayEntry(builder: (context) => proxyChild);
    overlay.insert(_overlayEntry!);

    return _ReorderableItemDrag(
      index: index,
      onUpdate: (details) => dragUpdate(index, details),
      onCancel: dragEnd,
      onEnd: dragEnd,
    );
  }

  void dragUpdate(int index, DragUpdateDetails details) {
    // Ignore drag events on repositioned items.
    if (_repositionOffsets[index] != Offset.zero) return;

    _setParentScrollability(false);
    _startAutoScrollIfNecessary();

    _dragInfo!.updateDrag(details.delta);
  }

  Future<void> dragEnd() async {
    // A dragged item should not be repositioned (i.e. its position should not
    // be affected by a reposition offset).
    assert(_repositionOffsets[_dragInfo!.index] == Offset.zero);

    _setParentScrollability(true);

    final Offset delta;
    if (_collisionIndex != null) {
      delta = _collisionDefaultCenter! -
          _dragInfo!.defaultCenter -
          _dragInfo!.dragOffset;
    } else {
      delta = _dragInfo!.dragOffset * -1;
    }

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: _getScaledAnimationDuration(delta.distance),
    );

    final offsetAnimation = Tween(
      begin: _dragInfo!.proxyPosition,
      end: _dragInfo!.proxyPosition + delta,
    ).chain(CurveTween(curve: _kReorderAnimationCurve)).animate(controller);

    offsetAnimation
        .addListener(() => _dragInfo!.proxyPosition = offsetAnimation.value);

    final proxyAnimationFuture = _dragInfo!.endDrag(delta);
    final proxyPositionFuture = controller.forward();

    await Future.wait([proxyAnimationFuture, proxyPositionFuture]);

    controller.dispose();
    _onDropCompleted();
  }

  void _onDropCompleted() {
    if (_collisionIndex != null) {
      // The reposition of the collided tile must be set to zero before its
      // index is swapped with the dragged tile.
      _repositionOffsets[_collisionIndex] = Offset.zero;
      widget.onReorder(_dragInfo!.index, _collisionIndex!);
      _collisionIndex = null;
      _collisionDefaultCenter = null;
    }

    setState(() => _resetDrag());
  }

  void _resetDrag() {
    _items[_dragInfo!.index]!.dragging = false;
    _dragInfo?.dispose();
    _dragInfo = null;
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
    _repositionAnimationControllers.clear();
    _autoScroller.stopAutoScroll();
  }

  void _updateCollision(int? collisionIndex, [Size? parentSize]) {
    _collisionIndex = collisionIndex;
    if (collisionIndex != null && parentSize != null) {
      _collisionDefaultCenter = _getDefaultCenter(
        index: collisionIndex,
        size: parentSize,
        rowHeight: widget.rowHeight,
      );
    } else {
      _collisionDefaultCenter = null;
    }
  }

  late final _autoScroller = EdgeDraggingAutoScroller(
    Scrollable.of(context),
    onScrollViewScrolled: _handleScrollableAutoScrolled,
    velocityScalar: widget.autoScrollerVelocityScalar,
  );

  void _startAutoScrollIfNecessary() {
    if (_dragInfo == null) return;

    // Continue scrolling if the drag is still in progress.
    //
    // Subtracting 30 from from the origen and adding 70 to the height adds slop
    // to the hit target for auto scrolling.
    _autoScroller.startAutoScrollIfNecessary(Rect.fromLTWH(
      _dragInfo!.proxyPosition.dx,
      _dragInfo!.proxyPosition.dy - 30,
      _dragInfo!.itemSize.width,
      _dragInfo!.itemSize.height + 70,
    ));
  }

  void _handleScrollableAutoScrolled() {
    if (_dragInfo ==
            null || /* TODO: CURRENT better marker for drag having ended than zero offset. it seems auto scrolling continues for a frame after drag ending.  */
        _dragInfo!.dragOffset == Offset.zero) return;

    _startAutoScrollIfNecessary();
    _dragInfo!.autoScrollPositions(context.findRenderObject() as RenderBox);
  }

  void _setParentScrollability(bool isParentScrollable) {
    ReorderableDragNotification(isParentScrollable).dispatch(context);
  }

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _ReorderableGridLayoutDelegate(
        ids: [for (int i = 0; i < widget.length; i++) widget.keyBuilder(i)],
        rowHeight: widget.rowHeight,
        dragInfo: _dragInfo,
        repositionOffsets: _repositionOffsets,
        repositionAnimationControllers: _repositionAnimationControllers,
        animatePosition: _animateReposition,
        updateCollision: _updateCollision,
        getDefaultCenter: _getDefaultCenter,
        getCrossAxisCount: _getCrossAxisCount,
        getRowFromPosition: _getRowFromPosition,
        //TODO: messy. this should be inside of getIndicesInRow. caller should not have the responsibility of checking this.
        getIndicesInRow: (row) {
          final indices = _getIndicesInRow(row);
          indices.removeWhere((index) => index >= widget.length);
          return indices;
        },
        scrollablePosition: Scrollable.of(context).position,
      ),
      children: [
        for (int index = 0; index < widget.length; index++)
          LayoutId(
            id: widget.keyBuilder(index),
            child: _ReorderableItem(
              index: index,
              gridState: this,
              child: widget.itemBuilder(context, index),
            ),
          ),
      ],
    );
  }
}

class _ReorderableGridLayoutDelegate extends MultiChildLayoutDelegate {
  final List ids;
  final double rowHeight;
  final _DragInfo? dragInfo;
  final MapNotifier<int, Offset> repositionOffsets;
  final AnimationControllerManager repositionAnimationControllers;
  final void Function(int, Offset, Direction) animatePosition;
  final void Function(int?, [Size?]) updateCollision;
  final Offset Function({
    required int index,
    required Size size,
    required double rowHeight,
  }) getDefaultCenter;
  final int Function(int) getCrossAxisCount;
  final List<int> Function(int) getIndicesInRow;
  final int Function(double) getRowFromPosition;
  final ScrollPosition scrollablePosition;

  final Map<int, Size> _itemSizes = {};

  _ReorderableGridLayoutDelegate({
    required this.ids,
    required this.rowHeight,
    required this.dragInfo,
    required this.repositionOffsets,
    required this.repositionAnimationControllers,
    required this.animatePosition,
    required this.updateCollision,
    required this.getDefaultCenter,
    required this.getCrossAxisCount,
    required this.getIndicesInRow,
    required this.getRowFromPosition,
    required this.scrollablePosition,
  }) : super(relayout: Listenable.merge([dragInfo, repositionOffsets]));

  @override
  void performLayout(Size parentSize) {
    for (int index = 0; index < ids.length; index++) {
      _itemSizes[index] =
          layoutChild(ids[index], BoxConstraints.loose(parentSize));
    }

    // The index of the item that the dragged item is colliding with. Null if no
    // collision.
    int? collisionIndex;

    for (int index = 0; index < ids.length; index++) {
      var center = getDefaultCenter(
        index: index,
        size: parentSize,
        rowHeight: rowHeight,
      );

      final repositionOffset = repositionOffsets[index]!;

      // A item cannot both currently be being dragged and be repositioned due
      // to a collision with a dragged item. Drag events are ignored for
      // repositioned items.
      if (dragInfo?.index == index && dragInfo?.dragOffset != Offset.zero) {
        center = center + dragInfo!.dragOffset;

        // Do not allow collisions when scrolling. This is especially important
        // during auto scrolling.
        final isScrolling = scrollablePosition.isScrollingNotifier.value;

        // Only animate a collision if the drag velocity is small to avoid very fast
        // and jittery animations if the user is dragging a item quickly across the
        // screen. This would lead to collisions that persist for only a few frames
        // causing items to animate forward and back in the span of a few
        // milliseconds, which is visually overwhelming.
        // 0.5 seems to be a good value that eliminates jitter while have no
        // perceptible lag during intended collisions/item swaps.
        //TODO: calibrate the threshold value and verify that velocity is independent of refresh rate
        if (!isScrolling && dragInfo!.dragVelocity.distanceSquared < 0.5) {
          collisionIndex = detectCollisions(center, parentSize);
          if (collisionIndex != null) {
            repositionCollidedItems(collisionIndex, parentSize);
          }
        }
      } else if (repositionOffset != Offset.zero) {
        center = center + repositionOffset;
      }

      final childSize = _itemSizes[index]!;

      // The child is positioned from its upper-left corner, not its center.
      final position = center.translate(
        -1 * childSize.width / 2,
        -1 * childSize.height / 2,
      );

      positionChild(ids[index], position);
    }

    // Checks if any items are repositioned that are not currently collided
    // with.
    final extraneousRepositions = repositionOffsets.entries.where(
        (entry) => entry.value != Offset.zero && entry.key != collisionIndex);

    // These items should be animated back to their original positions. This can
    // occur after children are positioned since reversing a reposition only
    // takes effect in subsequent frames.
    for (var entry in extraneousRepositions) {
      if (repositionAnimationControllers.get(entry.key)?.status ==
          AnimationStatus.reverse) continue;

      updateCollision(null);
      animatePosition(entry.key, Offset.zero, Direction.reverse);
    }
  }

  /// Returns the index of any items collided with, or null if no collisions
  /// occur.
  int? detectCollisions(Offset center, Size parentSize) {
    final collider = getCollider(dragInfo!.index, center);

    // The row index that the top and bottom edges of the currently dragged
    // item are touching, respectively.
    final rowFromTop = getRowFromPosition(collider.top);
    final rowFromBottom = getRowFromPosition(collider.bottom);

    // Only check collisions with items that are in the rows that the currently
    // dragged item is touching.
    final collisionIndicesToCheck = [
      ...getIndicesInRow(rowFromTop),
      if (rowFromBottom != rowFromTop) ...getIndicesInRow(rowFromBottom),
    ];
    collisionIndicesToCheck.remove(dragInfo!.index);

    final collidersToCheck = Map<int, Rect>.fromIterable(
      collisionIndicesToCheck,
      value: (index) => getCollider(
        index,
        getDefaultCenter(
          index: index,
          size: parentSize,
          rowHeight: rowHeight,
        ),
      ),
    );

    (int, double)? collision;
    for (var entry in collidersToCheck.entries) {
      // In the event of a collision, reposition the collided item.
      if (collider.overlaps(entry.value)) {
        final delta = collider.center - entry.value.center;

        // Distance squared is cheaper to compute than distance
        if (collision == null || delta.distanceSquared < collision.$2) {
          collision = (entry.key, delta.distanceSquared);
        }
      }
    }

    return collision?.$1;
  }

  void repositionCollidedItems(
    int collisionIndex,
    Size parentSize,
  ) {
    // If the collided item is currently animating to or finished animating to
    // its repositioned location, any subsequent calls to reposition it are
    // redundant.
    final collisionAnimationController =
        repositionAnimationControllers.get(collisionIndex);
    if (collisionAnimationController?.isForwardOrCompleted ?? false) return;

    updateCollision(collisionIndex, parentSize);

    // The default center of the collided item.
    final defaultCenter = getDefaultCenter(
      index: collisionIndex,
      size: parentSize,
      rowHeight: rowHeight,
    );
    // The center to reposition the collided item to, which is the center of
    // the dragged item.
    final repositionedCenter = dragInfo!.defaultCenter;

    // If the collided item is already in the current position, this does
    // nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      animatePosition(
        collisionIndex,
        Offset(
          repositionedCenter.dx - defaultCenter.dx,
          repositionedCenter.dy - defaultCenter.dy,
        ),
        Direction.forward,
      );
    });
  }

  Rect getCollider(int index, Offset center) {
    final childSize = _itemSizes[index]!;

    return Rect.fromCenter(
      center: center,
      width: childSize.width,
      height: childSize.height,
    );
  }

  @override
  // Relayout is handled by the listenable passed to the delegate's constructor.
  bool shouldRelayout(_ReorderableGridLayoutDelegate oldDelegate) => false;
}

class _ReorderableItem extends StatefulWidget {
  final int index;
  final _ReorderableGridBaseState gridState;
  final Widget child;

  const _ReorderableItem({
    required this.index,
    required this.gridState,
    required this.child,
  });

  @override
  State<_ReorderableItem> createState() => _ReorderableItemState();
}

class _ReorderableItemState extends State<_ReorderableItem> {
  bool _dragging = false;

  set dragging(bool dragging) {
    setState(() => _dragging = dragging);
  }

  int get index => widget.index;

  @override
  void initState() {
    super.initState();
    widget.gridState._registerItem(index, this);
  }

  @override
  void didUpdateWidget(covariant _ReorderableItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != index) {
      widget.gridState._unregisterItem(oldWidget.index, this);
      widget.gridState._registerItem(index, this);
    }
  }

  @override
  void deactivate() {
    widget.gridState._unregisterItem(index, this);
    super.deactivate();
  }

  @override
  void dispose() {
    widget.gridState._unregisterItem(index, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _dragging
        ? SizedBox.fromSize(size: widget.gridState._dragInfo?.itemSize)
        : widget.child;
  }
}

/// A wrapper widget that will recognize the start of a drag on the wrapped
/// widget by a [PointerDownEvent], and immediately initiate dragging the
/// wrapped item to a new location in an [AnimatedReorderableGrid].
class ReorderableGridDragListener extends StatelessWidget {
  /// The index of the associated item that will be dragged in the list.
  final int index;

  /// The widget for which the application would like to respond to a tap and
  /// drag gesture by starting a reordering drag on an
  /// [AnimatedReorderableGrid].
  final Widget child;

  /// Whether the [child] item can be dragged and moved in the list.
  ///
  /// If true, the item can be moved to another location in the list when the
  /// user taps on the child. If false, tapping on the child will be ignored.
  final bool enabled;

  const ReorderableGridDragListener({
    super.key,
    required this.index,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: enabled
          ? (PointerDownEvent event) => _startDragging(context, event)
          : null,
      child: child,
    );
  }

  /// Provides the gesture recognizer used to indicate the start of a reordering
  /// drag operation.
  ///
  /// By default this returns an [ImmediateMultiDragGestureRecognizer] but
  /// subclasses can use this to customize the drag start gesture.
  @protected
  MultiDragGestureRecognizer createRecognizer() {
    return ImmediateMultiDragGestureRecognizer(debugOwner: this);
  }

  void _startDragging(BuildContext context, PointerDownEvent event) {
    final DeviceGestureSettings? gestureSettings =
        MediaQuery.maybeGestureSettingsOf(context);
    final _ReorderableGridBaseState? grid =
        _ReorderableGridBase.maybeOf(context);
    grid?.startItemDragReorder(
      index: index,
      event: event,
      recognizer: createRecognizer()..gestureSettings = gestureSettings,
    );
  }
}

class _DragInfo extends ChangeNotifier {
  final int index;
  final Offset defaultCenter;
  final ReorderItemProxyDecorator proxyDecorator;
  final TickerProvider tickerProvider;

  /// The offset of the global origin from the origin of the dragged item's
  /// coordinate system.
  late final Offset globalOffset;
  late final Size itemSize;
  late final Ticker _ticker;

  Offset _dragOffset = Offset.zero;
  late final ValueNotifier<Offset> _proxyPositionNotifier =
      ValueNotifier(initialGlobalPosition);
  Offset _dragVelocity = Offset.zero;
  Duration _elapsed = Duration.zero;
  Duration _lastFrameTime = Duration.zero;
  AnimationController? _proxyAnimation;

  _DragInfo({
    required _ReorderableItemState item,
    required this.defaultCenter,
    required this.proxyDecorator,
    required this.tickerProvider,
  }) : index = item.index {
    final itemRenderBox = item.context.findRenderObject() as RenderBox;
    globalOffset = itemRenderBox.globalToLocal(Offset.zero);
    itemSize = item.context.size!;
    _ticker = tickerProvider.createTicker(_updateFrameTime)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _proxyAnimation?.dispose();
    super.dispose();
  }

  Offset get initialGlobalPosition => globalOffset * -1;

  Offset get dragOffset => _dragOffset;

  /// The velocity of the currently dragged item in units of pixels/millisecond.
  Offset get dragVelocity => _dragVelocity;

  Offset get proxyPosition => _proxyPositionNotifier.value;

  set proxyPosition(Offset position) => _proxyPositionNotifier.value = position;

  void startDrag() {
    _proxyAnimation = AnimationController(
      vsync: tickerProvider,
      duration: const Duration(milliseconds: 250),
    )..forward();
  }

  void updateDrag(Offset delta) {
    _proxyPositionNotifier.value += delta;
    _dragOffset += delta;
    _dragVelocity = delta / _lastFrameTime.inMilliseconds.toDouble();
    notifyListeners();
  }

  Future<void> endDrag(Offset offsetIncrement) async {
    _dragOffset += offsetIncrement;
    _dragVelocity = Offset.zero;
    notifyListeners();

    await _proxyAnimation!.reverse();
  }

  void autoScrollPositions(RenderBox gridRenderBox) {
    var defaultOrigin = defaultCenter.translate(
      -1 * itemSize.width / 2,
      -1 * itemSize.height / 2,
    );

    _dragOffset = gridRenderBox.globalToLocal(proxyPosition) - defaultOrigin;
    notifyListeners();
  }

  void _updateFrameTime(Duration elapsed) {
    _lastFrameTime = elapsed - _elapsed;
    _elapsed = elapsed;
  }

  Widget createProxy(Widget child) {
    return ValueListenableBuilder(
      valueListenable: _proxyPositionNotifier,
      builder: (context, proxyPosition, child) => _DragItemProxy(
        index: index,
        position: proxyPosition - _overlayOrigin(context),
        size: itemSize,
        proxyDecorator: proxyDecorator,
        proxyAnimation: _proxyAnimation!,
        child: child!,
      ),
      child: child,
    );
  }

  Offset _overlayOrigin(BuildContext context) {
    final OverlayState overlay =
        Overlay.of(context, debugRequiredFor: context.widget);
    final RenderBox overlayBox =
        overlay.context.findRenderObject()! as RenderBox;
    return overlayBox.localToGlobal(Offset.zero);
  }
}

class _DragItemProxy extends StatelessWidget {
  final int index;
  final Offset position;
  final Size size;
  final ReorderItemProxyDecorator proxyDecorator;
  final AnimationController proxyAnimation;
  final Widget child;

  const _DragItemProxy({
    required this.index,
    required this.position,
    required this.size,
    required this.proxyDecorator,
    required this.proxyAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      // Remove the top padding so that any nested list views in the item
      // won't pick up the scaffold's padding in the overlay.
      data: MediaQuery.of(context).removePadding(removeTop: true),
      child: Positioned(
        left: position.dx,
        top: position.dy,
        child: SizedBox.fromSize(
          size: size,
          child: proxyDecorator(child, index, proxyAnimation.view),
        ),
      ),
    );
  }
}

typedef _DragItemUpdate = void Function(DragUpdateDetails details);

class _ReorderableItemDrag extends Drag {
  final int index;
  final _DragItemUpdate onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;

  _ReorderableItemDrag({
    required this.index,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  @override
  void update(DragUpdateDetails details) => onUpdate(details);

  @override
  void end(DragEndDetails details) => onEnd();

  @override
  void cancel() => onCancel();
}

int _numRows(
  int length,
  List<(int, int)>? overriddenRowCounts,
  int crossAxisCount,
) {
  if (overriddenRowCounts == null) {
    return (length / crossAxisCount).ceil();
  } else {
    final overriddenItems =
        overriddenRowCounts.fold(0, (val, element) => val + element.$2);
    final defaultRows = ((length - overriddenItems) / crossAxisCount).ceil();
    return defaultRows + overriddenRowCounts.length;
  }
}
