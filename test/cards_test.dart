import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/icons.dart';
import 'package:togetherly_money/screens/accounts_screen.dart';
import 'package:togetherly_money/screens/account_edit_screen.dart';
import 'package:togetherly_money/widgets/card_tile.dart';

import 'tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

Database sample() => Database(
      baseCurrency: 'MDL',
      pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: const [
        Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true, last4: '4568',
            brand: CardBrand.mastercard, design: 0),
        Account(name: 'Моя копилка', currency: 'MDL', last4: '2210',
            brand: CardBrand.mir, kind: AccountKind.savings, owner: 'u_me', design: 1),
      ],
      transactions: const [
        Transaction(id: 'a', date: '2026-09-10', kind: TxKind.income,
            account: 'Общий кошелёк', currency: 'MDL', amount: 18652.11,
            amountBase: 18652.11, author: 'u_me', payer: 'u_me'),
        Transaction(id: 'b', date: '2026-09-10', kind: TxKind.income,
            account: 'Моя копилка', currency: 'MDL', amount: 4300,
            amountBase: 4300, author: 'u_me', payer: 'u_me'),
      ],
    );

Store storeOf([Database? db]) {
  final store = Store()..importBackupForTest(db ?? sample());
  store.syncEnabled = true;
  store.viewer = me.uid;
  return store;
}

