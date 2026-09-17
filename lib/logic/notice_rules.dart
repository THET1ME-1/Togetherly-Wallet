/// Свои правила разбора списаний.
///
/// Приложение и без них помнит, какую категорию человек поставил магазину
/// (`categoryForNotice`), и это остаётся бесплатным. Правила — про другое: они
/// работают ДО первого подтверждения и умеют то, чего память не умеет.
///
/// Что правило умеет:
///
/// * узнать магазин по куску имени, а не по точному совпадению: банк пишет
///   «SC TUCANO SRL CHISINAU», а человек думает словом «Tucano»;
/// * различить суммы: «больше 2000 — спроси», «мелочь до 100 — пиши молча»;
/// * различить дни: доставка по будням это обед, в выходной — ужин;
/// * поставить не только категорию, но и подкатегорию, счёт, делёж, заметку;
/// * остановить разбор совсем: банковская комиссия человеку не нужна.
///
/// Чего правило НЕ делает: не трогает уже записанные операции. Оно про то,
/// что делать с новым уведомлением, и только.
library;

import '../data/models.dart';
import 'notice_parse.dart';

/// Что правило проверяет.
class NoticeWhen {
  const NoticeWhen({
    this.merchant,
    this.sender,
    this.min,
    this.max,
    this.weekdays = const {},
    this.income,
    this.last4,
  });

  /// Кусок имени магазина, без учёта регистра. «tucano» ловит
  /// «SC TUCANO SRL CHISINAU».
  final String? merchant;

  /// Пакет банковского приложения. Пусто — любой источник.
  final String? sender;

  /// Границы суммы, в валюте уведомления. Обе необязательные.
  final double? min;
  final double? max;

  /// Дни недели по счёту Dart: 1 — понедельник, 7 — воскресенье. Пусто —
  /// любой день.
  final Set<int> weekdays;

  /// Только приход (`true`) или только расход (`false`). Пусто — любое.
  final bool? income;

  /// Последние четыре цифры карты.
  final String? last4;

  bool get isEmpty =>
      (merchant ?? '').trim().isEmpty &&
      (sender ?? '').trim().isEmpty &&
      min == null &&
      max == null &&
      weekdays.isEmpty &&
      income == null &&
      (last4 ?? '').trim().isEmpty;

  /// Подходит ли уведомление под условие.
  bool matches(ParsedNotice n) {
    final merchantWant = (merchant ?? '').trim().toLowerCase();
    if (merchantWant.isNotEmpty) {
      // Ищем и в имени магазина, и в заголовке с телом: банк иногда кладёт
      // название туда, откуда разбор его не достал.
      final hay = [
        n.merchant ?? '',
        n.title,
        n.body,
      ].join(' ').toLowerCase();
      if (!hay.contains(merchantWant)) return false;
    }

    final senderWant = (sender ?? '').trim();
    if (senderWant.isNotEmpty && n.package != senderWant) return false;

    final digits = (last4 ?? '').trim();
    if (digits.isNotEmpty && n.last4 != digits) return false;

    if (min != null && n.amount < min! - 0.005) return false;
    if (max != null && n.amount > max! + 0.005) return false;

    if (income != null && (n.kind == TxKind.income) != income) return false;

    if (weekdays.isNotEmpty) {
      final day = DateTime.fromMillisecondsSinceEpoch(n.at).weekday;
      if (!weekdays.contains(day)) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        if ((merchant ?? '').isNotEmpty) 'merchant': merchant,
        if ((sender ?? '').isNotEmpty) 'sender': sender,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (weekdays.isNotEmpty) 'weekdays': weekdays.toList()..sort(),
        if (income != null) 'income': income,
        if ((last4 ?? '').isNotEmpty) 'last4': last4,
      };

  factory NoticeWhen.fromJson(Map<String, dynamic> j) => NoticeWhen(
        merchant: j['merchant'] as String?,
        sender: j['sender'] as String?,
        min: (j['min'] as num?)?.toDouble(),
        max: (j['max'] as num?)?.toDouble(),
        weekdays: {
          for (final d in (j['weekdays'] as List?) ?? const [])
            if (d is num) d.toInt(),
        },
        income: j['income'] is bool ? j['income'] as bool : null,
        last4: j['last4'] as String?,
      );

  NoticeWhen copyWith({
    String? merchant,
    String? sender,
    double? min,
    double? max,
    Set<int>? weekdays,
    bool? income,
    String? last4,
    bool clearMin = false,
    bool clearMax = false,
    bool clearIncome = false,
  }) =>
      NoticeWhen(
        merchant: merchant ?? this.merchant,
        sender: sender ?? this.sender,
        min: clearMin ? null : (min ?? this.min),
        max: clearMax ? null : (max ?? this.max),
        weekdays: weekdays ?? this.weekdays,
        income: clearIncome ? null : (income ?? this.income),
        last4: last4 ?? this.last4,
      );
}

/// Что правило делает с подошедшим уведомлением.
enum NoticeDo {
  /// Записать сразу, ничего не спрашивая.
  record,

  /// Положить в разбор и спросить человека.
  ask,

