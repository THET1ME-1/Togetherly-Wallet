import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/backup.dart';

Database sample(int count) => Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      transactions: [
        for (var i = 0; i < count; i++)
          Transaction(
            id: 't$i',
            date: '2026-09-${(1 + i % 28).toString().padLeft(2, '0')}',
            kind: TxKind.expense,
            account: 'Карта',
            currency: 'MDL',
            amount: -(10 + i).toDouble(),
            amountBase: -(10 + i).toDouble(),
            author: 'u_me',
            payer: 'u_me',
          ),
      ],
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tm-backup');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  group('автокопии', () {
    test('копия пишется файлом и читается обратно', () async {
      final store = Store()..importBackupForTest(sample(3));
      final file = await writeBackup(store, dir, at: DateTime(2026, 9, 13));

      expect(file, isNotNull);
      expect(file!.existsSync(), isTrue);
      expect(file.path, contains('2026-09-13'));

      final back = Store()..importBackupForTest(const Database());
      final count = back.importBackup(await file.readAsString());
      expect(count, 3);
      expect(back.db.transactions.length, 3);
    });

    test('храним семь последних, старые уходят', () async {
      final store = Store()..importBackupForTest(sample(1));
      for (var day = 1; day <= 10; day++) {
        await writeBackup(store, dir, at: DateTime(2026, 9, day));
      }
      final left = backupsIn(dir);
      expect(left.length, 7);
      // Самая свежая — первой: человек ищет вчерашнюю, а не позапрошлогоднюю.
      expect(left.first.path, contains('2026-09-10'));
      expect(left.last.path, contains('2026-09-04'));
    });

    test('копия за сегодня не переписывается второй раз', () async {
      final store = Store()..importBackupForTest(sample(1));
      final at = DateTime(2026, 9, 13);
      expect(await dueForBackup(dir, at: at), isTrue);
      await writeBackup(store, dir, at: at);
      expect(await dueForBackup(dir, at: at), isFalse,
          reason: 'дважды в день копия не нужна');
      expect(await dueForBackup(dir, at: DateTime(2026, 9, 14)), isTrue);
    });

    test('пустую базу не сохраняем: незачем', () async {
      final store = Store()..importBackupForTest(const Database());
      final file = await writeBackup(store, dir, at: DateTime(2026, 9, 13));
      expect(file, isNull);
      expect(backupsIn(dir), isEmpty);
    });

    test('битый файл не рушит восстановление', () {
      final store = Store()..importBackupForTest(sample(2));
      expect(store.importBackup('{это не json'), 0);
      expect(store.importBackup(jsonEncode({'format': 'чужой'})), 0);
      expect(store.db.transactions.length, 2, reason: 'своё осталось на месте');
    });
  });
}
