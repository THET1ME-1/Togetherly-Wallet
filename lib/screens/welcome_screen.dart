import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../services/oauth.dart';
import '../services/session.dart';
import '../ui/theme/tm_scheme.dart';
import '../widgets/auth_providers.dart';
import '../design/accents.dart';
import '../widgets/card_tile.dart';
import '../widgets/grid_backdrop.dart';
import '../widgets/money_text.dart';

/// Единственный экран до входа: карты, обещание и одна кнопка.
///
/// Формы почты отдельным экраном больше нет. Человек нажимает «Начать», карты
/// уезжают вверх, и на их месте проступают поля — низ остаётся на месте,
/// кнопка меняет слово. Так вход ощущается продолжением экрана, а не новой
/// страницей, куда его увели («зачем всё вокруг», 13.09.2026).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.account});

  final Session account;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

/// Что показано в верхней половине: карты, регистрация или вход.
enum _Step { intro, register, signIn }

/// Какое поле не заполнено: его линия краснеет.
enum _Bad { none, name, email, password }

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  _Step _step = _Step.intro;

  /// Ход перехода: 0 — карты, 1 — форма. Карты разъезжаются влево и вправо,
  /// а форма наплывает из глубины — «как будто влетаешь в середину»
  /// (13.09.2026). `AnimatedSwitcher` так не умеет: он показывал обе половины
  /// разом, и поля просвечивали сквозь карты.
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    reverseDuration: const Duration(milliseconds: 520),
  );

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _hidden = true;
  bool _busy = false;
  String? _error;
  _Bad _bad = _Bad.none;

  @override
  void dispose() {
    _swap.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _go(_Step step) {
    setState(() {
      _step = step;
      _error = null;
      _bad = _Bad.none;
    });
    if (step == _Step.intro) {
      _swap.reverse();
    } else {
      _swap.forward();
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_step == _Step.intro) {
      _go(_Step.register);
      return;
    }
    // Клавиатура сдвигает разметку, и палец промахивается мимо поля: пустое
    // поле — наш случай, а не повод спрашивать сервер.
    if (_step == _Step.register && _name.text.trim().isEmpty) {
      setState(() {
        _error = tr('authNeedName');
        _bad = _Bad.name;
      });
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() {
        _error = tr('authFillBoth');
        _bad = _Bad.email;
      });
      return;
    }
    if (_password.text.isEmpty) {
      setState(() {
        _error = tr('authFillBoth');
        _bad = _Bad.password;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _bad = _Bad.none;
    });
    try {
      if (_step == _Step.register) {
        await widget.account.register(_email.text, _password.text, _name.text);
      } else {
        await widget.account.signIn(_email.text, _password.text);
      }
    } on SessionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Вход провайдером. Аккаунт ТОТ ЖЕ, что в Togetherly.
  Future<void> _withProvider(OAuthProvider provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.account.signInWith(provider);
    } on OAuthCancelled {
      // Человек закрыл окно провайдера — это не ошибка.
    } on SessionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = trf('authProviderFailed', [oauthProviderTitle(provider)]));
      }
      debugPrint('oauth ${oauthProviderKey(provider)} failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ширина карты на сцене: та же, что была у `_Scene`.
  static double _cardWidth(double width) => (width - 30).clamp(250.0, 340.0);

  String get _action => switch (_step) {
        _Step.intro => tr('welcomeStart'),
        _Step.register => tr('authRegister'),
        _Step.signIn => tr('authSignIn'),
      };

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final width = MediaQuery.sizeOf(context).width;
    final big = width < 360 ? 25.0 : 28.0;

    return Scaffold(
      backgroundColor: tm.bg,
      body: Stack(children: [
        // Фон-сетка: пустой чёрный лист человек отверг прямо («пустой экран,
        // мне не нравится», 13.09.2026). Рисунок лежит ассетом и в светлой
        // теме переворачивается в тёмные точки по белому.
        Positioned.fill(child: GridBackdrop(dark: tm.dark)),
        SafeArea(
        child: Padding(
          // Клавиатуру отбивает САМ Scaffold (`resizeToAvoidBottomInset`), и
          // добавлять её высоту здесь второй раз нельзя: экран переполнялся
          // ровно на этот избыток — «BOTTOM OVERFLOWED BY 29 PIXELS» на живом
          // эмуляторе 17.09.2026, жёлто-чёрной лентой поверх кнопки входа.
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
          child: Column(children: [
            Expanded(
              child: AnimatedBuilder(
                animation: _swap,
                builder: (context, _) {
                  final t = Curves.easeInOutCubic.transform(_swap.value);
                  return Stack(alignment: Alignment.center, children: [
                    // Карты разъезжаются в стороны и тают. Уехавшие наверх
                    // выглядели побегом, а не сменой сцены.
                    if (t < 0.999)
                      IgnorePointer(
                        ignoring: t > 0.02,
                        child: Opacity(
                          opacity: (1 - t * 1.4).clamp(0.0, 1.0),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _Fan(card: _cardWidth(width), away: t),
                            ),
                          ),
                        ),
                      ),
                    // Про общий аккаунт человек узнаёт на первом экране, иначе
                    // заводит второй. Строка гаснет вместе с картами.
                    if (t < 0.999)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Opacity(
                          opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                          child: _Quiet(
                            text: tr('authOneAccount'),
                            brand: true,
                            onTap: t > 0.02 ? null : _openApps,
                          ),
                        ),
                      ),
                    // Форма наплывает из глубины: человек влетает в середину.
                    if (t > 0.001)
                      IgnorePointer(
                        ignoring: t < 0.98,
                        child: Opacity(
                          opacity: ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * t,
                            child: LayoutBuilder(builder: (context, box) {
                              // Сцена забирает ТО, ЧТО ОСТАЛОСЬ от полей:
                              // прокрутки на этом экране нет, а плашки,
                              // которым не хватило места, не рисуются вовсе
                              // (14.09.2026).
                              final need =
                                  (_step == _Step.register ? 3 : 2) * 68 + 92;
                              final room =
                                  (box.maxHeight - need).clamp(0.0, 300.0);
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (room > 96)
                                    SizedBox(
                                      height: room,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.bottomCenter,
                                        child: _Bits(width: width),
                                      ),
                                    ),
                                  const SizedBox(height: 20),
                            // Поля собраны БЛАНКОМ: подпись сверху, ввод
                            // крупно, тонкая линия снизу. Три серых бруска
                            // подряд человек назвал ужасом (13.09.2026) — и
                            // был прав: иерархии в них не было никакой.
                            AutofillGroup(
                              child: Column(children: [
                                if (_step == _Step.register) ...[
                                  _Field(
                                    controller: _name,
                                    hint: tr('authName'),
                                    capitalize: true,
                                    textInputAction: TextInputAction.next,
                                    autofill: const [AutofillHints.name],
                                    bad: _bad == _Bad.name,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _Field(
                                  controller: _email,
                                  hint: tr('authEmail'),
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofill: const [AutofillHints.email],
                                  bad: _bad == _Bad.email,
                                ),
                                const SizedBox(height: 10),
                                _Field(
                                  controller: _password,
                                  hint: tr('authPassword'),
                                  obscure: _hidden,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                  autofill: [
                                    _step == _Step.register
                                        ? AutofillHints.newPassword
                                        : AutofillHints.password,
                                  ],
                                  bad: _bad == _Bad.password,
                                  trailing: IconButton(
                                    onPressed: () =>
                                        setState(() => _hidden = !_hidden),
                                    icon: Icon(_hidden ? Myna.eye : Myna.eyeOff,
                                        size: 20),
                                    tooltip:
                                        tr(_hidden ? 'authShow' : 'authHide'),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 24),
                            // Приложением можно пользоваться и без аккаунта.
                            // Строка живёт ЗДЕСЬ, а не внизу: низ экрана при
                            // переходе не шевелится вовсе.
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _Quiet(
                                text: tr('authSkip'),
                                onTap: _busy ? null : widget.account.stayLocal,
                              ),
                            ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                  ]);
                },
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: _step == _Step.intro
                    ? RichText(
                        key: const ValueKey('slogan'),
                        text: TextSpan(children: [
                          TextSpan(
                            text: tr('welcomeTitle'),
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontSize: big,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                              letterSpacing: -0.5,
                              color: tm.text,
                            ),
                          ),
                          TextSpan(
                            // Вторая половина фразы серым: цвета в системе
                            // нет, а ударение поставить надо — светлотой.
                            text: '\n${tr('welcomeTitleSecond')}',
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontSize: big,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                              letterSpacing: -0.5,
                              color: tm.muted,
                            ),
                          ),
                        ]),
                      )
                    : Column(
                        key: ValueKey(_step),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tr(_step == _Step.register
                                ? 'authRegisterTitle'
                                : 'authSignInTitle'),
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontSize: big,
                              fontWeight: FontWeight.w800,
                              height: 1.18,
                              letterSpacing: -0.5,
                              color: tm.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr(_step == _Step.register
                                ? 'authRegisterNote'
                                : 'authSignInNote'),
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 13.5,
                              height: 1.35,
                              color: tm.muted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            // Место под ошибку ЗАНЯТО всегда: без этого низ экрана
            // подпрыгивал при неверном пароле («уезжает наверх, если код
            // неверный», 13.09.2026).
            SizedBox(
              height: 34,
              child: _error == null
                  ? null
                  : Row(children: [
                      Icon(Myna.dangerCircle, size: 17, color: tm.expense),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 13.5,
                            height: 1.25,
                            color: tm.expense,
                          ),
                        ),
                      ),
                    ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: _busy
                        ? SizedBox(
                            key: const ValueKey('wait'),
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: tm.onAccent,
                            ),
                          )
                        : Row(
                            key: ValueKey(_action),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_step == _Step.intro) ...[
                                Icon(Myna.arrowRight,
                                    size: 18, color: tm.onAccent),
                                const SizedBox(width: 8),
                              ],
                              Text(_action),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Те же двери, что в Togetherly: учётка одна на экосистему.
              AuthProviderRow(busy: _busy, onPick: _withProvider),
            ]),
            const SizedBox(height: 14),
            _Switcher(step: _step, onGo: _go),
          ]),
        ),
        ),
      ]),
    );
  }

  /// Страница про связь приложений: аккаунт один на все наши приложения, и
  /// люди об этом не знают — заводят второй.
  Future<void> _openApps() => launchUrl(
        Uri.parse('https://togetherly.day/money/apps/'),
        mode: LaunchMode.externalApplication,
      );
}

/// Нижняя строка: «Уже есть аккаунт? Войти» и обратно.
class _Switcher extends StatelessWidget {
  const _Switcher({required this.step, required this.onGo});

  final _Step step;
  final ValueChanged<_Step> onGo;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final toSignIn = step != _Step.signIn;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          tr(toSignIn ? 'welcomeHaveAccount' : 'welcomeNoAccount'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13.5,
            color: tm.muted,
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => onGo(toSignIn ? _Step.signIn : _Step.register),
          child: Text(
            tr(toSignIn ? 'authSignIn' : 'authRegister'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: tm.text,
              color: tm.text,
            ),
          ),
        ),
      ]),

    ]);
  }
}

