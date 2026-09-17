import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import 'tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Карта баланса. scope решает всё: общая — мятная, личная — лавандовая.
enum TmWalletScope { shared, personal, pot }

class TmBalanceCard extends StatelessWidget {
  const TmBalanceCard({
    super.key,
    required this.title,
    required this.amount,
    this.scope = TmWalletScope.pot,
    this.caption,
    this.deltaLabel,
    this.actions = const [],
    this.trailing,
    this.compactAmount = false,
  });

  final String title;
  final Money amount;
  final TmWalletScope scope;
  final String? caption;
  final String? deltaLabel;

  /// Кладутся в `Row` как есть. Растягивающийся элемент оборачивайте
  /// в `Expanded` на своей стороне — карта повторно его не оборачивает.
  final List<Widget> actions;
  final Widget? trailing;
  final bool compactAmount;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final bg = switch (scope) {
      TmWalletScope.shared || TmWalletScope.pot => tm.sharedFill,
      TmWalletScope.personal => tm.personalFill,
    };
    final fg = scope == TmWalletScope.personal ? context.tm.onAccent : context.tm.onAccent;

    return Container(
      padding: const EdgeInsets.all(TmSpace.xl),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(TmRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: TmColors.card.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(TmRadius.pill),
              ),
              child: Text(title,
                  style: TmText.label(fg), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
        if (caption != null) ...[
          const SizedBox(height: TmSpace.l),
          TmGroupLabel(caption!, color: fg.withValues(alpha: 0.7)),
        ],
        const SizedBox(height: TmSpace.s),
        // Сумма ужимается, а не режется: на 320 dp «128 640 ₽» с плашкой
        // прироста не помещался и уезжал за правый край.
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    amount.format(withSymbol: false),
                    style: compactAmount ? TmText.balanceXl(fg) : TmText.balanceXxl(fg),
                  ),
                  const SizedBox(width: 7),
                  Text(amount.symbol, style: TmText.titleDisplay(fg.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ),
          if (deltaLabel != null) ...[
            const SizedBox(width: TmSpace.s),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: TmColors.card.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(TmRadius.pill),
              ),
              child: Text(deltaLabel!, style: TmText.label(fg)),
            ),
          ],
        ]),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(spacing: 9, children: actions),
        ],
      ]),
    );
  }
}

/// Строка операции. Ключ дизайна: подпись «кто платил · как делим»
/// и вторая строка суммы «за кем сколько».
class TmTxRow extends StatelessWidget {
  const TmTxRow({
    super.key,
    required this.title,
    required this.amount,
    this.categoryColor = const Color(0xFFDCDCDC),
    this.categoryInitials = '',
    this.meta,
    this.debtNote,
    this.income = false,
    this.hidden = false,
    this.revealLabel,
    this.onTap,
  });

  final String title;
  final Money amount;
  final Color categoryColor;
  final String categoryInitials;
  final String? meta;
  final String? debtNote;
  final bool income;
  final bool hidden;
  final String? revealLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final bg = hidden ? tm.personalTint : tm.card;
    final amountColor = hidden
        ? tm.textAlpha(0.6)
        : (income ? tm.income : tm.text);

