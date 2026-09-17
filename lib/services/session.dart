import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import 'auth_failure.dart';
import 'oauth.dart';

/// Учётка экосистемы: та же коллекция `users`, что у Togetherly.
///
/// Одна коллекция, а не своя, потому что участники пары в `groups` — это uid
/// из `users`: человек из отдельной таблицы не смог бы оказаться в одной паре
/// с человеком из Togetherly. Само приложение Togetherly при этом не нужно —
/// аккаунт заводится прямо здесь, а пара собирается кодом.
const String kApiBase = 'https://togetherly.day';

/// Как человек решил жить: сам с собой на устройстве или с аккаунтом.
enum SessionMode {
  /// Ещё не выбрал — показываем экран входа.
  undecided,

  /// Без аккаунта: база лежит файлом, пары нет, синхронизации нет.
  local,

  /// Вошёл: данные уезжают в облако, пара возможна.
  signedIn,
}

/// Тело ответа словарём. Битое или не-JSON — пусто: экран решит по коду.
Map<String, dynamic>? _bodyOf(String raw) {
  if (raw.isEmpty) return null;
  try {
    final parsed = jsonDecode(raw);
    return parsed is Map ? parsed.cast<String, dynamic>() : null;
  } catch (_) {
    return null;
  }
}

class SessionError implements Exception {
  SessionError(this.failure, {this.serverMessage, this.status, this.body});

  final AuthFailure failure;

  /// Что сказал сам сервер. Его слова человеку полезнее наших догадок:
  /// на 503 «разговор пока не подключён» мы показывали «проверьте сеть».
  final String? serverMessage;
  final int? status;

  /// Тело отказа целиком. Сервер кладёт туда подробности, которые экрану
  /// нужны для решения: сколько роликов осталось, нужна ли подписка.
  final Map<String, dynamic>? body;

  bool get needPlus => status == 402;

  String get message {
    final own = (serverMessage ?? '').trim();
    return own.isEmpty ? authFailureText(failure) : own;
  }

  @override
  String toString() => message;
}