/// Тихая строка-ссылка: подчёркнута серым, не спорит с кнопкой.
class _Quiet extends StatelessWidget {
  const _Quiet({required this.text, required this.onTap, this.brand = false});

  final String text;
  final VoidCallback? onTap;

  /// Показывать ли значок Togetherly слева. Строку про общий аккаунт люди не
  /// замечали словами — знак приложения виден сразу.
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final label = Text(
      text,
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 12.5,
        height: 1.4,
        color: tm.muted,
        decoration: TextDecoration.underline,
        decorationColor: tm.line,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: brand
          // Значок стоит ПОСЛЕ слова «Togetherly», как подпись у названия.
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: label),
              const SizedBox(width: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  'assets/brand/togetherly.png',
                  width: 18,
                  height: 18,
                ),
              ),
            ])
          : label,
    );
  }
}

/// Поле ввода: заливка, крупный шрифт, пример внутри. Ни рамки, ни линии.
///
/// Бланк с подчёркиванием был и отвергнут в тот же час: «мне не нравятся
/// такие инпуты, верни те, что были, БЕЗ БОРДЕРОВ» (13.09.2026).
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.capitalize = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    this.autofill,
    this.bad = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool capitalize;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  /// Подсказки автозаполнения: пароль из менеджера подставляется сам.
  final List<String>? autofill;

  /// Поле не заполнено — заливка отдаёт красным.
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofill,
      textCapitalization:
          capitalize ? TextCapitalization.words : TextCapitalization.none,
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 16,
        color: tm.text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 16,
          color: tm.muted,
        ),
        filled: true,
        fillColor: bad
            ? tm.expense.withValues(alpha: tm.dark ? 0.22 : 0.12)
            : tm.field,
        suffixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Две карты веером, и они ДЫШАТ.