    // Material принимает ЛИБО shape, ЛИБО borderRadius: вместе они валят
    // ассерт material.dart:209, и экран встаёт красным в отладке.
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TmRadius.row),
        side: hidden ? BorderSide(color: context.tm.accent) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TmRadius.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hidden ? context.tm.field : categoryColor,
                borderRadius: BorderRadius.circular(13),
              ),
              child: hidden
                  ? Icon(Myna.lock, size: 17, color: context.tm.onAccent)
                  : Text(categoryInitials, style: TmText.rowTitle(TmColors.ink)),
            ),
            const SizedBox(width: TmSpace.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TmText.rowTitle(tm.text), overflow: TextOverflow.ellipsis),
                if (meta != null || revealLabel != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    revealLabel ?? meta!,
                    style: TmText.meta(revealLabel != null
                        ? (tm.dark ? const Color(0xFFC9B2FA) : context.tm.text)
                        : tm.textAlpha(0.6)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ]),
            ),
            const SizedBox(width: TmSpace.s),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                income ? amount.format(signed: true) : amount.format(),
                style: TmText.amountRow(amountColor),
              ),
              if (debtNote != null) ...[
                const SizedBox(height: 5),
                Text(debtNote!, style: TmText.meta(tm.textAlpha(0.55))),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Сальдо долга. Нигде не хранится — считается из журнала операций.
class TmBalanceDueCard extends StatelessWidget {
  const TmBalanceDueCard({super.key, required this.text, this.onSettle, this.label = 'Сальдо'});

  final String text;
  final String label;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return TmSurface(
      color: tm.card,
      radius: TmRadius.tile,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      border: BorderSide(color: tm.line),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TmText.meta(tm.textAlpha(0.6))),
            const SizedBox(height: 7),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TmText.titleDisplay(tm.text).copyWith(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ]),
        ),
        const SizedBox(width: TmSpace.m),
        GestureDetector(
          onTap: onSettle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: kTmMinTap,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: context.tm.accent, width: 1.5),
              borderRadius: BorderRadius.circular(TmRadius.pill),
            ),
            child: Text('Выровнять',
                style: TmText.label(tm.dark ? context.tm.accent : context.tm.text)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

/// Скрытая трата у автора: сумма и дата раскрытия, прогресс до даты.
class TmHiddenTxCard extends StatelessWidget {
  const TmHiddenTxCard({
    super.key,
    required this.amount,
    required this.note,
    required this.revealLabel,
    this.progress,
    this.progressNote,
  });

  final Money amount;
  final String note;
  final String revealLabel;
  final double? progress;
  final String? progressNote;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tm.personalTint,
        borderRadius: BorderRadius.circular(TmRadius.tile),
        border: Border.all(color: context.tm.accent),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.tm.field,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Myna.lock, size: 18, color: context.tm.onAccent),
          ),
          const SizedBox(width: TmSpace.m),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(note, style: TmText.rowTitle(tm.text), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(revealLabel,
                  style: TmText.meta(tm.dark ? const Color(0xFFC9B2FA) : context.tm.text)),
            ]),
          ),
          const SizedBox(width: TmSpace.s),
          Text(amount.format(), style: TmText.amount(tm.text)),
        ]),
        if (progress != null) ...[
          const SizedBox(height: TmSpace.l),
          ClipRRect(
            borderRadius: BorderRadius.circular(TmRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: tm.dark ? context.tm.field : const Color(0xFFE3DCF2),
              valueColor: AlwaysStoppedAnimation(context.tm.accent),
            ),
          ),
          if (progressNote != null) ...[
            const SizedBox(height: 10),
            Text(progressNote!, style: TmText.meta(tm.textAlpha(0.6))),
          ],
        ],
      ]),
    );
  }
}

/// Плавающая таблетка навигации. Активный раздел — мятный круг.
class TmTabBar extends StatelessWidget {
  const TmTabBar({super.key, required this.index, this.onChanged});

  final int index;
  final ValueChanged<int>? onChanged;

  static const _icons = [
    Myna.home,
    Myna.fileText,
    Myna.chartLine,
    Myna.flag,
    Myna.user,
  ];

