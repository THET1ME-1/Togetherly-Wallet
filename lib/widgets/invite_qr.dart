import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import 'package:qr/qr.dart';

import '../ui/theme/tm_colors.dart';

/// QR приглашения, нарисованный своим painter'ом.
///
/// Пакет `qr` считает только матрицу, рисунок наш: готовые виджеты кладут
/// чёрные квадраты, а в этой системе чёрного нет вовсе. Модули скруглены и
/// покрашены чернильным цветом, углы-искатели выделены — так код читается
/// сканером не хуже, а на экране выглядит частью приложения.
class InviteQr extends StatelessWidget {
  const InviteQr({super.key, required this.data, this.size = 220});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Средний уровень: код показывают с экрана телефона, бликов хватает,
    // а плотность при шести символах всё равно небольшая.
    final image = QrImage(QrCode(
      payload: QrPayload.fromString(data),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ));

    return Semantics(
      label: tr('inviteQrAlt'),
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // Единственное место, где фон белый в обеих темах: сканеры читают
          // тёмные модули по светлому полю, и «тёмная тема» здесь означала бы
          // код, который не считывается. Исключение из палитры осознанное.
          color: TmColors.paper,
          borderRadius: BorderRadius.circular(24),
        ),
        child: CustomPaint(painter: _QrPainter(image)),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  /// Чёрный по белому и никак иначе: код читают камерой, а не глазами, и
  /// «тёмная тема» здесь означала бы нечитаемый код.
  static const ink = TmColors.ink;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final cell = size.width / count;
    final dot = Paint()..color = ink;
    final radius = Radius.circular(cell * 0.32);

    for (var y = 0; y < count; y++) {
      for (var x = 0; x < count; x++) {
        if (!image.isDark(y, x)) continue;
        if (_inFinder(x, y, count)) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x * cell + cell * 0.1, y * cell + cell * 0.1,
                cell * 0.8, cell * 0.8),
            radius,
          ),
          dot,
        );
      }
    }

    // Три угла-искателя рисуются рамкой, а не россыпью точек: так сканер
    // находит код быстрее, а глаз сразу понимает, что это QR.
    for (final corner in [const Offset(0, 0), Offset(count - 7, 0), Offset(0, count - 7)]) {
      _finder(canvas, corner * cell, cell);
    }
  }

  bool _inFinder(int x, int y, int count) {
    bool within(int ox, int oy) => x >= ox && x < ox + 7 && y >= oy && y < oy + 7;
    return within(0, 0) || within(count - 7, 0) || within(0, count - 7);
  }

  void _finder(Canvas canvas, Offset origin, double cell) {
    final outer = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + cell * 0.5, origin.dy + cell * 0.5, cell * 6, cell * 6),
        Radius.circular(cell * 2),
      ),
      outer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + cell * 2, origin.dy + cell * 2, cell * 3, cell * 3),
        Radius.circular(cell),
      ),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