void main() {
  setUpAll(loadTmFonts);

  group('карта счёта', () {
    test('оформление подбирается по имени, но своё сильнее', () {
      const plain = Account(name: 'Карта maib', currency: 'MDL');
      const chosen = Account(name: 'Карта maib', currency: 'MDL', design: 3);
      expect(designOf(plain, plain.name), designOf(null, 'Карта maib'),
          reason: 'без своего оформления цвет берётся из имени и не прыгает');
      expect(designOf(chosen, chosen.name), cardDesigns[3]);
    });

    test('поля карты доживают до диска и обратно', () {
      const acc = Account(name: 'Карта maib', currency: 'MDL', last4: '8413',
          brand: CardBrand.visa, kind: AccountKind.credit, design: 2);
      final again = Account.fromJson(acc.toJson());
      expect(again.last4, '8413');
      expect(again.brand, CardBrand.visa);
      expect(again.kind, AccountKind.credit);
      expect(again.design, 2);
    });

    test('карта уезжает на сервер и приезжает обратно', () {
      final store = storeOf();
      store.editAccount('Общий кошелёк', last4: '9999', brand: CardBrand.visa,
          kind: AccountKind.credit, design: 5);
      expect(store.outbox, contains('acc:Общий кошелёк'));
      final acc = store.db.accounts.firstWhere((a) => a.name == 'Общий кошелёк');
      expect(acc.last4, '9999');
      expect(acc.brand, CardBrand.visa);

      store.clearOutbox(store.outbox.toSet());
      store.applyRemote({
        'now': 2,
        'accounts': [
          {'name': 'Карта партнёра', 'currency': 'MDL', 'owner_uid': '', 'is_pot': false,
           'last4': '1234', 'brand': 'mastercard', 'card_kind': 'card', 'design': 4},
        ],
      });
      final came = store.db.accounts.firstWhere((a) => a.name == 'Карта партнёра');
      expect(came.last4, '1234');
      expect(came.brand, CardBrand.mastercard);
      expect(came.design, 4);
    });

    test('пустое оформление с сервера не прилипает к нулевому', () {
      // -1 значит «подобрать по имени», а не «первое оформление в наборе».
      final store = storeOf();
      store.applyRemote({
        'now': 3,
        'accounts': [
          {'name': 'Без оформления', 'currency': 'MDL', 'design': -1},
        ],
      });
      expect(store.db.accounts.firstWhere((a) => a.name == 'Без оформления').design, isNull);
    });

    testWidgets('на карте видно систему, четыре цифры и вид', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: Center(
            child: CardTile(
              name: 'Моя копилка',
              account: sample().accounts[1],
              amount: 4300,
              currency: 'MDL',
              onDetails: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Моя копилка'), findsOneWidget);
      expect(find.text('•••• 2210'), findsOneWidget);
      expect(find.text('Накопительный'), findsOneWidget);
      expect(find.text('МИР'), findsOneWidget);
      // Личный счёт помечен замком, а не словами: слова не влезали.
      expect(find.byIcon(Myna.lock), findsOneWidget);
      expect(find.text('Настроить'), findsOneWidget);
    });

    testWidgets('без номера карта не выглядит битой', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: const Scaffold(
          body: Center(
            child: CardTile(
              name: 'Наличные',
              account: Account(name: 'Наличные', currency: 'MDL', kind: AccountKind.cash),
              amount: 1240.55,
              currency: 'MDL',
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Без номера'), findsOneWidget);
      expect(find.text('Наличные'), findsWidgets);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('счета собираются на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: MoneyTheme.light(),
            darkTheme: MoneyTheme.dark(),
            themeMode: mode,
            home: AccountsScreen(store: storeOf(), onEdit: (_) {}, onAccountOps: (_) {}),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('карта ведёт к операциям счёта, «Настроить» — в правку',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: AccountsScreen(store: storeOf(), onEdit: (_) {}, onAccountOps: (_) {}),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Настроить').first);
      await tester.pumpAndSettle();
      // Подписи разделов идут капсом — как в каркасе настроек, на котором
      // экран правки собран с 13.09.2026.
      expect(find.text('Платёжная система'.toUpperCase()), findsOneWidget);
      expect(find.text('Имя счёта'.toUpperCase()), findsOneWidget);
    });
  });

  group('знак на карте', () {
    testWidgets('в углу стоит значок САМОГО счёта, а не заглушка-карта',
        (tester) async {
      // «У счёта при создании есть иконка, она и должна отображаться»
      // (13.09.2026). Раньше всем без платёжной системы рисовалась карта, и у
      // наличных в углу была карта.
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: const Scaffold(
          body: CardTile(
            name: 'Копилка',
            account: Account(name: 'Копилка', currency: 'MDL', icon: 'savings'),
            amount: 100,
            currency: 'MDL',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final icons = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
      expect(icons, contains(iconChoices['savings']));
      expect(icons, isNot(contains(Myna.creditCard)));
    });

    testWidgets('без своего значка он подбирается по имени', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: const Scaffold(
          body: CardTile(
            name: 'Наличные',
            account: null,
            amount: 100,
            currency: 'MDL',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final icons = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
      expect(icons, contains(accountIcon('Наличные')));
    });
  });

  group('значок счёта', () {
    test('ряды в выборе ровные и знаки не повторяются', () {
      expect(accountIconChoices.length % 6, 0,
          reason: 'сетка по шесть: неполный ряд читается поломкой');
      expect(accountIconChoices.values.toSet().length,
          accountIconChoices.length,
          reason: 'два одинаковых знака подряд выглядят промахом');
    });

    testWidgets('выбранный значок доезжает до базы', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAccountSheet(context,
                  store: store, name: 'Моя копилка'),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      final cell = find.byIcon(accountIconChoices['crypto']!);
      await tester.scrollUntilVisible(cell, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(cell);
      await tester.pumpAndSettle();

      final save = find.text(tr('accountSave'));
      await tester.scrollUntilVisible(save, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final acc = store.db.accounts.firstWhere((a) => a.name == 'Моя копилка');
      expect(acc.icon, 'crypto');
      expect(store.outbox, contains('acc:Моя копилка'));
    });

    test('снятый значок не возвращается из старой записи', () {
      // `icon ?? this.icon` оставлял бы прежний знак навсегда: null значит и
      // «не меняем», и «убрать». Разводит их флаг.
      final store = storeOf();
      store.editAccount('Моя копилка', icon: 'crypto');
      expect(store.db.accounts
          .firstWhere((a) => a.name == 'Моя копилка').icon, 'crypto');
      store.editAccount('Моя копилка', clearIcon: true);
      expect(store.db.accounts
          .firstWhere((a) => a.name == 'Моя копилка').icon, isNull);
    });
  });

  group('фактура карты', () {
    test('доживает до диска и обратно', () {
      const acc = Account(name: 'Карта maib', currency: 'MDL',
          texture: CardTexture.guilloche);
      expect(Account.fromJson(acc.toJson()).texture, CardTexture.guilloche);
      // Умолчание в json не пишется: у заведённых раньше счетов поля нет, и
      // читаться они обязаны как «имя повторами».
      const plain = Account(name: 'Наличные', currency: 'MDL');
      expect(plain.toJson().containsKey('texture'), isFalse);
      expect(Account.fromJson(const {'name': 'Наличные'}).texture,
          CardTexture.watermark);
    });

    test('незнакомое слово с сервера читается как имя повторами', () {
      // Клиент новее сервера или наоборот — вид не должен пропадать в пустоту.
      expect(cardTextureOf('плед'), CardTexture.watermark);
      expect(cardTextureOf(null), CardTexture.watermark);
      expect(cardTextureOf('stripes'), CardTexture.stripes);
    });

    test('уезжает на сервер и приезжает обратно', () {
      final store = storeOf();
      store.editAccount('Моя копилка', texture: CardTexture.stripes);
      expect(store.outbox, contains('acc:Моя копилка'));
      expect(
        store.db.accounts
            .firstWhere((a) => a.name == 'Моя копилка')
            .texture,
        CardTexture.stripes,
      );

      store.clearOutbox(store.outbox.toSet());
      store.applyRemote({
        'now': 4,
        'accounts': [
          {'name': 'Карта партнёра', 'currency': 'MDL', 'texture': 'guilloche'},
        ],
      });
      expect(
        store.db.accounts
            .firstWhere((a) => a.name == 'Карта партнёра')
            .texture,
        CardTexture.guilloche,
      );
    });

    testWidgets('выбор в листе доезжает до базы', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAccountSheet(context,
                  store: store, name: 'Моя копилка'),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      // Ключ, а не слово: подпись переводится, а образец должен находиться на
      // любом языке. И ensureVisible обязателен — список строит лениво, а
      // кнопка «Сохранить» прибита к низу и перекрывает нижний образец.
      const choice = ValueKey('texture-stripes');
      await tester.scrollUntilVisible(find.byKey(choice), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(choice));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(choice));
      await tester.pumpAndSettle();

      final save = find.text(tr('accountSave'));
      await tester.scrollUntilVisible(save, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        store.db.accounts.firstWhere((a) => a.name == 'Моя копилка').texture,
        CardTexture.stripes,
      );
    });
  });

  group('экран счёта', () {
    testWidgets('клавиатура на входе не лезет', (tester) async {
      // Автофокус на имени поднимал клавиатуру и закрывал ею карту с формой:
      // человек пришёл настроить счёт, а не переименовать его.
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAccountSheet(context,
                  store: store, name: 'Моя копилка'),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields, isNotEmpty);
      expect(fields.every((f) => f.autofocus == false), isTrue);
      expect(
        tester.binding.testTextInput.isVisible,
        isFalse,
        reason: 'клавиатура поднимается, когда человек сам коснётся поля',
      );
    });
  });
}
