import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/notice_match.dart';
import '../logic/notice_parse.dart';

/// Состояние чтения уведомлений: что система, что служба, что уже пришло.
class NoticeState {
  const NoticeState({
    this.supported = true,
    this.granted = false,
    this.connected = false,
    this.waiting = 0,
    this.seen = 0,
    this.restricted = false,
  });

  /// Чтение уведомлений вообще возможно на этом устройстве. На iPhone — нет,
  /// и там экран говорит это прямо, вместо того чтобы просить разрешение,
  /// которого не существует.
  final bool supported;

  /// Доступ выдан в настройках Android.
  final bool granted;

  /// Служба на связи прямо сейчас.
  final bool connected;

  /// Сколько пушей лежит в файле и ждёт разбора.
  final int waiting;

  /// Сколько уведомлений служба приняла за всё время — ЛЮБЫХ, не только
  /// банковских. Ноль при выданном доступе значит, что до приложения не
  /// доходит ничего: или служба не поднялась, или прошивка её усыпила.
  final int seen;

  /// Android не даёт выдать доступ, пока человек не снимет запрет в сведениях
  /// о приложении. Переключатель доступа при этом серый, и без объяснения
  /// человек считает сломанным приложение.
  final bool restricted;

  /// Доступ есть, а службы нет. Лечится `rebind`, а не походом в настройки.
  bool get asleep => granted && !connected;
}

/// Чтение банковских уведомлений со стороны Dart.
///
/// Нативная служба только складывает пуши в файл. Здесь их разбирают,
/// привязывают к счёту и отдают хранилищу — так весь смысл лежит в коде,
/// который проверяется тестами, а не в Kotlin.
///
/// На iPhone этого нет и быть не может: приложениям там не дают читать
/// уведомления вовсе. Поэтому класс молча ничего не делает на всём, кроме
/// Android, и экран об этом честно говорит.
class Notices {
  Notices(this.store);

  final Store store;

  static const _calls = MethodChannel('togetherly.money/notices');
  static const _live = EventChannel('togetherly.money/notices/live');

  StreamSubscription<dynamic>? _wake;

  /// Есть ли смысл вообще показывать чтение уведомлений.
  static bool get supported => !kIsTest && Platform.isAndroid;

