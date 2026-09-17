import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../design/myna_search.dart';
import '../l10n/strings.dart';
import '../logic/icon_search.dart';
import 'app_sheet.dart';

/// Выбрать значок из всего набора MyNaUI. Возвращает имя знака или null.
///
/// Один лист на счета и категории: выбор значка у них одинаковый, и две копии
/// разъехались бы на первой же правке.
Future<String?> showIconSearch(BuildContext context) =>
    showMoneySheet<String>(context, builder: (context) => const IconSearchSheet());

/// Поиск значка по всему набору MyNaUI — 1310 знаков.
///
/// Выбор из тридцати четырёх человека не устроил прямо: «мало иконок, хоть бы
/// поиск сделал по всей базе» (13.09.2026). Имена в наборе английские, поэтому
/// поверх лежит слой русских слов (`logic/icon_search.dart`).
class IconSearchSheet extends StatefulWidget {
  const IconSearchSheet({super.key});

  @override
  State<IconSearchSheet> createState() => IconSearchSheetState();
}

class IconSearchSheetState extends State<IconSearchSheet> {
  final _query = TextEditingController();
  late List<IconHit> _hits = searchIcons('');

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          tr('categoryIconSearch'),
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('categoryIconHint'),
            prefixIcon: const Icon(Myna.search, size: 20),
          ),
          onChanged: (v) => setState(() => _hits = searchIcons(v)),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            trf('categoryIconAll', ['${mynaByName.length}']),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Высота задана долей экрана: лист с клавиатурой и без неё должен
        // оставаться одного роста, иначе сетка прыгает на каждой букве.
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.42,
          child: _hits.isEmpty
              ? Center(
                  child: Text(
                    tr('categoryIconNothing'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _hits.length,
                  itemBuilder: (context, i) {
                    final hit = _hits[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).pop(hit.name),
                      child: Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          hit.icon,
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