///
/// Покачивание медленное и разное у каждой карты: экран живой, но внимание не
/// перетягивает. Настоящие карты приложения, а не картинка — те же фактуры и
/// знаки систем, которые человек увидит у себя на счетах.
class _Fan extends StatefulWidget {
  const _Fan({required this.card, this.away = 0});

  final double card;

  /// Ход ухода: 0 — карты на месте, 1 — разъехались за края экрана.
  final double away;

  @override
  State<_Fan> createState() => _FanState();
}

class _FanState extends State<_Fan> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Система просит меньше движения — сцена замирает. Это и правило
    // доступности, и спасение виджет-тестов: бесконечная анимация не даёт
    // им успокоиться.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _c.isAnimating) {
      _c.stop();
    } else if (!still && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final height = card / cardAspect;

    return SizedBox(
      // Своя коробка: без неё карты рисовались от верха экрана и срезались.
      width: card * 1.1,
      height: height * 1.55,
      child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        return Stack(clipBehavior: Clip.none, children: [
          floating(
            top: math.sin(t) * 7,
            // Верхняя уходит ВЛЕВО, нижняя ВПРАВО: сцена раскрывается, а не
            // улетает целиком.
            left: 8 + math.cos(t * 0.7) * 4 - widget.away * card * 1.6,
            angle: -0.05 + math.sin(t * 0.8) * 0.012 - widget.away * 0.12,
            child: CardTile(
              name: tr('welcomeCardShared'),
              account: const Account(
                name: 'shared',
                currency: '',
                brand: CardBrand.visa,
                last4: '1234',
                // Сталь, а не чёрное: на тёмном фоне чёрная карта исчезала.
                design: 8,
                texture: CardTexture.guilloche,
              ),
              amount: 12480,
              currency: '',
              width: card,
            ),
          ),
          floating(
            // Вторая карта качается в противофазе: иначе пара двигается как
            // один кусок картона.
            top: height * 0.46 + math.sin(t + math.pi) * 8,
            left: math.cos(t * 0.9 + 1) * 5 + widget.away * card * 1.6,
            angle: 0.04 + math.sin(t * 0.6 + 2) * 0.014 + widget.away * 0.12,
            child: CardTile(
              name: tr('welcomeCardMine'),
              account: const Account(
                name: 'mine',
                currency: '',
                brand: CardBrand.mastercard,
                last4: '3507',
                design: 9,
                texture: CardTexture.stripes,
              ),
              amount: 3175.77,
              currency: '',
              width: card,
            ),
          ),
        ]);
      },
    ),
    );
  }
}

