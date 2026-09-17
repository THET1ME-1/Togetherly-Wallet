import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/accounts_screen.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';
import 'package:togetherly_money/screens/categories.dart';
import 'package:togetherly_money/screens/debts_screen.dart';
import 'package:togetherly_money/screens/goals_screen.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/screens/operation_edit.dart';
import 'package:togetherly_money/screens/plan_screen.dart';
import 'package:togetherly_money/screens/recurring_screen.dart';
import 'package:togetherly_money/screens/stats_screen.dart';
import 'package:togetherly_money/widgets/money_text.dart';

import 'tm_fonts.dart';

/// Крупные суммы на всех экранах.
///
/// Родилось из жалобы «ты напиши сумму больше 1000 и она пропадает просто»
/// (14.09.2026): валюта и число склеивались обычным пробелом, и строка на одну
/// строчку рвалась по нему — число уезжало на вторую строку, которой нет, а на
/// экране оставалось «MDL». Проверять такое глазами по одной сумме бессмысленно:
/// граница пропажи зависит от ширины экрана, кегля и системного шрифта.
///
/// Поэтому тест берёт разряды от тысячи до миллиарда и прогоняет по ним экраны
/// в худших условиях: 320 dp при системном шрифте 1.3. Ловит три беды сразу —
/// переполнение разметки, обрезку текста и перенос числа на вторую строку.

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

/// Разряды, на которых ломается вёрстка: тысяча, десятки тысяч, миллион и
/// миллиард. Копейки ненулевые нарочно — «,00» короче и прячет беду.
const bigAmounts = <double>[
  1000.00,
  12345.67,
  999999.99,
  1234567.89,
  99999999.99,
  987654321.12,
];

/// Условия, в которых крупное число прижимается к краю.
const tight = <({String name, Size size, double scale})>[
  (name: '393 dp', size: Size(393, 852), scale: 1.0),
  (name: '320 dp', size: Size(320, 640), scale: 1.0),
  (name: '320 dp при шрифте 1.3', size: Size(320, 640), scale: 1.3),
];

Database dbWith(double amount) => Database(
      baseCurrency: 'MDL',
      accounts: const [
        Account(name: 'Карта Salut', currency: 'MDL', last4: '3507'),
        Account(name: 'Наличные', currency: 'MDL'),
        Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
      ],
      categories: presetCategories(),
      transactions: [
        Transaction(
          id: 'big',
          kind: TxKind.expense,
          account: 'Карта Salut',
          category: 'Еда и напитки',
          amount: -amount,
          amountBase: -amount,
          currency: 'MDL',
          date: '2026-08-14',
          note: 'Крупная трата',
          author: me.uid,
          payer: me.uid,
        ),
        Transaction(
          id: 'big-income',
          kind: TxKind.income,
          account: 'Карта Salut',
          category: 'Работа',
          amount: amount,
          amountBase: amount,
          currency: 'MDL',
          date: '2026-08-10',
          note: 'Крупный доход',
          author: me.uid,
          payer: me.uid,
        ),
      ],
      goals: [
        Goal(name: 'Машина', target: amount, currency: 'MDL'),
      ],
      budgets: [
        Budget(
          category: 'Еда и напитки',
          limit: amount,
          currency: 'MDL',
          period: 'monthly',
        ),
      ],
      debts: [
        Debt(
          name: 'Ипотека',
          principal: amount,
          currency: 'MDL',
          rate: 8.5,
          minPayment: amount / 100,
        ),
      ],
      pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
    );

Store storeWith(double amount) {
  final store = Store()..importBackupForTest(dbWith(amount));
  store.viewer = me.uid;
  return store;
}

/// Сумма, которая обязана быть видна целиком.
String moneyOf(double v) => formatMoney(v, 'MDL');