/// Сессия и профиль. Токен лежит файлом рядом с базой.
///
/// Класс называется Session, а не Account: счётом (Account) в этом
/// приложении зовётся кошелёк, и два смысла на одно имя путали бы код.
///
/// Шифрования файла пока нет — это долг, записанный в CLAUDE.md: в Togetherly
/// кэш шифруется ключом из Keystore, и Money придёт к тому же.
class Session extends ChangeNotifier {
  Session({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  SessionMode _mode = SessionMode.undecided;
  SessionMode get mode => _mode;

  String _token = '';
  String _uid = '';
  String _email = '';
  String _name = '';

  /// Своя аватарка из профиля. Держим рядом с именем: в составе пары сервер
  /// Togetherly её не всегда отдаёт, и собственный бейдж оставался буквой.
  String _avatar = '';

  String get uid => _uid;

  /// Токен сессии. Нужен фоновой доставке: изолят живёт отдельно и своей
  /// сессии не имеет — ему передают ровно токен и номер группы.
  String get token => _token;
  String get email => _email;
  String get name => _name;
  String get avatar => _avatar;
  bool get signedIn => _mode == SessionMode.signedIn && _token.isNotEmpty;

  File? _file;

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/account.json');
    if (await _file!.exists()) {
      try {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _token = j['token'] as String? ?? '';
        _uid = j['uid'] as String? ?? '';
        _email = j['email'] as String? ?? '';
        _name = j['name'] as String? ?? '';
        _avatar = j['avatar'] as String? ?? '';
        _mode = switch (j['mode'] as String?) {
          'local' => SessionMode.local,
          'signedIn' => _token.isEmpty ? SessionMode.undecided : SessionMode.signedIn,
          _ => SessionMode.undecided,
        };
      } catch (_) {
        // Битый файл не должен запирать вход: человек просто выберет заново.
        _mode = SessionMode.undecided;
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final f = _file;
    if (f == null) return;
    await f.writeAsString(jsonEncode({
      'mode': _mode.name,
      'token': _token,
      'uid': _uid,
      'email': _email,
      'name': _name,
      'avatar': _avatar,
    }));
  }

  /// «Пока без аккаунта»: решение запоминается, чтобы экран входа не
  /// встречал человека каждый запуск.
  Future<void> stayLocal() async {
    _mode = SessionMode.local;
    notifyListeners();
    await _save();
  }

  Future<void> signIn(String email, String password) async {
    final r = await post('/api/collections/users/auth-with-password', {
      'identity': email.trim(),
      'password': password,
    });
    _apply(r);
    await _save();
  }

  /// Вход провайдером: Google, Яндекс или Apple.
  ///
  /// Сессию добывает [OAuthService], а хранит её по-прежнему этот класс —
  /// токен и профиль лежат в одном месте, откуда их читают синхронизация и
  /// разговор о деньгах.
  ///
  /// Пометку `origin` ставим только НОВОЙ записи: у человека, пришедшего из
  /// Togetherly, она своя, и переписывать её незачем.
  Future<void> signInWith(OAuthProvider provider, {OAuthService? service}) async {
    final oauth = service ?? OAuthService();
    final session = await oauth.signIn(provider);
    _apply({'token': session.token, 'record': session.record});
    await _save();
    await _fillProfile(session);
  }

  /// Что дописываем записи после входа провайдером.
  ///
  /// Имя и картинку PocketBase из профиля провайдера НЕ переносит: без этого
  /// партнёр видит заглушку вместо имени. Пометку `origin` ставим только новой
  /// записи — у человека из Togetherly она своя. Ошибка здесь вход не ломает:
  /// он уже состоялся.
  Future<void> _fillProfile(OAuthSession session) async {
    if (_uid.isEmpty) return;
    final record = session.record;
    final patchBody = <String, dynamic>{};

    final display = '${record['display_name'] ?? ''}'.trim();
    final plain = '${record['name'] ?? ''}'.trim();
    final fromProvider = (session.name ?? '').trim();
    if (display.isEmpty && fromProvider.isNotEmpty) {
      patchBody['display_name'] = fromProvider;
      if (plain.isEmpty) patchBody['name'] = fromProvider;
    }

    final avatar = '${record['avatar_url'] ?? ''}'.trim();
    final providerAvatar = (session.avatarUrl ?? '').trim();
    if (avatar.isEmpty && providerAvatar.isNotEmpty) {
      patchBody['avatar_url'] = providerAvatar;
    }

    if ('${record['origin'] ?? ''}'.trim().isEmpty) {
      patchBody['origin'] = 'money';
    }
    if (patchBody.isEmpty) return;

    try {
      final r = await patch('/api/collections/users/records/$_uid', patchBody);
      if (r['id'] != null) {
        _apply({'token': _token, 'record': r});
        await _save();
      }
    } catch (_) {
      // Профиль дополнится при следующем входе.
    }
  }

  Future<void> register(String email, String password, String name) async {
    await post('/api/collections/users/records', {
      'email': email.trim(),
      'password': password,
      'passwordConfirm': password,
      'name': name.trim(),
      // display_name читают и Togetherly, и роут карточки человека: без него
      // партнёр видит заглушку вместо имени.
      'display_name': name.trim(),
      // По этой пометке метрики Togetherly отделяют своих людей от тех, кто
      // пришёл за финансами и Togetherly в глаза не видел.
      'origin': 'money',
    });
    await signIn(email, password);
  }

  Future<void> signOut() async {
    _token = '';
    _uid = '';
    _email = '';
    _name = '';
    _mode = SessionMode.undecided;
    notifyListeners();
    await _save();
  }

  /// Распустить пару.
  ///
  /// Пара из двоих: ушёл один — пары больше нет, поэтому запись группы
  /// помечается распущенной, как это делает Togetherly (коллекция `groups`
  /// одна на экосистему, и два разных понимания «пара кончилась» рассорили бы
  /// приложения). Втроём и больше — выходим только сами, серверным маршрутом:
  /// он атомарный, а правка состава с устройства теряла участника при
  /// одновременном выходе обоих.
  Future<void> disbandPair(Pair pair) async {
    if (!signedIn || pair.groupId.isEmpty) return;
    if (pair.members.length > 2) {
      await post('/api/group/leave', {'groupId': pair.groupId, 'uid': _uid});
      return;
    }
    await patch('/api/collections/groups/records/${pair.groupId}', {
      'disbanded': true,
      'disbanded_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Удалить аккаунт целиком: данные на сервере и саму запись человека.
  ///
  /// Порядок важен. Сперва данные — на это нужна живая сессия; потом запись в
  /// `users`, после которой токен уже ничего не откроет; и только затем
  /// локальный выход.
  ///
  /// Запись в `users` одна на экосистему, поэтому вместе с Money исчезает и
  /// аккаунт Togetherly. Экран говорит это прямо: тихо снести человеку второе
  /// приложение нельзя.
  ///
  /// Общая история пары на сервере остаётся — это деньги партнёра тоже, и
  /// уносить их с собой было бы уничтожением чужого учёта. Сервер удаляет
  /// только личное: личные счета с их операциями, личные долги и лимиты, свои
  /// реплики, расход вопросов к модели и кэш ответов.
  /// Сколько дней аккаунт можно вернуть простым входом.
  static const int deleteGraceDays = 7;

  /// `pair` больше не используется: роспуск пары перенесён на день, когда
  /// аккаунт действительно стирают. Параметр оставлен, чтобы не переписывать
  /// вызовы, и чтобы в истории было видно, что он делал раньше.
  Future<void> deleteAccount({Pair? pair}) async {
    if (!signedIn) {
      await signOut();
      return;
    }
    // НИЧЕГО необратимого здесь не делается: ни роспуска пары, ни удаления
    // денег. Раньше и то и другое случалось сразу, и вернуть было нечего.
    //
    // 13.09.2026 учётка заказчика пропала вместе с парой, и спасла только
    // ночная копия. Кто нажал — так и не выяснили, а значит защита обязана
    // работать независимо от того, кто нажал.
    //
    // Теперь запись помечается, живёт неделю и возвращается обычным входом —
    // вместе с парой, воспоминаниями и деньгами. По истечении срока ночная
    // задача сервера распускает пары и стирает всё разом.
    await post('/api/account/schedule-delete', const {});
    await signOut();
  }

  /// Пара из Togetherly, если она есть. Кодов и приглашений на этом пути не
  /// нужно: группа уже собрана, участники приезжают вместе с ней.
  ///
  /// [preferred] — группа, выбранная человеком: пар у него может быть
  /// несколько (в базе 2052 человека состоят в двух живых группах, 128 — в
  /// трёх). Раньше запрос брал `perPage=1` и молча приносил первую попавшуюся.
  Future<Pair?> loadPair({String? preferred}) async {
    final all = await loadPairs();
    if (all.isEmpty) return null;
    if (preferred != null && preferred.isNotEmpty) {
      for (final p in all) {
        if (p.groupId == preferred) return p;
      }
    }
    return all.first;
  }

  /// ВСЕ живые пары человека.
  Future<List<Pair>> loadPairs() async {
    if (!signedIn) return const [];
    // `disbanded = false` обязателен: без него распущенная пара возвращалась
    // сама. Человек нажимал «Распустить», хранилище становилось личным, а
    // следующий круг синхронизации тянул ту же группу обратно и пара
    // «воскресала» (поймано на живом эмуляторе 12.09.2026).
    final res = await get('/api/collections/groups/records?perPage=20&filter='
        '${Uri.encodeQueryComponent('members ~ "$_uid" && disbanded = false')}');
    final items = (res['items'] as List?) ?? const [];
    final out = <Pair>[];
    for (final raw in items) {
      final pair = await _pairOf((raw as Map).cast<String, dynamic>());
      if (pair != null) out.add(pair);
    }
    return out;
  }

  Future<Pair?> _pairOf(Map<String, dynamic> g) async {

    final ids = ((g['members'] as List?) ?? const []).map((e) => '$e').toList();
    final names = ((g['member_names'] as Map?) ?? const {}).cast<String, dynamic>();
    final avatars = ((g['member_avatars'] as Map?) ?? const {}).cast<String, dynamic>();

    final members = <Member>[];
    for (final id in ids) {
      var name = (names[id] as String? ?? '').trim();
      var avatar = avatars[id] as String?;
      if (id == _uid) {
        if (name.isEmpty || _looksLikePlaceholder(name)) name = _name;
        // Своя аватарка: в составе пары её может не быть, а в профиле она
        // есть — иначе собственный бейдж остаётся буквой, когда у партнёра
        // стоит фотография.
        if ((avatar ?? '').trim().isEmpty && _avatar.isNotEmpty) avatar = _avatar;
      } else if (name.isEmpty || _looksLikePlaceholder(name)) {
        // В member_names сервер Togetherly пишет заглушку «Partner», когда
        // профиль ещё не заполнен. Спрашиваем карточку человека: коллекция
        // users закрыта правилом, а этот роут отдаёт ровно публичные поля.
        final card = await _card(id);
        final fromCard = card?.$1 ?? '';
        // Карточка тоже отдаёт заглушку, когда человек не заполнил имя, — и
        // тогда на экране стоит английское «Вы должны Partner» (поймано на
        // живом эмуляторе 12.09.2026).
        name = fromCard.isEmpty || _looksLikePlaceholder(fromCard)
            ? 'Партнёр'
            : fromCard;
        avatar ??= card?.$2;
      }
      members.add(Member(uid: id, name: name, avatarUrl: avatar));
    }

    return Pair(
      groupId: g['id'] as String? ?? '',
      baseCurrency: 'MDL',
      members: members,
      // Дата начала различает две пары с одним человеком: старую группу в
      // Togetherly часто просто бросают, не распуская.
      since: _dayOf(g['start_date'] ?? g['created']),
    );
  }

  /// Первые десять знаков даты: «2026-05-31T20:40:51Z» → «2026-05-31».
  static String _dayOf(Object? raw) {
    final text = '${raw ?? ''}'.trim();
    return text.length >= 10 ? text.substring(0, 10) : '';
  }

  static bool _looksLikePlaceholder(String name) {
    final low = name.toLowerCase();
    return low == 'partner' || low == 'партнёр' || low == 'партнер' || low == 'user';
  }

  /// Имя и аватар человека из пары. Возвращает null, если роут недоступен:
  /// имя тогда останется заглушкой, но приложение работает.
  Future<(String, String?)?> _card(String uid) async {
    try {
      final r = await get('/api/user/card?uid=$uid');
      final name = ((r['display_name'] ?? r['name'] ?? '') as String).trim();
      if (name.isEmpty) return null;
      return (name, r['avatar_url'] as String?);
    } catch (_) {
      return null;
    }
  }

  void _apply(Map<String, dynamic> r) {
    _token = r['token'] as String? ?? '';
    final rec = ((r['record'] as Map?) ?? const {}).cast<String, dynamic>();
    _uid = rec['id'] as String? ?? '';
    _email = rec['email'] as String? ?? '';
    final display = (rec['display_name'] as String? ?? '').trim();
    _name = display.isNotEmpty ? display : (rec['name'] as String? ?? '');
    _avatar = (rec['avatar_url'] as String? ?? '').trim();
    _mode = _token.isEmpty ? SessionMode.undecided : SessionMode.signedIn;
    notifyListeners();
  }

  /// Подставить вход в тестах и съёмках: сетевого входа там нет, а экраны
  /// профиля и пары без сессии не собрать.
  @visibleForTesting
  void pretendSignedIn({
    required String uid,
    String email = '',
    String name = '',
    String avatar = '',
  }) {
    _token = 'test-token';
    _uid = uid;
    _email = email;
    _name = name;
    _avatar = avatar;
    _mode = SessionMode.signedIn;
    notifyListeners();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token.isNotEmpty) 'Authorization': _token,
      };

  /// Двадцать секунд хватает всему, кроме разговора о деньгах: там запрос
  /// идёт к модели, а со снимком чека — к двум, и одна только отправка кадра
  /// по мобильной сети занимает больше лимита. Вызывающий говорит свой срок.
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _send(() => _http
          .post(Uri.parse('$kApiBase$path'), headers: _headers, body: jsonEncode(body))
          .timeout(timeout));

  /// Срок задаёт вызывающий: двадцати секунд хватает почти всему, но не
  /// разбору месяца — там сервер может писать текст моделью прямо сейчас.
  Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _send(() => _http
          .get(Uri.parse('$kApiBase$path'), headers: _headers)
          .timeout(timeout));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send(() => _http
          .patch(Uri.parse('$kApiBase$path'), headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20)));

  Future<Map<String, dynamic>> delete(String path) =>
      _send(() => _http
          .delete(Uri.parse('$kApiBase$path'), headers: _headers)
          .timeout(const Duration(seconds: 20)));

  /// Сообщение из тела ответа, если оно написано для человека. Технические
  /// отказы PocketBase («Failed to authenticate.») сюда не проходят: их
  /// переводит authFailureText.
  static String? _messageOf(String body) {
    if (body.isEmpty) return null;
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final m = '${j['message'] ?? ''}'.trim();
      if (m.isEmpty) return null;
      final looksTechnical = RegExp(r'^[\x00-\x7F]+$').hasMatch(m);
      return looksTechnical ? null : m;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response res;
    try {
      res = await call();
    } catch (e) {
      throw SessionError(authFailureOf(error: e));
    }
    if (res.statusCode >= 400) {
      throw SessionError(
        authFailureOf(status: res.statusCode, body: res.body),
        serverMessage: _messageOf(res.body),
        status: res.statusCode,
        body: _bodyOf(res.body),
      );
    }
    if (res.body.isEmpty) return const {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
