#!/usr/bin/env bash
# Genera skill/reportar-xima/SKILL.md y skill/reportar-xima.zip desde el bloque
# de prompt canónico de REPORTAR-CON-IA.md (el fence ````text).
# El doc es la ÚNICA fuente: editá el prompt ahí y corré este script.
#
# Uso:
#   tools/build-reportar-skill.sh          # regenera SKILL.md + zip
#   tools/build-reportar-skill.sh --check  # falla si lo commiteado quedó viejo (CI)
set -euo pipefail
cd "$(dirname "$0")/.."

DOC=REPORTAR-CON-IA.md
OUT_DIR=skill/reportar-xima
OUT_MD=$OUT_DIR/SKILL.md
OUT_ZIP=skill/reportar-xima.zip

# claude.ai exige: name ≤64 chars (lowercase/números/guiones), description ≤200 chars.
DESCRIPTION='Reportar bugs o mejoras de XIAgenda o XNómina como issues de GitHub (XimaArgentina) vía MCP. Usar cuando el usuario cuente que algo falló o quiera pedir una mejora en esos productos.'

build_skill_md() { # $1 = archivo destino
  [ "$(printf '%s' "$DESCRIPTION" | wc -m)" -le 200 ] \
    || { echo "ERROR: la description supera los 200 chars que permite claude.ai" >&2; exit 1; }
  mkdir -p "$(dirname "$1")"
  {
    printf -- '---\nname: reportar-xima\ndescription: %s\n---\n\n' "$DESCRIPTION"
    awk '/^````text$/{f=1;next} f&&/^````$/{exit} f' "$DOC"
  } > "$1"
  # Si el fence se movió y la extracción vino (casi) vacía, cortar acá y no
  # dejar que un zip hueco llegue a los testers.
  [ "$(wc -l < "$1")" -gt 20 ] || { echo "ERROR: no encontré el bloque de prompt en $DOC" >&2; exit 1; }
}

build_zip() { # $1 = workdir con reportar-xima/SKILL.md, $2 = zip destino
  rm -f "$2"
  # touch con fecha fija + zip -X: el zip solo cambia cuando cambia el contenido.
  (cd "$1" && find reportar-xima -exec touch -t 202601010000 {} + && zip -X -q -r skill.zip reportar-xima)
  mv "$1/skill.zip" "$2"
}

if [ "${1:-}" = "--check" ]; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  build_skill_md "$tmp/reportar-xima/SKILL.md"
  diff -u "$OUT_MD" "$tmp/reportar-xima/SKILL.md" \
    || { echo "ERROR: $OUT_MD quedó viejo. Corré tools/build-reportar-skill.sh y commiteá." >&2; exit 1; }
  unzip -p "$OUT_ZIP" reportar-xima/SKILL.md > "$tmp/from-zip.md"
  diff -u "$tmp/from-zip.md" "$tmp/reportar-xima/SKILL.md" \
    || { echo "ERROR: $OUT_ZIP quedó viejo. Corré tools/build-reportar-skill.sh y commiteá." >&2; exit 1; }
  echo "OK: la skill está en sync con $DOC"
else
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  build_skill_md "$tmp/reportar-xima/SKILL.md"
  mkdir -p "$OUT_DIR"
  cp "$tmp/reportar-xima/SKILL.md" "$OUT_MD"
  build_zip "$tmp" "$OUT_ZIP"
  echo "Generados $OUT_MD y $OUT_ZIP"
fi
