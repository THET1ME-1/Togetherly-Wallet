#!/usr/bin/env python3
"""Перевести код с Material Icons на MyNaUI по карте `tool/myna_map.json`.

Одноразовый скрипт переезда: оставлен, чтобы карта соответствий не жила
только в истории гита и правилась вместе с кодом.

    python3 tool/apply_myna.py
"""
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAP = json.loads((ROOT / 'tool/myna_map.json').read_text())

# Нижняя навигация: тот же знак, но из шрифта заливки — раздел наливается
# при выборе.
NAV_SOLID = {
    'home_rounded', 'donut_large_rounded', 'bar_chart_rounded',
    'receipt_long_rounded',
}


def dart_name(key: str) -> str:
    parts = key.split('-')
    name = parts[0] + ''.join(p.capitalize() for p in parts[1:])
    return 'n' + name if name[0].isdigit() else name


def convert(path: Path) -> bool:
    src = path.read_text()
    if 'Icons.' not in src:
        return False

    def swap(mo: re.Match) -> str:
        name = mo.group(1)
        if name == 'apple':
            return mo.group(0)  # знак бренда, в наборе MyNaUI его нет
        if name not in MAP:
            raise SystemExit(f'нет пары для Icons.{name} в {path}')
        return f'Myna.{dart_name(MAP[name])}'

    out = re.sub(r'\bIcons\.([a-zA-Z0-9_]+)', swap, src)
    if 'Myna.' not in out:
        return False
    if path.parts[0] == 'test':
        imp = "import 'package:togetherly_money/design/myna.dart';"
    else:
        imp = f"import '{os.path.relpath(ROOT / 'lib/design/myna.dart', path.parent)}';"
    if imp not in out:
        lines = out.split('\n')
        last = max(i for i, line in enumerate(lines) if line.startswith('import '))
        lines.insert(last + 1, imp)
        out = '\n'.join(lines)
    path.write_text(out)
    return True


def main() -> None:
    os.chdir(ROOT)
    done = [f for root in ('lib', 'test')
            for f in sorted(Path(root).rglob('*.dart')) if convert(f)]
    print(f'файлов правлено: {len(done)}')


if __name__ == '__main__':
    main()
