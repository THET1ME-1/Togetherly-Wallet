import '../data/models.dart';

/// Какие категории предлагать на этом счёте.
///
/// У счёта «Яндекс Реклама» нет продуктов, а у карты нет рекламных
/// поступлений: общий список из сорока категорий заставлял искать нужную
/// глазами каждый раз.
///
/// Категория при этом остаётся ОДНОЙ на пару — в отчётах «Еда» не распадается
/// на «Еду карты» и «Еду наличных». Здесь только порядок и видимость.
///
/// Порядок: то, чем уже платили с этого счёта (чаще — раньше), затем
/// привязанные к счёту руками, затем общие по частоте вообще. Категории,
/// привязанные к ДРУГИМ счетам, не показываются вовсе.
List<String> categoriesForAccount(
  Database db, {
  required String? account,
  required bool income,
  int limit = 14,
}) {
  final byName = {for (final c in db.categories) c.name: c};

  bool allowed(String name) {
    final category = byName[name];
    if (category == null) return true;
    // Подкатегория не самостоятельна: она уточняет родителя и выбирается уже
    // после него. В общем ряду она встала бы вторым именем того же уровня.
    if (category.parent != null) return false;
    // Вид задан — верим ему. Не задан (всё, что заведено до этой правки) —
    // судим по операциям, как раньше.
    if (category.kind != null && category.isIncome != income) return false;
    return category.fitsAccount(account);
  }

  bool ownKind(Transaction t) => income ? t.amount > 0 : t.amount < 0;

  // Частота по этому счёту и по всем счетам считается отдельно: «чем платили
  // здесь» сильнее, чем «чем платили вообще».
  final here = <String, int>{};
  final everywhere = <String, int>{};
  for (final t in db.transactions) {
    final name = t.category;
    if (name == null || name.isEmpty || !ownKind(t)) continue;
    everywhere[name] = (everywhere[name] ?? 0) + 1;
    if (account != null && t.account == account) {
      here[name] = (here[name] ?? 0) + 1;
    }
  }

  List<String> sorted(Map<String, int> counts) {
    final list = counts.entries.where((e) => allowed(e.key)).toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return [for (final e in list) e.key];
  }

  final out = <String>[
    ...sorted(here),
    // Привязанные к счёту руками идут сразу за использованными: человек сам
    // сказал, что они тут нужны.
    ...db.categories
        .where((c) => account != null && c.accounts.contains(account))
        .map((c) => c.name),
    ...sorted(everywhere),
    // Счёт не выбран — показываем всё: скрывать привязанные не от чего.
    // Отбор по виду и по родителю делает `allowed` ниже, один на все ветки.
    ...db.categories
        .where((c) => account == null || c.accounts.isEmpty)
        .map((c) => c.name),
  ];

  final seen = <String>{};
  final result = <String>[];
  for (final name in out) {
    if (name.isEmpty || !allowed(name) || !seen.add(name)) continue;
    result.add(name);
    if (result.length >= limit) break;
  }
  return result;
}
