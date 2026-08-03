#!/usr/bin/env bash
# Labels as code para el ecosistema xima. Fuente de verdad: .github/labels.json
#
# Uso:
#   .github/scripts/sync-labels.sh                # todos los repos de la org
#   .github/scripts/sync-labels.sh xiagenda ...   # sólo esos repos
#
# Idempotente: crea lo que falta, corrige color/descripcion, borra lo que sobra.
# Ojo: borrar una label la quita de los issues que la tenian. Por eso el manifiesto
# es la unica fuente de verdad y no se editan labels a mano en la UI.
set -euo pipefail

ORG="${ORG:-XimaArgentina}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABELS_FILE="${LABELS_FILE:-$HERE/../labels.json}"

if [ "$#" -gt 0 ]; then
  REPOS=("$@")
else
  mapfile -t REPOS < <(gh repo list "$ORG" --limit 200 --json name --jq '.[].name')
fi

WANTED=$(jq -r '.[].name' "$LABELS_FILE" | sort)
uri() { jq -rn --arg n "$1" '$n|@uri'; }

for repo in "${REPOS[@]}"; do
  echo "== $ORG/$repo"
  jq -c '.[]' "$LABELS_FILE" | while read -r l; do
    name=$(jq -r '.name' <<<"$l")
    color=$(jq -r '.color' <<<"$l")
    desc=$(jq -r '.description' <<<"$l")
    if gh api "repos/$ORG/$repo/labels/$(uri "$name")" >/dev/null 2>&1; then
      gh api -X PATCH "repos/$ORG/$repo/labels/$(uri "$name")" \
        -f new_name="$name" -f color="$color" -f description="$desc" >/dev/null
      echo "   ~ $name"
    else
      gh api -X POST "repos/$ORG/$repo/labels" \
        -f name="$name" -f color="$color" -f description="$desc" >/dev/null
      echo "   + $name"
    fi
  done
  have=$(mktemp)
  gh api --paginate "repos/$ORG/$repo/labels" --jq '.[].name' | sort > "$have"
  comm -13 <(echo "$WANTED") "$have" | while read -r extra; do
    [ -z "$extra" ] && continue
    gh api -X DELETE "repos/$ORG/$repo/labels/$(uri "$extra")" >/dev/null
    echo "   - $extra"
  done
  rm -f "$have"
done
echo "listo."
