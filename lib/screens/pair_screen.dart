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
import '../widgets/animated_invite_code.dart';
import '../design/myna.dart';
import '../widgets/invite_qr.dart';
import '../widgets/member_badge.dart';
import '../widgets/motion.dart';
import '../logic/haptics.dart';

/// Как позвать второго. Три пути к одному коду: продиктовать, отправить
/// ссылку, показать QR. Четвёртый путь — ввести код партнёра.
class PairScreen extends StatefulWidget {
  const PairScreen({
    super.key,
    required this.session,
    required this.store,
    this.demoCode,
    this.initialCode,
  });

  final Session session;
  final Store store;

  /// Код для съёмки витрины: экран рисует то же, что увидит человек, но
  /// сервер за ним не спрашивается. В приложении не используется.
  final String? demoCode;

  /// Код партнёра из ссылки-приглашения (`togetherlywallet://invite/CODE`):
  /// экран подставляет его в поле и сразу принимает, если человек вошёл.
  final String? initialCode;

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

  /// Растёт на каждый отказ приёма: поле с кодом встряхивается.
  int _shake = 0;

  @override
  void initState() {
    super.initState();
    // Код выпускает сервер и только вошедшему. Без аккаунта экран честно
    // говорит об этом, а не отдаёт ошибку входа на ровном месте.
    if (widget.demoCode != null) {
      _code = widget.demoCode!;
    } else if (widget.session.signedIn) {
      _load();
    }
    final incoming = normalizeInviteCode(widget.initialCode);
    if (incoming.isNotEmpty) {
      _input.text = incoming;
      if (widget.session.signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _accept();
        });
      }
    }
  }

  String? get _group =>
      inviteGroupFor(widget.store.db.pair, widget.session.uid);

  /// Свой прежний код, а если его нет — новый. Экран открывают много раз, и
  /// ссылка, уже отправленная партнёру, должна совпадать с кодом на экране.
  Future<void> _load() async {
    setState(() => _busy = true);
    final have = await _invite.current(groupId: _group);
    if (!mounted) return;
    if (have != null) {
      setState(() {
        _code = have;
        _busy = false;
      });
      return;
    }
    await _issue();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _issue() async {
    setState(() => _busy = true);
    try {
      final code = await _invite.issue(groupId: _group, oldCode: _code);
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
      Tap.warn();
      setState(() {
        _busy = false;
        _error = r.message;
        _shake++;
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
    Tap.cheer();
    setState(() {
      _busy = false;
      _done = r.restored ? tr('pairBack') : tr('pairDone');
    });
  }

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final link = _code.isEmpty ? '' : Invite.linkFor(_code);
    final still = Motion.still(context);

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
              // Буквы — цвет текста, а не onAccent: карточка лежит на поле, и
              // onAccent давал белое по светлому и чёрное по тёмному — код на
              // экране было не прочесть (снимок 18.09.2026).
              Text(tr('pairYourCode'), style: TmText.label(tm.textAlpha(0.65))),
              const SizedBox(height: TmSpace.m),
              // Код набирают с голоса и переписывают глазами, поэтому он
              // крупный: в алфавите нет ни I, ни O, ни нуля. Появляется
              // «дешифратором», как в Togetherly: пока код грузится, позиции
              // бегут, пришёл — садятся по очереди. Без кода и без загрузки
              // (человек не вошёл) стоят точки.
              if (_code.isEmpty && !_busy)
                Text('••••••',
                    style: TmText.balanceXxl(tm.textAlpha(0.35)).copyWith(letterSpacing: 6),
                    textAlign: TextAlign.center)
              else
                AnimatedInviteCode(
                  code: _code,
                  loading: _busy && _code.isEmpty,
                  style: TmText.balanceXxl(tm.text).copyWith(fontSize: 44),
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
          // QR раскрывается и сворачивается по высоте, а не выпрыгивает:
          // под ним кнопки и поле, и они уезжали за кадр.
          AnimatedSize(
            duration: still ? Duration.zero : Motion.layout,
            curve: Motion.move,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : Motion.state,
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.exit,
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(a),
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: _showQr && _code.isNotEmpty
                  ? Column(key: const ValueKey('qr'), children: [
                      const SizedBox(height: TmSpace.l),
                      Center(child: InviteQr(data: link, size: 240)),
                      SizedBox(height: TmSpace.s),
                      Text(tr('pairQrNote'),
                          style: TmText.meta(tm.textAlpha(0.55)), textAlign: TextAlign.center),
                    ])
                  : const SizedBox(key: ValueKey('no-qr'), width: double.infinity),
            ),
          ),

          SizedBox(height: TmSpace.s),
          TextButton(
            onPressed: _busy ? null : _issue,
            child: Text(tr('pairNewCode'),
                style: TmText.label(tm.dark ? context.tm.accent : context.tm.text)),
          ),

          const SizedBox(height: TmSpace.xxl),
          TmGroupLabel(tr('pairHaveCode')),
          const SizedBox(height: TmSpace.m),
          Shake(
            trigger: _shake,
            child: TextField(
            controller: _input,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(hintText: tr('pairCodeField')),
            onSubmitted: (_) => _accept(),
          ),
          ),
          SizedBox(height: TmSpace.m),
          TmButton(
            label: _busy ? tr('pairWait') : tr('pairAccept'),
            size: TmButtonSize.large,
            expand: true,
            onPressed: _busy ? null : _accept,
          ),

          // Ответ на «Принять код» проявляется, а не выскакивает. Успех —
          // отдельный момент: две аватарки сходятся, и ставится галочка.
          AnimatedSize(
            duration: still ? Duration.zero : Motion.layout,
            curve: Motion.move,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : Motion.state,
              switchInCurve: Motion.enter,
              switchOutCurve: Motion.exit,
              child: _done != null
                  ? Padding(
                      key: const ValueKey('done'),
                      padding: const EdgeInsets.only(top: TmSpace.l),
                      child: PairedMoment(
                        pair: widget.store.db.pair,
                        me: widget.session.uid,
                        text: _done!,
                      ),
                    )
                  : _error != null
                      ? Padding(
                          key: ValueKey('error-$_shake'),
                          padding: const EdgeInsets.only(top: TmSpace.m),
                          child: _banner(_error!, context.tm.field, context.tm.expense),
                        )
                      : const SizedBox(key: ValueKey('none'), width: double.infinity),
            ),
          ),

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

/// Пара собрана: две аватарки съезжаются из краёв и встают внахлёст, на
/// стыке появляется галочка, под ними — слова. Раньше на этом месте была
/// строка текста, и событие, ради которого открывают экран, проходило
/// незамеченным.
class PairedMoment extends StatefulWidget {
  const PairedMoment({
    super.key,
    required this.pair,
    required this.me,
    required this.text,
  });

  final Pair pair;
  final String me;
  final String text;

  @override
  State<PairedMoment> createState() => _PairedMomentState();
}

class _PairedMomentState extends State<PairedMoment> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.still(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    const size = 56.0;
    final me = widget.pair.byUid(widget.me) ?? Member(uid: widget.me, name: '');
    final other = widget.pair.other(widget.me);

    final meet = CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Motion.move));
    final appear = CurvedAnimation(parent: _c, curve: const Interval(0, 0.3, curve: Curves.easeOut));
    final tick = CurvedAnimation(parent: _c, curve: const Interval(0.45, 0.8, curve: Motion.enter));
    final words = CurvedAnimation(parent: _c, curve: const Interval(0.5, 1, curve: Motion.enter));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: TmSpace.xl, horizontal: TmSpace.l),
      decoration: BoxDecoration(
        color: tm.field,
        borderRadius: BorderRadius.circular(TmRadius.card),
      ),
      child: Column(children: [
        SizedBox(
          height: size + 8,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              // Из 64 точек от центра — к 20: аватарки заходят друг на друга.
              final gap = 64 - 44 * meet.value;
              return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                Transform.translate(
                  offset: Offset(-gap, 0),
                  child: Opacity(
                    opacity: appear.value,
                    child: _ring(context, MemberBadge(member: me, size: size, showName: false)),
                  ),
                ),
                Transform.translate(
                  offset: Offset(gap, 0),
                  child: Opacity(
                    opacity: appear.value,
                    child: _ring(context, MemberBadge(member: other, size: size, showName: false)),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, size / 2 - 4),
                  child: Opacity(
                    opacity: tick.value,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * tick.value,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: tm.text,
                          shape: BoxShape.circle,
                          border: Border.all(color: tm.field, width: 3),
                        ),
                        child: Icon(Myna.check, size: 15, color: tm.field),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: TmSpace.l),
        FadeTransition(
          opacity: words,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(words),
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TmText.label(tm.text),
            ),
          ),
        ),
      ]),
    );
  }

  /// Кольцо цвета карточки вокруг аватарки: на нахлёсте видно, где кончается
  /// одна и начинается другая.
  Widget _ring(BuildContext context, Widget child) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: context.tm.field, shape: BoxShape.circle),
        child: child,
      );
}
