import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/notice_match.dart';
import '../logic/plus.dart';
import '../services/notices.dart';
import '../services/plus.dart';
import '../widgets/plus_gate.dart';
import '../widgets/sender_logo.dart';
import '../widgets/settings_kit.dart';
import 'notice_rules_screen.dart';
import 'notices_review_screen.dart';
import '../design/myna.dart';
import '../ui/theme/tm_scheme.dart';

/// Настройка чтения банковских уведомлений.
///
/// Только настройки: кого слушать и куда складывать. Разобранные списания
/// живут на своём экране — здесь лишь строка перехода.
///
/// Главное решение этого экрана: показываем ТОЛЬКО те источники, которые есть
/// на телефоне или уже что-то присылали. Список из двадцати четырёх банков,
/// которых у человека нет, — мусор, мешающий найти свои два.
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key, required this.store, this.notices, this.plus});

  final Store store;
  final Notices? notices;

  /// Подписка: молчаливая запись трат платная. Пусто — не запираем.
  final PlusService? plus;

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  // До первого ответа канала экран знает про службу ровно одно — бывает ли
  // она на этой платформе вовсе.
  NoticeState _state = NoticeState(supported: Notices.supported);

  Notices? get _service => widget.notices;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final service = _service;
    if (service == null) return;
    final state = await service.state();
    // Доступ есть, а службы нет — поднимаем сразу, не спрашивая: человек
    // разрешение уже дал, и повторный поход в настройки ему ничего не скажет.
    if (state.asleep) await service.rebind();
    final installed = await service.installed();
    await service.loadLogos({
      ...installed,
      ...widget.store.senders.keys,
      ...widget.store.noticeSenders,
    });
    if (!mounted) return;
    // Хранилище тоже должно знать, что стоит на телефоне: по этому списку
    // кнопка «Банк / Кошелёк / Оба» решает, чьи режимы трогать.
    widget.store.installedSenders = installed;
    setState(() => _state = state);
    if (state.granted) await service.drain();
  }

  /// Свои источники — ГРУППАМИ по банку, а не по пакету.
  ///
  /// У maib три приложения, у Victoriabank два, у Wise два. Раньше каждое
  /// стояло отдельной строкой, и один банк выглядел тремя («мне сразу
  /// отобразился ВЕСЬ список приложений, которых у меня нет», 13.09.2026).
  ///
  /// В список попадает только то, что человека касается: стоит на телефоне,
  /// уже присылало уведомления или включено им самим. Банк, выключенный в
  /// поиске и отсутствующий на телефоне, живёт в поиске, а не здесь.
  List<List<String>> get _mine {
    // Список установленных берётся ИЗ ХРАНИЛИЩА, а не из поля экрана: одно
    // место правды на приложение, и его же читает кнопка «Банк / Кошелёк».
    final installed = widget.store.installedSenders;
    final seen = <String>{
      ...installed,
      ...widget.store.chosenSenders,
      ...widget.store.noticeSenders,
      for (final n in widget.store.pendingNotices) n.package,
    };

    // Пакеты одного банка держатся вместе: имя у них одно, и строка обязана
    // быть одна. Порядок — как в справочнике, чтобы список не скакал.
    final groups = <String, List<String>>{};
    for (final package in [
      ...knownSenders.keys.where(seen.contains),
      ...seen.where((p) => !knownSenders.containsKey(p)),
    ]) {
      groups.putIfAbsent(senderTitle(package), () => []).add(package);
    }

    // Внутри группы первым идёт тот, что стоит на телефоне: у него настоящий
    // логотип, а у второго пакета его нет и быть не может.
    for (final list in groups.values) {
      list.sort((a, b) {
        final byInstalled = (installed.contains(b) ? 1 : 0)
            .compareTo(installed.contains(a) ? 1 : 0);
        return byInstalled != 0 ? byInstalled : a.compareTo(b);
      });
    }
    return groups.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final mine = _mine;
        final waiting = store.pendingNotices.length;
        final learned = store.noticeCategories.isNotEmpty ||
            store.noticeAccounts.isNotEmpty;
        final wallets = mine.any((g) => g.any(isWalletSender));

        return Scaffold(
          appBar: AppBar(title: Text(tr('noticesTitle'))),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                _Access(
                  state: _state,
                  onOpen: _openSettings,
                  onDetails: _openAppDetails,
                  onWake: _wake,
                  hintDone: store.noticeHintDone,
                  onHintDone: store.hideNoticeHint,
                ),
                SettingsSection(
                  tr('noticesWhoSends'),
                  icon: Myna.bank,
                ),
                // Без доступа Android эти переключатели не делают НИЧЕГО, и
                // выглядят при этом рабочими. Говорим это словами: человек
                // включает источник, видит «Спросить» и считает, что настроил
                // («Я скачивал с нуля. Все включено, а не работает»).
                if (!_state.granted) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text(
                      tr('noticesSwitchesIdle'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                if (mine.isNotEmpty)
                  SettingsGroup([
                    for (final group in mine)
                      _Source(
                        store: store,
                        packages: group,
                        plus: widget.plus,
                        logo: _service?.logos[group.first],
                        onBankSettings: () =>
                            _service?.openAppSettings(group.first),
                      ),
                  ])
                else
                  SettingsGroup([const _NoSources()]),
                if (wallets) ...[
                  SettingsSection(
                    tr('noticesPhonePayments'),
                    icon: Myna.contactless,
                  ),
                  SettingsGroup([
                    SettingsBlock(child: _SourcePick(store: store)),
                  ]),
                ],
                if (learned) ...[
                  SettingsSection(
                    tr('noticesRemembered'),
                    icon: Myna.atom,
                  ),
                  SettingsGroup([SettingsBlock(child: _Learned(store: store))]),
                ],
                SettingsSection(tr('noticesMore'), icon: Myna.dots),
                SettingsGroup([
                  // Правила стоят рядом с источниками: человек приходит сюда
                  // после того, как разбор ошибся, и чинит это здесь же.
                  SettingsRow(
                    icon: Myna.filter,
                    title: tr('nruleTitle'),
                    subtitle: store.noticeRules.isEmpty
                        ? tr('nruleEmptyTitle')
                        : '${store.noticeRules.length} ${trn('nrules', store.noticeRules.length)}',
                    trailing: const SettingsChevron(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NoticeRulesScreen(
                        store: store,
                        plus: widget.plus,
                      ),
                    )),
                  ),
                  SettingsRow(
                    icon: Myna.search,
                    title: tr('noticesFind'),
                    subtitle: tr('noticesTurnOnAhead'),
                    trailing: SettingsChevron(),
                    onTap: () => _find(context),
                  ),
                  if (waiting > 0)
                    SettingsRow(
                      icon: Myna.bellOn,
                      title: tr('noticesReview'),
                      subtitle: trf('noticesWaitingFor', [waiting, _waitWord(waiting)]),
                      trailing: const SettingsChevron(),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => NoticesReviewScreen(
                          store: store,
                          notices: _service,
                        ),
                      )),
                    ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _waitWord(int n) => trn('wait', n);

  Future<void> _find(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _FindSheet(
        store: widget.store,
        installed: widget.store.installedSenders,
        logos: _service?.logos ?? const {},
      ),
    );
  }

  /// Сведения о приложении: там снимают запрет Android. Вернувшись, человек
  /// должен увидеть обновлённый экран, а не прежнюю жалобу.
  Future<void> _openAppDetails() async {
    await _service?.openAppDetails();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
  }

  /// Поднять службу и пересчитать состояние. Разрешение при этом не трогаем:
  /// оно уже выдано, чинить надо связь.
  Future<void> _wake() async {
    await _service?.rebind();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await _refresh();
  }

  Future<void> _openSettings() async {
    await _service?.openSettings();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await _refresh();
  }
}

/// Состояние доступа. Своего разрешения у чтения уведомлений нет: его даёт
/// только Android, и только на своём экране.
class _Access extends StatelessWidget {
  const _Access({
    required this.state,
    required this.onOpen,
    required this.onDetails,
    required this.onWake,
    required this.hintDone,
    required this.onHintDone,
  });

  final NoticeState state;
  final Future<void> Function() onOpen;
  final Future<void> Function() onDetails;
  final Future<void> Function() onWake;
  final bool hintDone;
  final VoidCallback onHintDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!state.supported) {
      if (hintDone) return SizedBox.shrink();
      return SettingsGroup([
        SettingsBlock(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tr('noticesAndroidOnlyBadge'),
            style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            tr('noticesAndroidOnlyLong'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onHintDone,
              child: Text(tr('noticesGotIt')),
            ),
          ),
        ]),
        ),
      ]);
    }

    // Доступ выдан, служба на связи, а за всё время не пришло ни одного
    // уведомления — ни банковского, ни любого другого. Значит их глушит сама
    // прошивка (энергосбережение), и ни один тумблер в приложении этого не
    // изменит. Молчать тут нельзя: человек видит включённые источники и
    // считает, что всё настроено.
    if (state.granted && state.connected && state.seen == 0) {
      return SettingsGroup([
        SettingsBlock(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tr('noticesNothingArrives'),
            style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            tr('noticesNothingArrivesWhy'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpen,
              child: Text(tr('noticesOpenAndroid')),
            ),
          ),
        ]),
        ),
      ]);
    }

    // Разрешение на месте, а службы нет. Так бывает после установки поверх:
    // Android рвёт связь и сам её не возвращает.
    if (state.asleep) {
      return SettingsGroup([
        SettingsBlock(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tr('noticesServiceAsleep'),
            style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            tr('noticesServiceAsleepWhy'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onWake,
              child: Text(tr('noticesWakeService')),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpen,
              child: Text(tr('noticesOpenAndroid')),
            ),
          ),
        ]),
        ),
      ]);
    }

    if (state.granted) {
      return SettingsGroup([
        SettingsBlock(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: context.tm.accent,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('noticesAccessGranted'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: context.tm.field,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tr('noticesWorks'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.tm.text,
                ),
              ),
            ),
          ]),
          SizedBox(height: 10),
          Text(
            tr('noticesTextStays'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ]),
        ),
      ]);
    }

    // Android 13 и выше держит доступ к уведомлениям закрытым у всего, что
    // поставлено мимо магазина: переключатель серый, и человек винит
    // приложение. Порядок здесь обратный привычному — сперва снять запрет в
    // сведениях о приложении, и только потом выдавать доступ.
    final steps = Text(
      tr('noticesRestrictedSteps'),
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 13.5,
        height: 1.6,
        color: scheme.onSurface,
      ),
    );

    if (state.restricted) {
      return SettingsGroup([
        SettingsBlock(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            tr('noticesRestricted'),
            style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Text(
            tr('noticesRestrictedWhy'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          steps,
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDetails,
              child: Text(tr('noticesOpenAppInfo')),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onOpen,
              child: Text(tr('noticesOpenAndroid')),
            ),
          ),
        ]),
        ),
      ]);
    }

    return SettingsGroup([
      SettingsBlock(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          tr('noticesPermissionOnce'),
          style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Text(
          tr('noticesPermissionHowLong'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onOpen,
            child: Text(tr('noticesOpenAndroid')),
          ),
        ),
        // Запрет система признаёт не на всякой прошивке, а серый переключатель
        // человек видит на любой: шаги стоят здесь же, ниже кнопки.
        const SizedBox(height: 14),
        Text(
          tr('noticesRestrictedWhy'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        steps,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onDetails,
            child: Text(tr('noticesOpenAppInfo')),
          ),
        ),
      ]),
      ),
    ]);
  }
}

