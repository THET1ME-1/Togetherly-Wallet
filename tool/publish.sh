#!/usr/bin/env bash
# Обновить открытый репозиторий приложения.
#
# Открытая копия живёт отдельной папкой и отдельной историей: в приватной
# лежит server/ с маршрутами и живыми пробами, адреса машин и личные заметки,
# и раз опубликованное уже не отозвать. Поэтому наружу едет rsync с явным
# списком исключений, а не `git push` ветки.
#
#   tool/publish.sh "Строка коммита"
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="${WALLET_PUBLIC_DIR:-$HOME/Projects/GitHub/Togetherly-Wallet}"
MSG="${1:-Обновление приложения}"

if [ ! -d "$DST/.git" ]; then
  echo "Открытой копии нет: $DST" >&2
  exit 1
fi

rsync -a --delete \
  --exclude '.git/' --exclude 'build/' --exclude '.dart_tool/' \
  --exclude 'server/' --exclude 'CLAUDE.md' --exclude 'CLAUDE.local.md' \
  --exclude 'sample-data.json' --exclude 'android/app/google-services.json' \
  --exclude 'test/shots/' --exclude 'test/failures/' \
  --exclude '.flutter-plugins*' --exclude 'android/local.properties' \
  --exclude 'ios/Flutter/ephemeral/' --exclude 'ios/Flutter/Generated.xcconfig' \
  --exclude 'ios/Flutter/flutter_export_environment.sh' --exclude '.idea/' \
  --exclude 'ios/Pods/' --exclude 'ios/.symlinks/' --exclude '.impeccable/' \
  --exclude '*.iml' \
  --exclude '.github/' --exclude 'LICENSE' --exclude 'README.md' \
  --exclude 'README.ru.md' --exclude 'CONTRIBUTING.md' --exclude '.gitignore' \
  "$SRC/" "$DST/"

cd "$DST"

# Последняя проверка: наружу не должно уехать ничего из закрытого списка.
if git status --porcelain | grep -qiE 'server/|CLAUDE\.md|sample-data|google-services|\.jks|key\.properties'; then
  echo "СТОП: в открытую копию попало закрытое. Разберитесь руками." >&2
  git status --short | head -20 >&2
  exit 1
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "менять нечего"
  exit 0
fi

git add -A
git commit -q -m "$MSG"
git push -q
echo "выложено: $(git log --oneline -1)"