  static const _labels = ['Главная', 'Операции', 'Отчёты', 'Цели', 'Профиль'];

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final bar = tm.dark ? context.tm.card : TmColors.ink;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(TmRadius.pill)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < _icons.length; i++)
          Semantics(
            button: true,
            selected: i == index,
            label: _labels[i],
            child: GestureDetector(
              onTap: () => onChanged?.call(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: kTmMinTap,
                height: kTmMinTap,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == index ? context.tm.accent : const Color(0x00000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[i],
                  size: 20,
                  // 55% белого давало 3.37:1 — ниже порога для мелкой графики.
                  color: i == index ? context.tm.onAccent : TmColors.card.withValues(alpha: 0.72),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Цифровая клавиатура суммы: 3×4, плоские клавиши.
class TmKeypad extends StatelessWidget {
  const TmKeypad({super.key, this.onKey});
  final ValueChanged<String>? onKey;

  static const _keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'];

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    // Высота клавиши считается от места, а не задаётся отношением сторон:
    // фиксированный childAspectRatio переполнял сетку на 320 dp.
    return LayoutBuilder(builder: (context, box) {
      final rowHeight = box.hasBoundedHeight
          ? ((box.maxHeight - 9 * 3) / 4).clamp(kTmMinTap, 96.0)
          : 56.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 4; r++) ...[
            if (r > 0) const SizedBox(height: 9),
            SizedBox(
              height: rowHeight,
              child: Row(spacing: 9, children: [
                for (var c = 0; c < 3; c++)
                  Expanded(child: _key(tm, _keys[r * 3 + c])),
              ]),
            ),
          ],
        ],
      );
    });
  }

  Widget _key(TmPalette tm, String k) => Material(
        color: (k == ',' || k == '⌫') ? tm.field : tm.card,
        borderRadius: BorderRadius.circular(TmRadius.field),
        child: InkWell(
          onTap: () => onKey?.call(k),
          borderRadius: BorderRadius.circular(TmRadius.field),
          child: Center(
            child: Text(
              k,
              style: TmText.titleDisplay(tm.text).copyWith(fontSize: 21, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      );
}

/// Договорённость: предложение со статусом, а не молчаливая настройка.
enum TmAgreementStatus { proposed, active, declined }

class TmAgreementCard extends StatelessWidget {
  const TmAgreementCard({
    super.key,
    required this.title,
    required this.status,
    this.author,
    this.authorInitial = 'Л',
    this.oldValue,
    this.newValue,
    this.note,
    this.onAccept,
    this.onDiscuss,
  });

  final String title;
  final TmAgreementStatus status;
  final String? author;
  final String authorInitial;
  final String? oldValue, newValue, note;
  final VoidCallback? onAccept, onDiscuss;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final proposed = status == TmAgreementStatus.proposed;
    return TmSurface(
      radius: proposed ? 26 : TmRadius.tile,
      padding: const EdgeInsets.all(TmSpace.xl),
      color: status == TmAgreementStatus.declined ? tm.row : tm.card,
      border: proposed
          ? BorderSide(color: context.tm.accent, width: 1.5)
          : BorderSide(color: status == TmAgreementStatus.declined ? tm.lineSoft : tm.line),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (author != null) ...[
          Row(children: [
            TmAvatar(initial: authorInitial, color: labelColors[4], size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(author!,
                  style: TmText.label(tm.textAlpha(0.7)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (!proposed)
              TmChip(
                status == TmAgreementStatus.active ? 'Активно' : 'Отклонено',
                scope: status == TmAgreementStatus.active ? TmChipScope.income : TmChipScope.expense,
              ),
          ]),
          const SizedBox(height: TmSpace.l),
        ],
        Text(title,
            style: proposed
                ? TmText.titleDisplay(tm.text).copyWith(fontSize: 19)
                : TmText.rowTitle(tm.text)),
        if (newValue != null) ...[
          const SizedBox(height: 14),
          // Старое и новое значение переносятся, а не уезжают за край:
          // «24 000 ₽ → 30 000 ₽» не помещалось в строку даже на 393 dp.
          Wrap(
            spacing: TmSpace.m,
            runSpacing: TmSpace.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (oldValue != null)
                Text(
                  oldValue!,
                  style: TmText.amount(tm.textAlpha(0.4))
                      .copyWith(decoration: TextDecoration.lineThrough),
                ),
              Text(newValue!, style: TmText.balanceXl(tm.text).copyWith(fontSize: 26)),
            ],
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: 10),
          Text(note!, style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12.5, height: 1.5)),
        ],
        if (proposed) ...[
          const SizedBox(height: 18),
          Row(spacing: 10, children: [
            Expanded(child: TmButton(label: 'Согласен', onPressed: onAccept, expand: true)),
            Expanded(
              child: TmButton(
                label: 'Обсудим',
                variant: TmButtonVariant.outline,
                onPressed: onDiscuss,
                expand: true,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
