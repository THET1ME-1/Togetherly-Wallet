import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

import 'data/models.dart';
import 'data/store.dart';
import 'services/notices.dart';
import 'logic/backup.dart';
import 'services/rates.dart';
import 'services/analytics.dart';
import 'services/session.dart';
import 'services/live.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/language.dart';
import 'l10n/strings.dart';
import 'services/local_push.dart';
import 'services/locale.dart';
import 'services/push.dart';
import 'services/push_bg.dart';
import 'services/sync.dart';
import 'design/money_theme.dart';
import 'logic/notice_match.dart';
import 'logic/period.dart';
import 'logic/stats.dart';
import 'screens/accounts_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/debts_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/plan_screen.dart';
import 'screens/categories.dart';
import 'screens/categories_edit.dart';
import 'screens/chat.dart';
import 'logic/store_kind.dart';
import 'services/ads.dart';
import 'services/billing.dart';
import 'services/lock.dart';
import 'services/snapshots.dart';
import 'services/plus.dart';
import 'screens/lock_screen.dart';
import 'screens/ask_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home.dart';
import 'screens/ledger.dart';
import 'screens/operation_edit.dart';
import 'screens/settings.dart';
import 'screens/notices_review_screen.dart';
import 'screens/stats_screen.dart';
import 'widgets/import_ask.dart';
import 'design/myna.dart';
import 'design/myna_solid.dart';

class MoneyApp extends StatefulWidget {
  final Store store;
  final Session account;
  final Sync sync;
  final Live live;
  final Notices notices;

  /// Пуши Google: основная система доставки.
  final Push push;

  /// Уведомления своими силами: вторая система, работает без сервисов Google.
  final LocalPush local;

  /// Язык интерфейса.
  final AppLocale locale;

  /// Подписка Wallet+: талон и калитки.
  final PlusService plus;

  /// Замок на вход: код и отпечаток.
  final LockService lock;

  /// Снимки базы за каждый день.
  final SnapshotService snapshots;

  const MoneyApp({
    super.key,
    required this.store,
    required this.account,
    required this.sync,
    required this.live,
    required this.notices,
    required this.push,
    required this.local,
    required this.locale,
    required this.plus,
    required this.lock,
    required this.snapshots,
  });

  @override
  State<MoneyApp> createState() => _MoneyAppState();
}

class _MoneyAppState extends State<MoneyApp> with WidgetsBindingObserver {
  Store get store => widget.store;
  Session get account => widget.account;

