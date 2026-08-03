#!/usr/bin/env bash
# Configura el GitHub Project del ecosistema xima: campos, opciones y vistas.
#
#   ./setup-project.sh          # project #1 de la org
#   ./setup-project.sh 3        # por número
#
# Requiere: gh con scope `project`  →  gh auth refresh -h github.com -s project
#
# Idempotente: se puede correr las veces que haga falta.
#
# Lo que NO hace (la API de Projects v2 no lo expone): agrupar y ordenar dentro de
# cada vista, y crear/configurar los workflows del tablero. Ver SETUP-PROJECT.md.
set -euo pipefail

ORG=XimaArgentina
NUM="${1:-1}"

q() { gh api graphql "$@"; }

PID=$(q -f query='query($o:String!,$n:Int!){organization(login:$o){projectV2(number:$n){id}}}' \
      -f o="$ORG" -F n="$NUM" --jq '.data.organization.projectV2.id')
TITLE=$(q -f query='query($o:String!,$n:Int!){organization(login:$o){projectV2(number:$n){title}}}' \
      -f o="$ORG" -F n="$NUM" --jq '.data.organization.projectV2.title')
echo "Project #$NUM — $TITLE"

snapshot() {
  q -f query='query($o:String!,$n:Int!){organization(login:$o){projectV2(number:$n){
      fields(first:60){nodes{
        ... on ProjectV2FieldCommon { id name dataType }
        ... on ProjectV2SingleSelectField { options { id name } } }}
      views(first:30){nodes{ id name }}}}}' -f o="$ORG" -F n="$NUM"
}
SNAP=$(snapshot)
fid() { jq -r --arg n "$1" '.data.organization.projectV2.fields.nodes[]?|select(.name==$n)|.id' <<<"$SNAP"; }
oid() { jq -r --arg f "$1" --arg o "$2" '.data.organization.projectV2.fields.nodes[]?|select(.name==$f)|.options[]?|select(.name==$o)|.id' <<<"$SNAP"; }
vid() { jq -r --arg n "$1" '.data.organization.projectV2.views.nodes[]?|select(.name==$n)|.id' <<<"$SNAP"; }

# Preservar el id de una opción existente mantiene enganchados los workflows del
# tablero que la referencian. Si no existe, se crea (sin id).
opt() { # opt <campo> <nombre-viejo> <nombre-nuevo> <color> <descripcion>
  local id; id=$(oid "$1" "$2"); [ -z "$id" ] && id=$(oid "$1" "$3")
  if [ -n "$id" ]; then jq -nc --arg i "$id" --arg n "$3" --arg c "$4" --arg d "$5" \
      '{id:$i,name:$n,color:$c,description:$d}'
  else jq -nc --arg n "$3" --arg c "$4" --arg d "$5" '{name:$n,color:$c,description:$d}'; fi
}

# gh api graphql -F no serializa arrays/objetos JSON: hay que mandar el request
# completo por --input. Este helper es el único camino para variables complejas.
gql() { # gql <query> <variables-json>
  jq -n --arg q "$1" --argjson v "$2" '{query:$q,variables:$v}' | gh api graphql --input -
}

set_select() { # <field-id> <nombre-final> <json-array>
  gql 'mutation($f:ID!,$n:String!,$o:[ProjectV2SingleSelectFieldOptionInput!]!){
        updateProjectV2Field(input:{fieldId:$f,name:$n,singleSelectOptions:$o}){
          projectV2Field{... on ProjectV2SingleSelectField{name}}}}' \
    "$(jq -nc --arg f "$1" --arg n "$2" --argjson o "$3" '{f:$f,n:$n,o:$o}')" \
    | jq -r '.data.updateProjectV2Field.projectV2Field.name // ("ERROR: "+(.errors[0].message//"?"))' | sed 's/^/   ~ /'
}

new_select() { # <nombre> <json-array>
  gql 'mutation($p:ID!,$n:String!,$o:[ProjectV2SingleSelectFieldOptionInput!]!){
        createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:$n,singleSelectOptions:$o}){
          projectV2Field{... on ProjectV2SingleSelectField{name}}}}' \
    "$(jq -nc --arg p "$PID" --arg n "$1" --argjson o "$2" '{p:$p,n:$n,o:$o}')" \
    | jq -r '.data.createProjectV2Field.projectV2Field.name // ("ERROR: "+(.errors[0].message//"?"))' | sed 's/^/   + /'
}

