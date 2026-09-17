#!/usr/bin/env python3
"""Пересобрать `lib/design/myna_search.dart` — каталог для поиска значка.

    npm pack @mynaui/icons && tar xzf mynaui-icons-*.tgz
    python3 tool/gen_myna_search.py путь/к/package

Карта ссылается на КАЖДЫЙ знак набора, поэтому шрифт в сборке остаётся целым:
отсев неиспользуемых глифов после этого не срабатывает. Это цена поиска по
всей базе, и она заплачена осознанно.

Русские слова к значкам лежат отдельно, в `lib/logic/icon_search.dart`: они
пишутся руками и в набор не входят.
"""
import json
import re
import sys
from pathlib import Path

DART_KW = {
    'as', 'in', 'is', 'if', 'for', 'do', 'new', 'null', 'this', 'true', 'false',
    'set', 'get', 'part', 'show', 'hide', 'on', 'var', 'void', 'with', 'when',
    'sync', 'async', 'await', 'class', 'const', 'enum', 'final', 'super',
    'switch', 'throw', 'try', 'while', 'yield', 'return', 'static', 'abstract',
    'base', 'sealed', 'library', 'import', 'export', 'extends', 'external',
    'factory', 'implements', 'interface', 'mixin', 'operator', 'rethrow',
    'typedef', 'covariant', 'deferred', 'dynamic', 'required', 'assert',
    'break', 'case', 'catch', 'continue', 'default', 'else', 'extension',
    'finally', 'function', 'late',
}


def dart_name(key: str) -> str:
    parts = key.split('-')
    name = parts[0] + ''.join(p.capitalize() for p in parts[1:])
    if name[0].isdigit():
        name = 'n' + name
    return name + 'Icon' if name in DART_KW else name


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else 'package')
    root = Path(__file__).resolve().parent.parent
    meta = json.loads((src / 'meta.json').read_text())
    css = (src / 'mynaui.css').read_text()
    names = sorted(
        m[1] for m in re.finditer(r'\.mynaui-([a-z0-9-]+)::before', css)
    )

    lines = [
        '// СГЕНЕРИРОВАНО. Руками не править: пересобрать tool/gen_myna_search.py.',
        '//',
        '/// Поиск по ВСЕМУ набору MyNaUI: имя знака, его английские метки и',
        '/// русские слова к ним.',
        '///',
        '/// Выбор из тридцати четырёх значков человека не устроил прямо: «мало',
        '/// иконок, хоть бы поиск сделал по всей базе» (13.09.2026). Теперь в',
        '/// выборе все 1310.',
        '///',
        '/// Карта ссылается на каждый знак, поэтому шрифт в сборке остаётся целым',
        '/// (550 КБ вместо 52 КБ после отсева). Это цена поиска, и она заплачена',
        '/// осознанно: APK и так двадцать два мегабайта.',
        'library;',
        '',
        "import 'myna.dart';",
        "import 'package:flutter/widgets.dart';",
        '',
        '/// Знак по имени набора: `cart`, `home-smile`.',
        'const Map<String, IconData> mynaByName = {',
    ]
    lines += [f"  '{k}': Myna.{dart_name(k)}," for k in names]
    lines += ['};', '', '/// Английские метки знака — по ним идёт поиск.',
              'const Map<String, String> mynaTags = {']
    for key in names:
        tags = ' '.join(meta.get(key, {}).get('tags', [])).replace("'", "\\'")
        if tags:
            lines.append(f"  '{key}': '{tags}',")
    lines += ['};', '']
    (root / 'lib/design/myna_search.dart').write_text('\n'.join(lines) + '\n')
    print(f'знаков в каталоге: {len(names)}')


if __name__ == '__main__':
    main()
