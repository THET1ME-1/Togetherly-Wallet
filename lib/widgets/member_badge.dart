import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/avatar.dart';

/// Кто платил — аватаром и именем, а не словом в общей строке подписи.
///
/// В подписи имя стояло последним и обрезалось первым: «Общий кошелёк · Linella
/// вдвоём · Лен…». Аватар узнаётся с одного взгляда и не спорит за место с
/// названием счёта.
class MemberBadge extends StatelessWidget {
  const MemberBadge({
    super.key,
    required this.member,
    this.isMe = false,
    this.size = 16,
    this.showName = true,
  });

  final Member? member;
  final bool isMe;
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Имя, и только имя: «Вы», «Я» и «Партнёр» человек видеть не должен —
    // «оно должно отображаться ник мой или ник партнёра» (13.09.2026).
    // Заглушка остаётся ровно на случай, когда имени нет вовсе.
    final name = member?.name.trim() ?? '';
    final label = name.isNotEmpty
        ? name
        : (isMe ? tr('youShort') : tr('accountPartner'));
    // Буква в кружке берётся из ИМЕНИ, а не из подписи: у себя подпись «вы»,
    // и кружок читался бы «в» у человека по имени Саша.
    final letterFrom = name.isNotEmpty ? name : label;
    final color = member?.color != null
        ? Color(member!.color!)
        : labelColorFor(member?.uid ?? label);

    return Container(
      padding: EdgeInsets.only(left: 2, right: showName ? 7 : 2, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Avatar(url: member?.avatarUrl, name: letterFrom, color: color, size: size),
        if (showName) ...[
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.color,
    required this.size,
  });

  final String? url;
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.characters.isEmpty ? '?' : name.characters.first.toUpperCase();
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: size * 0.55,
          fontWeight: FontWeight.w700,
          height: 1,
          // Буква лежит на пастельном кружке, который не меняется с темой.
          color: inkOn(color),
        ),
      ),
    );

    // Схема `pb://media/...` разворачивается в настоящую ссылку: иначе у
    // человека с фотографией в профиле стоит буква.
    final link = avatarLink(url) ?? '';
    if (link.isEmpty) return circle;

    return ClipOval(
      child: Image.network(
        link,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Аватар приезжает из Togetherly и может не загрузиться: кружок с
        // буквой на его месте лучше пустой дырки.
        errorBuilder: (_, __, ___) => circle,
        loadingBuilder: (_, child, progress) => progress == null ? child : circle,
      ),
    );
  }
}
