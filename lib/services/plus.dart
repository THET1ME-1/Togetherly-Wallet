import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../logic/plus.dart';
import 'session.dart';

/// Подписка Wallet+ на устройстве.
///
/// Талон приезжает с сервера (`/api/money/plus`) и ложится файлом рядом с
/// базой. Сервер — единственный, кто решает, оплачено или нет: касс три, и
/// договариваться с каждой на телефоне значит открыть подписку любому, кто
/// умеет править файл.
///
/// Локальная копия нужна для другого: без сети приложение обязано работать.
/// Талон живёт [PlusPass.offlineDays] дней с последней сверки, потом платное
/// закрывается — иначе отменивший подписку пользовался бы ей вечно, просто не
/// включая интернет.
/// Пара, которой можно отдать второе место.
class PlusSeat {
  const PlusSeat({
    required this.groupId,
    required this.uid,
    required this.name,
    required this.avatarUrl,
    required this.size,
    required this.can,
  });

  final String groupId;
  final String uid;
  final String name;
  final String avatarUrl;

  /// Сколько человек в группе. Трое и больше второго места не дают.
  final int size;
  final bool can;

  factory PlusSeat.fromJson(Map<String, dynamic> raw) => PlusSeat(
        groupId: '${raw['group_id'] ?? ''}',
        uid: '${raw['uid'] ?? ''}',
        name: '${raw['name'] ?? ''}',
        avatarUrl: '${raw['avatar_url'] ?? ''}',
        size: (raw['size'] as num?)?.toInt() ?? 0,
        can: raw['can'] == true,
      );
}

class PlusService extends ChangeNotifier {
  PlusService({this.session});

  Session? session;

  PlusPass? _pass;
  File? _file;

  /// Идёт ли сейчас сверка. Витрина показывает это кружком, чтобы «Вернуть
  /// покупку» не выглядела мёртвой кнопкой.
  bool _busy = false;

  PlusPass? get pass => _pass;
  bool get busy => _busy;

  /// Открыто ли платное прямо сейчас.
  bool get active => _pass?.activeAt(DateTime.now()) ?? false;

  /// Подписку оплатил партнёр.
  bool get fromPartner => _pass?.fromPartner ?? false;

  /// Кому отдано второе место и когда его отдали. Нужно витрине: человек
  /// обязан видеть, кто пользуется его подпиской.
  String seatUid = '';
  int seatFreeAt = 0;

  /// Сколько вопросов и файлов израсходовано из бесплатного.
  ///
  /// Числа СЕРВЕРНЫЕ: считать их на устройстве значит раздавать потолок
  /// переустановкой приложения, а у человека бывает два телефона. `null` —
  /// сервер ещё не отвечал или подписка открыта; тогда счётчик не рисуется,
  /// потому что врать «осталось 3» нельзя.
  int? asksLeft;
  int? filesLeft;

  /// Запомнить остаток, пришедший в ответе разговора или разбора файла.
  ///
  /// Иначе счётчик оставался вчерашним до следующего запуска: человек задаёт
  /// вопрос и видит прежнее число.
  void noteUsage({int? asks, int? files}) {
    if (asks == null && files == null) return;
    if (asks != null) asksLeft = asks;
    if (files != null) filesLeft = files;
    notifyListeners();
  }