/// Общая укладка летающего: смещение и наклон.
Widget floating({
  required double top,
  required double left,
  required double angle,
  required Widget child,
}) =>
    Positioned(
      top: top,
      left: left,
      child: Transform.rotate(angle: angle, child: child),
    );

/// Верх формы: счета и траты, летающие под наклоном.
///
/// Счета показаны СТРОКОЙ, как на главной (кружок, название, остаток), а не
/// картой: карты остались на первом экране. Плашки держатся В ПРЕДЕЛАХ ЭКРАНА
/// — вылезая за край, они выглядели обрезанными (13.09.2026).
class _Bits extends StatefulWidget {
  const _Bits({required this.width});

  final double width;

  @override
  State<_Bits> createState() => _BitsState();
}

class _BitsState extends State<_Bits> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _c.isAnimating) {
      _c.stop();
    } else if (!still && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = widget.width - 44;
    final chip = (scene * 0.62).clamp(150.0, 250.0);
    // Поворот выносит угол плашки наружу: запас считается от её ширины, а не
    // берётся на глаз.
    final room = scene - chip - 10;

    return SizedBox(
      width: scene,
      height: 304,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;

          /// Смещение вдоль ряда, не выходящее за края сцены.
          double slide(double base, double wave) =>
              (base * room + wave).clamp(0.0, room);

          return Stack(children: [
            _float(
              top: 0 + math.sin(t) * 5,
              left: slide(0, math.cos(t * 0.8) * 5),
              angle: -0.05 + math.sin(t * 0.9) * 0.015,
              child: _Chip(
                width: chip,
                name: tr('welcomeAccCard'),
                icon: Myna.creditCard,
                amount: 8241.25,
                color: labelColors[0],
                account: true,
              ),
            ),
            _float(
              top: 60 + math.sin(t * 1.2 + 1) * 6,
              left: slide(1, math.cos(t * 0.7) * 5),
              angle: 0.045 + math.sin(t * 0.6 + 1) * 0.015,
              child: _Chip(
                width: chip,
                name: tr('welcomeDemoSalary'),
                icon: Myna.briefcase,
                amount: 14200,
                color: labelColors[14],
              ),
            ),
            _float(
              top: 120 + math.sin(t * 0.9 + 2) * 5,
              left: slide(0.08, math.cos(t * 1.1 + 2) * 5),
              angle: -0.04 + math.sin(t * 0.7 + 2) * 0.015,
              child: _Chip(
                width: chip * 0.94,
                name: tr('welcomeAccCash'),
                icon: Myna.dollarCircle,
                amount: 1320,
                color: labelColors[10],
                account: true,
              ),
            ),
            _float(
              top: 180 + math.sin(t * 1.3 + 3) * 6,
              left: slide(0.92, math.cos(t * 0.9 + 3) * 5),
              angle: 0.05 + math.sin(t + 1.5) * 0.015,
              child: _Chip(
                width: chip * 0.96,
                name: tr('welcomeDemoGroceries'),
                icon: Myna.store,
                amount: -890.50,
                color: labelColors[1],
              ),
            ),
            _float(
              top: 240 + math.sin(t * 1.1 + 4) * 5,
              left: slide(0.12, math.cos(t * 0.6 + 4) * 5),
              angle: -0.045 + math.sin(t * 0.8 + 3) * 0.015,
              child: _Chip(
                width: chip * 0.9,
                name: tr('welcomeDemoCoffee'),
                icon: Myna.coffee,
                amount: -120,
                color: labelColors[8],
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _float({
    required double top,
    required double left,
    required double angle,
    required Widget child,
  }) =>
      Positioned(
        top: top,
        left: left,
        child: Transform.rotate(angle: angle, child: child),
      );
}

/// Летающая плашка: счёт с остатком или трата с суммой.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.width,
    required this.name,
    required this.icon,
    required this.amount,
    required this.color,
    this.account = false,
  });

  final double width;
  final String name;
  final IconData icon;
  final double amount;
  final Color color;

  /// Счёт показывает ОСТАТОК обычным цветом, трата — сумму со знаком.
  final bool account;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
      decoration: BoxDecoration(
        color: tm.card,
        border: Border.all(color: tm.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: inkOn(color)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: tm.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                // Суммы БЕЗ кода валюты: приложение одинаково живёт с леями,
                // рублями и евро, и выбирать за человека тут нечего.
                formatMoney(amount, '', sign: !account),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: account
                      ? tm.text
                      : (amount > 0 ? tm.income : tm.expense),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
