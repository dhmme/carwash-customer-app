import 'package:flutter/material.dart';
import '../worker_localization.dart';

// Self-contained illustrations stay available without external image requests.
enum AddOnPicture { tire, wax, mats, other }

AddOnPicture addOnPicture(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.contains('كفر') || normalized.contains('إطار') ||
      normalized.contains('اطار') || normalized.contains('tire')) {
    return AddOnPicture.tire;
  }
  if (normalized.contains('واكس') || normalized.contains('wax')) {
    return AddOnPicture.wax;
  }
  if (normalized.contains('وطاي') || normalized.contains('تكييس') ||
      normalized.contains('floor mat')) {
    return AddOnPicture.mats;
  }
  return AddOnPicture.other;
}

class WorkerAddOns extends StatelessWidget {
  const WorkerAddOns({super.key, required this.addOns, required this.localizations});
  final List<Map<String, dynamic>> addOns;
  final WorkerLocalizations localizations;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 16, bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xff103544),
      border: Border.all(color: const Color(0xff48c9e8), width: 1.5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(localizations.additionalServices,
          style: const TextStyle(color: Colors.white, fontSize: 19,
              fontWeight: FontWeight.bold)),
      if (addOns.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(localizations.noAdditionalServices,
                style: const TextStyle(color: Color(0xffc4dce5))))
      else
        ...addOns.map((addOn) {
          final name = addOn['name']?.toString() ?? '';
          final translated = localizations.serviceName(name);
          return Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xff194858),
                borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Semantics(label: translated, image: true,
                child: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: CustomPaint(size: const Size(84, 84),
                      painter: _ServiceIllustration(addOnPicture(name))))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(translated, style: const TextStyle(color: Colors.white,
                      fontSize: 19, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${localizations.quantity}: ${addOn['quantity'] ?? 1}',
                      style: const TextStyle(color: Color(0xff8ce3f5),
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ])),
            ]),
          );
        }),
    ]),
  );
}

class _ServiceIllustration extends CustomPainter {
  const _ServiceIllustration(this.picture);
  final AddOnPicture picture;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final paint = Paint();
    void rect(Rect r, Color color, [double radius = 6]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)),
          paint..color = color..style = PaintingStyle.fill);
    }
    void circle(Offset c, double radius, Color color) {
      canvas.drawCircle(c, radius, paint..color = color..style = PaintingStyle.fill);
    }
    const blue = Color(0xff177ba6);
    const cyan = Color(0xff39c2e5);
    const dark = Color(0xff142b3b);
    rect(const Rect.fromLTWH(0, 0, 100, 100), const Color(0xffe8f7fc), 0);
    switch (picture) {
      case AddOnPicture.tire:
        circle(const Offset(45, 54), 34, dark);
        circle(const Offset(45, 54), 23, const Color(0xff738c9b));
        circle(const Offset(45, 54), 17, const Color(0xffd5e7ef));
        circle(const Offset(45, 54), 7, blue);
        for (final p in [const Offset(45, 41), const Offset(32, 54),
            const Offset(58, 54), const Offset(45, 67)]) {
          circle(p, 3, dark);
        }
        rect(const Rect.fromLTWH(70, 44, 14, 34), cyan, 3);
        rect(const Rect.fromLTWH(73, 37, 8, 10), blue, 2);
        _sparkle(canvas, const Offset(73, 22), 11, blue);
        _sparkle(canvas, const Offset(18, 19), 7, cyan);
      case AddOnPicture.wax:
        rect(const Rect.fromLTWH(29, 27, 42, 58), blue, 10);
        rect(const Rect.fromLTWH(37, 18, 26, 14), cyan, 3);
        rect(const Rect.fromLTWH(36, 45, 28, 25), Colors.white, 5);
        _sparkle(canvas, const Offset(50, 57), 9, cyan);
        circle(const Offset(77, 26), 7, const Color(0xff93dfef));
        circle(const Offset(20, 42), 5, const Color(0xff93dfef));
        circle(const Offset(79, 44), 4, cyan);
      case AddOnPicture.mats:
        rect(const Rect.fromLTWH(14, 20, 34, 62), cyan, 8);
        rect(const Rect.fromLTWH(50, 20, 34, 62), cyan, 8);
        rect(const Rect.fromLTWH(18, 25, 26, 51), dark, 6);
        rect(const Rect.fromLTWH(54, 25, 26, 51), dark, 6);
        for (var y = 35.0; y < 72; y += 9) {
          rect(Rect.fromLTWH(23, y, 16, 3), const Color(0xff6c8798), 1);
          rect(Rect.fromLTWH(59, y, 16, 3), const Color(0xff6c8798), 1);
        }
        final bag = Path()..moveTo(11, 14)..lineTo(88, 14)..lineTo(91, 87)
          ..lineTo(8, 87)..close();
        canvas.drawPath(bag, paint..color = const Color(0xff76d8ef)
          ..style = PaintingStyle.stroke..strokeWidth = 3);
        canvas.drawLine(const Offset(14, 10), const Offset(86, 10), paint);
        canvas.drawLine(const Offset(17, 25), const Offset(30, 70),
            paint..color = Colors.white..strokeWidth = 3);
      case AddOnPicture.other:
        circle(const Offset(50, 50), 30, blue);
        rect(const Rect.fromLTWH(45, 32, 10, 36), Colors.white, 3);
        rect(const Rect.fromLTWH(32, 45, 36, 10), Colors.white, 3);
    }
    canvas.restore();
  }
  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path()..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * .3, center.dy - radius * .3)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * .3, center.dy + radius * .3)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * .3, center.dy + radius * .3)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * .3, center.dy - radius * .3)..close();
    canvas.drawPath(path, Paint()..color = color);
  }
  @override
  bool shouldRepaint(_ServiceIllustration oldDelegate) => picture != oldDelegate.picture;
}
