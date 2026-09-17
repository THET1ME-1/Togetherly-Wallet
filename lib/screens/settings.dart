import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/session.dart';
import '../services/sync.dart';
import 'pair_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/links.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../logic/backup.dart';
import '../logic/chat_log.dart';
import '../services/locale.dart';
import '../widgets/language_sheet.dart';
import '../logic/presets.dart';
import '../logic/split.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'currency_screen.dart';
import '../widgets/rules_sheet.dart';
import '../widgets/app_sheet.dart';
import '../widgets/member_badge.dart';
import '../widgets/settings_kit.dart';
import '../widgets/split_rule_sheet.dart';
import 'categories_edit.dart';
import 'debts_screen.dart';
import 'recurring_screen.dart';
import '../design/app_theme.dart';
import '../logic/ask.dart';
import '../logic/notice_match.dart';
import '../services/notices.dart';
import '../logic/period.dart';
import '../services/billing.dart';
import '../logic/plus.dart';
import '../widgets/plus_gate.dart';
import '../services/lock.dart';
import '../services/plus.dart';
import '../services/snapshots.dart';
import 'plus_screen.dart';
import 'lock_screen.dart';
import 'notices_screen.dart';
import 'report_screen.dart';
import 'review_screen.dart';
import 'snapshots_screen.dart';
import '../design/myna.dart';

/// Настройки. Порядок разделов — по тому, как часто в них заходят: вид меняют
/// чаще, чем ключи моделей.
/// Настройки. Здесь же живёт вход в пару: приглашение, состав, выход.
class SettingsScreen extends StatefulWidget {
  final Store store;
  const SettingsScreen({
    super.key,
    required this.store,
    this.session,
    this.sync,
    this.notices,
    this.locale,
    this.plus,
    this.lock,
    this.snapshots,
    this.billing,
  });

  final Session? session;
  final Sync? sync;
  final Notices? notices;

  /// Язык интерфейса. Может не приехать в тестах отдельных экранов — тогда
  /// раздел языка просто не показывается.
  final AppLocale? locale;

  /// Подписка Wallet+: строка состояния и вход на витрину.
  final PlusService? plus;

  /// Замок на вход: код и отпечаток.
  final LockService? lock;

  /// Снимки базы за каждый день.
  final SnapshotService? snapshots;

  /// Покупка в магазине. Пусто — витрина предложит кассу lava или скажет
  /// «скоро», смотря по сборке.
  final Billing? billing;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _note;

  /// Что написано под строкой подписки: срок у действующей, обещание у той,
  /// которой нет.
  String _plusNote() {
    final plus = widget.plus;
    if (plus == null || !plus.active) return tr('plusTitle');
    final pass = plus.pass!;
    final until = DateTime.fromMillisecondsSinceEpoch(pass.until);
    final line = trf('plusUntil', [Period(PeriodKind.day, until).label]);
    return pass.fromPartner ? '$line · ${tr('plusFromPartner')}' : line;
  }


  /// Что написано под строкой замка.
  String _lockNote() {
    final lock = widget.lock;
    if (lock == null || !lock.enabled) return tr('lockRowOff');
    return lock.biometrics ? tr('lockRowBoth') : tr('lockRowOn');
  }

  /// Замок: завести код, включить отпечаток, снять.
  ///
  /// Калитка стоит на ВКЛЮЧЕНИИ, а не на экране: человек, чья подписка
  /// кончилась, обязан уметь снять свой замок — иначе платная функция
  /// запирает его в собственном приложении.
  Future<void> _openLock() async {
    final lock = widget.lock;
    if (lock == null) return;
    if (!lock.enabled) {
      if (!await askPlus(context, plus: widget.plus, gate: PlusGate.lock)) {
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LockScreen(
          lock: lock,
          setup: true,
          onDone: () => Navigator.of(context).pop(),
        ),
      ));
      if (mounted) setState(() {});
      return;
    }

