import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import 'tm_fonts.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'JB SHARAN');

Store storeOf({bool paired = true, List<Member> members = const [me, you]}) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [
        Account(name: 'Карта Sanamacos', currency: 'USD', last4: '4417', brand: CardBrand.visa),
        Account(name: 'Наличные', currency: 'MDL'),
        Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
      ],
      categories: presetCategories(),
      pair: paired
          ? Pair(groupId: 'g1', members: members, baseCurrency: 'MDL')
          : const Pair(),
    ));
  store.viewer = me.uid;
  return store;
}

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
      home: home,
    );

/// Сколько ещё осталось прокрутки: ноль значит «влезло целиком».
///
/// Меряем по СОСТОЯНИЮ прокрутки, а не по `Scrollable.controller`: своего
/// контроллера у формы нет, и проверка по нему молча отвечала нулём на любой
/// экран — тест был зелёным всегда.
double leftToScroll(WidgetTester tester) {
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = element as StatefulElement;
    final scroll = state.state as ScrollableState;
    if (scroll.axisDirection == AxisDirection.down ||
        scroll.axisDirection == AxisDirection.up) {
      return scroll.position.maxScrollExtent;
    }
  }
  return 0;
}

void main() {
  setUpAll(loadTmFonts);

  group('экран записи в паре', () {
    for (final size in const [(393.0, 852.0, 'обычный'), (360.0, 740.0, 'короткий')]) {
      testWidgets('ничего не наезжает друг на друга, ${size.$3}', (tester) async {
        tester.view.physicalSize = Size(size.$1 * 3, size.$2 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(OperationScreen(store: storeOf())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'переполнение колонки рисует поля поверх суммы');
      });
    }

    testWidgets('перевод не ломает раскладку', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(OperationScreen(store: storeOf())));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('opTransfer')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('помещается без прокрутки', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(OperationScreen(store: storeOf())));
      await tester.pumpAndSettle();
      expect(leftToScroll(tester), 0,
          reason: 'запись траты — самый частый экран, листать его нечего');
    });

    testWidgets('сюрприз и крупный шрифт не кладут поля друг на друга',
        (tester) async {
      // Ровно то, что человек показал на записи: пара, счёт в долларах,
      // включённый сюрприз и системный шрифт крупнее обычного.
      // Высота взята за вычетом строки состояния и полосы навигации: на
      // телефоне форме достаётся меньше, чем говорит диагональ.
      tester.view.physicalSize = const Size(412 * 3, 730 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
        child: app(OperationScreen(store: storeOf())),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'без сюрприза уже тесно');

      // Сюрприз стоит мелкой кнопкой в строке сводки: до него не надо ни
      // листать, ни прокручивать — он на виду с первого кадра.
      final secret = find.byTooltip(tr('opSecretShort'));
      expect(secret, findsOneWidget);
      await tester.tap(secret);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'сюрприз добавляет подпись — и строки лезут друг на друга');
    });

    testWidgets('категории видны сразу, а не за прокруткой', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(OperationScreen(store: storeOf())));
      await tester.pumpAndSettle();

      // Строка сводки открывает панель категорий — одно касание.
      await tester.tap(find.text(tr('opPickCategory')));
      await tester.pumpAndSettle();

      final food = find.text('Продукты');
      expect(food, findsWidgets);
      final box = tester.getRect(food.first);
      final screen = tester.getRect(find.byType(Scaffold).first);
      expect(box.bottom, lessThanOrEqualTo(screen.bottom),
          reason: 'категория за краем экрана — это её нет');

      // Панель показывает десятки категорий сразу: в прежнем ряду с
      // прокруткой вбок их было видно две с половиной из двадцати шести.
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      expect(tester.widgetList(cells).length, greaterThanOrEqualTo(8),
          reason: 'ради выбора категории не листают');
    });

    testWidgets('выбранная категория открывает подкатегории, и всё влезает',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(OperationScreen(store: storeOf())));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('opPickCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продукты').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Подкатегории встают НАД сеткой той же панели: ни отдельного экрана,
      // ни второго листания.
      expect(find.text('Супермаркет'), findsOneWidget);

      // Сводка остаётся на месте целиком: панель живёт своей жизнью и ничего
      // не выталкивает за экран. Прокрутка есть только внутри самой сетки —
      // двадцать шесть категорий не влезут в панель ни при какой вёрстке.
      final screen = tester.getRect(find.byType(Scaffold).first);
      for (final label in ['Карта Sanamacos', 'Продукты', 'Сегодня']) {
        final box = tester.getRect(find.text(label).first);
        expect(box.bottom, lessThanOrEqualTo(screen.bottom),
            reason: '«$label» уехало за нижний край');
        expect(box.top, greaterThanOrEqualTo(screen.top));
      }
    });

    testWidgets('человек подписан именем, а не «я» и не «партнёр»',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(OperationScreen(store: storeOf())));
      await tester.pumpAndSettle();

      expect(find.text('Саша'), findsWidgets);

      // Имя партнёра — в листе «Кто платил»: строка сводки показывает того,
      // кто платит сейчас, а выбор открывается касанием.
      await tester.tap(find.text('Саша').first);
      await tester.pumpAndSettle();
      expect(find.text('JB SHARAN'), findsWidgets);
      expect(find.textContaining('Платил я'), findsNothing);
      expect(find.textContaining('Платила'), findsNothing);
      expect(find.textContaining('Вы '), findsNothing);
    });
  });
}
