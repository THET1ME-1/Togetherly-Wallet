import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/money.dart';
import 'member_badge.dart';
import 'money_text.dart';
import '../design/myna.dart';
import 'motion.dart';

/// Разговор под операцией.
///
/// Половина ссор о деньгах начинается с непонятного списания. Вопрос задаётся
/// здесь, рядом с суммой и датой, а не в мессенджере, где через неделю никто
/// не помнит, о какой именно трате шла речь.
Future<void> showComments(BuildContext context, Store store, Transaction op) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _CommentsSheet(store: store, op: op),
    );

/// Четыре отклика без слов: их ставят в одно касание, и на них уходит
/// большинство вопросов вроде «понял».
const _quick = ['👍', '❓', '🙏', '❤️'];

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.store, required this.op});

  final Store store;
  final Transaction op;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  bool _hasText = false;

  /// Реплики, которые уже были на экране: при открытии история стоит, а
  /// выплывает только новая — своя или пришедшая от партнёра.
  final _seen = <Object>{};

  @override
  void initState() {
    super.initState();
    _seen.addAll(widget.store.commentsOf(widget.op.id).map((c) => c.id));
    _input.addListener(() {
      final now = _input.text.trim().isNotEmpty;
      if (now != _hasText) setState(() => _hasText = now);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send({String text = '', String emoji = ''}) {
    final store = widget.store;
    store.saveComment(Comment(
      id: 'cm-${DateTime.now().microsecondsSinceEpoch}',
      txId: widget.op.id,
      uid: store.viewer,
      text: text.trim(),
      emoji: emoji,
      created: DateTime.now().millisecondsSinceEpoch,
    ));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = widget.store;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final db = store.db;
        final said = store.commentsOf(widget.op.id);
        final inBase = convert(db, widget.op.amount, widget.op.currency);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // О чём разговор: сумма и дата стоят рядом со словами, иначе
            // реплика «а это что?» через неделю непонятна и автору.
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      (widget.op.category ?? '').trim().isEmpty
                          ? tr('noCategory')
                          : widget.op.category!,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 18,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.op.date} · ${widget.op.account}',
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                MoneyText(inBase,
                    currency: db.baseCurrency, size: 16, colored: true,
                    weight: FontWeight.w700),
              ]),
            ),
            Flexible(
              child: said.isEmpty
                  ? _Empty()
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      itemCount: said.length,
                      itemBuilder: (context, i) => Entry(
                        key: ValueKey(said[i].id),
                        group: _seen,
                        id: said[i].id,
                        grow: true,
                        child: _Bubble(
                          store: store,
                          comment: said[i],
                          onDelete: () => store.deleteComment(said[i].id),
                        ),
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(children: [
                for (final e in _quick) ...[
                  _QuickEmoji(emoji: e, onTap: () => _send(emoji: e)),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _send(text: v);
                      },
                      decoration: InputDecoration(hintText: tr('chatHint')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _hasText ? () => _send(text: _input.text) : null,
                    icon: const Icon(Myna.arrowUp),
                    style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 14, 28, 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Myna.chat, size: 34, color: scheme.onSurfaceVariant),
        SizedBox(height: 10),
        Text(
          tr('commentsEmpty'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.store, required this.comment, required this.onDelete});

  final Store store;
  final Comment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = comment.uid == store.viewer;
    final member = store.db.pair.byUid(comment.uid);
    final onlyEmoji = comment.text.trim().isEmpty && comment.emoji.isNotEmpty;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (store.db.pair.members.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: MemberBadge(member: member, isMe: mine),
              ),
            GestureDetector(
              // Свою реплику можно убрать долгим нажатием. Чужую — нельзя:
              // чужие слова не правит и не стирает никто, это стережёт и сервер.
              onLongPress: mine ? onDelete : null,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                ),
                padding: onlyEmoji
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  // Своя реплика — инверсия, как везде в системе. Пастель
                  // общего контура отменена вместе с «мята-лаванда», и
                  // `tm.field` остался цветом ЧУЖОГО пузыря: свои слова
                  // стояли белым по светло-серому.
                  color: mine ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 6),
                    bottomRight: Radius.circular(mine ? 6 : 18),
                  ),
                ),
                child: Text(
                  onlyEmoji ? comment.emoji : _withEmoji(comment),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: onlyEmoji ? 22 : 14.5,
                    height: onlyEmoji ? 1.1 : 1.4,
                    color: mine ? scheme.onSecondaryContainer : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _withEmoji(Comment c) =>
      c.emoji.isEmpty ? c.text : '${c.emoji} ${c.text}';
}

class _QuickEmoji extends StatelessWidget {
  const _QuickEmoji({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          constraints: const BoxConstraints(minWidth: 52, minHeight: 44),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
