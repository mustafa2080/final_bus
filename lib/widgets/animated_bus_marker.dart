import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// حالة الباص المؤثرة على لون الماركر
enum BusMarkerStatus {
  active, // نشط وبيتحرك - أخضر
  idle, // نشط بس متوقف/بطيء - أصفر
  inactive, // غير نشط - أحمر
}

/// ماركر باص احترافي متحرك (Custom Painted) مع دايرة نبض (pulse)
/// وحركة دوران حسب اتجاه السير (heading).
class AnimatedBusMarker extends StatefulWidget {
  final double heading;
  final BusMarkerStatus status;
  final String label;
  final double size;

  const AnimatedBusMarker({
    super.key,
    required this.heading,
    required this.status,
    required this.label,
    this.size = 56,
  });

  @override
  State<AnimatedBusMarker> createState() => _AnimatedBusMarkerState();
}

class _AnimatedBusMarkerState extends State<AnimatedBusMarker>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _headingController;
  late Animation<double> _headingAnimation;
  double _currentHeading = 0;

  @override
  void initState() {
    super.initState();
    _currentHeading = widget.heading;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _headingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _headingAnimation = Tween<double>(
      begin: _currentHeading,
      end: _currentHeading,
    ).animate(
      CurvedAnimation(parent: _headingController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBusMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heading != widget.heading) {
      // نختار أقصر مسار دوران (تجنّب اللف الطويل بين 350° و10° مثلاً)
      double delta = widget.heading - _currentHeading;
      delta = ((delta + 180) % 360 + 360) % 360 - 180;
      final target = _currentHeading + delta;

      _headingAnimation = Tween<double>(
        begin: _currentHeading,
        end: target,
      ).animate(
        CurvedAnimation(parent: _headingController, curve: Curves.easeInOut),
      );
      _currentHeading = target;
      _headingController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _headingController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case BusMarkerStatus.active:
        return const Color(0xFF34C759); // أخضر
      case BusMarkerStatus.idle:
        return const Color(0xFFFFB020); // أصفر
      case BusMarkerStatus.inactive:
        return const Color(0xFFE84D4D); // أحمر
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final double pulseSize = widget.size * 2.4;

    return SizedBox(
      width: pulseSize,
      height: pulseSize + 34, // مساحة إضافية للليبل فوق
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // ليبل اسم الطالب/الباص
          Positioned(
            top: 0,
            child: _BusLabel(text: widget.label, color: color),
          ),

          // دايرة النبض (pulse) - تشتغل فقط لو نشط
          if (widget.status != BusMarkerStatus.inactive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final t = _pulseController.value;
                return Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0) * 0.45,
                  child: Transform.scale(
                    scale: 0.55 + t * 0.9,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),

          // جسم الماركر نفسه مع الدوران حسب الاتجاه
          AnimatedBuilder(
            animation: _headingAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _headingAnimation.value * math.pi / 180,
                child: child,
              );
            },
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _BusMarkerPainter(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _BusLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.85)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// يرسم أيقونة باص شبه-واقعية بتدرّج لوني وظل وتفاصيل (شبابيك/عجل)
class _BusMarkerPainter extends CustomPainter {
  final Color color;

  _BusMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ظل قوي أسفل الماركر
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center.translate(0, 3), radius - 2, shadowPaint);

    // الدائرة الخلفية بتدرّج لوني (حسب الحالة)
    final bgRect = Rect.fromCircle(center: center, radius: radius);
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(color, Colors.white, 0.15)!,
          Color.lerp(color, Colors.black, 0.15)!,
        ],
      ).createShader(bgRect);
    canvas.drawCircle(center, radius, bgPaint);

    // حافة بيضاء
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;
    canvas.drawCircle(center, radius - borderPaint.strokeWidth / 2, borderPaint);

    // جسم الباص (مستطيل بحواف ناعمة) في المنتصف
    final busWidth = size.width * 0.56;
    final busHeight = size.height * 0.40;
    final busRect = Rect.fromCenter(
      center: center.translate(0, -size.height * 0.02),
      width: busWidth,
      height: busHeight,
    );
    final busRRect = RRect.fromRectAndRadius(
      busRect,
      Radius.circular(busHeight * 0.28),
    );

    final busBodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFEDEDED)],
      ).createShader(busRect);
    canvas.drawRRect(busRRect, busBodyPaint);

    // شبابيك الباص (خطين فاتحين)
    final windowPaint = Paint()..color = color.withOpacity(0.85);
    final windowHeight = busHeight * 0.34;
    final windowRect = Rect.fromCenter(
      center: busRect.center.translate(0, -busHeight * 0.10),
      width: busWidth * 0.72,
      height: windowHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(windowRect, Radius.circular(windowHeight * 0.3)),
      windowPaint,
    );
    // فاصل بين الشبابيك
    final dividerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.018;
    final dividerX = windowRect.left + windowRect.width * 0.5;
    canvas.drawLine(
      Offset(dividerX, windowRect.top),
      Offset(dividerX, windowRect.bottom),
      dividerPaint,
    );

    // عجلتين صغيرتين أسفل الجسم
    final wheelPaint = Paint()..color = const Color(0xFF2B2B2B);
    final wheelRadius = busHeight * 0.13;
    final wheelY = busRect.bottom - wheelRadius * 0.4;
    canvas.drawCircle(
      Offset(busRect.left + busWidth * 0.22, wheelY),
      wheelRadius,
      wheelPaint,
    );
    canvas.drawCircle(
      Offset(busRect.right - busWidth * 0.22, wheelY),
      wheelRadius,
      wheelPaint,
    );

    // سهم اتجاه صغير أعلى الماركر (يوضح الهيدينج)
    final arrowPaint = Paint()..color = Colors.white;
    final arrowPath = Path()
      ..moveTo(center.dx, center.dy - radius + size.width * 0.06)
      ..lineTo(center.dx - size.width * 0.08, center.dy - radius + size.width * 0.20)
      ..lineTo(center.dx + size.width * 0.08, center.dy - radius + size.width * 0.20)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _BusMarkerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// طبقة ماركر واحدة تتحرك بسلاسة بين نقطتين (from -> to) بدل ما تقفز مباشرة.
/// مفيدة لعرض حركة الباص على الخريطة بشكل طبيعي عند وصول موقع جديد.
class AnimatedMarkerPositionLayer extends StatefulWidget {
  final LatLng from;
  final LatLng to;
  final double width;
  final double height;
  final Widget child;
  final Duration duration;

  const AnimatedMarkerPositionLayer({
    super.key,
    required this.from,
    required this.to,
    required this.child,
    this.width = 140,
    this.height = 140,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedMarkerPositionLayer> createState() =>
      _AnimatedMarkerPositionLayerState();
}

class _AnimatedMarkerPositionLayerState
    extends State<AnimatedMarkerPositionLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late LatLng _animFrom;
  late LatLng _animTo;

  @override
  void initState() {
    super.initState();
    _animFrom = widget.from;
    _animTo = widget.to;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (_animFrom != _animTo) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMarkerPositionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.to != oldWidget.to) {
      _animFrom = oldWidget.to;
      _animTo = widget.to;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _lerp(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final point = _lerp(_animFrom, _animTo, _animation.value);
        return MarkerLayer(
          markers: [
            Marker(
              width: widget.width,
              height: widget.height,
              point: point,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}
