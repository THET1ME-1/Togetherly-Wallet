import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'session.dart';

/// Своя аналитика: экраны, действия, воронка новичка, деньги и реклама.
///
/// Считает Tessera (`github.com/THET1ME-1/Tessera`) — та же, что у Togetherly,
/// но ПРИЛОЖЕНИЕ другое: у Wallet свой ключ, и события ложатся под `wallet`.
/// Аккаунт у экосистемы общий, поэтому иначе было бы не ответить на простой
/// вопрос — сколько людей у Wallet, а сколько у Togetherly (просьба человека
/// 18.09.2026).
///
/// Приватность прежняя: `uid` уходит как есть, а хеширует его СЕРВЕР своей
/// солью — связки «человек → его экраны» в базе нет. Событие несёт имя экрана,
/// имя действия и числа. Ни сумм, ни категорий, ни заметок: это деньги пары, и
/// в аналитике им не место.
class Analytics {
  Analytics._();
  static final Analytics instance = Analytics._();

  /// Отдельная копия для тестов: со своим ключом и своим транспортом.
  @visibleForTesting
  factory Analytics.forTest({required String key, required http.Client client}) {
    final a = Analytics._();
    a._keyForTest = key;
    a._client = client;
    return a;
  }

  String? _keyForTest;
  http.Client? _client;

  /// Ключ приложения в Tessera. Приходит сборкой
  /// (`--dart-define=TESSERA_KEY=...`) и в репозитории не лежит: открытый
  /// исходник с ключом означал бы, что мусорные события может слать кто угодно.
  /// Пусто — аналитика молчит совсем, и форк ничего никуда не отправляет.
  static const String _envKey = String.fromEnvironment('TESSERA_KEY');

  String get _key => _keyForTest ?? _envKey;

  /// Куда шлём пачки. Тот же домен, что и остальное API.
  static const String _url = 'https://togetherly.day/api/tessera/i';

  /// Потолок очереди: дальше выбрасываем самое старое. Копить бесконечно
  /// вреднее, чем потерять хвост статистики.
  static const int _maxQueue = 300;

  /// Как часто сбрасываем накопленное.
  static const Duration _interval = Duration(minutes: 1);

  final List<Map<String, dynamic>> _queue = [];
  final Random _random = Random();
  Timer? _timer;
  bool _sending = false;
  String _version = '';
  Session? _session;

  /// Кем считать человека, когда он не вошёл. Wallet работает и без аккаунта:
  /// без этого номера одиночки не попадали бы в счёт людей вовсе.
  String _installId = '';

  /// Наблюдатель для `MaterialApp.navigatorObservers`: считает открытия
  /// экранов и время на них, не требуя ни строчки в самих экранах.
  late final NavigatorObserver observer = _ScreenObserver(this);

  /// Отладочные запуски статистику не портят, но тестам нужен рабочий путь:
  /// у копии из `forTest` свой ключ, и она считает себя включённой.
  bool get enabled => _key.isNotEmpty && (!kDebugMode || _keyForTest != null);

  /// Сколько событий ждёт отправки. Нужно тестам и отладке.
  @visibleForTesting
  int get queued => _queue.length;

  Future<void> init(Session session, {String installId = ''}) async {
    _session = session;
    _installId = installId;
    if (!enabled || _timer != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _version = '';
    }
    _timer = Timer.periodic(_interval, (_) => unawaited(flush()));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// Сбрасывает накопленное. Зовётся по таймеру, при сворачивании и на выходе.
  Future<void> flush() async {
    if (!enabled || _sending || _queue.isEmpty) return;
    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      final send = _client ?? http.Client();
      final res = await send
          .post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'X-Tessera-Key': _key,
            },
            body: jsonEncode({
              'app': 'wallet',
              'sdk': 'wallet/$_version',
              'events': batch,
            }),
          )
          .timeout(const Duration(seconds: 10));
      // 4xx — пачка кривая или ключ не тот, повторять незачем. 5xx — сервер
      // прилёг, вернём в очередь.
      if (res.statusCode >= 500) _requeue(batch);
    } catch (_) {
      _requeue(batch);
    } finally {
      _sending = false;
    }
  }

  void _requeue(List<Map<String, dynamic>> batch) {
    _queue.insertAll(0, batch);
    _trim();
  }

  void _trim() {
    if (_queue.length <= _maxQueue) return;
    _queue.removeRange(0, _queue.length - _maxQueue);
  }

  /// Номер события: по нему сервер отбрасывает повторы, когда пачка уехала
  /// дважды на плохой связи.
  String _eid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$now-${_random.nextInt(1 << 32).toRadixString(16)}';
  }

  void _add(String kind, String name, {int? ms, Map<String, Object?>? params}) {
    if (!enabled) return;
    _queue.add({
      'eid': _eid(),
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      // Вошедшего считаем по uid — тогда человек с двумя телефонами остаётся
      // одним человеком. Не вошедшего — по номеру устройства.
      'who': (_session?.uid ?? '').isNotEmpty ? _session!.uid : _installId,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'version': _version,
      'kind': kind,
      'name': name,
      if (ms != null) 'ms': ms,
      if (params != null && params.isNotEmpty) 'params': params,
    });
    _trim();
  }

  // ── Что считаем ───────────────────────────────────────────────────────────

  /// Экран закрыли: [ms] — сколько на нём пробыли.
  void screen(String name, {int? ms}) => _add('screen', name, ms: ms);

  /// Действие внутри приложения.
  void action(String name, {Map<String, Object?>? params}) =>
      _add('action', name, params: params);

  /// Шаг пути новичка: `open`, `signup`, `signin`, `first_op`, `pair_joined`.
  /// По нему видно, где обрывается путь до работающего трекера.
  void funnel(String step) => _add('funnel', step);

  /// Деньги: витрина Плюса, покупка, отказ. Сумм тут нет — только событие.
  void money(String name, {Map<String, Object?>? params}) =>
      _add('money', name, params: params);

  /// Рекламный блок попал на экран. [slot] — место: `home`, `quarters`,
  /// `ledger`, `stats`. Свой счёт рядом с кабинетом РСЯ показывает, где
  /// теряются показы.
  void ad(String slot) => _add('ad', slot);
}

/// Считает экраны по переходам навигатора.
///
/// Имя берётся из `RouteSettings.name`. Безымянные маршруты пропускаются:
/// нижних листов в приложении десятки, и статистика от них только шумела бы.
class _ScreenObserver extends NavigatorObserver {
  _ScreenObserver(this._analytics);

  final Analytics _analytics;
  final Map<String, DateTime> _openedAt = {};

  String? _nameOf(Route<dynamic>? route) {
    final raw = route?.settings.name ?? '';
    final name = raw.replaceAll('/', '').trim();
    return name.isEmpty ? null : name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _nameOf(route);
    if (name != null) _openedAt[name] = DateTime.now();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = _nameOf(route);
    if (name == null) return;
    final opened = _openedAt.remove(name);
    _analytics.screen(
      name,
      ms: opened == null
          ? null
          : DateTime.now().difference(opened).inMilliseconds,
    );
  }
}
