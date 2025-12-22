import 'dart:ui';

class PredictionTracker {
  Rect? _currentBox;
  Rect? _previousBox;
  Offset _velocity = Offset.zero;
  DateTime? _lastUpdateTime;
  bool _hasTarget = false;

  bool get hasTarget => _hasTarget;

  void reset() {
    _currentBox = null;
    _previousBox = null;
    _velocity = Offset.zero;
    _lastUpdateTime = null;
    _hasTarget = false;
  }

  void updateFromDetection(Rect detectedBox) {
    final now = DateTime.now();
    if (_previousBox == null || _currentBox == null) {
      _currentBox = detectedBox;
      _previousBox = detectedBox;
      _velocity = Offset.zero;
    } else {
      final previousCenter = _previousBox!.center;
      final detectedCenter = detectedBox.center;
      final dtSeconds = _lastUpdateTime != null
          ? now.difference(_lastUpdateTime!).inMilliseconds / 1000.0
          : 1 / 30;
      final safeDtSeconds = dtSeconds > 0 ? dtSeconds : 1 / 30;
      final rawVelocity =
          (detectedCenter - previousCenter) / safeDtSeconds;
      const alpha = 0.5;
      _velocity = Offset(
        alpha * rawVelocity.dx + (1 - alpha) * _velocity.dx,
        alpha * rawVelocity.dy + (1 - alpha) * _velocity.dy,
      );
      _previousBox = detectedBox;
      _currentBox = detectedBox;
    }

    _lastUpdateTime = now;
    _hasTarget = true;
  }

  Rect? predict(Duration delta) {
    if (!_hasTarget || _currentBox == null) {
      return null;
    }

    final deltaSeconds = delta.inMilliseconds / 1000.0;
    final currentCenter = _currentBox!.center;
    final predictedCenter = Offset(
      currentCenter.dx + _velocity.dx * deltaSeconds,
      currentCenter.dy + _velocity.dy * deltaSeconds,
    );

    final width = _currentBox!.width;
    final height = _currentBox!.height;

    final unclampedRect = Rect.fromCenter(
      center: predictedCenter,
      width: width,
      height: height,
    );

    return _clampRect(unclampedRect, width, height);
  }

  Rect _clampRect(Rect rect, double width, double height) {
    final safeWidth = width.clamp(0.0, 1.0) as double;
    final safeHeight = height.clamp(0.0, 1.0) as double;
    final maxLeft = (1.0 - safeWidth).clamp(0.0, 1.0) as double;
    final maxTop = (1.0 - safeHeight).clamp(0.0, 1.0) as double;
    final clampedLeft = rect.left.clamp(0.0, maxLeft) as double;
    final clampedTop = rect.top.clamp(0.0, maxTop) as double;
    return Rect.fromLTWH(clampedLeft, clampedTop, safeWidth, safeHeight);
  }
}

Rect lerpRect(Rect a, Rect b, double t) {
  final clampedT = t.clamp(0.0, 1.0) as double;
  return Rect.fromLTRB(
    _lerpDouble(a.left, b.left, clampedT),
    _lerpDouble(a.top, b.top, clampedT),
    _lerpDouble(a.right, b.right, clampedT),
    _lerpDouble(a.bottom, b.bottom, clampedT),
  );
}

double _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}