  /// Сколько дней осталось жить без сети. Ноль — сверка нужна сейчас.
  int get offlineLeft {
    final at = _pass?.checkedAt;
    if (at == null) return 0;
    final spent = DateTime.now().millisecondsSinceEpoch - at;
    final left = PlusPass.offlineDays - (spent / 86400000).floor();
    return left < 0 ? 0 : left;
  }

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/plus.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString());
        if (raw is Map) _pass = PlusPass.fromJson(raw.cast<String, dynamic>());
      }
    } catch (_) {
      // Битый файл не запирает запуск: подписка просто считается закрытой до
      // первой удачной сверки.
      _pass = null;
    }
    notifyListeners();
  }

  /// Сверить с сервером. Молча переживает обрыв сети: старый талон остаётся
  /// в силе, пока не вышли его офлайновые дни.
  Future<void> refresh() async {
    final s = session;
    if (s == null || !s.signedIn) return;
    _busy = true;
    notifyListeners();
    try {
      final r = await s.get('/api/money/plus');
      seatUid = '${r['seat_uid'] ?? ''}';
      seatFreeAt = (r['seat_free_at'] as num?)?.toInt() ?? 0;
      asksLeft = (r['asks_left'] as num?)?.toInt();
      filesLeft = (r['files_left'] as num?)?.toInt();
      final until = (r['until'] as num?)?.toInt() ?? 0;
      final source = plusSourceOf('${r['source'] ?? ''}');
      if (r['active'] == true && source != null && until > 0) {
        await _keep(PlusPass(
          until: until,
          source: source,
          checkedAt: DateTime.now().millisecondsSinceEpoch,
          fromPartner: r['from_partner'] == true,
        ));
      } else {
        // Сервер ответил «нет»: талон снимаем СРАЗУ, а не ждём офлайновых
        // дней. Ответ получен, гадать не о чем.
        await _keep(null);
      }
    } catch (_) {
      // Сеть молчит — оставляем как было.
    }
    _busy = false;
    notifyListeners();
  }

  /// Пары, которым можно отдать второе место.
  ///
  /// Спрашивается у сервера, а не собирается на устройстве: состав групп он
  /// знает точно, а телефон видит только текущую пару.
  Future<List<PlusSeat>> seats() async {
    final s = session;
    if (s == null || !s.signedIn) return const [];
    try {
      final r = await s.get('/api/money/plus/seats');
      final raw = r['pairs'];
      if (raw is! List) return const [];
      return [
        for (final item in raw)
          if (item is Map) PlusSeat.fromJson(item.cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Отдать второе место партнёру. Пусто — оставить его свободным.
  ///
  /// Возвращает пусто при удаче и причину отказа словом: `too_soon` — место
  /// меняли меньше месяца назад.
  Future<String> giveSeat(String uid) async {
    final s = session;
    if (s == null || !s.signedIn) return 'offline';
    try {
      final r = await s.post('/api/money/plus/seat', {'uid': uid});
      if (r['ok'] == true) {
        await refresh();
        return '';
      }
      return '${r['error'] ?? 'refused'}';
    } catch (_) {
      return 'offline';
    }
  }

  /// Ссылка на оплату в lava. Так платят сборки RuStore и GitHub: своего
  /// биллинга у них нет, а Google в России не принимает деньги вовсе.
  Future<String> checkout(PlusPlan plan, {String seat = '', String currency = 'RUB'}) async {
    final s = session;
    if (s == null || !s.signedIn) return '';
    _busy = true;
    notifyListeners();
    var url = '';
    try {
      final r = await s.post('/api/money/plus/checkout', {
        'plan': plan.code,
        'currency': currency,
        'seat_uid': seat,
      });
      url = '${r['url'] ?? ''}';
    } catch (_) {
      url = '';
    }
    _busy = false;
    notifyListeners();
    return url;
  }

  /// Забыть подписку: выход из аккаунта, стирание данных.
  Future<void> forget() => _keep(null);

  Future<void> _keep(PlusPass? next) async {
    _pass = next;
    try {
      if (next == null) {
        if (await (_file?.exists() ?? Future.value(false))) {
          await _file!.delete();
        }
      } else {
        await _file?.writeAsString(jsonEncode(next.toJson()));
      }
    } catch (_) {
      // Не записалось — подписка доживёт до перезапуска. Лучше, чем отказ.
    }
    notifyListeners();
  }

  /// Подставить талон в тестах и при выдаче руками.
  @visibleForTesting
  void setForTest(PlusPass? pass) {
    _pass = pass;
    notifyListeners();
  }
}