echo "→ Campos"

# --- Status: las columnas. Una por "quién está bloqueado". ---------------------
# Reusamos los ids de Todo/In progress/Done para no dejar huérfanos los workflows
# que ya vienen activos del template (Item added / Item closed / PR merged), y los
# mapeamos al estado que esos workflows realmente significan.
STATUS=$(jq -sc '.' <<EOF
$(opt Status "Todo"        "Inbox"       GRAY   "Crudo o esperando una decisión humana. La IA todavía no lo puede tomar.")
$(opt Status "__nuevo__"   "Listo"       BLUE   "ready: alcance cerrado y criterio verificable. Claude Code lo toma sin preguntar.")
$(opt Status "In progress" "En curso"    YELLOW "Hay rama y una sesión trabajando.")
$(opt Status "__nuevo__"   "En revisión" ORANGE "PR abierto o ya mergeado a dev. Falta salir a staging.")
$(opt Status "__nuevo__"   "A validar"   PURPLE "Está en staging. Le toca a quien lo reportó. Única columna con cuello de botella humano.")
$(opt Status "Done"        "Hecho"       GREEN  "En producción y validado.")
$(opt Status "__nuevo__"   "Descartado"  RED    "No se hace. El comentario de cierre dice por qué.")
EOF
)
set_select "$(fid Status)" "Status" "$STATUS"

# --- Prioridad: sólo 3. Con un dev, "cuarta prioridad" y "backlog" son lo mismo.
# El campo `Priority` que trae el template NO se puede actualizar por API
# ("Only custom fields can be updated"): se borra más abajo y creamos uno propio.
if [ -z "$(fid Prioridad)" ]; then
new_select "Prioridad" '[
 {"name":"P0 Ahora","color":"RED","description":"Clientes reales afectados ahora, o riesgo legal/de datos."},
 {"name":"P1 Próximo","color":"YELLOW","description":"Duele seguido pero hay workaround."},
 {"name":"P2 Algún día","color":"GRAY","description":"Todo lo demás. Es más barato subir una prioridad que bajar cinco."}]'
fi

# --- Tamaño IA: la unidad real es la sesión de contexto, no la hora-hombre ------
# El campo puede llamarse todavía "Size" (template) o ya "Tamaño IA" (corrida previa).
SZ="Tamaño IA"; [ -z "$(fid "$SZ")" ] && SZ="Size"
SIZE=$(jq -sc '.' <<EOF
$(opt "$SZ" "S" "S — 1 sesión"     GREEN  "Entra en una sesión de Claude Code de punta a punta.")
$(opt "$SZ" "M" "M — 2-3 sesiones" YELLOW "Necesita handoff entre sesiones.")
$(opt "$SZ" "L" "L — dividir"      RED    "No es una estimación: es un pedido de partirlo antes de marcarlo ready.")
EOF
)
set_select "$(fid "$SZ")" "Tamaño IA" "$SIZE"

# --- Campos nuevos -------------------------------------------------------------
if [ -z "$(fid Producto)" ]; then
new_select "Producto" '[
 {"name":"XIAgenda","color":"BLUE","description":"Turnos"},
 {"name":"XNómina","color":"GREEN","description":"Sueldos y recibos"},
 {"name":"Reception","color":"PURPLE","description":"Primer contacto"},
 {"name":"Libs compartidas","color":"GRAY","description":"llm-saas-core, payments-core, whatsapp-core"},
 {"name":"Infra","color":"ORANGE","description":"Deploy, CI, Cloudflare, boxes"},
 {"name":"Sitios","color":"PINK","description":"Sitios estáticos y centro de ayuda"}]'
fi

if [ -z "$(fid Área)" ]; then
new_select "Área" '[
 {"name":"Turnos","color":"BLUE","description":""},
 {"name":"Pacientes","color":"BLUE","description":""},
 {"name":"WhatsApp y canales","color":"GREEN","description":""},
 {"name":"Agente IA","color":"PURPLE","description":""},
 {"name":"Pagos y suscripción","color":"YELLOW","description":""},
 {"name":"Panel y UX","color":"PINK","description":""},
 {"name":"Liquidación","color":"ORANGE","description":"XNómina"},
 {"name":"Recibos y firma","color":"ORANGE","description":"XNómina"},
 {"name":"Auth y permisos","color":"RED","description":""},
 {"name":"Infra y deploy","color":"GRAY","description":""},
 {"name":"Marketing y sitio","color":"PINK","description":""},
 {"name":"Otros","color":"GRAY","description":""}]'
