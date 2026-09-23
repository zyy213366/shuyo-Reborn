import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef ScheduleWeekBuilder =
    Widget Function(BuildContext context, int week, double days, int firstDay);

class ScheduleGesturePager extends StatefulWidget {
  const ScheduleGesturePager({
    super.key,
    required this.week,
    required this.maxWeek,
    required this.visibleDays,
    required this.onWeekChanged,
    required this.onVisibleDaysChanged,
    required this.builder,
    this.showControls = true,
    this.minWeek = 1,
  });
  final int week;
  final int maxWeek;
  final int minWeek;
  final int visibleDays;
  final ValueChanged<int> onWeekChanged;
  final ValueChanged<int> onVisibleDaysChanged;
  final ScheduleWeekBuilder builder;
  final bool showControls;

  @override
  State<ScheduleGesturePager> createState() => _ScheduleGesturePagerState();
}

class _ScheduleGesturePagerState extends State<ScheduleGesturePager>
    with SingleTickerProviderStateMixin {
  late final PageController _pages;
  late final AnimationController _zoom;
  late double _days;
  double _zoomFrom = 7;
  double _zoomTo = 7;
  double _pinchDays = 7;
  double _startPixels = 0;
  double _dragDx = 0;
  Drag? _pageDrag;
  int _targetWeek = 1;
  int _gestureWeek = 1;
  int _visibleWeek = 1;
  int _firstDay = 1;
  bool _interacting = false;
  bool _animatingPage = false;
  int _settleGeneration = 0;

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: widget.week - widget.minWeek);
    _days = widget.visibleDays.toDouble();
    _zoomTo = _days;
    _targetWeek = widget.week;
    _visibleWeek = widget.week;
    _zoom =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(
          () => setState(() {
            _days =
                _zoomFrom +
                (_zoomTo - _zoomFrom) *
                    Curves.easeOutCubic.transform(_zoom.value);
          }),
        );
  }

  @override
  void didUpdateWidget(covariant ScheduleGesturePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.week != widget.week && widget.week != _visibleWeek) ||
        oldWidget.minWeek != widget.minWeek) {
      // A calendar selection is external; page-change acknowledgements are not.
      // Select distant weeks directly, without rendering intervening pages.
      _settleGeneration++;
      _animatingPage = false;
      _targetWeek = widget.week;
      _visibleWeek = widget.week;
      _pages.jumpToPage(widget.week - widget.minWeek);
    }
    if (!_interacting &&
        (oldWidget.visibleDays != widget.visibleDays ||
            _zoomTo != widget.visibleDays.toDouble())) {
      _animateDays(widget.visibleDays.toDouble());
    }
  }

  void _animateDays(double days) {
    _zoomFrom = _days;
    _zoomTo = days;
    if (days == 7) _firstDay = 1;
    _zoom.forward(from: 0);
  }

  void _start() {
    _settleGeneration++;
    _gestureWeek = _animatingPage
        ? _targetWeek
        : ((_pages.page ?? 0).round() + widget.minWeek);
    _animatingPage = false;
    _interacting = true;
    _startPixels =
        (_gestureWeek - widget.minWeek) * _pages.position.viewportDimension;
    _dragDx = 0;
    (_pages.position as ScrollPositionWithSingleContext)
        .goIdle(); // Take over the exact offset of the old animation.
    _pageDrag = _pages.position.drag(
      DragStartDetails(),
      () => _pageDrag = null,
    );
    setState(() {});
  }

  void _drag(double dx) {
    final previous = _dragDx;
    _dragDx = dx;
    final delta = dx - previous;
    _pageDrag?.update(
      DragUpdateDetails(
        delta: Offset(delta, 0),
        primaryDelta: delta,
        globalPosition: Offset.zero,
      ),
    );
  }

  void _pinchStart() {
    if (!_interacting) _start();
    _zoom.stop();
    _pinchDays = _days;
    (_pages.position as ScrollPositionWithSingleContext).goIdle();
    _pageDrag = null;
    // A second finger cancels a partially dragged week before zooming.
    _pages.jumpTo(_startPixels);
  }

  void _pinch(double scale) {
    setState(() {
      _days = (_pinchDays / scale).clamp(5.0, 7.0);
      if (_days > 5.05) _firstDay = 1;
    });
  }

  void _end(bool pinched, double velocity, bool cancelled) {
    _interacting = false;
    // Disposing the drag directly avoids cancel() starting a ballistic rebound
    // before the intended snap. Continue from the currently rendered pixels.
    (_pages.position as ScrollPositionWithSingleContext).goIdle();
    _pageDrag = null;
    if (pinched) {
      final target = cancelled ? widget.visibleDays : (_days < 6 ? 5 : 7);
      _animateDays(target.toDouble());
      if (!cancelled && target != widget.visibleDays) {
        widget.onVisibleDaysChanged(target);
      }
    } else {
      final moved =
          _dragDx.abs() >
              (_pages.position.viewportDimension * .06).clamp(18.0, 30.0) ||
          velocity.abs() > 350;
      final direction = velocity.abs() > 350 ? velocity : _dragDx;
      final target = !cancelled && moved
          ? _gestureWeek + (direction < 0 ? 1 : -1)
          : _gestureWeek;
      _settle(target.clamp(widget.minWeek, widget.maxWeek), velocity: velocity);
    }
  }

  Future<void> _settle(int week, {double velocity = 0}) async {
    final generation = ++_settleGeneration;
    _targetWeek = week;
    if (!_pages.hasClients) return;
    final current = _pages.page ?? (widget.week - widget.minWeek).toDouble();
    final distance = (current - (week - widget.minWeek)).abs();
    final duration = velocity.abs() > 350
        ? (distance * _pages.position.viewportDimension / velocity.abs() * 1500)
              .clamp(100.0, 260.0)
              .round()
        : (180 + distance * 70).clamp(180.0, 300.0).round();
    setState(() => _animatingPage = true);
    await _pages.animateToPage(
      week - widget.minWeek,
      duration: Duration(milliseconds: duration),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || generation != _settleGeneration) return;
    setState(() => _animatingPage = false);
    if (week != _visibleWeek) _pageChanged(week - widget.minWeek);
  }

  void _pageChanged(int page) {
    final week = page + widget.minWeek;
    if (week == _visibleWeek) return;
    _visibleWeek = week;
    widget.onWeekChanged(week);
  }

  @override
  void dispose() {
    _pageDrag?.cancel();
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.showControls)
        SizedBox(
          key: const ValueKey('schedule-controls'),
          height: 36,
          child: Row(
            children: [
              IconButton(
                tooltip: '上一周',
                padding: EdgeInsets.zero,
                onPressed:
                    (_animatingPage ? _targetWeek : widget.week) >
                        widget.minWeek
                    ? () => _settle(
                        (_animatingPage ? _targetWeek : widget.week) - 1,
                      )
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              IconButton(
                tooltip: '下一周',
                padding: EdgeInsets.zero,
                onPressed:
                    (_animatingPage ? _targetWeek : widget.week) <
                        widget.maxWeek
                    ? () => _settle(
                        (_animatingPage ? _targetWeek : widget.week) + 1,
                      )
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
              const Spacer(),
              if (_days < 5.05)
                TextButton(
                  key: const ValueKey('five-day-range'),
                  onPressed: () => setState(
                    () => _firstDay = _firstDay == 3 ? 1 : _firstDay + 1,
                  ),
                  child: Text(['周一–周五', '周二–周六', '周三–周日'][_firstDay - 1]),
                ),
              TextButton(
                onPressed: () {
                  final days = widget.visibleDays == 7 ? 5 : 7;
                  _animateDays(days.toDouble());
                  widget.onVisibleDaysChanged(days);
                },
                child: Text('${widget.visibleDays}天'),
              ),
            ],
          ),
        ),
      Expanded(
        child: RawGestureDetector(
          key: const ValueKey('schedule-gestures'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            _ScheduleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  _ScheduleGestureRecognizer
                >(
                  _ScheduleGestureRecognizer.new,
                  (instance) => instance
                    ..onStart = _start
                    ..onDrag = _drag
                    ..onPinchStart = _pinchStart
                    ..onPinch = _pinch
                    ..onEnd = _end,
                ),
          },
          child: AbsorbPointer(
            absorbing: _interacting || _animatingPage,
            child: PageView.builder(
              key: const ValueKey('schedule-weeks'),
              controller: _pages,
              allowImplicitScrolling: true,
              onPageChanged: _pageChanged,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.maxWeek - widget.minWeek + 1,
              itemBuilder: (context, index) => widget.builder(
                context,
                index + widget.minWeek,
                _days,
                _firstDay,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Competes with taps and the grid's native vertical scroll. Horizontal movement
/// or a second pointer wins; a vertical single-finger drag yields to scrolling.
/// Once pinching starts, lifting just one finger cannot turn it into a week drag.
class _ScheduleGestureRecognizer extends OneSequenceGestureRecognizer {
  VoidCallback? onStart;
  ValueChanged<double>? onDrag;
  VoidCallback? onPinchStart;
  ValueChanged<double>? onPinch;
  void Function(bool pinched, double velocity, bool cancelled)? onEnd;
  final _points = <int, Offset>{};
  Offset _origin = Offset.zero;
  VelocityTracker? _velocity;
  bool _active = false;
  bool _pinched = false;
  bool _cancelled = false;
  double _span = 1;

  double get _distance => (_points.values.first - _points.values.elementAt(1))
      .distance
      .clamp(1.0, double.infinity);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _points[event.pointer] = event.localPosition;
    if (_points.length == 1) {
      _origin = event.localPosition;
      _velocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.localPosition);
    } else if (_points.length == 2 && !_pinched) {
      _span = _distance;
      _pinched = true;
      resolve(GestureDisposition.accepted);
      if (!_active) {
        _active = true;
        onStart?.call();
      }
      onPinchStart?.call();
    } else if (_active) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _points[event.pointer] = event.localPosition;
      if (_pinched) {
        if (_points.length >= 2) onPinch?.call(_distance / _span);
      } else {
        _velocity?.addPosition(event.timeStamp, event.localPosition);
        final delta = event.localPosition - _origin;
        if (!_active && delta.distance > kTouchSlop) {
          if (delta.dx.abs() > delta.dy.abs()) {
            resolve(GestureDisposition.accepted);
            _active = true;
            onStart?.call();
          } else {
            resolve(GestureDisposition.rejected);
            return;
          }
        }
        if (_active) onDrag?.call(delta.dx);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _cancelled |= event is PointerCancelEvent;
      _points.remove(event.pointer);
      if (!_active) resolve(GestureDisposition.rejected);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _points.remove(pointer);
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (_active) {
      onEnd?.call(
        _pinched,
        _velocity?.getVelocity().pixelsPerSecond.dx ?? 0,
        _cancelled,
      );
    }
    _active = false;
    _pinched = false;
    _cancelled = false;
    _points.clear();
  }

  @override
  String get debugDescription => 'schedule horizontal drag / pinch';
}
