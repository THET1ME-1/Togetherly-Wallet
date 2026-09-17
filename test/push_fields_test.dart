import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/services/sync.dart';

/// Что уезжает на сервер.
///
/// Грабля этого проекта, сработавшая ЧЕТЫРЕ раза: поле есть в модели, колонка
/// есть в базе, а в теле push его нет — сервер отвечает 200 и молча теряет
/// значение. Так пропадали `bucket`, `rollover`, `kind`/`months`, а
/// 17.09.2026 — значок и цвет цели: человек менял их, следующая дельта
/// возвращала цель пустой, и выбранный значок сбрасывался на глазах.
///
/// Поэтому сторож смотрит не на отдельные поля, а на ВСЕ: он берёт запись,
/// заполненную целиком, и требует, чтобы каждое непустое значение нашлось в
/// отправленном теле. Добавил поле в модель — тест покажет, что его забыли
/// довезти.

/// Сессия, которая ничего не шлёт, а запоминает.
class _Spy extends Session {
  final List<Map<String, dynamic>> sent = [];

  @override
  bool get signedIn => true;

  @override
  String get uid => 'u_me';

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    // Именованный `timeout` обязателен: без него `@override` не сходится и
    // падает загрузка всего файла теста.
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      {'since': 0};

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (path.contains('push')) sent.add(body);
    return {'ok': true, 'updated': 1};
  }
}

Database full() => Database(
      baseCurrency: 'MDL',
      // Пространство должно совпасть с тем, куда шлёт Sync: у одиночки это
      // его собственный uid.
      pair: const Pair(groupId: 'u_me', members: [Member(uid: 'u_me', name: 'Саша')]),
      accounts: const [
        Account(
          name: 'Карта',
          currency: 'MDL',
          icon: 'credit-card',
          color: 0xFF112233,
          last4: '0354',
          brand: CardBrand.visa,
          kind: AccountKind.credit,
          design: 3,
          texture: CardTexture.guilloche,
          bank: 'md.maib.mobile',
        ),
      ],
      categories: const [
        Category(name: 'Бензин', icon: 'car', color: 0xFF445566, bucket: Bucket.needs),
        Category(name: 'Мойка'),
      ],
      budgets: const [
        Budget(
          category: 'Бензин',
          limit: 3000,
          currency: 'EUR',
          period: 'custom',
          rollover: true,
          days: 10,
          startDate: '2026-09-01',
          name: 'Машина',
          icon: 'car',
          color: 0xFF112233,
          extraCategories: ['Мойка'],
          accounts: ['Карта'],
        ),
      ],
      goals: const [
        Goal(
          name: 'Отпуск',
          target: 40000,
          currency: 'EUR',
          deadline: '2027-06-01',
          kind: GoalKind.reserve,
          months: 6,
          icon: 'umbrella',
          color: 0xFF778899,
        ),
      ],
      recurring: const [
        Recurring(
          id: 'rec1',
          name: 'Подписка',
          amount: 199,
          currency: 'EUR',
          account: 'Карта',
          category: 'Бензин',
          interval: 'custom',
          nextDate: '2026-10-05',
          kind: 'expense',
          active: true,
          target: 'Отпуск',
          lastRun: '2026-09-05',
          days: 10,
          icon: 'refresh',
          color: 0xFF223344,
        ),
      ],
    );

/// Все непустые значения записи, которые обязаны доехать.
Map<String, Object?> expected(Map<String, dynamic> json, {Set<String> skip = const {}}) =>
    {
      for (final e in json.entries)
        if (!skip.contains(e.key) && e.value != null && e.value != '') e.key: e.value,
    };

/// Нашлось ли значение в отправленной записи — под своим именем или под
/// серверным (`limit` → `limit_value`, `nextDate` → `next_date`).
void mustCarry(
  Map<String, dynamic> sent,
  Map<String, Object?> want, {
  Map<String, String> renamed = const {},
}) {
  final missing = <String>[];
  for (final e in want.entries) {
    final key = renamed[e.key] ?? e.key;
    if (!sent.containsKey(key)) {
      missing.add(e.key);
      continue;
    }
    final got = sent[key];
    final same = got is List && e.value is List
        ? '$got' == '${e.value}'
        : got == e.value;
    if (!same) missing.add('${e.key}: отправлено $got вместо ${e.value}');
  }
  expect(missing, isEmpty, reason: 'не доехало на сервер: ${missing.join(', ')}');
}

void main() {
  Future<Map<String, dynamic>> pushOf(Database db) async {
    final store = Store()
      ..importBackupForTest(db)
      ..syncEnabled = true;
    store.markAllForSync();
    final spy = _Spy();
    final sync = Sync(session: spy, store: store);
    await sync.run();
    sync.dispose();
    expect(spy.sent, isNotEmpty, reason: 'push не ушёл вовсе');
    return spy.sent.first;
  }

  test('бюджет уезжает со всеми своими полями', () async {
    final body = await pushOf(full());
    final sent = (body['budgets'] as List).first as Map<String, dynamic>;
    mustCarry(
      sent,
      expected(full().budgets.single.toJson()),
      renamed: const {'limit': 'limit_value'},
    );
  });

  test('цель уезжает со всеми своими полями', () async {
    final body = await pushOf(full());
    final sent = (body['goals'] as List).first as Map<String, dynamic>;
    // `kind` на сервере строкой «reserve»/«plain», а в модели перечислением.
    mustCarry(
      sent,
      expected(full().goals.single.toJson(), skip: const {'kind'}),
    );
    expect(sent['kind'], 'reserve');
  });

  test('регулярное уезжает со всеми своими полями', () async {
    final body = await pushOf(full());
    final sent = (body['recurring'] as List).first as Map<String, dynamic>;
    mustCarry(
      sent,
      expected(full().recurring.single.toJson(), skip: const {'target', 'lastRun'}),
      renamed: const {
        'interval': 'interval_rule',
        'nextDate': 'next_date',
      },
    );
    expect(sent['goal'], 'Отпуск', reason: 'цель регулярного едет как goal');
    expect(sent['last_run'], '2026-09-05');
  });

  test('счёт уезжает со всеми своими полями', () async {
    final body = await pushOf(full());
    final sent = (body['accounts'] as List).first as Map<String, dynamic>;
    // Цвет в бэкапе строкой «#112233», на сервере — тоже строкой; вид счёта
    // едет под именем `card_kind`, чтобы не спорить с `kind` операции.
    mustCarry(
      sent,
      expected(full().accounts.single.toJson()),
      renamed: const {'kind': 'card_kind', 'owner': 'owner_uid', 'isPot': 'is_pot'},
    );
  });
}
