import 'dart:io';

import '../data/store.dart';

/// Копии базы на устройстве.
///
/// Ручная копия («Сохранить копию») спасает от потери телефона, но её надо не
/// забыть сделать. Автокопия делается сама раз в сутки при запуске: человек о
/// ней не думает, а когда «всё пропало» — она есть.
///
/// Копии лежат рядом с базой в подпапке `backups`, семь последних. Больше
/// незачем: база это несколько сотен килобайт, а старее недели копия уже
/// бесполезна — за неделю человек заметит пропажу.
const _keep = 7;

String _stamp(DateTime at) =>
    '${at.year}-${at.month.toString().padLeft(2, '0')}-'
    '${at.day.toString().padLeft(2, '0')}';

/// Папка копий. Создаётся сама: отдельной кнопки «включить» нет.
Future<Directory> backupsDir(Directory home) async {
  final dir = Directory('${home.path}/backups');
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir;
}

/// Копии от свежей к старой.
List<File> backupsIn(Directory dir) {
  if (!dir.existsSync()) return const [];
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  return files;
}

/// Пора ли делать копию: раз в сутки, и не дважды в один день.
Future<bool> dueForBackup(Directory dir, {DateTime? at}) async {
  final today = _stamp(at ?? DateTime.now());
  return !backupsIn(dir).any((f) => f.path.contains(today));
}

/// Записать копию. Пустую базу не сохраняем: восстанавливать из неё нечего,
/// а место в списке она займёт.
Future<File?> writeBackup(Store store, Directory dir, {DateTime? at}) async {
  final db = store.db;
  if (db.transactions.isEmpty && db.accounts.isEmpty) return null;
  if (!dir.existsSync()) await dir.create(recursive: true);

  final file = File('${dir.path}/money-${_stamp(at ?? DateTime.now())}.json');
  await file.writeAsString(store.exportJson(), flush: true);

  // Лишние уходят сразу: иначе папка растёт годами, а смотрит в неё человек
  // раз в жизни.
  final all = backupsIn(dir);
  for (final old in all.skip(_keep)) {
    try {
      await old.delete();
    } catch (_) {
      // Файл мог исчезнуть сам: это не беда, ради которой стоит шуметь.
    }
  }
  return file;
}
