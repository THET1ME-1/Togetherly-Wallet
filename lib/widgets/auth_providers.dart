import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/strings.dart';

import '../services/oauth.dart';

/// Ряд круглых кнопок входа: Google, Яндекс, Apple.
///
/// Ровно тот же вид, что в Togetherly: три плоских круга в одну строку, внутри
/// фирменные знаки. Крупные кнопки в столбик занимали треть экрана и повторяли
/// друг друга словом «Продолжить», хотя выбор здесь — это выбор иконки.
///
/// Знаки нарисованы кодом: картинок чужих брендов в APK не держим, а рисунок
/// не расплывается на любом экране.
class AuthProviderRow extends StatelessWidget {
  const AuthProviderRow({super.key, required this.onPick, this.busy = false});

  final void Function(OAuthProvider provider) onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // Apple только на своих устройствах, как в Togetherly: там вход
    // спрашивается системным окном и работает, а веб-поток Apple обрывался
    // чаще, чем проходил.
    final providers = <OAuthProvider>[
      OAuthProvider.google,
      OAuthProvider.yandex,
      if (OAuthService.appleNative) OAuthProvider.apple,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final provider in providers)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: _Round(
              onTap: busy ? null : () => onPick(provider),
              tooltip: oauthProviderTitle(provider),
              child: switch (provider) {
                OAuthProvider.google => const GoogleGlyph(size: 22),
                OAuthProvider.yandex => const YandexGlyph(size: 26),
                OAuthProvider.apple => AppleGlyph(
                    size: 26,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              },
            ),
          ),
      ],
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.child, required this.onTap, required this.tooltip});

  final Widget child;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Плоский круг без рамки: та же тональная поверхность, что у полей.
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          // 52 — палец попадает, и три круга помещаются даже на 320 dp.
          child: SizedBox(width: 52, height: 52, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Знак Google: четыре дуги фирменных цветов и перекладина.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GooglePainter()),
      );
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final sw = r * 0.22;
    final arc = Rect.fromCircle(center: center, radius: r - sw / 2);

    double rad(double deg) => deg * math.pi / 180;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..isAntiAlias = true;

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arc, rad(28), rad(54), false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arc, rad(82), rad(90), false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arc, rad(172), rad(92), false, paint);

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arc, rad(264), rad(66), false, paint);

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTRB(r - sw * 0.15, r - sw / 2, r * 2 - sw * 0.5, r + sw / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}

/// Знак Яндекса: красный квадрат со скруглением и белая «Я».
class YandexGlyph extends StatelessWidget {
  const YandexGlyph({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(0xFFFC3F1D),
          borderRadius: BorderRadius.circular(size * 0.27),
        ),
        alignment: Alignment.center,
        child: Text(
          tr('meShort'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.62,
            height: 1,
          ),
        ),
      );
}

/// Знак Apple: системное яблоко, цвет идёт за темой.
class AppleGlyph extends StatelessWidget {
  const AppleGlyph({super.key, this.size = 26, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.apple, size: size, color: color);
}