    final can = await lock.canBiometrics();
    if (!mounted) return;
    await showMoneySheet<void>(
      context,
      builder: (context) => ListenableBuilder(
        listenable: lock,
        builder: (context, _) => SheetScaffold(
          icon: Myna.lock,
          title: tr('lockRow'),
          action: tr('lockChange'),
          onAction: () {
            Navigator.of(context).pop();
            Navigator.of(this.context).push(MaterialPageRoute(
              builder: (_) => LockScreen(
                lock: lock,
                setup: true,
                onDone: () => Navigator.of(this.context).pop(),
              ),
            ));
          },
          cancel: tr('close'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (can)
                SettingsRow(
                  icon: Myna.faceId,
                  title: tr('lockBiometrics'),
                  subtitle: tr('lockBiometricsNote'),
                  trailing: Switch(
                    value: lock.biometrics,
                    onChanged: (v) => lock.setBiometrics(v),
                  ),
                ),
              SettingsRow(
                icon: Myna.trash,
                title: tr('lockRemove'),
                subtitle: tr('lockRemoveText'),
                titleColor: Theme.of(context).colorScheme.error,
                onTap: () async {
                  await lock.disable();
                  if (context.mounted) Navigator.of(context).pop();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Копии на устройстве, от свежей к старой.
  List<File> _backups = const [];

  /// Удаление аккаунта идёт тремя запросами и занимает секунды: пока оно
  /// идёт, экран накрыт, иначе по кнопке нажмут второй раз.
  bool _deleting = false;

  /// Версия берётся из сборки, а не пишется руками: руками она врёт через
  /// один релиз.
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    }).catchError((_) => null);
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    try {
      final home = await getApplicationDocumentsDirectory();
      final dir = await backupsDir(home);
      if (mounted) setState(() => _backups = backupsIn(dir));
    } catch (_) {
      // Папки может не быть вовсе — тогда и строка скажет, что копий нет.
    }
  }

  /// Готовые акценты. Первый — фирменный индиго Орбиты, к нему возвращает
  /// кнопка сброса.

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: Text(tr('settingsTitle'))),
          // Пока аккаунт удаляется, экран не принимает нажатий: запросов три,
          // и повторное «Удалить» ушло бы в уже мёртвую сессию.
          body: _deleting
              ? const Center(child: CircularProgressIndicator())
              : ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              if (widget.session != null) ...[
                SettingsSection(tr('sectionTogether'), icon: Myna.heart),
                SettingsGroup([
                  SettingsBlock(
                    child: _PairBlock(
                      store: store,
                      session: widget.session!,
                      sync: widget.sync,
                    ),
                  ),
                ]),
              ],
              // Подписка стоит СРАЗУ под парой и выше оформления: человек
              // ищет её там же, где состояние аккаунта, а не в конце списка
              // среди версий и лицензий.
              if (widget.plus != null) ...[
                SettingsSection(tr('plusSection'), icon: Myna.sparkles),
                SettingsGroup([
                  SettingsRow(
                    icon: Myna.sparkles,
                    title: tr('plusName'),
                    subtitle: _plusNote(),
                    trailing: const SettingsChevron(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlusScreen(
                        plus: widget.plus!,
                        onBuy: widget.billing == null
                            ? null
                            : (plan) => widget.billing!.buy(plan),
                        onRestore: widget.billing?.restore,
                        prices: widget.billing?.prices,
                      ),
                    )),
                  ),
                ]),
              ],
              SettingsSection(tr('sectionLook'), icon: Myna.swatches),
              SettingsGroup([
                SettingsBlock(
                  child: _Segments(value: store.theme, onChange: store.setTheme),
                ),
                SettingsRow(
                  icon: Myna.circleHalf,
                  title: tr('blackBackground'),
                  subtitle: tr('blackBackgroundNote'),
                  onTap: () => store.setAmoled(!store.amoled),
                  trailing: Switch(
                    value: store.amoled,
                    onChanged: store.setAmoled,
                  ),
                ),
              ]),
              if (widget.locale != null) ...[
                SettingsSection(tr('languageSection'), icon: Myna.globe),
                SettingsGroup([
                  SettingsRow(
                    icon: Myna.globe,
                    title: tr('languageRow'),
                    subtitle: widget.locale!.chosen?.label ??
                        '${tr('languageSystem')} · ${widget.locale!.language.label}',
                    trailing: SettingsChevron(),
                    onTap: () => showLanguageSheet(context, widget.locale!),
                  ),
                ]),
              ],
              SettingsSection(tr('sectionMoney'), icon: Myna.arrowLeftRight),
              SettingsGroup([
                SettingsRow(
                  icon: Myna.dollarSquare,
                  title: tr('currencyRow'),
                  subtitle: _currencyNote(store),
                  trailing: SettingsChevron(),
                  onTap: () => showCurrencySheet(
                    context,
                    store: store,
                    session: widget.session,
                  ),
                ),
                SettingsRow(
                  icon: Myna.label,
                  title: tr('categoriesRow'),
                  subtitle: tr('categoriesNote'),
                  trailing: const SettingsChevron(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CategoriesEditScreen(store: store),
                  )),
                ),
                SettingsRow(
                  icon: Myna.refresh,
                  title: tr('catResetRow'),
                  subtitle: tr('catResetNote'),
                  trailing: const SettingsChevron(),
                  onTap: _resetCategories,
                ),
                SettingsRow(
                  icon: Myna.trash,
                  title: tr('catWipeRow'),
                  subtitle: tr('catWipeNote'),
                  trailing: const SettingsChevron(),
                  titleColor: scheme.error,
                  onTap: _wipeCategories,
                ),
              ]),
              SettingsSection(tr('sectionBudget'), icon: Myna.box),
              SettingsGroup([
                SettingsRow(
                  icon: Myna.listCheck,
                  title: tr('rulesRow'),
                  subtitle: tr('rulesNote'),
                  trailing: SettingsChevron(),
                  onTap: () => showRules(context, store),
                ),
                SettingsRow(
                  icon: Myna.refresh,
                  title: tr('recurringRow'),
                  subtitle: tr('recurringNote'),
                  trailing: SettingsChevron(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RecurringScreen(
                      store: store,
                      plus: widget.plus,
                    ),
                  )),
                ),
                if (widget.session != null)
                  SettingsRow(
                    icon: Myna.sparkles,
                    title: tr('monthReviewRow'),
                    subtitle: tr('monthReviewCardNote'),
                    trailing: const SettingsChevron(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReviewScreen(
                        store: store,
                        session: widget.session!,
                        plus: widget.plus,
                      ),
                    )),
                  ),
                if (widget.session != null)
                  SettingsRow(
                    icon: Myna.fileText,
                    title: tr('reportRow'),
                    subtitle: tr('reportRowNote'),
                    trailing: const SettingsChevron(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportScreen(
                        store: store,
                        session: widget.session!,
                        plus: widget.plus,
                      ),
                    )),
                  ),
                if (widget.snapshots != null && widget.session != null)
                  SettingsRow(
                    icon: Myna.archive,
                    title: tr('snapshotRow'),
                    subtitle: widget.snapshots!.ready
                        ? tr('snapshotRowOn')
                        : tr('snapshotRowOff'),
                    trailing: const SettingsChevron(),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SnapshotsScreen(
                        service: widget.snapshots!,
                        plus: widget.plus,
                      ),
                    )),
                  ),
                SettingsRow(
                  icon: Myna.lock,
                  title: tr('lockRow'),
                  subtitle: _lockNote(),
                  trailing: const SettingsChevron(),
                  onTap: _openLock,
                ),
                SettingsRow(
                  icon: Myna.bellOn,
                  title: tr('noticesRow'),
                  subtitle: _noticesNote(store),
                  trailing: const SettingsChevron(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => NoticesScreen(
                      store: store,
                      notices: widget.notices,
                      plus: widget.plus,
                    ),
                  )),
                ),
                SettingsRow(
                  icon: Myna.creditCard,
                  title: tr('debtsRow'),
                  subtitle: tr('debtsNote'),
                  trailing: const SettingsChevron(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DebtsScreen(store: store),
                  )),
                ),
              ]),
              SettingsSection(tr('sectionData'), icon: Myna.folder),
              SettingsGroup([
                SettingsRow(
                  icon: Myna.fileText,
                  title: tr('importRow'),
                  subtitle: tr('importNote'),
                  trailing: SettingsChevron(),
                  onTap: _pick,
                ),
                SettingsRow(
                  icon: Myna.share,
                  title: tr('exportRow'),
                  subtitle: tr('exportNote'),
                  trailing: const SettingsChevron(),
                  onTap: _export,
                ),
                // Копии, которые приложение делает само. Человек про них не
                // думает, пока не случилось «всё пропало».
                SettingsRow(
                  icon: Myna.archive,
                  title: tr('backupsRow'),
                  subtitle: _backupsNote(),
                  trailing: const SettingsChevron(),
                  onTap: _pickBackup,
                ),
              ]),
              if (_note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Text(
                    _note!,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // У вошедшего разговор о деньгах идёт через сервер: сводку
              // собирает он, а ключ модели человеку не нужен вовсе. Показывать
              // поле для ключа значило бы намекать, что без него не работает.
              if (widget.session == null || !widget.session!.signedIn) ...[
                SettingsSection(tr('aiKeysRow'), icon: Myna.key),
                SettingsGroup([
                  SettingsBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('aiKeysNoteFull'),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 13,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final p in Provider.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _KeyField(
                              store: store,
                              who: p.name,
                              title: _providerName(p),
                            ),
                          ),
                      ],
                    ),
                  ),
                ]),
              ],
              if (widget.session != null && widget.session!.signedIn) ...[
                SettingsSection(tr('sectionAccount'), icon: Myna.user),
                SettingsGroup([
                  SettingsRow(
                    icon: Myna.at,
                    title: widget.session!.email,
                    subtitle: tr('accountShared'),
                  ),
                  SettingsRow(
                    icon: Myna.logout,
                    title: tr('signOutRow'),
                    subtitle: tr('signOutNote'),
                    trailing: SettingsChevron(),
                    onTap: _signOut,
                  ),
                ]),
              ],
              SettingsSection(tr('sectionApp'), icon: Myna.infoCircle),
              SettingsGroup([
                SettingsRow(
                  icon: Myna.support,
                  title: tr('supportRow'),
                  subtitle: tr('supportNote'),
                  trailing: SettingsChevron(),
                  onTap: () => _open(kSupportMail),
                ),
                SettingsRow(
                  icon: Myna.bug,
                  title: tr('bugBotRow'),
                  subtitle: tr('bugBotNote'),
                  trailing: SettingsChevron(),
                  onTap: () => _open(kBugBot),
                ),
                SettingsRow(
                  icon: Myna.telegram,
                  title: tr('channelRow'),
                  subtitle: tr('channelNote'),
                  trailing: SettingsChevron(),
                  onTap: () => _open(kTgChannel),
                ),
                SettingsRow(
                  icon: Myna.video,
                  title: tr('tiktokRow'),
                  subtitle: tr('tiktokNote'),
                  trailing: SettingsChevron(),
                  onTap: () => _open(kTikTok),
                ),
                SettingsRow(
                  icon: Myna.shield,
                  title: tr('privacyRow'),
                  subtitle: tr('privacyNote'),
                  trailing: SettingsChevron(),
                  onTap: () => _open(kPrivacy),
                ),
                SettingsRow(
                  icon: Myna.hash,
                  title: tr('versionRow'),
                  subtitle: _version,
                ),
              ]),
              // Стереть всё стоит последним и отдельной секцией цвета ошибки:
              // рядом с «сохранить копию» по нему промахиваются.
              SettingsSection(
                tr('sectionDanger'),
                icon: Myna.dangerTriangle,
                color: scheme.error,
              ),
              SettingsGroup([
                SettingsRow(
                  icon: Myna.trash,
                  title: tr('wipeRow'),
                  subtitle: tr('wipeRowNote'),
                  iconBg: scheme.errorContainer,
                  iconFg: scheme.onErrorContainer,
                  titleColor: scheme.error,
                  onTap: _wipe,
                ),
                if (widget.session?.signedIn == true)
                  SettingsRow(
                    icon: Myna.userX,
                    title: tr('deleteAccountRow'),
                    subtitle: tr('deleteAccountRowNote'),
                    iconBg: scheme.errorContainer,
                    iconFg: scheme.onErrorContainer,
                    titleColor: scheme.error,
                    onTap: _deleteAccount,
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }

  /// Удаление аккаунта.
  ///
  /// Требование магазинов: удалить аккаунт и данные человек должен уметь из
  /// самого приложения, а не письмом в поддержку. Подтверждение просит ввести
  /// слово: «Удалить» рядом с «Выйти» нажимают по промаху, а обратно вернуть
  /// нечего.
  ///
  /// Запись человека одна на экосистему, поэтому исчезает и аккаунт
  /// Togetherly. Говорим это прямо в первой строке: тихо снести человеку
  /// второе приложение нельзя.
  Future<void> _deleteAccount() async {
    final session = widget.session;
    if (session == null || !session.signedIn) return;
    final store = widget.store;
    final inPair = store.db.pair.members.length > 1;

    final typed = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final yes = await showMoneySheet<bool>(
      context,
      // Пока слово не введено, кнопка выключена: лист слушает поле.
      builder: (context) => ValueListenableBuilder(
        valueListenable: typed,
        builder: (context, value, _) => SheetScaffold(
          icon: Myna.userX,
          tone: scheme.error,
          title: tr('deleteAccountTitle'),
          text: inPair
              ? '${trf('deleteAccountText', ['${Session.deleteGraceDays}'])} '
                  '${tr('deleteAccountPairNote')}'
              : trf('deleteAccountText', ['${Session.deleteGraceDays}']),
          action: tr('deleteAccountAction'),
          actionEnabled: value.text.trim().toLowerCase() ==
              tr('deleteAccountWord').toLowerCase(),
          onAction: () => Navigator.of(context).pop(true),
          // Слово вводят руками: «Удалить» рядом с «Выйти» нажимают по
          // промаху, а возврата нет.
          child: _TypedConfirm(
            controller: typed,
            word: tr('deleteAccountWord'),
          ),
        ),
      ),
    );
    typed.dispose();
    if (yes != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await session.deleteAccount(pair: store.db.pair);
      // Данные с устройства уходят тоже: аккаунта больше нет, а записи на
      // телефоне без него — след человека, который просил его убрать.
      store.wipe();
      await _forgetChat();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('deleteFailed', [e]))),
      );
    }
  }

  /// Выход из аккаунта. Данные с устройства не стираются: человек выходит,
  /// чтобы сменить аккаунт, а не чтобы потерять год записей.
  Future<void> _signOut() async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.logout,
        title: tr('signOutTitle'),
        text: tr('signOutText'),
        action: tr('signOut'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true) return;
    await widget.session?.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Открыть ссылку наружу.
  ///
  /// `launchUrl` на mailto без почтовой программы не возвращает false, а
  /// БРОСАЕТ `PlatformException` — без перехвата экран настроек падал бы на
  /// телефоне, где почта не заведена.
  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) setState(() => _note = tr('linkFailed'));
  }

  /// Вернуть стандартный набор категорий. Свои остаются: категория опознаётся
  /// именем, и перезапись унесла бы вместе с собой цвет, значок и привязку к
  /// счетам.
  Future<void> _resetCategories() async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.refresh,
        title: tr('catResetTitle'),
        text: trf('catResetText', ['${presetCount()}']),
        action: tr('catResetDo'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true || !mounted) return;
    widget.store.seedCategories();
    setState(() => _note = tr('catResetDone'));
  }

  /// Стереть все категории. Операции остаются: деньги записаны, и стирать их
  /// вместе с ярлыком нельзя.
  Future<void> _wipeCategories() async {
    final scheme = Theme.of(context).colorScheme;
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.trash,
        tone: scheme.error,
        title: tr('catWipeTitle'),
        text: tr('catWipeText'),
        action: tr('catWipeDo'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true || !mounted) return;
    widget.store.clearCategories();
    setState(() => _note = tr('catWipeDone'));
  }

  Future<void> _wipe() async {
    final scheme = Theme.of(context).colorScheme;
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.trash,
        tone: scheme.error,
        title: tr('wipeTitle'),
        text: tr('wipeText'),
        action: tr('wipe'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true) {
      widget.store.wipe();
      await _forgetChat();
      if (mounted) setState(() => _note = tr('wipeDone'));
    }
  }

  /// Переписка чата лежит своим файлом рядом с базой, и стирается вместе с ней:
  /// разговоры о деньгах — такой же след человека, как его траты.
  Future<void> _forgetChat() async {
    try {
      await ChatLog.forgetAll(await getApplicationDocumentsDirectory());
    } catch (_) {
      // Папки данных нет — стирать нечего.
    }
  }

  Future<void> _pick() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked?.files.firstOrNull;
    if (file == null) return;
    try {
      final text = file.bytes != null
          ? String.fromCharCodes(file.bytes!)
          : await File(file.path!).readAsString();
      final count = widget.store.importBackup(text);
      if (mounted) setState(() => _note = trf('importDone', [count]));
    } catch (_) {
      if (mounted) setState(() => _note = tr('importFailed'));
    }
  }

  /// Что написать про копии: когда сделана последняя и сколько их.
  String _backupsNote() {
    if (_backups.isEmpty) return tr('backupsNone');
    final name = _backups.first.path.split('/').last;
    final day = name.replaceAll('money-', '').replaceAll('.json', '');
    return trf('backupsHave', [day, '${_backups.length}']);
  }

  /// Восстановить из копии, сделанной приложением.
  Future<void> _pickBackup() async {
    if (_backups.isEmpty) {
      setState(() => _note = tr('backupsNone'));
      return;
    }
    final picked = await showMoneySheet<File>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.archive,
        title: tr('backupsPick'),
        text: tr('backupsText'),
        action: tr('cancel'),
        onAction: () => Navigator.of(context).pop(),
        child: Column(children: [
          for (final file in _backups)
            _BackupLine(
              file: file,
              onTap: () => Navigator.of(context).pop(file),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      final count = widget.store.importBackup(await picked.readAsString());
      if (!mounted) return;
      setState(() => _note = count > 0
          ? trf('importDone', [count])
          : tr('importFailed'));
    } catch (_) {
      if (mounted) setState(() => _note = tr('importFailed'));
    }
  }

  Future<void> _export() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/orbita-backup.json');
    await file.writeAsString(widget.store.exportJson());
    await Share.shareXFiles([XFile(file.path)]);
  }
}

