#!/usr/bin/env python3
"""Пересобрать `lib/design/myna.dart` и `myna_solid.dart` из набора MyNaUI.

    npm pack @mynaui/icons && tar xzf mynaui-icons-*.tgz
    python3 tool/gen_myna.py путь/к/package

Коды берутся из `mynaui.css` самого набора: у контура и заливки они
одинаковые, поэтому один и тот же `Myna.home` и `MynaSolid.home` — это две
версии одного знака. Шрифты `mynaui.ttf` и `mynaui-solid.ttf` кладутся в
`assets/fonts/` под именами `Myna.ttf` и `MynaSolid.ttf`.
"""
import re
import shutil
import sys
from pathlib import Path

DART_KW = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'false', 'final', 'finally', 'for', 'function',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'new', 'null', 'on', 'operator', 'part',
    'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
    'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef',
    'var', 'void', 'when', 'while', 'with', 'yield',
}


def dart_name(key: str) -> str:
    parts = key.split('-')
    name = parts[0] + ''.join(p.capitalize() for p in parts[1:])
    if name[0].isdigit():
        name = 'n' + name
    return name + 'Icon' if name in DART_KW else name


def codepoints(css: Path, prefix: str) -> dict[str, str]:
    text = css.read_text()
    pattern = r'\.' + prefix + r'-([a-z0-9-]+)::before\s*\{\s*content:\s*"\\([0-9a-f]+)"'
    return {m[1]: m[2] for m in re.finditer(pattern, text)}


def write(cls: str, family: str, out: Path, title: str, cps: dict[str, str]) -> None:
    lines = [
        '// СГЕНЕРИРОВАНО. Руками не править: пересобрать скриптом из',
        '// tool/gen_myna.py по пакету @mynaui/icons.',
        '//',
        f'/// {title}',
        '///',
        '/// Набор MyNaUI Icons (MIT, Praveen Juge, https://mynaui.com/icons).',
        '/// Шрифт собран самим набором, коды взяты из его же таблицы.',
        'library;',
        '',
        "import 'package:flutter/widgets.dart';",
        '',
        f'abstract final class {cls} {{',
        f"  static const String family = '{family}';",
        '',
    ]
    for key in sorted(cps):
        lines.append(
            f'  static const IconData {dart_name(key)} = '
            f'IconData(0x{cps[key]}, fontFamily: family);'
        )
    lines += ['}', '']
    out.write_text('\n'.join(lines))


def main() -> None:
    src = Path(sys.argv[1] if len(sys.argv) > 1 else 'package')
    root = Path(__file__).resolve().parent.parent
    outline = codepoints(src / 'mynaui.css', 'mynaui')
    solid = codepoints(src / 'mynaui-solid.css', 'mynaui-solid')
    if outline != solid:
        raise SystemExit('коды контура и заливки разошлись — карта знаков сломана')
    shutil.copy(src / 'mynaui.ttf', root / 'assets/fonts/Myna.ttf')
    shutil.copy(src / 'mynaui-solid.ttf', root / 'assets/fonts/MynaSolid.ttf')
    write('Myna', 'Myna', root / 'lib/design/myna.dart',
          'Значки набора MyNaUI — контур.', outline)
    write('MynaSolid', 'MynaSolid', root / 'lib/design/myna_solid.dart',
          'Значки набора MyNaUI — заливка. Имена те же, что у контура.', solid)
    print(f'знаков: {len(outline)}')


if __name__ == '__main__':
    main()
