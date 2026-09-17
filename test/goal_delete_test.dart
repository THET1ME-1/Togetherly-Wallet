import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/goals.dart';
import 'package:togetherly_money/logic/money.dart';

/// Удаление цели.
///
/// Цель собирается не только из записи, но и из операций по счёту «Цель: …»,
/// поэтому удаление ЗАПИСИ у цели с деньгами ничего не меняло: она возвращалась
/// на экран сама («цели нельзя удалить», 17.09.2026). Деньги надо сперва
/// вернуть на кошелёк.
Store storeWithGoal({double saved = 0}) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      goals: const [Goal(name: 'Отпуск', target: 5000, currency: 'MDL')],
      transactions: [
        if (saved > 0)
          Transaction(
            id: 'put-1',
            date: '2026-09-10',
            kind: TxKind.transfer,
            account: goalAccountOf('Отпуск'),
            currency: 'MDL',
            amount: saved,
            amountBase: saved,
          ),
      ],
    ));
  store.viewer = 'u_me';
  return store;
}

void main() {
  test('Пустая цель убирается запросто', () {
    final store = storeWithGoal();
    store.deleteGoal('Отпуск');

    expect(allGoals(store.db).where((g) => g.goal.name == 'Отпуск'), isEmpty);
  });

  test('Цель с деньгами возвращается, пока деньги на ней', () {
    final store = storeWithGoal(saved: 200);
    store.deleteGoal('Отпуск');

    expect(allGoals(store.db).where((g) => g.goal.name == 'Отпуск'), isNotEmpty,
        reason: 'деньги остались на счёте цели, и она собирается из операций');
  });

  test('Вернули деньги на кошелёк — цель уходит совсем', () {
    final store = storeWithGoal(saved: 200);
    final goal = store.db.goals.first;
    store.withdrawFromGoal(goal, to: 'Карта', amount: 200);
    store.deleteGoal('Отпуск');

    expect(allGoals(store.db).where((g) => g.goal.name == 'Отпуск'), isEmpty);
    final wallet = balances(store.db).firstWhere((a) => a.name == 'Карта');
    expect(wallet.mainAmount, 200, reason: 'накопленное вернулось человеку');
  });
}
