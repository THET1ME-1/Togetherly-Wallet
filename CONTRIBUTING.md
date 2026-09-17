# Contributing / Как участвовать

**English.** Pull requests are welcome. Before you open one:

1. `flutter analyze` says nothing and `flutter test` is green.
2. New logic comes with a test. Calculations live in `lib/logic` as pure
   functions precisely so they can be tested without a screen.
3. New user-facing text goes into `lib/l10n/dict/*.dart` with at least `ru` and
   `en`. A duplicate key across two dictionary files crashes the app at the
   first `tr()`, and CI checks for that.
4. Design rules are enforced by `test/design_rules_test.dart`: no shadows, no
   centred dialogs, no `labelText`. If your change fails it, change the design,
   not the test.
5. Screen layouts are checked at 320 dp with a 1.3 text scale. Phones that
   small still exist, and so do people who enlarge type.

**По-русски.** Правки принимаются. Перед тем как их прислать:

1. `flutter analyze` молчит, `flutter test` зелёный.
2. Новая логика приходит с тестом. Расчёты лежат в `lib/logic` чистыми
   функциями ровно для того, чтобы их можно было проверить без экрана.
3. Новые надписи заводятся в `lib/l10n/dict/*.dart` минимум на `ru` и `en`.
   Одинаковый ключ в двух словарях валит приложение на первом же `tr()` —
   это проверяет CI.
4. Правила оформления стережёт `test/design_rules_test.dart`: теней нет,
   диалогов по центру нет, `labelText` нет. Если правка его роняет, менять
   надо правку, а не тест.
5. Раскладка проверяется на 320 dp при шрифте 1.3. Такие телефоны ещё живы, а
   люди с увеличенным шрифтом — тем более.