/// Подпись строки валюты: базовая и сколько курсов задано. «MDL · курс USD и
/// EUR» отвечает на вопрос до захода внутрь.
String _currencyNote(Store store) {
  final base = store.db.baseCurrency;
  final others = store.currenciesInUse;
  if (others.isEmpty) return trf('currencyTotals', [base]);
  final known = others.where((c) => (store.db.rates[c] ?? 0) > 0).length;
  if (known == 0) return trf('ratesNone', [base]);
  if (known < others.length) {
    return trf('ratesMissing', [base, others.length - known]);
  }
  return trf('ratesSet', [base, others.join(', ')]);
}

/// Подпись строки уведомлений говорит состояние, а не название функции:
/// «включено у трёх банков» отвечает на вопрос до того, как человек зашёл.
String _noticesNote(Store store) {
  if (!Notices.supported) return tr('noticesAndroidOnly');
  final waiting = store.pendingNotices.length;
  if (waiting > 0) return trf('noticesWaiting', [waiting]);
  final on = store.senders.values.where((m) => m != NoticeMode.off).length;
  final seen = store.noticeSenders.length;
  if (seen > 0) return trf('noticesRead', [seen, trn('source', seen)]);
  if (on == 0) return tr('noticesNote');
  return trf('noticesSourcesOn', [on]);
}