  bool _handledSignIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    account.addListener(_onAccountChanged);
    store.addListener(_followPair);
    _onAccountChanged();
    // Круг синхронизации на старте и на каждом возврате из фона: партнёр мог
    // записать трату, пока приложение лежало свёрнутым.
    widget.sync.run().then((_) {
      if (mounted) _seedCategoriesIfFresh();
    });
    _runRecurring();
    // Уведомления, пришедшие пока приложение было закрыто, ждут в файле
    // службы. Разбираем их на старте — иначе человек откроет приложение и
    // увидит вчерашний остаток.
    widget.notices.listen();
    _drainNotices();
    // Логотипы банков читаются один раз на сеанс: они нужны и картам счетов,
    // и разбору, а лезть в PackageManager из списков нельзя. Просим и про
    // виденные источники: у банка вне списка знак снят с самого уведомления,
    // и без этой просьбы он не доезжал до экрана.
    _loadLogos();
    _startDelivery();
    // Талон на запуске: он живёт офлайн тридцать дней, но если человек
    // отменил подписку с другого устройства, узнать об этом надо сегодня.
    unawaited(widget.plus.refresh());
  }

  /// Доставка уведомлений. Две системы, и вторая поднимается только там, где
  /// первая не работает: у Android 14 на фоновый сервис шесть часов в сутки, а
  /// строка в шторке висит весь день — держать его при живых пушах значит
  /// платить за то, чего не нужно.
  Future<void> _startDelivery() async {
    await widget.local.init();
    await widget.push.start(account);
    if (!mounted) return;
    await _followDelivery();
  }

  /// Фоновый сокет следует за парой и за вердиктом о пушах.
  ///
  /// В сборке для Play его нет вовсе: там у каждого телефона есть сервисы
  /// Google, пуши доходят через FCM, а разрешение
  /// `FOREGROUND_SERVICE_DATA_SYNC` Google требует объяснять отдельной анкетой
  /// и видео. Запасной путь живёт в сборках RuStore и GitHub — там прошивки
  /// без Google обычное дело (18.09.2026).
  Future<void> _followDelivery() async {
    if (kStore == 'play' || !account.signedIn || !widget.push.needsLocal) {
      await PushBg.stop();
      return;
    }
    final pair = store.db.pair;
    if (pair.groupId.isEmpty || pair.members.length < 2) {
      // Одиночке уведомлять некого: сам себе он записи не присылает.
      await PushBg.stop();
      return;
    }
    await PushBg.start(
      authToken: account.token,
      groupId: pair.groupId,
      myUid: account.uid,
      partnerName: pair.other(account.uid)?.name ?? '',
    );
  }

  /// Логотипы источников: список банков плюс те, от кого уже приходило.
  Future<void> _loadLogos() async {
    await widget.notices.loadLogos(knownSenders.keys);
    for (var i = 0; i < 20 && !store.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;
    final seen = {...store.noticeSenders, ...store.senders.keys};
    if (seen.isEmpty) return;
    await widget.notices.loadLogos(seen);
    if (mounted) store.notify();
  }

  /// Разбор накопившихся пушей. Ждём базу: без счетов уведомление не к чему
  /// привязать, и всё легло бы в очередь вопросов вместо готовых трат.
  Future<void> _drainNotices() async {
    for (var i = 0; i < 20 && !store.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted || !store.ready) return;
    await widget.notices.drain();
  }

  /// Регулярное отрабатывает на старте и на возврате из фона.
  ///
  /// Приложение открывают не каждый день, и платёж от пятого числа обязан
  /// появиться седьмого, а не пропасть. База грузится с диска не мгновенно,
  /// поэтому ждём готовности: прогон по пустой базе не создал бы ничего, а
  /// дату регулярного сдвинул бы.
  Future<void> _runRecurring() async {
    for (var i = 0; i < 20 && !store.ready; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted || !store.ready) return;
    store.runRecurringDue();
    // Курсы тянутся сами: до этого чужая валюта считалась один к одному,
    // пока человек не нажмёт кнопку в настройках.
    unawaited(Rates(store, account).refreshIfStale());
    // Копия базы раз в сутки — сама. Ручную человек делать забывает, а
    // «всё пропало» случается именно тогда.
    unawaited(_autoBackup());
    unawaited(widget.snapshots.daily());
  }

  /// Копия базы раз в сутки, семь последних.
  Future<void> _autoBackup() async {
    try {
      final home = await getApplicationDocumentsDirectory();
      final dir = await backupsDir(home);
      if (!await dueForBackup(dir)) return;
      await writeBackup(store, dir);
    } catch (e) {
      // Нет места или нет доступа к папке — не беда, ради которой стоит
      // тревожить человека на запуске.
      debugPrint('auto backup failed: $e');
    }
  }

  @override
  void dispose() {
    account.removeListener(_onAccountChanged);
    store.removeListener(_followPair);
    widget.notices.stop();
    widget.live.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _followed = '';

  /// Подписка идёт за парой: собралась, сменилась, распалась — канал следует.
  ///
  /// У одиночки канала нет вовсе: хранилище у него своё (`group_id == uid`),
  /// группы с таким номером не существует, и сервер честно отказывал в токене
  /// подписки — в журнале это выглядело ошибкой входа.
  void _followPair() {
    final pair = store.db.pair;
    final alone = pair.groupId == account.uid || pair.members.length < 2;
    final id = account.signedIn && !alone ? pair.groupId : '';
    if (id == _followed) return;
    _followed = id;
    widget.live.follow(id);
    _followDelivery();
  }

  /// Стартовый набор категорий кладётся ОДИН раз и только на чистое место:
  /// после круга синхронизации, когда с сервера точно ничего не приехало.
  ///
  /// До этой правки новый человек видел пустоту вместо категорий — список
  /// собирался из операций, а операций у него нет («всё пусто», 13.09.2026).
  /// Класть набор ДО синхронизации нельзя: он уехал бы дублем к партнёру,
  /// у которого категории уже есть.
  void _seedCategoriesIfFresh() {
    if (store.categoriesSeeded || !store.categoriesUntouched) return;
    store.seedCategories();
  }

  void _onAccountChanged() {
    store.syncEnabled = account.signedIn;
    store.viewer = account.signedIn ? account.uid : '';
    if (!account.signedIn) {
      _handledSignIn = false;
      // Вышел — платное закрывается сразу, а не через месяц офлайновых дней:
      // на этом телефоне его больше некому подтвердить.
      widget.plus.forget();
      PushBg.stop();
      return;
    }
    if (_handledSignIn) return;
    _handledSignIn = true;
    // Талон сверяется СРАЗУ после входа. Без этого подписка, выданная или
    // купленная где-то ещё (другой телефон, витрина lava в браузере, выдача
    // руками), не доезжала до приложения вовсе: `refresh` звал только
    // магазинный биллинг. Поймано на живом эмуляторе 17.09.2026 — сервер
    // отвечал «активна», а приложение показывало «Деньги на автопилоте».
    unawaited(widget.plus.refresh());
    _afterSignIn();
  }

  /// Что происходит сразу после входа: подтягиваем пару (человек мог прийти
  /// из Togetherly, и тогда она уже собрана) и отправляем на сервер то, что
  /// человек успел записать без аккаунта. Без переноса он решит, что потерял
  /// все свои записи.
  Future<void> _afterSignIn() async {
    try {
      final pair = await account.loadPair(preferred: store.pairChoice);
      if (pair != null && pair.groupId.isNotEmpty) store.setPair(pair);
    } catch (_) {
      // Пара подтянется следующим кругом: без неё приложение работает.
    }
    // Человек мог месяц писать без аккаунта. Молча уносить его записи в
    // облако нельзя, а молча не уносить — он решит, что всё потерял.
    // Поэтому спрашиваем один раз, и до ответа круг идёт без них.
    if (store.db.transactions.isNotEmpty && store.syncMark == 0) {
      store.pendingLocal = store.db.transactions.length;
      store.notify();
    } else {
      store.markAllForSync();
    }
    await widget.sync.run();
    _seedCategoriesIfFresh();
    _followPair();
    // Токен устройства уезжает после входа: до него сервер не знал, кому
    // слать, и первый вечер пара оставалась без уведомлений.
    await widget.push.start(account);
    await _followDelivery();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Замок считает время в фоне сам: запирать мгновенно нельзя — человек
    // выходит в сообщения посмотреть сумму перевода и возвращается.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      widget.lock.leave();
      // Накопленное уезжает при сворачивании: телефон может не открыться до
      // завтра, а статистика за вчера нужна сегодня.
      unawaited(Analytics.instance.flush());
    }
    if (state == AppLifecycleState.resumed) {
      widget.lock.comeBack();
      // Подписку могли оформить в браузере, пока приложение лежало в фоне:
      // вернулся — сверяем.
      unawaited(widget.plus.refresh());
      widget.sync.run();
      store.runRecurringDue();
      unawaited(Rates(store, account).refreshIfStale());
      widget.notices.drain();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(
          [store, account, widget.sync, widget.locale, widget.lock]),
      builder: (context, _) {
        final system = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final dark = switch (store.theme) {
          ThemeChoice.light => false,
          ThemeChoice.dark => true,
          ThemeChoice.system => system,
        };
        return MaterialApp(
          title: 'Togetherly Wallet',
          debugShowCheckedModeBanner: false,
          // Экраны считаются сами, по именованным маршрутам: вписывать вызов
          // в каждый экран — верный способ забыть половину.
          navigatorObservers: [Analytics.instance.observer],
          // Язык: выбор человека или язык телефона. Системные окна (календарь,
          // меню копирования) берут его отсюда.
          locale: widget.locale.locale,
          supportedLocales: [
            for (final l in MoneyLanguage.values) Locale(l.code),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Палитра Money задана, а не выбирается: цвет здесь означает
          // приватность (мята общее, лаванда личное), а не вкус.
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: switch (store.theme) {
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
            ThemeChoice.system => ThemeMode.system,
          },
          home: _SystemBars(
            dark: dark,
            // Замок стоит ПЕРЕД всем: пока код не введён, за ним не должно
            // быть видно ни сумм, ни списка трат — даже мельком при
            // переключении приложений.
            child: widget.lock.locked
                ? LockScreen(
                    lock: widget.lock,
                    onDone: () => setState(() {}),
                  )
                // Пока человек не выбрал, как жить, приложение не
                // открывается: иначе он начнёт писать траты, а потом
                // окажется, что они никуда не уехали.
                : account.mode == SessionMode.undecided
                    ? WelcomeScreen(account: account)
                    : Shell(
                        store: store,
                        session: account,
                        sync: widget.sync,
                        notices: widget.notices,
                        locale: widget.locale,
                        plus: widget.plus,
                        lock: widget.lock,
                        snapshots: widget.snapshots,
                      ),
          ),
        );
      },
    );
  }
}

/// Полосы системы красятся в цвет экрана: светлые края поверх тёмного
/// приложения сразу выдают чужой холст.
class _SystemBars extends StatelessWidget {
  final bool dark;
  final Widget child;
  const _SystemBars({required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Theme.of(context).colorScheme.surfaceContainer,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}

/// Оболочка: четыре вкладки и кнопка записи. Отрезок и отбор живут здесь, а не
/// внутри экранов: человек выбирает месяц один раз, и все вкладки говорят об
/// одном и том же месяце.
class Shell extends StatefulWidget {
  final Store store;

  /// Сессия и синхронизация нужны блоку «Вдвоём» в настройках. У одиночки
  /// без аккаунта их нет вовсе, и блок не рисуется.
  final Session? session;
  final Sync? sync;

  /// Чтение уведомлений: на не-Android тут ничего не происходит, и экран это
  /// говорит прямо.
  final Notices? notices;

  /// Язык интерфейса — для раздела «Язык» в настройках.
  final AppLocale? locale;

  /// Подписка Wallet+.
  final PlusService? plus;

  /// Замок: настройка живёт в разделе настроек, а сам экран — в корне.
  final LockService? lock;

  /// Снимки базы за каждый день.
  final SnapshotService? snapshots;

  const Shell({
    super.key,
    required this.store,
    this.session,
    this.sync,
    this.notices,
    this.locale,
    this.plus,
    this.lock,
    this.snapshots,
  });

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  /// Покупка подписки в магазине. У сборок RuStore и GitHub её нет: они
  /// платят через lava прямо из витрины.
  late final Billing? billing = widget.plus == null || widget.session == null
      ? null
      : Billing(session: widget.session!, plus: widget.plus!);

  /// Реклама РСЯ: живёт рядом с экранами, потому что подписку она спрашивает
  /// сама и на каждой перерисовке. Без подписки сервиса нет вовсе.
  late final Ads? ads = widget.plus == null ? null : Ads(plus: widget.plus!);

  int _page = 0;
  Period _period = Period.month();
  Filter _filter = const Filter();

  @override
  void initState() {
    super.initState();
    // SDK рекламы поднимается на старте: первый баннер иначе ждёт
    // инициализации и появляется рывком посреди чтения.
    ads?.init();
    // Магазин слушаем с запуска: покупка приходит и тогда, когда человек
    // оплатил её вчера, а приложение закрыл.
    if (storeHasBilling) billing?.listen();
  }

  bool _askedAboutLocal = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Вопрос о переносе задаётся один раз и уже внутри приложения: на экране
    // входа человеку не до него.
    if (widget.store.pendingLocal > 0 && !_askedAboutLocal) {
      _askedAboutLocal = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) askAboutLocalRecords(context, widget.store);
      });
    }
  }

  void _edit([Transaction? op]) {
    Navigator.of(context)
        .push(operationRoute(widget.store, edit: op, session: widget.session));
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Переход из круга или строки категории в ленту: отбор ставится за человека,
  /// а вкладка переключается — иначе непонятно, куда он попал.
  /// Переход из числа в ленту: отбор ставится за человека, а вкладка
  /// переключается — иначе непонятно, куда он попал.
  ///
  /// Отрезок приезжает вместе с отбором: нажали квартал «Продукты» за неделю —
  /// лента обязана показать ту же неделю, а не свой прежний месяц.
  void _drill(String? category, bool income, [Period? period]) {
    setState(() {
      _filter = Filter(
        categories: category == null ? const {} : {category},
        kinds: {income ? TxKind.income : TxKind.expense},
      );
      if (period != null) _period = period;
      _page = 3;
    });
  }

  /// Операции одного счёта. Своего экрана у счёта нет: лента умеет то же
  /// самое и больше, а вторая её копия расходилась с оригиналом
  /// (16.09.2026). Прежний отбор заменяется целиком — человек просил ИМЕННО
  /// этот счёт.
  void _drillAccount(String account) {
    setState(() {
      _filter = Filter(accounts: {account});
      _page = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = widget.store;

    final screen = switch (_page) {
      0 => HomeScreen(
          store: store,
          ads: ads,
          plus: widget.plus,
          session: widget.session,
          onSpaceSwitched: () => widget.sync?.run(),
          period: _period,
          onPeriod: (p) => setState(() => _period = p),
          onAccounts: () => _open(AccountsScreen(
            store: store,
            onEdit: _edit,
            notices: widget.notices,
            onAccountOps: _drillAccount,
            plus: widget.plus,
          )),
          // Бюджеты у пары и у одиночки — ОДИН экран. У пары он открывается
          // договорённостью: сумма предлагается, второй соглашается, и
          // предложение стоит в том же списке. Отдельный экран
          // «Договорённости» на этом месте стоял до 17.09.2026 и приводил к
          // тому, что поставленный бюджет было негде увидеть.
          onBudgets: () => _open(BudgetsScreen(store: store, plus: widget.plus)),
          // Разговор о деньгах: у вошедшего сводку собирает сервер (личный и
          // общий контуры), у одиночки без аккаунта остаётся прежний чат с
          // моделью по своему ключу.
          onGoals: () => _open(GoalsScreen(store: store, plus: widget.plus)),
          onPlan: () => _open(PlanScreen(store: store, plus: widget.plus)),
          onDebts: () => _open(DebtsScreen(store: store, plus: widget.plus)),
          onChat: () => _open(widget.session != null && widget.session!.signedIn
              ? AskScreen(
                  store: store,
                  session: widget.session!,
                  ads: ads,
                  plus: widget.plus,
                )
              : ChatScreen(store: store, onEdit: _edit)),
          onSettings: () => _open(SettingsScreen(
            billing: storeHasBilling ? billing : null,
            locale: widget.locale,
            store: store,
            session: widget.session,
            sync: widget.sync,
            notices: widget.notices,
            plus: widget.plus,
            lock: widget.lock,
            snapshots: widget.snapshots,
          )),
          // С главной человек идёт РАЗБИРАТЬ списания, а не настраивать
          // чтение: настройки живут в своём пункте настроек.
          onNotices: () => _open(NoticesReviewScreen(
            store: store,
            notices: widget.notices,
          )),
          onDrill: _drill,
        ),
      1 => CategoriesScreen(
          store: store,
          ads: ads,
          period: _period,
          onPeriod: (p) => setState(() => _period = p),
          onDrill: (name, income) => _drill(name, income),
          onEditCategories: () => _open(CategoriesEditScreen(store: store)),
        ),
      2 => StatsScreen(
          store: store,
          ads: ads,
          period: _period,
          onPeriod: (p) => setState(() => _period = p),
          onDrill: _drill,
        ),
      _ => LedgerScreen(
          store: store,
          ads: ads,
          period: _period,
          onPeriod: (p) => setState(() => _period = p),
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
          onEdit: _edit,
          notices: widget.notices,
        ),
    };

    return Scaffold(
      body: screen,
      floatingActionButton: FloatingActionButton(
        onPressed: _edit,
        tooltip: tr('navAdd'),
        child: const Icon(Myna.plus),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (n) => setState(() {
          // Уход с ленты не должен уносить отбор: человек вернётся и не поймёт,
          // куда делись его галочки. Отбор снимает только он сам.
          _page = n;
        }),
        backgroundColor: scheme.surfaceContainer,
        // Выбранный раздел НАЛИВАЕТСЯ: тот же знак MyNaUI, только из шрифта
        // заливки. Своей отрисовки по путям больше нет — её первый заход
        // выглядел кустарно и был отвергнут.
        destinations: [
          NavigationDestination(
            icon: Icon(Myna.home),
            selectedIcon: Icon(MynaSolid.home),
            label: tr('navHome'),
          ),
          NavigationDestination(
            icon: Icon(Myna.chartPie),
            selectedIcon: Icon(MynaSolid.chartPie),
            label: tr('navCategories'),
          ),
          NavigationDestination(
            icon: Icon(Myna.chartBar),
            selectedIcon: Icon(MynaSolid.chartBar),
            label: tr('navStats'),
          ),
          NavigationDestination(
            icon: Icon(Myna.fileText),
            selectedIcon: Icon(MynaSolid.fileText),
            label: tr('navLedger'),
          ),
        ],
      ),
    );
  }
}
