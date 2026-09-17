import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../services/invite.dart';
import '../services/invite_code.dart';
import '../services/session.dart';
import '../ui/theme/tm_scheme.dart';
import '../ui/theme/tm_text.dart';
import '../ui/theme/tm_tokens.dart';
import '../ui/widgets/tm_primitives.dart';
import '../widgets/invite_qr.dart';

/// Как позвать второго. Три пути к одному коду: продиктовать, отправить
/// ссылку, показать QR. Четвёртый путь — ввести код партнёра.
class PairScreen extends StatefulWidget {
  const PairScreen({
    super.key,
    required this.session,
    required this.store,
    this.demoCode,
  });

  final Session session;
  final Store store;

  /// Код для съёмки витрины: экран рисует то же, что увидит человек, но
  /// сервер за ним не спрашивается. В приложении не используется.
  final String? demoCode;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  late final Invite _invite = Invite(widget.session);
  final _input = TextEditingController();

  String _code = '';
  bool _busy = false;
  bool _showQr = false;
  String? _error;
  String? _done;

  @override
  void initState() {
    super.initState();
    // Код выпускает сервер и только вошедшему. Без аккаунта экран честно
    // говорит об этом, а не отдаёт ошибку входа на ровном месте.
    if (widget.demoCode != null) {
      _code = widget.demoCode!;
    } else if (widget.session.signedIn) {
      _issue();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() => _busy = true);
    try {
      final code = await _invite.issue(
        groupId: widget.store.db.pair.groupId,
        oldCode: _code,
      );
      if (mounted) setState(() => _code = code);
    } on SessionError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    final code = normalizeInviteCode(_input.text);
    if (code.isEmpty) {
      setState(() => _error = tr('pairEnterCode'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });

    final r = await _invite.accept(code);
    if (!mounted) return;

    if (!r.ok) {
      setState(() {
        _busy = false;
        _error = r.message;
      });
      return;
    }

    // Состав пары берём с сервера, а не оставляем прежний: сразу после
    // приёма кода участники ещё не загружены, и экран говорил «пары нет»
    // при собравшейся паре (поймано на живом эмуляторе).
    Pair pair = Pair(
      groupId: r.pairId,
      members: widget.store.db.pair.members,
      baseCurrency: widget.store.db.baseCurrency,
    );
    try {
      final loaded = await widget.session.loadPair();
      if (loaded != null && loaded.groupId.isNotEmpty) pair = loaded;
    } catch (_) {
      // Состав догонит следующим кругом синхронизации.
    }
    widget.store.setPair(pair);
    setState(() {
      _busy = false;
      _done = r.restored ? tr('pairBack') : tr('pairDone');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final link = _code.isEmpty ? '' : Invite.linkFor(_code);

    return Scaffold(
      appBar: AppBar(title: Text(tr('pairInviteTitle')), leading: BackButton()),
      body: ListView(
        padding: EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          Text(
            widget.session.signedIn
                ? tr('pairHow')
                : tr('pairNeedAccount'),
            style: TmText.body(tm.textAlpha(0.65)),
          ),
          const SizedBox(height: TmSpace.xl),

          Container(
            padding: EdgeInsets.all(TmSpace.xl),
            decoration: BoxDecoration(
              color: tm.sharedFill,
              borderRadius: BorderRadius.circular(TmRadius.card),
            ),
            child: Column(children: [
              Text(tr('pairYourCode'), style: TmText.label(context.tm.onAccent)),
              const SizedBox(height: TmSpace.m),
              // Код набирают с голоса и переписывают глазами, поэтому он
              // крупный и с разрядкой: в алфавите нет ни I, ни O, ни нуля.
              SelectableText(
                _code.isEmpty ? '••••••' : _code,
                style: TmText.balanceXxl(context.tm.onAccent).copyWith(letterSpacing: 6),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: TmSpace.l),
              Row(spacing: TmSpace.s, children: [
                Expanded(
                  child: TmButton(
                    label: tr('pairCopy'),
                    variant: TmButtonVariant.ink,
                    expand: true,
                    onPressed: _code.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: _code));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(tr('pairCodeCopied'))),
                              );
                            }
                          },
                  ),
                ),
                Expanded(
                  child: TmButton(
                    label: tr('pairSend'),
                    variant: TmButtonVariant.outline,
                    expand: true,
                    onPressed: _code.isEmpty
                        ? null
                        : () => Share.share(
                              trf('pairShareText', [_code, link]),
                            ),
                  ),
                ),
              ]),
            ]),
          ),

          SizedBox(height: TmSpace.m),
          TmButton(
            label: _showQr ? tr('pairHideQr') : tr('pairShowQr'),
            variant: TmButtonVariant.quiet,
            expand: true,
            onPressed: _code.isEmpty ? null : () => setState(() => _showQr = !_showQr),
          ),
          if (_showQr && _code.isNotEmpty) ...[
            const SizedBox(height: TmSpace.l),
            Center(child: InviteQr(data: link, size: 240)),
            SizedBox(height: TmSpace.s),
            Text(tr('pairQrNote'),
                style: TmText.meta(tm.textAlpha(0.55)), textAlign: TextAlign.center),
          ],

          SizedBox(height: TmSpace.s),
          TextButton(
            onPressed: _busy ? null : _issue,
            child: Text(tr('pairNewCode'),
                style: TmText.label(tm.dark ? context.tm.accent : context.tm.text)),
          ),

          const SizedBox(height: TmSpace.xxl),
          TmGroupLabel(tr('pairHaveCode')),
          const SizedBox(height: TmSpace.m),
          TextField(
            controller: _input,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(hintText: tr('pairCodeField')),
            onSubmitted: (_) => _accept(),
          ),
          SizedBox(height: TmSpace.m),
          TmButton(
            label: _busy ? tr('pairWait') : tr('pairAccept'),
            size: TmButtonSize.large,
            expand: true,
            onPressed: _busy ? null : _accept,
          ),

          if (_error != null) ...[
            const SizedBox(height: TmSpace.m),
            _banner(_error!, context.tm.field, context.tm.expense),
          ],
          if (_done != null) ...[
            const SizedBox(height: TmSpace.m),
            _banner(_done!, context.tm.field, context.tm.onAccent),
          ],

          SizedBox(height: TmSpace.xl),
          Text(
            tr('pairCodeLives'),
            style: TmText.meta(tm.textAlpha(0.55)),
          ),
        ],
      ),
    );
  }

  Widget _banner(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(TmRadius.field)),
        child: Text(text, style: TmText.label(fg)),
      );
}