  /// Выбросить: комиссия, реклама, код из СМС.
  skip,
}

NoticeDo noticeDoOf(String? raw) => switch (raw) {
      'record' => NoticeDo.record,
      'skip' => NoticeDo.skip,
      _ => NoticeDo.ask,
    };

String noticeDoName(NoticeDo d) => switch (d) {
      NoticeDo.record => 'record',
      NoticeDo.ask => 'ask',
      NoticeDo.skip => 'skip',
    };

/// Правило целиком.
class NoticeRule {
  const NoticeRule({
    required this.id,
    required this.when,
    this.act = NoticeDo.ask,
    this.category,
    this.subcategory,
    this.account,
    this.split,
    this.note,
    this.on = true,
  });

  /// Свой номер: по нему правило правится и удаляется.
  final String id;

  final NoticeWhen when;
  final NoticeDo act;

  /// Чем заполнить запись. Пусто — оставить, как разобралось.
  final String? category;
  final String? subcategory;
  final String? account;
  final SplitMode? split;
  final String? note;

  /// Выключенное правило остаётся в списке, но ничего не делает: это удобнее,
  /// чем удалять и заводить заново.
  final bool on;

  NoticeRule copyWith({
    NoticeWhen? when,
    NoticeDo? act,
    String? category,
    String? subcategory,
    String? account,
    SplitMode? split,
    String? note,
    bool? on,
    bool clearCategory = false,
    bool clearSubcategory = false,
    bool clearAccount = false,
    bool clearSplit = false,
    bool clearNote = false,
  }) =>
      NoticeRule(
        id: id,
        when: when ?? this.when,
        act: act ?? this.act,
        category: clearCategory ? null : (category ?? this.category),
        subcategory:
            clearSubcategory ? null : (subcategory ?? this.subcategory),
        account: clearAccount ? null : (account ?? this.account),
        split: clearSplit ? null : (split ?? this.split),
        note: clearNote ? null : (note ?? this.note),
        on: on ?? this.on,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'when': when.toJson(),
        'act': noticeDoName(act),
        if ((category ?? '').isNotEmpty) 'category': category,
        if ((subcategory ?? '').isNotEmpty) 'subcategory': subcategory,
        if ((account ?? '').isNotEmpty) 'account': account,
        if (split != null) 'split': split!.name,
        if ((note ?? '').isNotEmpty) 'note': note,
        if (!on) 'on': false,
      };

  factory NoticeRule.fromJson(Map<String, dynamic> j) => NoticeRule(
        id: '${j['id'] ?? ''}',
        when: NoticeWhen.fromJson(
            ((j['when'] as Map?) ?? const {}).cast<String, dynamic>()),
        act: noticeDoOf(j['act'] as String?),
        category: j['category'] as String?,
        subcategory: j['subcategory'] as String?,
        account: j['account'] as String?,
        split: j['split'] == null
            ? null
            : SplitMode.values
                .where((m) => m.name == '${j['split']}')
                .firstOrNull,
        note: j['note'] as String?,
        on: j['on'] != false,
      );
}

/// Первое подошедшее правило. Порядок в списке и есть приоритет: правило выше
/// сильнее, и человек двигает их сам — иначе «всё, что дороже 2000» съедало бы
/// частный случай «Tucano».
NoticeRule? ruleFor(ParsedNotice notice, List<NoticeRule> rules) {
  for (final r in rules) {
    if (!r.on) continue;
    if (r.when.isEmpty) continue; // пустое условие подошло бы ко всему
    if (r.when.matches(notice)) return r;
  }
  return null;
}

/// Человеческое описание условия: «Tucano · больше 2000 · по будням».
/// Собирается из кусков, потому что в списке правило надо узнавать взглядом.
List<String> ruleWhenParts(
  NoticeWhen when, {
  required String Function(String package) senderTitle,
  required String Function(double amount) money,
  required List<String> weekdayNames,
  required String anyLabel,
  required String fromLabel,
  required String toLabel,
  required String cardLabel,
  required String incomeLabel,
  required String expenseLabel,
}) {
  final parts = <String>[];
  final merchant = (when.merchant ?? '').trim();
  if (merchant.isNotEmpty) parts.add(merchant);

  final sender = (when.sender ?? '').trim();
  if (sender.isNotEmpty) parts.add(senderTitle(sender));

  final last4 = (when.last4 ?? '').trim();
  if (last4.isNotEmpty) parts.add('$cardLabel $last4');

  if (when.min != null && when.max != null) {
    parts.add('${money(when.min!)} – ${money(when.max!)}');
  } else if (when.min != null) {
    parts.add('$fromLabel ${money(when.min!)}');
  } else if (when.max != null) {
    parts.add('$toLabel ${money(when.max!)}');
  }

  if (when.income != null) {
    parts.add(when.income! ? incomeLabel : expenseLabel);
  }

  if (when.weekdays.isNotEmpty && when.weekdays.length < 7) {
    final days = when.weekdays.toList()..sort();
    parts.add([for (final d in days) weekdayNames[d - 1]].join(', '));
  }

  return parts.isEmpty ? [anyLabel] : parts;
}
