import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/period.dart';
import '../logic/plus.dart';
import '../services/plus.dart';
import '../services/review.dart';
import '../services/session.dart';
import '../widgets/plus_gate.dart';

/// Разбор месяца от модели.
///
/// Экран читается, а не листается: это письмо про закрытый месяц, и всё, что
/// в нём есть, — заголовок с месяцем и текст. Числа модель берёт из сводки
/// сервера; выдумывать ей нечего, в сводке лежит только то, что человек
/// записал.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.store,
    required this.session,
    this.plus,
    this.month,
  });

  final Store store;
  final Session session;
  final PlusService? plus;
  final String? month;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewService _service = ReviewService(session: widget.session);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pair = widget.store.db.pair;
    final group = pair.groupId.isEmpty ? widget.session.uid : pair.groupId;
    await _service.load(group, month: widget.month);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final review = _service.review;
        final month = review?.month ?? widget.month ?? ReviewService.previousMonth();
        final at = DateTime.tryParse('$month-01') ?? DateTime.now();

        return Scaffold(
          appBar: AppBar(
            title: Text('${tr('monthReviewTitle')} · ${monthName(at.month)}'),
          ),
          body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                if (_service.busy) ...[
                  const SizedBox(height: 80),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Text(
                    tr('monthReviewWriting'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (_service.needPlus)
                  _Locked(
                    onOpen: () =>
                        askPlus(context, plus: widget.plus, gate: PlusGate.monthReview),
                  )
                else if (_service.problem.isNotEmpty)
                  _Message(text: _service.problem)
                else if (review == null || review.isEmpty)
                  _Message(text: tr('monthReviewEmpty'))
                else
                  // Текст модели — абзацами, кеглем письма, а не сноской:
                  // это единственное, ради чего экран открыт.
                  Text(
                    review.text,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15.5,
                      height: 1.55,
                      color: scheme.onSurface,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 14,
          height: 1.45,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Myna.sparkles, size: 27, color: scheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            tr('monthReviewNeedPlus'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('plusGateReview'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onOpen,
            child: Text(tr('plusGateOpen')),
          ),
        ],
      ),
    );
  }
}