  /// В тестах и на вебе каналов нет: пусть будет одна проверка, а не try в
  /// каждом методе.
  static bool get kIsTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// Дал ли человек доступ в настройках Android.
  Future<bool> granted() async {
    if (!supported) return false;
    try {
      return await _calls.invokeMethod<bool>('granted') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Что происходит со службой на самом деле.
  ///
  /// Три разных состояния человек видит одинаково — «уведомления не
  /// приходят», — а чинятся они по-разному: доступ не выдан, доступ выдан и
  /// служба молчит (так бывает после установки поверх), доступ выдан и служба
  /// работает, а молчит сам банк. Экран обязан их различать, иначе разговор
  /// идёт вслепую («Я скачивал с нуля. Все включено, а не работает»,
  /// 14.09.2026).
  NoticeState? _fake;

  /// Подменить состояние в тестах: каналов к Android там нет, а три ветки
  /// экрана проверять надо.
  void setStateForTest(NoticeState value) => _fake = value;

  Future<NoticeState> state() async {
    final fake = _fake;
    if (fake != null) return fake;
    if (!supported) return const NoticeState(supported: false);
    try {
      final raw = await _calls.invokeMethod<Map<Object?, Object?>>('state');
      if (raw == null) return const NoticeState();
      return NoticeState(
        granted: raw['granted'] == true,
        connected: raw['connected'] == true,
        waiting: (raw['waiting'] as num?)?.toInt() ?? 0,
        seen: (raw['seen'] as num?)?.toInt() ?? 0,
        restricted: raw['restricted'] == true,
      );
    } on PlatformException {
      return const NoticeState();
    } on MissingPluginException {
      return const NoticeState();
    }
  }

  /// Открыть сведения о нашем приложении: оттуда снимают запрет Android.
  Future<void> openAppDetails() async {
    if (_fake != null) return;
    if (!supported) return;
    try {
      await _calls.invokeMethod<void>('appDetails');
    } on MissingPluginException {
      // Нативной части нет — молчим.
    } on PlatformException {
      // Экрана нет — человеку остаётся общий путь через настройки.
    }
  }

  /// Попросить систему поднять службу заново.
  ///
  /// После установки поверх Android рвёт связь со службой и сам её не
  /// возвращает: разрешение на месте, галочка стоит, уведомления не читаются.
  /// Раньше это лечилось только снятием и повторной выдачей доступа руками.
  Future<void> rebind() async {
    if (_fake != null) return;
    if (!supported) return;
    try {
      await _calls.invokeMethod<void>('rebind');
    } on MissingPluginException {
      // Нативной части нет — молчим.
    } on PlatformException {
      // Система отказала: экран всё равно предложит открыть настройки.
    }
  }

  /// Открыть системный экран с разрешением. Своего экрана у этого доступа нет
  /// и быть не может: его даёт только Android.
  Future<void> openSettings() async {
    if (!supported) return;
    try {
      await _calls.invokeMethod<void>('openSettings');
    } on MissingPluginException {
      // Собрано без нативной части — молчим, экран уже сказал главное.
    }
  }

  /// Какие из банковских приложений стоят на телефоне.
  Future<Set<String>> installed() async {
    if (_fake != null) return {};
    if (!supported) return {};
    try {
      final list = await _calls.invokeMethod<List<Object?>>(
        'installed',
        knownSenders.keys.toList(),
      );
      return (list ?? const []).whereType<String>().toSet();
    } on MissingPluginException {
      return {};
    }
  }

  /// Настоящие логотипы: иконки банковских приложений с этого телефона.
  /// Кэш в памяти — иконки не меняются в течение сеанса, а лезть в
  /// PackageManager на каждый кадр списка нельзя.
  final Map<String, Uint8List> _logos = {};
  Map<String, Uint8List> get logos => Map.unmodifiable(_logos);

  Future<Map<String, Uint8List>> loadLogos(Iterable<String> packages) async {
    if (_fake != null) return const {};
    if (!supported) return const {};
    final need = packages.where((p) => !_logos.containsKey(p)).toList();
    if (need.isEmpty) return logos;
    try {
      final raw = await _calls.invokeMethod<Map<Object?, Object?>>('icons', need);
      for (final e in (raw ?? const {}).entries) {
        final bytes = e.value;
        if (bytes is Uint8List && bytes.isNotEmpty) _logos['${e.key}'] = bytes;
      }
    } on MissingPluginException {
      return logos;
    } on PlatformException {
      return logos;
    }
    return logos;
  }

  /// Открыть настройки уведомлений самого банка: если банк молчит, причина
  /// обычно там, и приложению её не исправить.
  Future<void> openAppSettings(String package) async {
    if (!supported) return;
    try {
      await _calls.invokeMethod<void>('appSettings', package);
    } on MissingPluginException {
      // Нативной части нет — молчим.
    }
  }

  /// Сколько пушей ждёт разбора в файле службы.
  Future<int> waiting() async {
    if (!supported) return 0;
    try {
      return await _calls.invokeMethod<int>('waiting') ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Забрать накопленное и разобрать. Возвращает, сколько операций записалось
  /// само — это единственное число, которое интересно снаружи.
  Future<int> drain() async {
    if (_fake != null) return 0;
    if (!supported) return 0;
    List<Object?>? raw;
    try {
      raw = await _calls.invokeMethod<List<Object?>>('drain');
    } on MissingPluginException {
      return 0;
    }
    if (raw == null || raw.isEmpty) return 0;

    var written = 0;
    final fresh = <String>{};
    for (final item in raw) {
      final map = item is Map ? item : null;
      if (map == null) continue;
      final notice = parseOne(map);
      if (notice == null) continue;
      fresh.add(notice.package);
      if (store.addNotice(notice)) written++;
    }
    // Знак нового источника снят службой с самого уведомления — забираем его
    // сразу, иначе в списке останется пустая заглушка до перезапуска.
    final unknown = fresh.where((p) => !_logos.containsKey(p)).toSet();
    if (unknown.isNotEmpty) {
      await loadLogos(unknown);
      store.notify();
    }
    return written;
  }

  /// Разбор одной записи из файла службы.
  ///
  /// Валюта берётся у банка-источника, а если банк незнаком — базовая валюта
  /// пары: у молдавского пуша «300,00» без кода это леи, и подставлять сюда
  /// доллары было бы хуже, чем ничего.
  ParsedNotice? parseOne(Map<Object?, Object?> map) {
    final package = '${map['package'] ?? ''}';
    if (package.isEmpty) return null;
    final at = (map['at'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    return parseNotice(
      package: package,
      title: '${map['title'] ?? ''}',
      body: '${map['body'] ?? ''}',
      at: at,
      fallbackCurrency: knownSenders[package]?.currency ?? store.db.baseCurrency,
    );
  }

  /// Слушать живые пуши, пока приложение открыто. Событие приносит одно слово
  /// «проснись»: сами данные лежат в файле, чтобы путь доставки был один.
  void listen() {
    if (!supported || _wake != null) return;
    _wake = _live.receiveBroadcastStream().listen(
      (_) => drain(),
      onError: (_) {},
    );
  }

  void stop() {
    _wake?.cancel();
    _wake = null;
  }
}