/// Источник: логотип, режим, маршрут «карта → счёт» и тишина, если банк
/// перестал присылать.
///
/// Строк РОВНО три, каждая в одну строку текста: иначе блоки в группе выходят
/// разной высоты, и раздел выглядит собранным из кусков. Длинное имя счёта и
/// длинная подпись обрезаются, а не переносятся.
class _Source extends StatelessWidget {
  const _Source({
    required this.store,
    required this.packages,
    required this.onBankSettings,
    this.plus,
    this.logo,
  });

  final Store store;
  final PlusService? plus;

  /// Все приложения этого банка. Первый — тот, что стоит на телефоне: у него
  /// настоящий логотип и к нему ведут настройки Android.
  final List<String> packages;

  final VoidCallback onBankSettings;
  final Uint8List? logo;

  String get package => packages.first;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Банк читается, если читается хоть одно его приложение: у maib их три, и
    // уведомление приходит от того, которым человек платит.
    final mode = packages
        .map(store.modeOf)
        .reduce((a, b) => a == NoticeMode.off ? b : a);
    final on = mode != NoticeMode.off;
    final routes = [for (final p in packages) ...store.routesOf(p)];
    final count = packages.fold(0, (sum, p) => sum + store.noticeCountOf(p));
    final last = packages
        .map(store.noticeLastAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final wallet = isWalletSender(package);
    // Включён, но месяц молчит: уведомления банка выключены в Android, и
    // починить это можно только там.
    final silent = on && count == 0;

    final hint = TextStyle(
      fontFamily: AppTheme.bodyFont,
      fontSize: 11.5,
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      // Отступы как у строки настроек: источник живёт в той же группе, что и
      // остальные пункты, и обязан стоять по той же сетке.
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        SenderLogo(package: package, bytes: logo, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(
                  senderTitle(package),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: senderStyle(context),
                ),
              ),
              if (on) ...[
                const SizedBox(width: 7),
                _ModePill(
                  auto: mode == NoticeMode.auto,
                  onTap: () async {
                    final auto = mode == NoticeMode.auto;
                    // Платное здесь — молчаливая запись, а не возврат к
                    // подтверждению: выход из платного всегда свободен.
                    if (!auto &&
                        !await askPlus(context,
                            plus: plus, gate: PlusGate.autoNotices)) {
                      return;
                    }
                    final next = auto ? NoticeMode.ask : NoticeMode.auto;
                    for (final p in packages) {
                      store.setSenderMode(p, next);
                    }
                  },
                ),
              ],
            ]),
            const SizedBox(height: 5),
            // Вторая строка — всегда маршрут или его отсутствие.
            if (routes.isNotEmpty)
              _Route(
                last4: routes.first.last4,
                account: routes.first.account,
                live: on,
              )
            else
              Text(
                wallet ? tr('noticesSameCharge') : tr('noticesAskOnce'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hint,
              ),
            SizedBox(height: 4),
            // Третья строка — всегда состояние.
            if (!on)
              Text(tr('noticesNotReading'), maxLines: 1, style: hint)
            else if (silent)
              InkWell(
                onTap: onBankSettings,
                child: Text(
                  tr('noticesSilentMonth'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: hint.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.tm.expense,
                  ),
                ),
              )
            else
              Text(
                '${last == null ? '' : '${_when(last)} · '}'
                '${trf('noticesMonthCount', [count])}'
                '${routes.length > 1 ? trf('noticesCards', [routes.length]) : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hint,
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Switch(
          value: on,
          onChanged: (v) {
            for (final p in packages) {
              store.setSenderMode(p, v ? NoticeMode.ask : NoticeMode.off);
            }
          },
        ),
      ]),
    );
  }

  static String _when(DateTime at) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
    return switch (days) {
      0 => tr('noticesToday'),
      1 => tr('noticesYesterday'),
      _ => trf('noticesDaysAgo', [days, trn('days', days)]),
    };
  }
}