/// Все беды текста разом: обрезка, перенос числа и выход за свой слот.
///
/// `didExceedMaxLines` ловит «не влезло в отведённые строки», число строк —
/// перенос суммы («MDL» на первой строке, цифры на второй), сравнение ширины —
/// выход за границы родителя.
void expectAmountsWhole(WidgetTester tester, String where) {
  final broken = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;
    final text = render.text.toPlainText();
    // Сумма узнаётся по коду валюты рядом с цифрами.
    if (!text.contains('MDL')) continue;
    if (!RegExp(r'\d').hasMatch(text)) continue;

    if (render.didExceedMaxLines) {
      broken.add('обрезано: «$text» (кегль ${render.text.style?.fontSize})');
      continue;
    }
    final painter = TextPainter(
      text: render.text,
      textDirection: render.textDirection,
      textAlign: render.textAlign,
      textScaler: render.textScaler,
      maxLines: render.maxLines,
      ellipsis: render.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    )..layout(maxWidth: render.size.width);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    if (lines > 1) {
      broken.add('перенос на $lines строк: «$text» '
          '(кегль ${render.text.style?.fontSize}, слот '
          '${render.constraints.maxWidth.round()})');
      continue;
    }
    final slot = render.constraints.maxWidth;
    if (slot.isFinite && render.size.width > slot + 0.5) {
      broken.add('шире слота на ${(render.size.width - slot).round()} px: «$text»');
    }
  }
  expect(broken, isEmpty, reason: '$where\n${broken.join('\n')}');
}

Future<void> show(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required double scale,
  bool dark = false,
  // Экран записи держит свой Scaffold: чужой поверх него ломает разметку и
  // даёт переполнение, которого в приложении нет.
  bool scaffold = true,
}) async {
  // Размер задаётся окну в dp: свой `size` внутри MediaQuery поверхность
  // отрисовки не меняет, и экран собирается по чужой ширине.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        darkTheme: MoneyTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: scaffold ? Scaffold(body: screen) : screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(loadTmFonts);

  final period = Period.month(DateTime(2026, 8, 15));

  // Каждый экран строится своей записью: у них разные обязательные колбэки.
  final screens = <String, Widget Function(Store)>{
    'главная': (store) => HomeScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          onAccounts: () {},
          onBudgets: () {},
          onGoals: () {},
          onPlan: () {},
          onDebts: () {},
          onChat: () {},
          onSettings: () {},
          onNotices: () {},
          onDrill: (_, __, [Period? ___]) {},
        ),
    'лента': (store) => LedgerScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: ([Transaction? _]) {},
        ),
    'статистика': (store) => StatsScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          onDrill: (_, __, [Period? ___]) {},
        ),
    'категории': (store) => CategoriesScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          onDrill: (_, __) {},
          onEditCategories: () {},
        ),
    'счета': (store) => AccountsScreen(
          store: store,
          onEdit: ([Transaction? _]) {},
          onAccountOps: (_) {},
        ),
    'цели': (store) => GoalsScreen(store: store),
    'бюджеты': (store) => BudgetsScreen(store: store),
    'план': (store) => PlanScreen(store: store),
    'долги': (store) => DebtsScreen(store: store),
    'регулярное': (store) => RecurringScreen(store: store),
    // Экран записи: с него и началась жалоба про пропавшую сумму.
    'запись': (store) => OperationScreen(store: store),
    // Правка записи: там же стоит заметка, и длинная строка в ряду мелочей
    // вела себя иначе, чем пустая.
    'правка записи': (store) => OperationScreen(
          store: store,
          edit: store.db.transactions.first,
        ),
  };

  for (final amount in bigAmounts) {
    for (final view in tight) {
      testWidgets('${moneyOf(amount)} целиком видна на ${view.name}',
          (tester) async {
        for (final entry in screens.entries) {
          await show(
            tester,
            entry.value(storeWith(amount)),
            size: view.size,
            scale: view.scale,
            scaffold: !entry.key.contains('запис'),
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'разметка переполнилась: ${entry.key}, ${view.name}, '
                '${moneyOf(amount)}',
          );
          expectAmountsWhole(
            tester,
            'экран «${entry.key}», ${view.name}, ${moneyOf(amount)}',
          );
        }
      });
    }
  }

  testWidgets('миллиард не ломает экраны и на тёмной теме', (tester) async {
    for (final entry in screens.entries) {
      await show(
        tester,
        entry.value(storeWith(987654321.12)),
        size: const Size(320, 640),
        scale: 1.3,
        dark: true,
        scaffold: !entry.key.contains('запис'),
      );
      expect(tester.takeException(), isNull, reason: 'тёмная: ${entry.key}');
      expectAmountsWhole(tester, 'тёмная тема, экран «${entry.key}»');
    }
  });
}
