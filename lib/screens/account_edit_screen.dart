import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../widgets/plus_gate.dart';
import '../services/plus.dart';
import '../logic/plus.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../logic/card_brands.dart';
import '../logic/icon_search.dart';
import '../logic/icons.dart';
import '../logic/notice_match.dart';
import '../services/notices.dart';
import '../widgets/card_tile.dart';
import '../widgets/icon_search_sheet.dart';
import '../widgets/pick_row.dart';
import '../widgets/sender_logo.dart';
import '../widgets/settings_kit.dart';

/// Правка счёта: имя, чей он, общий ли и как выглядит картой.
///
/// Это ЭКРАН, а не нижний лист. Листом он был, пока спрашивал три поля; с
/// значком, оформлением и фактурой форма занимает высоту экрана целиком, и
/// попап во весь экран — просто экран, которому мешает ручка сверху
/// («зачем это попап, если легче сделать нормальный экран» — 13.09.2026).
///
/// Полный номер карты приложение не спрашивает НИКОГДА: для узнавания хватает
/// четырёх цифр, а всё остальное — данные, которые могут утечь и не нужны ни
/// одной функции.
Future<void> showAccountSheet(
  BuildContext context, {
  required Store store,
  required String name,
  PlusService? plus,

  /// Банки с этого телефона: их настоящие логотипы ставятся на карту и
  /// связывают счёт с уведомлениями банка.
  Notices? notices,
}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => AccountEditScreen(
        store: store,
        name: name,
        plus: plus,
        notices: notices,
      ),
    ));

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({
    super.key,
    required this.store,
    required this.name,
    this.notices,
    this.plus,
  });

  final Store store;
  final String name;
  final Notices? notices;

  /// Подписка: премиальные оформления карт открываются ею.
  final PlusService? plus;

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  late final TextEditingController controller;
  late final TextEditingController last4;
  late final Account account;
  late final List<String> banks;

  late bool personal;
  late bool pot;
  late CardBrand brand;
  late AccountKind kind;
  late int? design;
  late String? bank;
  late String? icon;
  late CardTexture texture;

  Store get store => widget.store;
  String get name => widget.name;
  Notices? get notices => widget.notices;

  @override
  void initState() {
    super.initState();
    final db = store.db;
    final at = db.accounts.indexWhere((a) => a.name == name);
    account = at >= 0
        ? db.accounts[at]
        : Account(name: name, currency: db.baseCurrency);

    controller = TextEditingController(text: account.name);
    last4 = TextEditingController(text: account.last4 ?? '');
    personal = !account.isShared;
    pot = account.isPot;
    brand = account.brand;
    kind = account.kind;
    design = account.design;
    bank = account.bank;
    icon = account.icon;
    texture = account.texture;

    // Список банков: те, что стоят на телефоне, — с логотипами. Их немного, и
    // выбор занимает одно касание.
    banks = <String>[
      ...knownSenders.keys.where((p) => notices?.logos.containsKey(p) ?? false),
      if (bank != null && !(notices?.logos.containsKey(bank) ?? false)) bank!,
    ];
  }

  @override
  void dispose() {
    controller.dispose();
    last4.dispose();
    super.dispose();
  }

  void _save() {
    final next = controller.text.trim();
    final digits = last4.text.trim();
    store.editAccount(
      name,
      newName: next.isEmpty || next == name ? null : next,
      owner: personal ? store.viewer : null,
      clearOwner: !personal,
      isPot: pot,
      last4: digits.isEmpty ? null : digits,
      clearLast4: digits.isEmpty,
      brand: brand,
      kind: kind,
      design: design,
      icon: icon,
      clearIcon: icon == null,
      texture: texture,
      bank: bank,
      clearBank: bank == null,
    );
    Navigator.of(context).pop();
  }


  /// Выбрать оформление. Платное сперва спрашивает подписку: калитка стоит
  /// ПЕРЕД выбором, иначе человек увидит свою карту в цвете, который у него
  /// тут же отберут.
  Future<void> _pickDesign(int i) async {
    if (cardDesigns[i].plus &&
        !await askPlus(context, plus: widget.plus, gate: PlusGate.looks)) {
      return;
    }
    if (mounted) setState(() => design = i);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.db;
    final paired = db.pair.members.length > 1;
    final me = store.viewer;

    return Scaffold(
      appBar: AppBar(title: Text(tr('accountEditTitle'))),
      // Кнопка прибита к низу: форма длинная, и докручивать до «Сохранить»
      // через весь экран — лишняя работа пальцем.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _save,
            child: Text(tr('accountSave')),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
            // Карта первой и на виду: человек правит её, глядя на неё, —
            // поэтому она занимает ВСЮ ширину листа. На 260 точках она висела
            // марочкой посреди пустых полей.
            LayoutBuilder(
              builder: (context, box) => CardTile(
                name: controller.text.trim().isEmpty ? name : controller.text.trim(),
                account: account.copyWith(
                  last4: last4.text.trim().isEmpty ? null : last4.text.trim(),
                  clearLast4: last4.text.trim().isEmpty,
                  brand: brand,
                  kind: kind,
                  design: design,
                  icon: icon,
                  texture: texture,
                  owner: personal ? me : null,
                  clearOwner: !personal,
                  isPot: pot,
                  bank: bank,
                  clearBank: bank == null,
                ),
                amount: 0,
                currency: account.currency,
                // Потолок для планшета: во весь экран карта выглядит плакатом.
                width: box.maxWidth > 420 ? 420 : box.maxWidth,
                bankLogo: bank == null ? null : notices?.logos[bank],
              ),
            ),
            const SizedBox(height: 18),

            // Дальше — тот же каркас, что в настройках: подпись капсом, под
            // ней блоки одной ширины с одинаковыми зазорами. Раньше здесь было
            // пять разных языков вёрстки: свои подписи, свои отступы, Wrap с
            // рваными строками — «у всех элементов разный контейнер, разное
            // расстояние» (13.09.2026).
            SettingsSection(tr('accountName'), icon: Myna.creditCard),
            SettingsGroup([
              SettingsBlock(
                // Автофокуса НЕТ: имя счёт уже носит, а клавиатура на входе
                // закрывала карту и половину формы.
                child: SettingsInput(
                  controller: controller,
                  hint: tr('accountNameHint'),
                ),
              ),
              SettingsBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SettingsInput(
                      controller: last4,
                      hint: tr('accountLast4'),
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      capitalize: false,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ]),

            if (banks.isNotEmpty) ...[
              SettingsSection(tr('accountBank'), icon: Myna.bank),
              SettingsGroup([
                SettingsBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ряд с прокруткой, а не Wrap: банков бывает пять, и
                      // перенос делал строки рваными.
                      PickRow(
                        height: 44,
                        children: [
                          for (final package in banks)
                            _BankChoice(
                              package: package,
                              logo: notices?.logos[package],
                              chosen: bank == package,
                              onTap: () => setState(
                                () => bank = bank == package ? null : package,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]),
            ],

            SettingsSection(tr('accountKind'), icon: Myna.label),
            SettingsGroup([
              SettingsBlock(
                // Видов ровно четыре — ложатся в две строки по два без
                // остатка. Сетка, а не Wrap: строки обязаны быть ровными.
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 3.1,
                  children: [
                    for (final k in AccountKind.values)
                      _Choice(
                        title: accountKindTitle(k),
                        on: kind == k,
                        onTap: () => setState(() => kind = k),
                      ),
                  ],
                ),
              ),
            ]),

            SettingsSection(tr('accountBrand'), icon: Myna.contactless),
            SettingsGroup([
              SettingsBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Порядок зависит от страны телефона: в Кишинёве впереди
                    // Visa, в Москве — МИР. Ничего не прячется.
                    PickRow(
                      height: 44,
                      children: [
                        for (final b in brandsHere())
                          _Choice(
                            title: _brandTitle(b),
                            on: brand == b,
                            onTap: () => setState(() => brand = b),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),

            SettingsSection(tr('accountIcon'), icon: Myna.sparkles),
            SettingsGroup([
              SettingsBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Частые лежат сразу, весь набор — за поиском. Сетка по
                    // шесть: ряды обязаны быть ровными, и восемнадцать знаков
                    // дают ровно три.
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: [
                        for (final entry in _iconChoicesFor(icon))
                          _IconCell(
                            icon: entry.$2,
                            on: icon == entry.$1,
                            onTap: () => setState(
                              () => icon = icon == entry.$1 ? null : entry.$1,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Кнопка под сеткой во всю ширину: рядом с подсказкой она
                    // жалась в угол и ломала ряд.
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          final picked = await showIconSearch(context);
                          if (picked != null) setState(() => icon = picked);
                        },
                        icon: const Icon(Myna.search, size: 18),
                        label: Text(tr('categoryIconFind')),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            SettingsSection(tr('accountLook'), icon: Myna.swatches),
            SettingsGroup([
              SettingsBlock(
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (var i = 0; i < cardDesigns.length; i++)
                      GestureDetector(
                        onTap: () => _pickDesign(i),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: cardDesigns[i].fill,
                                shape: BoxShape.circle,
                                border: design == i
                                    ? Border.all(
                                        color: scheme.onSurface, width: 2.5)
                                    // Графитовый и чернильный круги на тёмной
                                    // теме сливались с карточкой: мягкая линия
                                    // на ней не видна вовсе.
                                    : Border.all(color: scheme.outline),
                              ),
                            ),
                            // Платное оформление подписано искрой ПОВЕРХ
                            // цвета: прятать его из набора нельзя — человек
                            // должен видеть, что в подписке, а серый круг с
                            // замком выглядел бы поломкой.
                            if (cardDesigns[i].plus && !(widget.plus?.active ?? true))
                              Icon(
                                Myna.sparkles,
                                size: 13,
                                color: cardDesigns[i].ink,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ]),

            SettingsSection(tr('accountTexture'), icon: Myna.grid),
            SettingsGroup([
              SettingsBlock(
                child: Row(
                  children: [
                    for (final t in CardTexture.values) ...[
                      Expanded(
                        child: _TextureChoice(
                          key: ValueKey('texture-${cardTextureName(t)}'),
                          texture: t,
                          name: controller.text.trim().isEmpty
                              ? name
                              : controller.text.trim(),
                          design: designOf(
                            account.copyWith(design: design),
                            name,
                          ),
                          on: texture == t,
                          onTap: () => setState(() => texture = t),
                        ),
                      ),
                      if (t != CardTexture.values.last)
                        const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ]),

            if (paired) ...[
              SettingsSection(tr('accountWhose'), icon: Myna.users),
              SettingsGroup([
                SettingsRow(
                  icon: personal ? Myna.lock : Myna.users,
                  title: tr('accountPersonal'),
                  subtitle: personal
                      ? tr('accountPersonalNote')
                      : tr('accountSharedNote'),
                  trailing: Switch(
                    value: personal,
                    onChanged: (v) => setState(() {
                      personal = v;
                      if (v) pot = false;
                    }),
                  ),
                ),
                if (!personal)
                  SettingsRow(
                    icon: Myna.heartPlus,
                    title: tr('accountPot'),
                    subtitle: tr('accountPotNote'),
                    trailing: Switch(
                      value: pot,
                      onChanged: (v) => setState(() => pot = v),
                    ),
                  ),
              ]),
            ],
        ],
      ),
    );
  }
}

String _brandTitle(CardBrand b) => switch (b) {
      CardBrand.visa => 'Visa',
      CardBrand.mastercard => 'Mastercard',
      CardBrand.mir => tr('accountMir'),
      CardBrand.maestro => 'Maestro',
      CardBrand.amex => 'Amex',
      CardBrand.unionpay => 'UnionPay',
      CardBrand.none => tr('accountBrandNone'),
    };

/// Банк карты: настоящий логотип приложения и его имя. Нажатие выбирает и
/// снимает выбор — банк у счёта дело добровольное.
/// Пилюля выбора одного значения. Одна на весь лист: вид счёта и платёжная
/// система выглядели по-разному, хотя делают одно и то же.
class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.on, required this.onTap});

  final String title;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            widthFactor: 1,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? scheme.onSecondaryContainer : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BankChoice extends StatelessWidget {
  const _BankChoice({
    required this.package,
    required this.chosen,
    required this.onTap,
    this.logo,
  });

  final String package;
  final bool chosen;
  final VoidCallback onTap;
  final Uint8List? logo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      // Выбранное — ИНВЕРСИЯ, правило системы. `tm.field` тут стоял до
      // 14.09.2026 и означал ровно то же, что фон невыбранного: человек
      // нажимал на банк и не видел НИЧЕГО («он не выделяется включением»).
      color: chosen ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SenderLogo(package: package, bytes: logo, size: 24),
            const SizedBox(width: 8),
            Text(
              senderTitle(package),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: chosen ? scheme.onSecondaryContainer : scheme.onSurface,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


/// Что стоит в выборе значков счёта: частые плюс найденный поиском, если его
/// там нет. Иначе выбранный знак пропадал бы с глаз сразу после выбора.
List<(String, IconData)> _iconChoicesFor(String? chosen) {
  final out = <(String, IconData)>[
    for (final e in accountIconChoices.entries) (e.key, e.value),
  ];
  if (chosen != null && !accountIconChoices.containsKey(chosen)) {
    final found = iconByName(chosen) ?? iconChoices[chosen];
    if (found != null) out.insert(0, (chosen, found));
  }
  return out;
}

class _IconCell extends StatelessWidget {
  const _IconCell({required this.icon, required this.on, required this.onTap});

  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          size: 22,
          color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}


/// Образец фактуры: та же карта в четверть размера, нарисованная теми же
/// руками, что и настоящая. Рисовать выбор словами бессмысленно — «гильош»
/// человеку ничего не говорит, пока он его не увидит.
class _TextureChoice extends StatelessWidget {
  const _TextureChoice({
    super.key,
    required this.texture,
    required this.name,
    required this.design,
    required this.on,
    required this.onTap,
  });

  final CardTexture texture;
  final String name;
  final CardDesign design;
  final bool on;
  final VoidCallback onTap;

  String get _title => switch (texture) {
        CardTexture.watermark => tr('textureWatermark'),
        CardTexture.guilloche => tr('textureGuilloche'),
        CardTexture.stripes => tr('textureStripes'),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Рамка выбора повторяет форму карты: радиус берётся оттуда же,
          // откуда его берёт сама карта.
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardRadius(compact: true) + 3),
              border: Border.all(
                color: on ? scheme.onSurface : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardRadius(compact: true)),
              child: AspectRatio(
                aspectRatio: cardAspect,
                child: ColoredBox(
                  color: design.fill,
                  child: CustomPaint(
                    painter: cardTexturePainter(
                      texture,
                      name: name,
                      ink: design.ink,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _title,
            maxLines: 2,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 11.5,
              height: 1.25,
              fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              color: on ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