/// Маршрут: карта банка и счёт приложения. Отвечает на «куда попадёт трата» —
/// главный вопрос к этому экрану.
class _Route extends StatelessWidget {
  const _Route({required this.last4, required this.account, required this.live});

  final String last4;
  final String account;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = TextStyle(
      fontFamily: AppTheme.bodyFont,
      fontSize: 11.5,
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Text(last4 == '*' ? tr('anyCard') : '•••• $last4', style: label),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: live
                    ? LinearGradient(
                        colors: [context.tm.accent, context.tm.accent],
                      )
                    : null,
                color: live ? null : scheme.outlineVariant,
              ),
            ),
          ),
        ),
        Flexible(
          child: Text(
            account,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: label.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Что делать с уведомлением: одна пилюля вместо трёх сегментов. Выключение
/// живёт в тумблере, а здесь остаётся честный выбор из двух.
class _ModePill extends StatelessWidget {
  const _ModePill({required this.auto, required this.onTap});

  final bool auto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: auto ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            auto ? tr('noticesModeAuto') : tr('noticesModeAsk'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: auto ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Пусто: ни одного банковского приложения. Ругать человека не за что —
/// объясняем, что будет дальше.
class _NoSources extends StatelessWidget {
  const _NoSources();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SettingsBlock(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          tr('noticesNobodyYet'),
          style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 17),
        ),
        const SizedBox(height: 8),
        Text(
          tr('noticesNoBanksLong'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }
}

/// Чему приложение научилось: магазин → категория, карта → счёт. Это и есть
/// причина, по которой трата попадает в «Продукты» сама, поэтому список
/// открыт человеку, а не спрятан внутри.
class _Learned extends StatelessWidget {
  const _Learned({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cards = <({String package, String last4, String account})>[];
    for (final package in {...knownSenders.keys, ...store.senders.keys}) {
      for (final route in store.routesOf(package)) {
        cards.add((
          package: package,
          last4: route.last4,
          account: route.account,
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        tr('noticesRememberedHowX'),
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12.5,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in store.noticeCategories.entries)
            _Chip(
              text: '${_titled(e.key)} → ${e.value}',
              onRemove: () => store.forgetNoticeCategory(e.key),
            ),
          for (final card in cards)
            _Chip(
              text: '${card.last4 == '*' ? senderTitle(card.package) : '•••• ${card.last4}'}'
                  ' → ${card.account}',
              onRemove: () =>
                  store.forgetNoticeAccount(card.package, card.last4),
            ),
        if (store.noticeCategories.isEmpty && cards.isEmpty)
          Text(
            tr('noticesLearnedNothing'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ]),
    ]);
  }

  /// Магазин запомнен строчными для сверки, а человеку показываем с большой.
  static String _titled(String raw) =>
      raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.onRemove});

  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 11, right: 5, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 11.5,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              Myna.x,
              size: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Выбор источника разом: банк, кошелёк или оба.
class _SourcePick extends StatelessWidget {
  const _SourcePick({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final source = store.noticeSource;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<NoticeSource>(
          segments: [
            ButtonSegment(
              value: NoticeSource.bank,
              label: Text(tr('noticesBank')),
            ),
            ButtonSegment(
              value: NoticeSource.wallet,
              label: Text(tr('noticesWallet')),
            ),
            ButtonSegment(
              value: NoticeSource.both,
              label: Text(tr('noticesBoth')),
            ),
          ],
          // Пустой выбор разрешён: человек может выключить чтение вовсе, и
          // подсвеченная кнопка врала бы, что что-то читается.
          emptySelectionAllowed: true,
          selected: source == null ? const {} : {source},
          showSelectedIcon: false,
          onSelectionChanged: (v) {
            if (v.isNotEmpty) store.setNoticeSource(v.first);
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      SizedBox(height: 8),
      Text(
        switch (source) {
          NoticeSource.bank =>
            tr('noticesBankNote'),
          NoticeSource.wallet =>
            tr('noticesWalletNote'),
          NoticeSource.both =>
            tr('noticesBothNoteShort'),
          null => tr('noticesNowhere'),
        },
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12.5,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
    ]);
  }
}

class _FindSheet extends StatefulWidget {
  const _FindSheet({
    required this.store,
    required this.installed,
    required this.logos,
  });

  final Store store;
  final Set<String> installed;
  final Map<String, Uint8List> logos;

  @override
  State<_FindSheet> createState() => _FindSheetState();
}

class _FindSheetState extends State<_FindSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Один пункт на ИМЯ банка, а не на пакет: у банка бывает несколько
  /// приложений (старое и новое), и два «Victoriabank» подряд читаются как
  /// ошибка приложения.
  Map<String, List<String>> get _byName {
    final text = _query.text.trim().toLowerCase();
    final out = <String, List<String>>{};
    for (final package in knownSenders.keys) {
      final name = senderTitle(package);
      if (text.isNotEmpty && !name.toLowerCase().contains(text)) continue;
      out.putIfAbsent(name, () => []).add(package);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _byName;
    final names = groups.keys.toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(children: [
            Text(
              tr('noticesBanksWallets'),
              style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 19),
            ),
            const SizedBox(height: 6),
            Text(
              tr('noticesSourcesHowShort'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: tr('bankName'),
                prefixIcon: Icon(Myna.search),
              ),
            ),
          ]),
        ),
        Flexible(
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => ListView.builder(
              shrinkWrap: true,
              itemCount: names.length,
              itemBuilder: (context, i) {
                final name = names[i];
                final packages = groups[name]!;
                final on = packages.any(
                  (p) => widget.store.modeOf(p) != NoticeMode.off,
                );
                final installed = packages.any(widget.installed.contains);
                // Логотип берём у того приложения банка, которое стоит на
                // телефоне: у второго пакета его нет и быть не может.
                final shown = packages.firstWhere(
                  (p) => widget.logos.containsKey(p),
                  orElse: () => packages.first,
                );
                return SwitchListTile(
                  value: on,
                  onChanged: (v) {
                    for (final package in packages) {
                      widget.store.setSenderMode(
                        package,
                        v ? NoticeMode.ask : NoticeMode.off,
                      );
                    }
                  },
                  secondary: SenderLogo(
                    package: shown,
                    bytes: widget.logos[shown],
                    size: 32,
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    installed
                        ? tr('noticesOnPhone')
                        : knownSenders[packages.first]!.currency,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 11.5,
                      color: installed
                          ? context.tm.text
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
      ]),
    );
  }

}