/// Имя провайдера так, как его пишут сами: ключ в базе остаётся строчным.
String _providerName(Provider p) => switch (p) {
      Provider.deepseek => 'DeepSeek',
      Provider.openrouter => 'OpenRouter',
      Provider.gemini => 'Gemini',
      Provider.claude => 'Claude',
    };

class _Segments extends StatelessWidget {
  final ThemeChoice value;
  final ValueChanged<ThemeChoice> onChange;
  const _Segments({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeChoice>(
      segments: [
        ButtonSegment(
          value: ThemeChoice.light,
          icon: const Icon(Myna.sun),
          label: Text(tr('themeLight')),
        ),
        ButtonSegment(
          value: ThemeChoice.system,
          icon: const Icon(Myna.eclipse),
          label: Text(tr('themeAuto')),
        ),
        ButtonSegment(
          value: ThemeChoice.dark,
          icon: const Icon(Myna.moon),
          label: Text(tr('themeDark')),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (s) => onChange(s.first),
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: AppTheme.bodyFont, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}


/// Поле ключа: значение прячется точками, но видно, что ключ задан.
class _KeyField extends StatefulWidget {
  final Store store;
  final String who;
  final String title;
  const _KeyField({required this.store, required this.who, required this.title});

  @override
  State<_KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<_KeyField> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.store.modelKeys[widget.who] ?? '';
    return TextField(
      controller: TextEditingController(text: value),
      obscureText: !_open,
      onChanged: (v) => widget.store.setKey(widget.who, v),
      style: TextStyle(fontFamily: AppTheme.bodyFont, fontSize: 14),
      decoration: InputDecoration(
        // Подпись у поля стоит строкой снаружи: `labelText` тема не
        // показывает вовсе (`floatingLabelBehavior: never`).
        hintText: tr('notSet'),
        suffixIcon: IconButton(
          icon: Icon(_open ? Myna.eyeOff : Myna.eye),
          onPressed: () => setState(() => _open = !_open),
        ),
      ),
    );
  }
}

/// Пара и синхронизация одним блоком: кто с вами, когда всё уехало и куда
/// нажать, чтобы позвать второго.
/// Правило дележа словами: у «по доходу» видны и сами доли, иначе непонятно,
/// что именно пара выбрала.
String _splitRuleLine(Store store) {
  final pair = store.db.pair;
  return switch (pair.defaultSplit) {
    SplitMode.equal => tr('splitEvenly'),
    SplitMode.payerOnly => tr('splitPayerPays'),
    SplitMode.income => 'По доходу: ${[
        for (final m in pair.members)
          '${m.name} ${(m.incomeShareBp / 100).round()}%',
      ].join(' · ')}',
    SplitMode.custom => tr('splitByShares'),
    SplitMode.none => tr('splitNone'),
  };
}

class _PairBlock extends StatefulWidget {
  const _PairBlock({required this.store, required this.session, this.sync});

  final Store store;
  final Session session;
  final Sync? sync;

  @override
  State<_PairBlock> createState() => _PairBlockState();
}

class _PairBlockState extends State<_PairBlock> {
  Store get store => widget.store;
  Session get session => widget.session;
  Sync? get sync => widget.sync;

  /// Живые пары, кроме нынешней. Спрашиваются один раз при входе на экран:
  /// список короткий, и дёргать сервер на каждый кадр незачем.
  List<Pair> _others = const [];

  @override
  void initState() {
    super.initState();
    _loadOthers();
  }

  Future<void> _loadOthers() async {
    if (!session.signedIn) return;
    try {
      final all = await session.loadPairs();
      if (!mounted) return;
      setState(() => _others = all
          .where((p) => p.groupId != store.db.pair.groupId)
          .toList());
    } catch (_) {
      // Сеть мёртвая — строки выбора просто не будет.
    }
  }

  /// Перейти в другую пару. Хранилище меняется целиком: записи прежней пары
  /// уходят, метка дельты сбрасывается, свои неотправленные переезжают.
  Future<void> _switchPair(BuildContext context) async {
    final picked = await showMoneySheet<Pair>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.users,
        title: tr('pairSwitchTitle'),
        text: tr('pairSwitchText'),
        action: tr('cancel'),
        onAction: () => Navigator.of(context).pop(),
        child: Column(children: [
          for (final p in _others)
            _PairLine(
              pair: p,
              me: session.uid,
              onTap: () => Navigator.of(context).pop(p),
            ),
        ]),
      ),
    );
    if (picked == null || !context.mounted) return;
    // Хранилище прежней пары не стирается, а откладывается: вернуться в него
    // можно тем же переключателем, и ждать нового круга не придётся.
    store.setPairChoice(picked.groupId);
    store.openSpace(picked);
    sync?.run();
    await _loadOthers();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pair = store.db.pair;
    final partner = pair.other(session.uid);
    final me = pair.byUid(session.uid);
    final myName = (me?.name ?? session.name).trim();
    final state = _syncLine(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Шапка профиля: лица и имена, а не строка почты. Почта — служебное
      // поле, а человек узнаёт себя и партнёра по лицу.
      Row(children: [
        _Faces(me: me, partner: partner, myName: myName),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              myName.isEmpty
                  ? (session.signedIn ? session.email : tr('accountNone'))
                  : myName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              partner != null
                  ? trf('pairWith', [partner.name])
                  : (session.signedIn ? session.email : tr('pairNone')),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ]),
        ),
      ]),

      const SizedBox(height: 12),
      // Состояние синхронизации — точкой и словом: цвет отвечает на вопрос
      // «всё ли уехало» раньше, чем человек дочитает строку.
      Row(children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: state.$2, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            state.$1,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              color: state.$2 == scheme.error
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ]),

      // Пары нет — скажем, почему её может не быть. Вход другим аккаунтом
      // заводит новую пустую учётку, и человек считает, что «всё обнулилось»
      // (13.09.2026).
      if (partner == null && session.signedIn) ...[
        const SizedBox(height: 8),
        Text(
          tr('pairFromTogetherly'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
      // Правило дележа — общее имущество пары, и меняется оно здесь, а не в
      // каждой записи по отдельности.
      if (partner != null) ...[
        const SizedBox(height: 12),
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => showSplitRule(context, store),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Myna.gitBranch, size: 20, color: scheme.onSurfaceVariant),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      tr('splitRow'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _splitRuleLine(store),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
                ),
                Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      ],
      SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: FilledButton(
            onPressed: session.signedIn
                ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PairScreen(session: session, store: store),
                    ))
                : null,
            child: Text(partner == null ? tr('pairInvite') : tr('pairCode')),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: sync == null ? null : () => sync!.run(),
          child: Text(tr('pairRefresh')),
        ),
      ]),
      // Пар бывает несколько: в базе Togetherly две тысячи человек состоят в
      // двух живых группах. Раньше приложение молча брало первую попавшуюся.
      if (_others.isNotEmpty) ...[
        const SizedBox(height: 10),
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _switchPair(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Myna.users, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trf('pairOthers', ['${_others.length}']),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      ],
      // Распустить пару можно только когда партнёр есть: у одиночки строка
      // читалась бы как «удалить что-то важное».
      if (partner != null) ...[
        const SizedBox(height: 10),
        // Опасное действие — обычным блоком с красным значком и словом.
        // Розовая полупрозрачная плашка на тёмном читалась грязным пятном.
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _disband(context, store, session, partner),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Icon(Myna.heartCrack, size: 20, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('disbandRow'),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.error,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('disbandRowNote'),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      ],
    ]);
  }

  /// Состояние синхронизации: что написать и каким цветом зажечь точку.
  (String, Color) _syncLine(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pending = store.outbox.length;
    if (sync == null) {
      return (tr('syncDone'), scheme.onSurfaceVariant);
    }
    if (sync!.busy) return (tr('syncRunning'), scheme.primary);
    // Пока назначен повтор, красной строки нет: приложение уже само
    // разбирается, и пугать человека нечем.
    if (sync!.retrying) return (tr('syncRetrying'), scheme.tertiary);
    if (sync!.error != null) return (sync!.error!, scheme.error);
    if (pending > 0) {
      return (trf('syncPending', [pending]), scheme.tertiary);
    }
    return (tr('syncDone'), scheme.primary);
  }

  /// Роспуск пары. Записи с устройства не исчезают: пара кончилась, а учёт
  /// продолжается — они просто переезжают в личное хранилище и уезжают на
  /// сервер под своим uid.
  Future<void> _disband(
    BuildContext context,
    Store store,
    Session session,
    Member partner,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.heartCrack,
        tone: scheme.error,
        title: tr('disbandTitle'),
        // Имя склоняется: «с Линеллой», а не «с Линелла». Латинское имя
        // остаётся как есть — «с Partnerой» выглядело бы поломкой.
        text: trf('disbandText', [instrumentalName(partner.name)]),
        action: tr('disband'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true || !context.mounted) return;

    try {
      await session.disbandPair(store.db.pair);
      store.leavePair(session.uid);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('disbandDone'))),
      );
      sync?.run();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('disbandFailed', [e]))),
      );
    }
  }
}

