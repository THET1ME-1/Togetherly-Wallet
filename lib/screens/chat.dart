import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/ask.dart';
import '../logic/period.dart';
import '../logic/query.dart';
import '../widgets/money_text.dart';
import 'ledger.dart';
import '../design/myna.dart';

/// Реплика разговора.
class Line {
  final String text;
  String? answer;
  QueryResult? found;
  bool waiting;
  Line(this.text, {this.answer, this.found, this.waiting = false});
}

/// Чат: спросить о деньгах словами. Под ответом лежат сами операции — слова о
/// деньгах без денег приходится перепроверять руками.
class ChatScreen extends StatefulWidget {
  final Store store;
  final void Function(Transaction op) onEdit;
  const ChatScreen({super.key, required this.store, required this.onEdit});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _lines = <Line>[];
  final _field = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final said = _field.text.trim();
    if (said.isEmpty) return;
    _field.clear();
    final line = Line(said, waiting: true);
    setState(() => _lines.add(line));
    _toBottom();

    final keys = widget.store.modelKeys;
    if (pickProvider(keys) == null) {
      setState(() {
        line.waiting = false;
        line.answer = tr('askNoKey');
      });
      return;
    }

    final today = iso(DateTime.now());
    final history = [
      for (final l in _lines)
        if (l.answer != null) Turn(l.text, l.answer!),
    ];
    final answer = await askAbout(keys, said, widget.store.db, today, history: history);
    if (!mounted) return;
    setState(() {
      line.waiting = false;
      line.answer = answer?.text ?? tr('askNoAnswer');
      line.found = answer?.result;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: AppTheme.emphasizedDecelerate,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('chatTitle'))),
      body: Column(
        children: [
          Expanded(
            child: _lines.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Myna.chatDots, size: 52, color: scheme.primary),
                          SizedBox(height: 20),
                          Text(
                            tr('chatExampleFood'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              letterSpacing: -0.4,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${tr('askWholeHistory')} '
                            '${tr('categoriesSeeOps')}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 14,
                              height: 1.4,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    itemCount: _lines.length,
                    itemBuilder: (context, i) => _Pair(
                      line: _lines[i],
                      store: widget.store,
                      onEdit: widget.onEdit,
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                6,
                14,
                8 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _field,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(fontFamily: AppTheme.bodyFont, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: tr('askInvite'),
                        hintStyle: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: scheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Кнопка гасит потерю фокуса: иначе поле теряет его, клавиатура
                  // уезжает, всё съезжает вниз и нажатие промахивается.
                  Listener(
                    onPointerDown: (_) {},
                    child: IconButton.filled(
                      onPressed: _send,
                      icon: const Icon(Myna.arrowUp),
                      iconSize: 22,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  final Line line;
  final Store store;
  final void Function(Transaction op) onEdit;

  const _Pair({required this.line, required this.store, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final found = line.found;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: BoxConstraints(maxWidth: width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Text(
              line.text,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ),
        if (line.waiting) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                tr('askThinking'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (line.answer != null) ...[
          const SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(maxWidth: width * 0.86),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              line.answer!,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                height: 1.45,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
        if (found != null && found.rows.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          found.title,
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      MoneyText(
                        found.total,
                        currency: store.db.baseCurrency,
                        size: 13.5,
                        colored: true,
                        sign: true,
                      ),
                    ],
                  ),
                ),
                for (final op in found.rows.take(8))
                  OperationRow(store: store, op: op, onTap: () => onEdit(op)),
                if (found.rows.length > 8)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 2),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        trf('andMoreRows', [found.rows.length - 8]),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
