import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/chat_log.dart';

Directory tempDir() =>
    Directory.systemTemp.createTempSync('money-chat-');

ChatTurn mine(String text, {int at = 0}) =>
    ChatTurn(mine: true, text: text, at: at);

ChatTurn theirs(String text, {int at = 0, List<String> done = const []}) =>
    ChatTurn(mine: false, text: text, at: at, done: done);

void main() {
  group('память чата', () {
    test('переписка переживает выход из приложения', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal', mine('Сколько я трачу на еду?'));
      log.add('g1', 'personal', theirs('4 210 MDL в месяц'));
      await log.flush();

      final again = ChatLog();
      await again.load(home);
      expect(again.of('g1', 'personal').length, 2);
      expect(again.of('g1', 'personal').last.text, '4 210 MDL в месяц');
    });

    test('личный и общий чат не смешиваются', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal', mine('Что с моей картой?'));
      log.add('g1', 'shared', mine('Сколько мы тратим вдвоём?'));

      expect(log.of('g1', 'personal').single.text, 'Что с моей картой?');
      expect(log.of('g1', 'shared').single.text, 'Сколько мы тратим вдвоём?');
    });

    test('у каждой пары своя переписка', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g_anya', 'personal', mine('Про Аню'));
      log.add('g_kirill', 'personal', mine('Про Кирилла'));

      expect(log.of('g_anya', 'personal').single.text, 'Про Аню');
      expect(log.of('g_kirill', 'personal').single.text, 'Про Кирилла');
    });

    test('модели уходят последние реплики, а не вся переписка', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      for (var i = 0; i < 30; i++) {
        log.add('g1', 'personal', mine('Вопрос $i', at: i));
      }

      final history = log.historyFor('g1', 'personal');
      expect(history.length, lessThanOrEqualTo(10));
      expect(history.last['text'], 'Вопрос 29', reason: 'свежая реплика последняя');
      expect(history.first['text'], isNot('Вопрос 0'));
    });

    test('простыня режется, а не уезжает в модель целиком', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      for (var i = 0; i < 10; i++) {
        log.add('g1', 'personal', mine('А' * 5000, at: i));
      }

      final history = log.historyFor('g1', 'personal');
      final total = history.fold<int>(0, (sum, m) => sum + m['text']!.length);
      expect(total, lessThanOrEqualTo(6000),
          reason: 'контекст модели не резиновый, и платим за него мы');
      for (final m in history) {
        expect(m['text']!.length, lessThanOrEqualTo(1000));
      }
    });

    test('роли расставлены: мой вопрос и ответ чата', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal', mine('Сколько?'));
      log.add('g1', 'personal', theirs('Много'));

      final history = log.historyFor('g1', 'personal');
      expect(history.first['role'], 'user');
      expect(history.last['role'], 'assistant');
    });

    test('сделанное уходит в историю: чат помнит, что записал', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal', mine('Я потратил 150 на чипсы'));
      log.add(
        'g1',
        'personal',
        theirs('Записал', done: ['Расход MDL 150,00 · Продукты · Карта']),
      );

      final history = log.historyFor('g1', 'personal');
      expect(history.last['text'], contains('Расход MDL 150,00'));
    });

    test('вложение без слов остаётся в памяти именем файла', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal',
          ChatTurn(mine: true, text: '', at: 1, files: const ['чек.pdf']));

      expect(log.historyFor('g1', 'personal').single['text'], contains('чек.pdf'));
    });

    test('файл не растёт без предела', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      for (var i = 0; i < 300; i++) {
        log.add('g1', 'personal', mine('Вопрос $i', at: i));
      }
      await log.flush();

      final again = ChatLog();
      await again.load(home);
      expect(again.of('g1', 'personal').length, 200);
      expect(again.of('g1', 'personal').first.text, 'Вопрос 100',
          reason: 'старое уходит первым');
    });

    test('очистка стирает только свою ветку', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal', mine('Личное'));
      log.add('g1', 'shared', mine('Общее'));
      log.clear('g1', 'personal');

      expect(log.of('g1', 'personal'), isEmpty);
      expect(log.of('g1', 'shared'), isNotEmpty);
    });

    test('стирание данных уносит переписку с телефона', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));

      final log = ChatLog();
      await log.load(home);
      log.add('g1', 'personal', mine('Сколько на карте?'));
      await log.flush();
      expect(File('${home.path}/chat.json').existsSync(), isTrue);

      await ChatLog.forgetAll(home);
      expect(File('${home.path}/chat.json').existsSync(), isFalse);

      final again = ChatLog();
      await again.load(home);
      expect(again.of('g1', 'personal'), isEmpty);
    });

    test('битый файл не роняет запуск', () async {
      final home = tempDir();
      addTearDown(() => home.deleteSync(recursive: true));
      File('${home.path}/chat.json').writeAsStringSync('{это не json');

      final log = ChatLog();
      await log.load(home);
      expect(log.of('g1', 'personal'), isEmpty);

      log.add('g1', 'personal', mine('Первый вопрос после беды'));
      await log.flush();
      expect(log.of('g1', 'personal').length, 1);
    });
  });
}