/// Поле подтверждения словом.
///
/// Опасное действие требует напечатать слово: это единственная защита, которую
/// не обойти промахом пальца.
class _TypedConfirm extends StatelessWidget {
  const _TypedConfirm({required this.controller, required this.word});

  final TextEditingController controller;
  final String word;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: trf('typeWord', [word]),
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
    );
  }
}

/// Опасная строка внутри карточки: знак, название, подпись последствия.
///
/// Текстовая ссылка в углу карточки читалась как сноска, а это решение, после
/// которого пара перестаёт вести общий учёт.


/// Два лица внахлёст: своё и партнёра. У одиночки — одно.
///
/// Аватар отвечает на вопрос «чей это профиль» быстрее строки почты, а пара
/// узнаётся без единого слова.
class _Faces extends StatelessWidget {
  const _Faces({required this.me, required this.partner, required this.myName});

  final Member? me;
  final Member? partner;
  final String myName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final single = partner == null;
    return SizedBox(
      width: single ? 52 : 78,
      height: 52,
      child: Stack(children: [
        if (partner != null)
          Positioned(
            right: 0,
            child: _Ring(
              color: scheme.surfaceContainerHigh,
              child: MemberBadge(
                member: partner,
                size: 44,
                showName: false,
              ),
            ),
          ),
        Positioned(
          left: 0,
          child: _Ring(
            color: scheme.surfaceContainerHigh,
            child: MemberBadge(
              member: me ?? Member(uid: '', name: myName),
              isMe: true,
              size: 44,
              showName: false,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Кольцо цвета подложки: без него два лица слипаются в пятно.
class _Ring extends StatelessWidget {
  const _Ring({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child,
      );
}


/// Строка пары в выборе: лица, имя партнёра и число участников.
class _PairLine extends StatelessWidget {
  const _PairLine({required this.pair, required this.me, required this.onTap});

  final Pair pair;
  final String me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final other = pair.other(me);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              MemberBadge(member: other, size: 32, showName: false),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  other?.name ?? tr('accountPartner'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}


/// Строка копии в списке: день и размер.
class _BackupLine extends StatelessWidget {
  const _BackupLine({required this.file, required this.onTap});

  final File file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = file.path.split('/').last;
    final day = name.replaceAll('money-', '').replaceAll('.json', '');
    final kb = (file.lengthSync() / 1024).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Myna.archive, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  day,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                trf('backupsSize', ['$kb']),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
