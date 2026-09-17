import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/haptics.dart';
import '../services/lock.dart';

/// Замок на вход.
///
/// Экран во весь лист, без шапки и без выхода: пока код не введён, за ним
/// ничего нет. Клавиатура СВОЯ, а не системная — системная на этом экране
/// показывает подсказки, буквы и историю ввода, а здесь нужны десять цифр и
/// ничего больше.
///
/// Точки ввода нарисованы тем же языком, что счёт до потолка: залитый круг —
/// введённая цифра, кольцо — пустое место. Одна форма на всё приложение
/// читается без объяснений.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.lock,
    this.setup = false,
    this.onDone,
  });

  final LockService lock;

  /// Заведение кода: спрашиваем дважды, чтобы человек не заперся опечаткой.
  final bool setup;

  /// Что делать, когда код принят. В режиме замка это снятие блокировки, в
  /// режиме заведения — возврат на экран настроек.
  final VoidCallback? onDone;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  static const _length = 4;

  String _pin = '';
  String _first = '';
  bool _wrong = false;

  /// Пока код проверяется, клавиатура молчит. Иначе быстрые нажатия
  /// набирают следующий код ПОВЕРХ проверяемого, и второй ввод сравнивается
  /// сам с собой (поймано тестом заведения кода).
  bool _busy = false;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.setup) _tryBiometrics();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Спросить отпечаток.
  ///
  /// Касание отзывается ВИБРАЦИЕЙ, и это не украшение: палец в этот момент
  /// лежит на датчике, а глаза — не на экране. Без отклика человек не знает,
  /// нажалось ли, и жмёт второй раз (просьба человека 17.09.2026). Удача
  /// отзывается ещё раз, коротко: замок открылся.
  Future<void> _tryBiometrics({bool byHand = false}) async {
    if (!widget.lock.biometrics) return;
    if (byHand) Tap.pick();
    final ok = await widget.lock.unlockByBiometrics();
    if (!ok) {
      // Отпечаток не признали — короткий отказ пальцу, а код никуда не делся.
      if (byHand) Tap.warn();
      return;
    }
    Tap.done();
    if (mounted) widget.onDone?.call();
  }

  void _press(String digit) {
    if (_busy || _pin.length >= _length) return;
    // Щелчок на каждую цифру: экран без него ощущается неживым, а попасть в
    // клавишу не глядя — обычное дело.
    Tap.pick();
    setState(() {
      _pin += digit;
      _wrong = false;
    });
    if (_pin.length == _length) _submit();
  }

  void _erase() {
    if (_busy || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _wrong = false;
    });
  }

  Future<void> _submit() async {
    // Пауза, чтобы последняя точка успела залиться: без неё экран отвечает
    // раньше, чем человек увидел свой ввод.
    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    _busy = false;

    if (widget.setup) {
      if (_first.isEmpty) {
        setState(() {
          _first = _pin;
          _pin = '';
        });
        return;
      }
      if (_first == _pin) {
        await widget.lock.setPin(_pin);
        if (mounted) widget.onDone?.call();
        return;
      }
      // Не совпало — начинаем сначала, а не просим «ещё раз повторить»:
      // человек уже не помнит, что набрал в первый раз.
      _fail();
      setState(() {
        _first = '';
        _pin = '';
      });
      return;
    }

    if (widget.lock.unlock(_pin)) {
      Tap.done();
      widget.onDone?.call();
      return;
    }
    _fail();
    setState(() => _pin = '');
  }

  void _fail() {
    setState(() => _wrong = true);
    _shake.forward(from: 0);
    Tap.warn();
  }

  String get _title {
    if (!widget.setup) return _wrong ? tr('lockWrong') : tr('lockTitle');
    if (_wrong) return tr('lockMismatch');
    return _first.isEmpty ? tr('lockNewTitle') : tr('lockRepeatTitle');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            children: [
              if (widget.setup)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Myna.chevronLeft),
                  ),
                ),
              const Spacer(),
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Myna.lock, size: 27, color: scheme.onSurface),
              ),
              const SizedBox(height: 18),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.4,
                  color: _wrong ? scheme.error : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 22),
              // Ряд точек вздрагивает при ошибке: движение говорит «не тот
              // код» быстрее любой надписи и не занимает места на экране.
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  final dx = t == 0 ? 0.0 : math.sin(t * math.pi * 4) * 9 * (1 - t);
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: _Dots(
                  filled: _pin.length,
                  total: _length,
                  wrong: _wrong,
                ),
              ),
              const Spacer(),
              _Pad(
                onDigit: _press,
                onErase: _erase,
                onBiometrics: !widget.setup && widget.lock.biometrics
                    ? () => _tryBiometrics(byHand: true)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Точки ввода: залитая — введённая цифра.
class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.total, required this.wrong});

  final int filled;
  final int total;
  final bool wrong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = wrong ? scheme.error : scheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? ink : Colors.transparent,
              border: Border.all(
                color: i < filled ? ink : scheme.outlineVariant,
                width: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}

/// Цифровая клавиатура.
///
/// Клавиша — круг в 72 точки: палец попадает в неё не глядя, а правило
/// системы про минимальную цель в 44 здесь перекрыто с запасом.
class _Pad extends StatelessWidget {
  const _Pad({required this.onDigit, required this.onErase, this.onBiometrics});

  final ValueChanged<String> onDigit;
  final VoidCallback onErase;
  final VoidCallback? onBiometrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget key(String digit) => _Key(
          onTap: () => onDigit(digit),
          child: Text(
            digit,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 25,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final d in row) key(d)],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Отпечаток стоит слева от нуля: справа его задевали бы стиранием.
            onBiometrics == null
                ? const _Key(onTap: null, child: SizedBox.shrink())
                : _Key(
                    onTap: onBiometrics,
                    flat: true,
                    child: Icon(Myna.faceId, size: 26, color: scheme.onSurface),
                  ),
            key('0'),
            _Key(
              onTap: onErase,
              flat: true,
              child: Icon(Myna.delete, size: 24, color: scheme.onSurface),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child, this.flat = false});

  final VoidCallback? onTap;
  final Widget child;

  /// Служебная клавиша: без заливки. Цифры — блоки, отпечаток и стирание —
  /// знаки: так ряд не выглядит двенадцатью одинаковыми кнопками.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Material(
        color: flat || onTap == null
            ? Colors.transparent
            : scheme.surfaceContainerHigh,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}
