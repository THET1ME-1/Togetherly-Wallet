import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/buckets.dart';
import '../logic/money.dart';
import '../logic/icon_search.dart';
import '../logic/icons.dart';
import '../widgets/icon_search_sheet.dart';
import '../widgets/money_text.dart';
import '../widgets/pick_row.dart';
import '../widgets/segmented.dart';
import '../design/myna.dart';

/// Редактор категорий. Категория опознаётся по имени, поэтому переименование
/// правит все операции разом — отдельного «id» у категории нет и не будет:
/// формат базы общий с бэкапом и с Таблицей.
///
/// Деления на доходные и расходные здесь нет: в базе такого поля нет, а гадать
/// сторону по прошлым операциям — врать в редакторе. Сторона видна там, где
/// она есть на самом деле, — на экране категорий за отрезок.
class CategoriesEditScreen extends StatefulWidget {
  final Store store;
  const CategoriesEditScreen({super.key, required this.store});

  @override
  State<CategoriesEditScreen> createState() => _CategoriesEditScreenState();
}

class _CategoriesEditScreenState extends State<CategoriesEditScreen> {
  final _query = TextEditingController();

  /// Какую сторону показываем: расходы или доходы. Вперемешку зарплата стояла
  /// между продуктами и подарками, и найти нужное было нечем.
  var _income = false;

  Store get store => widget.store;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Категории выбранной стороны, отобранные поиском.
  List<String> get _names {
    final db = store.db;
    final kinds = <String, CatKind?>{
      for (final c in db.categories.where((c) => c.parent == null))
        c.name: c.kind,
    };
    // Вид у старых категорий не задан: их сторону показывают сами операции.
    final byTx = <String, bool>{};
    for (final t in db.transactions) {
      final name = (t.category ?? '').trim();
      if (name.isEmpty) continue;
      if (t.kind == TxKind.income) byTx[name] = true;
      byTx.putIfAbsent(name, () => false);
    }

    bool isIncome(String name) {
      final kind = kinds[name];
      if (kind != null) return kind == CatKind.income;
      return byTx[name] ?? false;
    }

    final q = _query.text.trim().toLowerCase();
    return _allNames(db).where((name) {
      if (isIncome(name) != _income) return false;
      if (q.isEmpty) return true;
      if (name.toLowerCase().contains(q)) return true;
      // Ищем и по подкатегориям: «кофе» должно находить «Продукты».
      return store
          .subcategoriesOf(name)
          .any((c) => c.name.toLowerCase().contains(q));
    }).toList();
  }

  /// Сколько потрачено по категории за всё время — в базовой валюте.
  double _sumOf(String name) {
    final db = store.db;
    var sum = 0.0;
    for (final t in db.transactions) {
      if ((t.category ?? '') != name) continue;
      if (t.kind == TxKind.transfer) continue;
      sum += t.amountBase.abs();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final names = _names;
        final searching = _query.text.trim().isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('categoriesEditTitle')),
            actions: [
              IconButton(
                onPressed: () => _edit(context, null),
                icon: Icon(Myna.plus),
                tooltip: tr('categoryNew'),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: tr('categoryPickSearch'),
                      prefixIcon: const Icon(Myna.search, size: 20),
                      suffixIcon: searching
                          ? IconButton(
                              onPressed: () => setState(_query.clear),
                              icon: const Icon(Myna.x, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Segmented(
                titles: [tr('categorySideSpending'), tr('categorySideIncome')],
                index: _income ? 1 : 0,
                onPick: (i) => setState(() => _income = i == 1),
              ),
            ),
            Expanded(
              child: names.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          searching
                              ? tr('categoryPickNothing')
                              : tr('categoriesEditEmpty'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 15,
                            height: 1.4,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      children: [
                        for (final name in names)
                          _CategoryBlock(
                            store: store,
                            name: name,
                            spent: _sumOf(name),
                            onEdit: () => _edit(context, name),
                            onEditSub: (sub) => _editSub(context, name, sub),
                          ),
                      ],
                    ),
            ),
          ]),
        );
      },
    );
  }

  /// Правка подкатегории — тем же листом, что и категории: имя, цвет, значок,
  /// «Убрать». Подкатегория это та же запись с заполненным родителем, поэтому
  /// и обращаемся с ней так же.
  Future<void> _editSub(
    BuildContext context,
    String parent,
    String? name,
  ) async {
    final db = store.db;
    final current = name == null
        ? null
        : db.categories
            .where((c) => c.name == name && c.parent == parent)
            .firstOrNull;

    final result = await showModalBottomSheet<_Edited>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _CategorySheet(
        name: name ?? '',
        color: current?.color == null ? null : Color(current!.color!),
        icon: current?.icon,
        // Вид расхода у подкатегории свой не бывает: она наследует его от
        // родителя, иначе одна трата попала бы в две доли.
        bucket: Bucket.none,
        showBucket: false,
        accounts: current?.accounts ?? const [],
        allAccounts: const [],
        title: name == null ? tr('subcategoryNew') : tr('subcategoryOne'),
      ),
    );
    if (result == null) return;

    if (result.deleted && name != null) {
      store.deleteSubcategory(parent, name);
      return;
    }
    final next = result.name.trim();
    if (next.isEmpty) return;

    // Подкатегория берёт вид родителя: своего у неё не бывает, иначе одна
    // трата попала бы в два списка.
    final owner = db.categories.where((c) => c.name == parent).firstOrNull;
    store.saveSubcategory(
      parent,
      Category(
        name: next,
        parent: parent,
        color: result.color?.toARGB32(),
        icon: result.icon,
        kind: owner?.kind,
      ),
      renameFrom: name,
    );
  }

  Future<void> _edit(BuildContext context, String? name) async {
    final db = store.db;
    final at = name == null ? -1 : db.categories.indexWhere((c) => c.name == name);
    final current = at >= 0 ? db.categories[at] : null;

    final result = await showModalBottomSheet<_Edited>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _CategorySheet(
        name: name ?? '',
        color: current?.color == null ? null : Color(current!.color!),
        icon: current?.icon,
        bucket: current?.bucket ?? Bucket.none,
        // Вид спрашивается всегда: без него человек не знает, в какой список
        // попадёт категория при записи. По умолчанию расход — их больше.
        kind: current?.kind ?? CatKind.expense,
        accounts: current?.accounts ?? const [],
        allAccounts: [
          for (final a in db.accounts)
            if (!isVirtualAccount(a.name)) a.name,
        ],
      ),
    );
    if (result == null) return;

    if (result.deleted && name != null) {
      store.setCategories(db.categories.where((c) => c.name != name).toList());
      return;
    }
    if (result.name.trim().isEmpty) return;

    if (name != null && result.name != name) store.renameCategory(name, result.name);

    final list = [...store.db.categories];
    final i = list.indexWhere((c) => c.name == result.name);
    final next = Category(
      name: result.name,
      parent: i >= 0 ? list[i].parent : null,
      color: result.color?.toARGB32(),
      icon: result.icon,
      bucket: result.bucket,
      kind: result.kind,
      accounts: result.accounts,
    );
    // Вид родителя обязан дойти до подкатегорий: иначе «Супермаркет» остался
    // бы в расходах, когда «Продукты» перевели в доход.
    if (result.kind != null) {
      for (var j = 0; j < list.length; j++) {
        if (list[j].parent == result.name && list[j].kind != result.kind) {
          list[j] = list[j].copyWith(kind: result.kind);
        }
      }
    }
    if (i >= 0) {
      list[i] = next;
    } else {
      list.add(next);
    }
    store.setCategories(list);
  }
}

/// Завести категорию ТЕМ ЖЕ листом, что и на экране категорий, и сохранить её.
///
/// Раньше запись операции спрашивала одно имя и не сохраняла НИЧЕГО: категория
/// жила до закрытия экрана, а цвет со значком выбрать было негде («нигде не
/// сохраняются… ничего кроме названия нельзя, хотя уже есть готовый экран
/// создания категорий» — 13.09.2026).
///
/// Возвращает имя заведённой категории или null, если человек передумал.
Future<String?> addCategorySheet(
  BuildContext context,
  Store store, {
  required CatKind kind,
}) async {
  final result = await showModalBottomSheet<_Edited>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _CategorySheet(
      name: '',
      kind: kind,
      allAccounts: [
        for (final a in store.db.accounts)
          if (!isVirtualAccount(a.name)) a.name,
      ],
    ),
  );
  final name = result?.name.trim() ?? '';
  if (result == null || result.deleted || name.isEmpty) return null;

  final list = [...store.db.categories];
  final at = list.indexWhere((c) => c.name == name);
  final next = Category(
    name: name,
    parent: at >= 0 ? list[at].parent : null,
    color: result.color?.toARGB32(),
    icon: result.icon,
    bucket: result.bucket,
    kind: result.kind,
    accounts: result.accounts,
  );
  if (at >= 0) {
    list[at] = next;
  } else {
    list.add(next);
  }
  store.setCategories(list);
  return name;
}

/// Имена: заведённые в реестре плюс встреченные в операциях. Иначе старую
/// категорию, которой нет в реестре, нельзя ни переименовать, ни раскрасить.
List<String> _allNames(Database db) {
  // Подкатегории в верхний список не попадают: они стоят чипами под своей
  // категорией, а дважды на одном экране одно и то же имя читается поломкой.
  final names = <String>{
    ...db.categories.where((c) => (c.parent ?? '').isEmpty).map((c) => c.name),
    ...db.transactions.map((t) => (t.category ?? '').trim()).where((n) => n.isNotEmpty),
  }.toList()
    ..sort();
  return names;
}

/// Чем доля отличается от соседней — одной строкой. Без этого три пилюли
/// «Нужда / Желание / Сбережение» человеку ничего не говорили.
String _bucketWhy(Bucket b) => switch (b) {
      Bucket.needs => tr('bucketNeedWhy'),
      Bucket.wants => tr('bucketWantWhy'),
      Bucket.savings => tr('bucketSavingWhy'),
      Bucket.none => '',
    };

String _bucketTitle(Bucket b) => switch (b) {
      Bucket.needs => tr('bucketNeed'),
      Bucket.wants => tr('bucketWant'),
      Bucket.savings => tr('bucketSaving'),
      Bucket.none => tr('bucketUnmarked'),
    };

/// Пилюля выбора вида расхода.
class _BucketPick extends StatelessWidget {
  const _BucketPick({required this.title, required this.on, required this.onTap});

  final String title;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка выбора доли: слово и объяснение под ним, во всю ширину.
///
/// Пилюли в ряд объясняли нечего: три слова без разницы между ними. Строка
/// вмещает вторую строчку, и выбор становится понятным с первого взгляда.
class _BucketRow extends StatelessWidget {
  const _BucketRow({
    required this.title,
    required this.note,
    required this.on,
    required this.onTap,
  });

  final String title;
  final String note;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12.5,
                      color: on
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              on ? Myna.checkCircle : Myna.circle,
              size: 22,
              color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
          ]),
        ),
      ),
    );
  }
}

String _useWord(int n) => trn('useWord', n);

class _Edited {
  final String name;
  final Color? color;
  final String? icon;
  final Bucket bucket;

  /// Расход или доход. У подкатегории свой не спрашивается — она берёт
  /// родительский.
  final CatKind? kind;

  /// Счета, где категория показывается. Пусто — на всех.
  final List<String> accounts;
  final bool deleted;
  const _Edited(
    this.name,
    this.color,
    this.icon,
    this.bucket, {
    this.kind,
    this.accounts = const [],
    this.deleted = false,
  });
}

class _CategorySheet extends StatefulWidget {
  final String name;
  final Color? color;
  final String? icon;
  final Bucket bucket;
  final List<String> accounts;
  final List<String> allAccounts;

  /// Вид расхода спрашивается только у категории: подкатегория наследует его
  /// от родителя, иначе одна трата попала бы в две доли правила.
  final bool showBucket;

  /// Расход или доход. У подкатегории не спрашивается по той же причине.
  final CatKind? kind;

  /// Заголовок листа. У категории его нет — там и без слов понятно, — а у
  /// подкатегории нужен: иначе лист не отличить от правки самой категории.
  final String? title;

  const _CategorySheet({
    required this.name,
    this.color,
    this.icon,
    this.bucket = Bucket.none,
    this.accounts = const [],
    this.allAccounts = const [],
    this.showBucket = true,
    this.kind,
    this.title,
  });

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name = TextEditingController(text: widget.name);
  late Color? _color = widget.color;
  late String? _icon = widget.icon;
  late final Set<String> _accounts = {...widget.accounts};
  late Bucket _bucket = widget.bucket;
  late CatKind _kind = widget.kind ?? CatKind.expense;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _color ?? labelColorFor(_name.text.isEmpty ? tr('categoryWordPlaceholder') : _name.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // Шапка по ЦЕНТРУ: значок сверху, поле под ним во всю ширину.
              // Раньше значок и поле стояли в ряд, и лист «поплыл влево»
              // (13.09.2026), а плавающая подпись поля лезла на его рамку.
              Center(
                child: LabelDot(
                  name: _name.text,
                  icon: categoryIcon(_name.text, stored: _icon),
                  color: preview,
                  size: 72,
                ),
              ),
              const SizedBox(height: 16),
              _label(tr('categoryName')),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                autofocus: widget.name.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: tr('categoryNameHint')),
                style: TextStyle(fontFamily: AppTheme.bodyFont, fontSize: 16),
              ),
              if (widget.kind != null) ...[
                const SizedBox(height: 22),
                _label(tr('categoryKind')),
                const SizedBox(height: 4),
                _hint(tr('categoryKindWhy')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _BucketPick(
                      title: tr('categoryKindExpense'),
                      on: _kind == CatKind.expense,
                      onTap: () => setState(() => _kind = CatKind.expense),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BucketPick(
                      title: tr('categoryKindIncome'),
                      on: _kind == CatKind.income,
                      onTap: () => setState(() => _kind = CatKind.income),
                    ),
                  ),
                ]),
              ],
              // У дохода доли НЕТ: правило делит то, что пришло, а не то, чем
              // оно пришло. Три пилюли на экране дохода объясняли нечего и
              // сбивали с толку («совсем мне не понятны», 13.09.2026).
              if (widget.showBucket && _kind == CatKind.expense) ...[
                const SizedBox(height: 22),
                _label(tr('categoryBucket')),
                const SizedBox(height: 4),
                _hint(_bucket == Bucket.none && _name.text.trim().isNotEmpty
                    ? '${tr('categoryBucketWhy')} '
                        '${trf('categoryBucketGuess', [
                          _bucketTitle(bucketGuess(_name.text.trim()))
                        ])}'
                    : tr('categoryBucketWhy')),
                const SizedBox(height: 10),
                for (final b in const [
                  Bucket.needs,
                  Bucket.wants,
                  Bucket.savings,
                ]) ...[
                  _BucketRow(
                    title: _bucketTitle(b),
                    note: _bucketWhy(b),
                    on: _bucket == b,
                    onTap: () =>
                        setState(() => _bucket = _bucket == b ? Bucket.none : b),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 22),
              _label(tr('categoryColor')),
              const SizedBox(height: 10),
              // Сетка, а не Wrap: цветов двадцать четыре плюс «сам подберу»,
              // и ряды обязаны быть ровными. Wrap оставлял последнюю строку
              // с одним кружком, и лист выглядел сломанным.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _swatch(null, scheme),
                  for (final c in labelColors) _swatch(c, scheme),
                ],
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _label(tr('categoryIcon'))),
                TextButton.icon(
                  onPressed: _findIcon,
                  icon: const Icon(Myna.search, size: 18),
                  label: Text(tr('categoryIconFind')),
                ),
              ]),
              const SizedBox(height: 10),
              // Частые лежат сразу, остальные 1310 — за поиском. Раньше выбор
              // был из тридцати четырёх и на этом кончался.
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (final entry in _iconRow) _iconCell(entry.$1, entry.$2, scheme),
                ],
              ),
              if (widget.allAccounts.isNotEmpty) ...[
                SizedBox(height: 22),
                _label(tr('categoryAccounts')),
                SizedBox(height: 4),
                Text(
                  _accounts.isEmpty
                      ? tr('categoryAccountsAll')
                      : tr('categoryAccountsSome'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: Text(tr('categoryAccountsEvery')),
                    selected: _accounts.isEmpty,
                    onSelected: (_) => setState(_accounts.clear),
                  ),
                  for (final name in widget.allAccounts)
                    ChoiceChip(
                      label: Text(name),
                      selected: _accounts.contains(name),
                      onSelected: (_) => setState(() {
                        if (!_accounts.remove(name)) _accounts.add(name);
                      }),
                    ),
                ]),
              ],
              const SizedBox(height: 26),
              Row(
                children: [
                  if (widget.name.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.of(context)
                          .pop(_Edited('', null, null, Bucket.none, deleted: true)),
                      child: Text(tr('categoryRemove'), style: TextStyle(color: Money.down(context))),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _name.text.trim().isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_Edited(
                              _name.text.trim(),
                              _color,
                              _icon,
                              // Доход долей не размечается: она только у трат.
                              _kind == CatKind.income ? Bucket.none : _bucket,
                              kind: widget.kind == null ? null : _kind,
                              accounts: _accounts.toList()..sort(),
                            )),
                    child: Text(tr('categorySave')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  /// Объяснение под подписью. Человек решает по нему, а не по заголовку.
  Widget _hint(String text) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12.5,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  /// Что стоит в выборе значков: частые из старого набора плюс выбранный
  /// поиском, если его там нет. Иначе выбранный знак пропадал бы с глаз.
  List<(String, IconData)> get _iconRow {
    final out = <(String, IconData)>[
      for (final e in iconChoices.entries) (e.key, e.value),
    ];
    final chosen = _icon;
    if (chosen != null && !iconChoices.containsKey(chosen)) {
      final icon = iconByName(chosen);
      if (icon != null) out.insert(0, (chosen, icon));
    }
    return out;
  }

  Widget _iconCell(String key, IconData icon, ColorScheme scheme) {
    final on = _icon == key;
    return GestureDetector(
      onTap: () => setState(() => _icon = on ? null : key),
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

  /// Поиск по всему набору MyNaUI. Выбранное имя уезжает в базу строкой —
  /// то же поле, что хранит короткие ключи старого набора.
  Future<void> _findIcon() async {
    final picked = await showIconSearch(context);
    if (picked == null || !mounted) return;
    setState(() => _icon = picked);
  }

  Widget _swatch(Color? c, ColorScheme scheme) {
    final on = _color?.toARGB32() == c?.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => _color = c),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: c ?? scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: on ? Border.all(color: scheme.onSurface, width: 2.5) : null,
        ),
        child: c == null
            ? Icon(Myna.sparkles, size: 18, color: scheme.onSurfaceVariant)
            : (on ? Icon(Myna.check, size: 20, color: inkOn(c)) : null),
      ),
    );
  }
}

/// Категория и её подкатегории.
///
/// Подкатегории лежат тут же, а не на отдельном экране: у «Продуктов» их
/// три-четыре, и ходить за ними куда-то ещё незачем. Свой цвет и значок есть у
/// каждой — они же идут в ассорти на квартале категории.
class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.store,
    required this.name,
    required this.spent,
    required this.onEdit,
    required this.onEditSub,
  });

  final Store store;
  final String name;

  /// Сколько прошло через категорию — в базовой валюте.
  final double spent;

  final VoidCallback onEdit;
  final void Function(String? sub) onEditSub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subs = store.subcategoriesOf(name);
    final at = store.db.categories.indexWhere((c) => c.name == name);
    final stored = at >= 0 ? store.db.categories[at] : null;
    final tint = stored?.color == null ? labelColorFor(name) : Color(stored!.color!);
    final used = store.db.transactions.where((t) => t.category == name).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                LabelDot(
                  name: name,
                  icon: categoryIcon(name, stored: stored?.icon),
                  color: tint,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (stored != null && stored.bucket != Bucket.none)
                            _bucketTitle(stored.bucket),
                          used == 0
                              ? tr('noOperations')
                              : trf('noticesUsedIn', [used, _useWord(used)]),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Сумма по категории: экран правки заодно отвечает на вопрос
                // «куда вообще уходит», а не только «как это называется».
                if (spent > 0.005)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: MoneyText(
                      spent,
                      currency: store.db.baseCurrency,
                      size: 14,
                      weight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                IconButton(
                  onPressed: () => onEditSub(null),
                  icon: const Icon(Myna.plus, size: 20),
                  color: scheme.onSurfaceVariant,
                  tooltip: tr('subcategoryOne'),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),
          ),
          if (subs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 0, 12),
              child: PickRow(
                height: 38,
                children: [
                  for (final sub in subs)
                    _SubChip(
                      name: sub.name,
                      color: sub.color == null ? null : Color(sub.color!),
                      icon: categoryIcon(sub.name, stored: sub.icon),
                      onTap: () => onEditSub(sub.name),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}

class _SubChip extends StatelessWidget {
  const _SubChip({
    required this.name,
    required this.icon,
    required this.onTap,
    this.color,
  });

  final String name;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? labelColorFor(name);
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.only(left: 5, right: 12, top: 5, bottom: 5),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 14, color: inkOn(tint)),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}



