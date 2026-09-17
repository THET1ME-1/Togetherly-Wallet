import 'dart:math' as math;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../logic/icons.dart';
import '../design/app_theme.dart';
import 'money_text.dart';
import '../design/myna.dart';

/// Счёт карточкой, а не строкой.
///
/// Строка «Карта · 12 480,55» ничего не говорит о том, ЧЬЯ это карта и какая
/// из трёх: человек узнаёт свою по цвету, знаку системы и четырём цифрам.
/// Полного номера приложение не знает и не спрашивает.
///
/// Оформление плоское: ни градиентов, ни глянца, ни тени — правило системы.
/// Объём даёт водяной знак из имени счёта, как на настоящем пластике.

/// Пропорция банковской карты: 85,6 × 53,98 мм.
const cardAspect = 85.6 / 53.98;

/// Скругление карты. Обычной и ужатой — разное, и всякий, кто рисует вокруг
/// карты рамку, обязан брать радиус ОТСЮДА: обводка с чужим скруглением не
/// повторяет форму карты и сразу бросается в глаза.
double cardRadius({bool compact = false}) => compact ? 20 : 24;

/// Оформления: заливка и цвет надписи поверх неё. Проверены на контраст —
/// белым по пастели не видно ничего, поэтому надпись тёмная везде, кроме
/// графита.
class CardDesign {
  /// Ключ названия в словаре, а не само название: список константный, а язык
  /// человек меняет на ходу.
  final String titleKey;
  final Color fill;
  final Color ink;

  /// Премиальное оформление: открывается подпиской.
  ///
  /// Признак живёт В САМОМ оформлении, а не списком номеров на экране: номер
  /// уедет при первой же дописке, а поле переживёт любую.
  final bool plus;

  const CardDesign(this.titleKey, this.fill, this.ink, {this.plus = false});

  /// Название на языке интерфейса.
  String get title => tr(titleKey);
}

/// Оформления карт — ЦВЕТНЫЕ, плюс чёрная и графитовая.
///
/// Поверхности в системе печатные, но счёт человек узнаёт по цвету: «счета
/// сделать цветными, как и категории» (13.09.2026). Название лежит КЛЮЧОМ
/// словаря, а не готовой строкой: список константный, а язык меняется на ходу.
const cardDesigns = <CardDesign>[
  // ПОРЯДОК МЕНЯТЬ НЕЛЬЗЯ: у счёта хранится НОМЕР оформления, и перестановка
  // перекрашивает чужие карты. Один раз это уже случилось — голубая «Карта
  // Салют» и розовый «Togetherly+» стали чёрными (13.09.2026). Новые цвета
  // дописываются только в КОНЕЦ.
  CardDesign('designMint', Color(0xFF6FC2A8), Color(0xFF1E3C35)),
  CardDesign('designLavender', Color(0xFFA99BC7), Color(0xFF2A2540)),
  CardDesign('designPeach', Color(0xFFF4A58C), Color(0xFF3C231B)),
  CardDesign('designSand', Color(0xFFF2D68A), Color(0xFF3A3320)),
  CardDesign('designSky', Color(0xFFADD5F2), Color(0xFF1E2C3C)),
  CardDesign('designCoral', Color(0xFFE0656A), Color(0xFFFFFFFF)),
  CardDesign('designGraphite', Color(0xFF1C1C1C), Color(0xFFFFFFFF)),
  CardDesign('designInk', Color(0xFF000000), Color(0xFFFFFFFF)),
  CardDesign('designSteel', Color(0xFF3A3A3A), Color(0xFFFFFFFF)),
  CardDesign('designPaper', Color(0xFFF5F5F5), Color(0xFF000000)),
  // Премиальные. Дописаны 17.09.2026 в КОНЕЦ, как велит правило выше.
  // Оттенки глубокие, а не ещё шесть пастелей: бесплатный набор уже светлый,
  // и платное должно отличаться не «ещё одним розовым», а весом.
  CardDesign('designNight', Color(0xFF1E2A44), Color(0xFFFFFFFF), plus: true),
  CardDesign('designPine', Color(0xFF1E3B32), Color(0xFFFFFFFF), plus: true),
  CardDesign('designWine', Color(0xFF5A2333), Color(0xFFFFFFFF), plus: true),
  CardDesign('designBrass', Color(0xFFC9A227), Color(0xFF2E2409), plus: true),
  CardDesign('designIce', Color(0xFFDCEBF5), Color(0xFF223140), plus: true),
  CardDesign('designLilac', Color(0xFFE7C2E0), Color(0xFF3A2438), plus: true),
];


