import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import 'session.dart';

/// Разбор месяца от модели.
///
/// Единственная платная функция, которая приходит к человеку САМА: первого
/// числа сервер считает текст и шлёт пуш. Приложение только показывает
/// готовое — считать разбор в момент открытия значило бы держать человека
/// перед крутящимся кружком минуту.
class MonthReview {
  const MonthReview({
    required this.month,
    required this.text,
    required this.created,
  });

  /// Разобранный месяц, «ГГГГ-ММ».
  final String month;
  final String text;
  final int created;

  bool get isEmpty => text.trim().isEmpty;
}

class ReviewService extends ChangeNotifier {
  ReviewService({required this.session});

  final Session session;

  MonthReview? _review;
  bool _busy = false;

  /// Почему разбора нет. Пусто — всё в порядке либо ещё не спрашивали.
  String _problem = '';

  MonthReview? get review => _review;
  bool get busy => _busy;
  String get problem => _problem;

  /// Нужна ли подписка: сервер ответил 402.
  bool needPlus = false;

  /// Закрытый месяц: тот, что был до сегодняшнего дня.
  static String previousMonth([DateTime? now]) {
    final at = now ?? DateTime.now();
    final before = DateTime(at.year, at.month - 1);
    return '${before.year}-${before.month.toString().padLeft(2, '0')}';
  }

  Future<void> load(String groupId, {String? month}) async {
    if (!session.signedIn || _busy) return;
    _busy = true;
    _problem = '';
    notifyListeners();
    try {
      final target = month ?? previousMonth();
      final r = await session.get(
        '/api/money/review?group_id=$groupId&month=$target',
        // Разбора может не быть вовсе — тогда сервер пишет его прямо сейчас,
        // и это минута работы модели.
        timeout: const Duration(seconds: 90),
      );
      _review = MonthReview(
        month: '${r['month'] ?? target}',
        text: '${r['text'] ?? ''}',
        created: (r['created'] as num?)?.toInt() ?? 0,
      );
      needPlus = false;
    } on SessionError catch (e) {
      needPlus = e.needPlus;
      _problem = e.needPlus ? tr('monthReviewNeedPlus') : e.message;
    } catch (_) {
      _problem = tr('monthReviewFailed');
    }
    _busy = false;
    notifyListeners();
  }
}