fi

# --- Borrar lo que trae el template de planificación y no usamos ---------------
# No hay sprints ni story points: dejar los campos invita a llenarlos.
SNAP=$(snapshot)
for f in "Estimate" "Iteration" "Start date" "Target date" "Priority"; do
  id=$(fid "$f"); [ -z "$id" ] && continue
  q -f query='mutation($f:ID!){deleteProjectV2Field(input:{fieldId:$f}){clientMutationId}}' -f f="$id" >/dev/null
  echo "   - $f"
done

echo "→ Vistas"
SNAP=$(snapshot)

declare -A F
while IFS=$'\t' read -r n i; do F["$n"]="$i"; done < <(
  jq -r '.data.organization.projectV2.fields.nodes[]? | "\(.name)\t\(.id)"' <<<"$SNAP")

vfields() { local out=(); for n in "$@"; do [ -n "${F[$n]:-}" ] && out+=("${F[$n]}"); done
  printf '%s\n' "${out[@]}" | jq -Rsc 'split("\n")|map(select(length>0))'; }

mkview() { # <nombre> <layout> <filtro> <campos visibles...>
  local name="$1" layout="$2" filter="$3"; shift 3
  local id; id=$(vid "$name")
  if [ -z "$id" ]; then
    id=$(q -f query='mutation($p:ID!,$n:String!,$l:ProjectV2ViewLayout!){
        createProjectV2View(input:{projectId:$p,name:$n,layout:$l}){projectV2View{id}}}' \
      -f p="$PID" -f n="$name" -f l="$layout" --jq '.data.createProjectV2View.projectV2View.id')
    echo "   + $name"
  else
    echo "   ~ $name"
  fi
  gql 'mutation($v:ID!,$n:String!,$l:ProjectV2ViewLayout!,$f:String!,$c:ProjectV2ViewConfigurationInput!){
        updateProjectV2View(input:{viewId:$v,name:$n,layout:$l,filter:$f,configuration:$c}){projectV2View{id}}}' \
    "$(jq -nc --arg v "$id" --arg n "$name" --arg l "$layout" --arg f "$filter" \
        --argjson c "$(jq -nc --argjson v "$(vfields "$@")" '{visibleFieldIds:$v}')" \
        '{v:$v,n:$n,l:$l,f:$f,c:$c}')" \
    | jq -r 'if .errors then "     ERROR: "+.errors[0].message else empty end'
}

# 1. La cola de /triage. Debería estar vacía casi siempre.
mkview "📥 Inbox" TABLE_LAYOUT 'is:open label:triage' \
  Title Repository Assignees Created

# 2. LA vista del sistema: es lo que Claude Code lee para decidir qué hacer.
mkview "🤖 Cola de la IA" TABLE_LAYOUT 'is:open label:ready -label:blocked no:assignee' \
  Title Prioridad Producto Área "Tamaño IA" Repository

# 3. El tablero. Filtrar cerrados es lo que lo mantiene legible con cientos de issues.
mkview "🎯 Tablero" BOARD_LAYOUT 'is:open -status:Descartado' \
  Title Prioridad Producto "Tamaño IA" Assignees

# 4. La única vista que abren los testers.
mkview "🧪 Para validar" TABLE_LAYOUT 'status:"A validar"' \
  Title Producto Assignees Updated "Linked pull requests"

# 5. Para que nada quede trabado en silencio.
mkview "🚧 Trabado" TABLE_LAYOUT 'is:open label:blocked,needs-info' \
  Title Producto Área Assignees Updated

# 6. Se abre para decidir qué construir, no en el día a día.
mkview "🗺️ Mapa por área" TABLE_LAYOUT 'is:open' \
  Title Área Producto Prioridad "Tamaño IA"

# --- borrar las vistas del template -------------------------------------------
SNAP=$(snapshot)
for v in "Backlog" "Board" "Current iteration" "Roadmap" "My items" "Prioritized backlog"; do
  id=$(vid "$v"); [ -z "$id" ] && continue
  q -f query='mutation($v:ID!){deleteProjectV2View(input:{viewId:$v}){clientMutationId}}' -f v="$id" >/dev/null
  echo "   - $v"
done

echo
echo "Listo. Falta lo que la API no expone: agrupar/ordenar cada vista y los"
echo "workflows del tablero. Pasos exactos en SETUP-PROJECT.md."
