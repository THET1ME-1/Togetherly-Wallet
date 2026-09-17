import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../logic/notice_match.dart';
import '../ui/theme/tm_scheme.dart';

/// Логотип банка.
///
/// Берём НАСТОЯЩУЮ иконку банковского приложения с этого телефона: она точная,
/// живёт вместе с редизайнами банка и не тащит чужие товарные знаки в APK.
/// Приложения нет — рисуем свой знак карты, а не первую букву в кружке: буква
/// в кружке выглядит заглушкой, потому что она и есть заглушка.
class SenderLogo extends StatelessWidget {
  const SenderLogo({
    super.key,
    required this.package,
    this.bytes,
    this.size = 38,
  });

  final String package;
  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.3;
    final logo = bytes;

    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _Mark(package: package, size: size),
        ),
      );
    }
    return _Mark(package: package, size: size);
  }
}

/// Свой знак: карта с полосой у кошельков и с чипом у банков. Тональная
/// поверхность вместо цветного кружка — как и всё остальное в приложении.
class _Mark extends StatelessWidget {
  const _Mark({required this.package, required this.size});

  final String package;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wallet = isWalletSender(package);
    final dark = theme.brightness == Brightness.dark;
    // Подложка всегда тональная: светлый лавандовый чип в тёмной теме
    // оказывался единственным белым пятном на экране. Кошелёк отличается
    // цветом самого знака, а не фоном.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: CustomPaint(
        painter: _CardPainter(
          color: wallet
              ? (dark ? context.tm.accent : context.tm.text)
              : scheme.onSurfaceVariant,
          wallet: wallet,
        ),
      ),
    );
  }
}

class _CardPainter extends CustomPainter {
  const _CardPainter({required this.color, required this.wallet});

  final Color color;
  final bool wallet;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final line = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;

    // Карта: рамка со скруглением, полоса сверху, чип слева внизу.
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, w * 0.3, w * 0.56, w * 0.4),
      Radius.circular(w * 0.07),
    );
    canvas.drawRRect(card, line);
    canvas.drawLine(
      Offset(w * 0.22, w * 0.42),
      Offset(w * 0.78, w * 0.42),
      line..strokeWidth = w * 0.07,
    );
    if (!wallet) {
      canvas.drawLine(
        Offset(w * 0.32, w * 0.58),
        Offset(w * 0.46, w * 0.58),
        line..strokeWidth = w * 0.055,
      );
    }
  }

  @override
  bool shouldRepaint(_CardPainter old) =>
      old.color != color || old.wallet != wallet;
}

/// Подпись банка одной строкой: имя из списка или имя пакета, если банк нам
/// незнаком. Чтобы не писать эту развилку в каждом месте.
String senderName(String package) => senderTitle(package);

/// Стиль подписи источника.
TextStyle senderStyle(BuildContext context) => TextStyle(
      fontFamily: AppTheme.bodyFont,
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );
