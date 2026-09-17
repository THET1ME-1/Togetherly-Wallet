import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/category_pick.dart';
import 'package:togetherly_money/logic/presets.dart';

void main() {
  group('стартовый набор', () {
    test('в наборе есть и расходы, и доходы', () {
      final preset = presetCategories();
      final expense = preset.where((c) => c.kind == CatKind.expense);
      final income = preset.where((c) => c.kind == CatKind.income);
      // Человек жаловался ровно на это: «нет предустановленных категорий и
      // подкатегорий доходов отдельно и расходов».
      expect(expense.length, greaterThan(20));
      expect(income.length, greaterThan(5));
      expect(preset.any((c) => c.name == tr('catSalary')), isTrue);
      expect(preset.any((c) => c.name == tr('catGroceries')), isTrue);
    });

    test('у каждой подкатегории есть живой родитель того же вида', () {
      final preset = presetCategories();
      final tops = {
        for (final c in preset)
          if (c.parent == null) c.name: c,
      };
      final children = preset.where((c) => c.parent != null);
      expect(children, isNotEmpty);
      for (final child in children) {
        final parent = tops[child.parent];
        expect(parent, isNotNull, reason: 'родитель ${child.parent} потерялся');
        expect(child.kind, parent!.kind,
            reason: '${child.name} должна наследовать вид родителя');
      }
    });

    test('имена не повторяются внутри своего уровня', () {
      final seen = <String>{};
      for (final c in presetCategories()) {
        final key = '${c.parent ?? ''}/${c.name}';
        expect(seen.add(key), isTrue, reason: 'дубль $key');
      }
    });

    test('набор кладётся на чистое место, свои категории остаются', () {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          categories: [Category(name: 'Своя')],
        ));
      store.seedCategories();

      expect(store.db.categories.any((c) => c.name == 'Своя'), isTrue);
      expect(store.db.categories.length, presetCount() + 1);
      // Второй заход ничего не удваивает.
      store.seedCategories();
      expect(store.db.categories.length, presetCount() + 1);
    });

    test('удаление всех категорий не трогает деньги', () {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          categories: [Category(name: 'Продукты')],
          transactions: [
            Transaction(
              id: 't1',
              date: '2026-09-10',
              kind: TxKind.expense,
              account: 'Карта',
              currency: 'MDL',
              amount: -100,
              amountBase: -100,
              category: 'Продукты',
            ),
          ],
        ));
      store.clearCategories();

      expect(store.db.categories, isEmpty);
      // Деньги записаны — стирать их вместе с ярлыком нельзя.
      expect(store.db.transactions.length, 1);
      expect(store.db.transactions.first.amount, -100);
    });

    test('подкатегория наследует вид родителя при смене', () {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          categories: [
            Category(name: 'Продукты', kind: CatKind.expense),
            Category(name: 'Рынок', parent: 'Продукты', kind: CatKind.expense),
          ],
        ));

      // Ровно то, что делает лист правки: родителю сменили вид.
      final list = [...store.db.categories];
      list[0] = list[0].copyWith(kind: CatKind.income);
      for (var i = 0; i < list.length; i++) {
        if (list[i].parent == 'Продукты') {
          list[i] = list[i].copyWith(kind: CatKind.income);
        }
      }
      store.setCategories(list);

      // Иначе «Рынок» остался бы в расходах, когда родитель ушёл в доходы.
      final sub = store.db.categories.firstWhere((c) => c.name == 'Рынок');
      expect(sub.kind, CatKind.income);
    });

    test('в доходах не предлагаются расходные категории', () {
      final db = Database(baseCurrency: 'MDL', categories: presetCategories());

      final income = categoriesForAccount(db, account: null, income: true);
      final expense = categoriesForAccount(db, account: null, income: false);

      expect(income, contains(tr('catSalary')));
      expect(income, isNot(contains(tr('catGroceries'))));
      expect(expense, contains(tr('catGroceries')));
      expect(expense, isNot(contains(tr('catSalary'))));
      // Подкатегория не самостоятельна: в общем ряду её быть не должно.
      expect(expense, isNot(contains(tr('subSupermarket'))));
    });
  });
}