CardDesign designOf(Account? account, String name) {
  final chosen = account?.design;
  if (chosen != null && chosen >= 0 && chosen < cardDesigns.length) {
    return cardDesigns[chosen];
  }
  var hash = 0;
  for (final code in name.codeUnits) {
    hash = (hash * 31 + code) & 0x7FFFFFFF;
  }
  // Подбор идёт по ПЕРВЫМ СЕМИ цветным оформлениям, а не по всему списку:
  // длина входит в остаток от деления, и каждая новая карточка в наборе
  // перекрашивала бы все счета, у которых оформление не выбрано руками.
  // Именно так голубая «Карта Salut» и розовый «Togetherly+» уехали в другие
  // цвета (13.09.2026). Чёрная, стальная и бумажная остаются ручным выбором.
  return cardDesigns[hash % _autoDesigns];
}

/// Сколько оформлений участвует в подборе по имени. Число историческое и
/// менять его нельзя по той же причине, что и порядок списка.
const _autoDesigns = 7;

class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.name,
    required this.account,
    required this.amount,
    required this.currency,
    this.extraCurrencies = const [],
    this.width = 288,
    this.onTap,
    this.onDetails,
    this.bankLogo,
    this.compact = false,
  });

  /// Ужатая карта для выбора счёта при записи операции.
  ///
  /// Та же карта, тот же цвет и тот же знак системы — человек узнаёт свою с
  /// первого взгляда. Но размер вдвое меньше галерейного, и содержимое надо
  /// ужать вместе с ним: кегли, отступы и нижняя строка с видом счёта в
  /// половинную карту просто не влезают.
  final bool compact;

  /// Логотип банка — настоящая иконка его приложения с этого телефона.
  /// На пластике знак банка стоит сверху слева, здесь так же.
  final Uint8List? bankLogo;

  final String name;
  final Account? account;
  final double amount;
  final String currency;

  /// Остальные валюты этого счёта: на карте они строкой, потому что складывать
  /// лей с евро нельзя.
  final List<({String currency, double amount})> extraCurrencies;

  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final design = designOf(account, name);
    final kind = account?.kind ?? AccountKind.card;
    final personal = account != null && !account!.isShared;
    final ink = design.ink;

    return SizedBox(
      width: width,
      height: width / cardAspect,
      child: Material(
        color: design.fill,
        borderRadius: BorderRadius.circular(cardRadius(compact: compact)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Водяной знак: имя счёта повторяется, как на пластике. Плотность
              // низкая, иначе он спорит с суммой.
              Positioned.fill(
                child: CustomPaint(
                  painter: cardTexturePainter(
                    account?.texture ?? CardTexture.watermark,
                    name: name,
                    ink: ink,
                    compact: compact,
                  ),
                ),
              ),
              Padding(
                padding: compact
                    ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
                    : const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(children: [
                            if (bankLogo != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Image.memory(
                                  bankLogo!,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                name,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.displayFont,
                                  fontSize: compact ? 13 : 16,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  color: ink,
                                ),
                              ),
                            ),
                            if (personal) ...[
                              const SizedBox(width: 6),
                              Icon(Myna.lock, size: 14, color: ink),
                            ] else if (account?.isPot == true) ...[
                              const SizedBox(width: 6),
                              Icon(Myna.heartPlus, size: 14, color: ink),
                            ],
                          ]),
                        ),
                        const SizedBox(width: 10),
                        _Brand(
                          brand: account?.brand ?? CardBrand.none,
                          ink: ink,
                          name: name,
                          storedIcon: account?.icon,
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Сумма и номер жмутся, а не рвут карту: системный шрифт
                    // 1.3 иначе выдавливает нижнюю строку за край.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MoneyText(
                        amount,
                        currency: currency,
                        size: compact ? 16 : 22,
                        weight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                    // В ужатой карте второй валюте места нет: она видна в
                    // галерее счетов, где карта вдвое крупнее.
                    if (extraCurrencies.isNotEmpty && !compact)
                      Text(
                        extraCurrencies
                            .map((c) => formatMoney(c.amount, c.currency))
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 11.5,
                          color: ink.withValues(alpha: 0.75),
                        ),
                      ),
                    SizedBox(height: compact ? 4 : 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Вид счёта в ужатой карте не помещается, а
                              // четыре цифры — главная примета, и они остаются.
                              if (!compact) ...[
                                Text(
                                  accountKindTitle(kind),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.bodyFont,
                                    fontSize: 11.5,
                                    color: ink.withValues(alpha: 0.75),
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                (account?.last4 ?? '').isEmpty
                                    ? tr('cardNoNumber')
                                    : '•••• ${account!.last4}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.bodyFont,
                                  fontSize: compact ? 11.5 : 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onDetails != null)
                          _DetailsPill(onTap: onDetails!, fill: design.fill, ink: ink),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка «Настроить» на самой карте: правка счёта там, где на него смотрят.
class _DetailsPill extends StatelessWidget {
  const _DetailsPill({required this.onTap, required this.fill, required this.ink});

  final VoidCallback onTap;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    // Пилюля светлая на пастели и светлая на графите: своя заливка нужна,
    // чтобы кнопка читалась на любом оформлении.
    final light = ink.computeLuminance() < 0.5;
    final bg = light ? Colors.white.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.18);
    final fg = light ? ink : Colors.white;

    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            widthFactor: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Myna.fineTune, size: 15, color: fg),
              SizedBox(width: 5),
              Text(
                tr('reviewSetUp'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Знак платёжной системы. Рисуется, а не берётся картинкой: два круга
/// Mastercard и слово у остальных — ровно так их показывают кошельки.
class _Brand extends StatelessWidget {
  const _Brand({
    required this.brand,
    required this.ink,
    required this.name,
    required this.storedIcon,
  });

  final CardBrand brand;
  final Color ink;

  /// Имя счёта и выбранный человеком значок. Платёжной системы у наличных и
  /// копилки нет, а значок у КАЖДОГО счёта есть — он и стоит в углу.
  /// Заглушка-карта всем подряд давала наличным иконку карты (13.09.2026).
  final String name;
  final String? storedIcon;

  @override
  Widget build(BuildContext context) {
    if (brand == CardBrand.none) {
      return Icon(
        accountIcon(name, stored: storedIcon),
        size: 22,
        color: ink.withValues(alpha: 0.7),
      );
    }

    switch (brand) {
      case CardBrand.mastercard:
      case CardBrand.maestro:
        return SizedBox(
          width: 40,
          height: 24,
          child: CustomPaint(painter: _MastercardMark(maestro: brand == CardBrand.maestro)),
        );
      case CardBrand.visa:
        return _Word(text: 'VISA', ink: ink, italic: true);
      case CardBrand.mir:
        return _Word(text: tr('accountMir'), ink: ink);
      case CardBrand.amex:
        return _Word(text: 'AMEX', ink: ink);
      case CardBrand.unionpay:
        return _Word(text: 'UNIONPAY', ink: ink, size: 10);
      case CardBrand.none:
        // Разобрано выше: сюда не доходим.
        return const SizedBox.shrink();
    }
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.text, required this.ink, this.italic = false, this.size = 15});

  final String text;
  final Color ink;
  final bool italic;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: ink,
        ),
      );
}

class _MastercardMark extends CustomPainter {
  _MastercardMark({required this.maestro});

  final bool maestro;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final left = Offset(r + size.width * 0.04, size.height / 2);
    final right = Offset(size.width - r - size.width * 0.04, size.height / 2);
    final red = maestro ? const Color(0xFF0099DF) : const Color(0xFFEB001B);
    final yellow = maestro ? const Color(0xFFED0000) : const Color(0xFFF79E1B);

    canvas.drawCircle(left, r, Paint()..color = red);
    canvas.drawCircle(right, r, Paint()..color = yellow);
    // Пересечение кругов — оранжевая линза настоящего знака.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: left, radius: r)));
    canvas.drawCircle(right, r, Paint()..color = maestro
        ? const Color(0xFF6C6BBD)
        : const Color(0xFFFF5F00));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MastercardMark old) => old.maestro != maestro;
}

/// Водяной знак из имени счёта: наклонные строки, как тиснение на пластике.
class _Watermark extends CustomPainter {
  _Watermark({required this.text, required this.color, this.scale = 1});

  final String text;
  final Color color;

  /// Во сколько раз мельче обычного. На ужатой карте знак прежнего кегля
  /// перекрикивал и имя, и сумму — фактура превращалась в надпись.
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final word = text.toUpperCase();
    if (word.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: List.filled(6, word).join('  '),
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontSize: 13 * scale,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-size.width * 0.1, -size.height * 0.1);
    canvas.rotate(-8 * math.pi / 180);
    // Шаг крупнее кегля: знак должен читаться фактурой, а не надписью поверх
    // суммы. На 6% и плотной сетке он спорил с числом.
    for (var y = 0.0; y < size.height * 1.4; y += 30 * scale) {
      painter.paint(canvas, Offset(-((y ~/ 30) % 2) * 50, y));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Watermark old) =>
      old.text != text || old.color != color || old.scale != scale;
}

/// Фактура фона по виду. Живёт отдельной функцией, чтобы карта не знала про
/// каждый рисунок и съёмка вариантов ходила через одну дверь.
/// Фактура фона по виду. Живёт отдельной функцией, чтобы карта не знала про
/// каждый рисунок, а лист счёта рисовал теми же руками свои образцы.
CustomPainter cardTexturePainter(
  CardTexture kind, {
  required String name,
  required Color ink,
  bool compact = false,
}) {
  // На ужатой карте любая фактура слабее: места вдвое меньше, а сумма и имя
  // на ней те же.
  final dim = compact ? 0.7 : 1.0;
  switch (kind) {
    case CardTexture.watermark:
      return _Watermark(
        text: name,
        color: ink.withValues(alpha: compact ? 0.035 : 0.05),
        scale: compact ? 0.62 : 1,
      );
    case CardTexture.guilloche:
      return _Guilloche(color: ink.withValues(alpha: 0.11 * dim), seed: name);
    case CardTexture.stripes:
      return _Stripes(ink: ink, dim: dim);
  }
}

/// Гильош — розетка из тонких линий, как на банкноте и на настоящем пластике.
/// Рисунок свой у каждого счёта: число лепестков и наклон считаются из имени,
/// поэтому две карты не выходят одинаковыми.
class _Guilloche extends CustomPainter {
  _Guilloche({required this.color, required this.seed});

  final Color color;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    var hash = 0;
    for (final code in seed.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    // Лепестков от десяти до пятнадцати: меньше давало цветок, и медальон
    // читался кляксой, а не защитной сеткой.
    final petals = 10 + hash % 6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = color;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Центр за правым краем: розетка входит в карту частью, а не лежит
    // медальоном посреди суммы.
    final cx = size.width * 0.82;
    final cy = size.height * 0.50;
    final base = size.height * 0.80;

    for (var ring = 0; ring < 12; ring++) {
      final radius = base * (0.22 + ring * 0.072);
      final wobble = radius * 0.09;
      final phase = ring * math.pi / petals * 0.7;
      final path = Path();
      for (var step = 0; step <= 220; step++) {
        final t = step / 220 * 2 * math.pi;
        final r = radius + wobble * math.cos(petals * t + phase);
        final x = cx + r * math.cos(t);
        final y = cy + r * math.sin(t) * 0.92;
        step == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Guilloche old) =>
      old.color != color || old.seed != seed;
}

/// Ленты наискось: спокойная фактура, которая не спорит ни с суммой, ни со
/// знаком системы.
class _Stripes extends CustomPainter {
  _Stripes({required this.ink, required this.dim});

  final Color ink;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(-28 * math.pi / 180);
    canvas.translate(-size.width, -size.height);

    final band = Paint()..color = ink.withValues(alpha: 0.055 * dim);
    final hair = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ink.withValues(alpha: 0.10 * dim);

    final step = size.width * 0.30;
    for (var x = 0.0; x < size.width * 3; x += step) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, size.width * 0.14, size.height * 3),
        band,
      );
      canvas.drawLine(
        Offset(x + size.width * 0.19, 0),
        Offset(x + size.width * 0.19, size.height * 3),
        hair,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Stripes old) => old.ink != ink || old.dim != dim;
}

