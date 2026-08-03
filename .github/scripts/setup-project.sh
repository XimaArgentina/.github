#!/usr/bin/env bash
# Configura el GitHub Project del ecosistema xima: campos y opciones.
#
#   ./setup-project.sh            # busca el único project de la org
#   ./setup-project.sh 3          # por número de project
#
# Requiere: gh con scopes `project` + `read:project`
#   gh auth refresh -h github.com -s project,read:project
#
# Idempotente: si el campo ya existe, actualiza sus opciones en vez de duplicarlo.
#
# NO crea las vistas ni las automatizaciones: la API de Projects v2 no expone
# mutaciones para ninguna de las dos. Ese paso es manual y está documentado en
# SETUP-PROJECT.md, en la raíz de este repo.
set -euo pipefail

ORG=XimaArgentina
NUM="${1:-}"

api() { gh api graphql "$@"; }

if [ -z "$NUM" ]; then
  NUM=$(api -f query='query($o:String!){organization(login:$o){projectsV2(first:20){nodes{number title}}}}' \
        -f o="$ORG" --jq '.data.organization.projectsV2.nodes[0].number')
  echo "Project detectado: #$NUM"
fi

PID=$(api -f query='query($o:String!,$n:Int!){organization(login:$o){projectV2(number:$n){id title}}}' \
      -f o="$ORG" -F n="$NUM" --jq '.data.organization.projectV2.id')
TITLE=$(api -f query='query($o:String!,$n:Int!){organization(login:$o){projectV2(number:$n){title}}}' \
      -f o="$ORG" -F n="$NUM" --jq '.data.organization.projectV2.title')
echo "→ $TITLE ($PID)"

fields_json() {
  api -f query='query($o:String!,$n:Int!){organization(login:$o){projectV2(number:$n){
        fields(first:50){nodes{ ... on ProjectV2FieldCommon { id name dataType } }}}}}' \
      -f o="$ORG" -F n="$NUM"
}

field_id() { jq -r --arg n "$1" '.data.organization.projectV2.fields.nodes[]? | select(.name==$n) | .id' <<<"$FIELDS"; }

# --- helper: crea o actualiza un single-select con sus opciones -----------------
# uso: upsert_select "Nombre" '[{"name":"A","color":"RED","description":"..."}]'
upsert_select() {
  local name="$1" opts="$2" fid
  fid=$(field_id "$name")
  if [ -n "$fid" ]; then
    api -f query='mutation($f:ID!,$o:[ProjectV2SingleSelectFieldOptionInput!]!){
        updateProjectV2Field(input:{fieldId:$f,singleSelectOptions:$o}){projectV2Field{... on ProjectV2SingleSelectField{id name}}}}' \
      -f f="$fid" -F o="$opts" >/dev/null
    echo "   ~ $name"
  else
    api -f query='mutation($p:ID!,$n:String!,$o:[ProjectV2SingleSelectFieldOptionInput!]!){
        createProjectV2Field(input:{projectId:$p,dataType:SINGLE_SELECT,name:$n,singleSelectOptions:$o}){
          projectV2Field{... on ProjectV2SingleSelectField{id name}}}}' \
      -f p="$PID" -f n="$name" -F o="$opts" >/dev/null
    echo "   + $name"
  fi
}

FIELDS=$(fields_json)

# --- Status: las columnas del tablero -----------------------------------------
# Una columna por "quién está bloqueado". Si dos estados los destraba la misma
# persona con la misma acción, son la misma columna.
upsert_select "Status" '[
 {"name":"Inbox",      "color":"GRAY",  "description":"Crudo o esperando una decisión humana. La IA todavía no lo puede tomar."},
 {"name":"Listo",      "color":"BLUE",  "description":"ready: alcance cerrado y criterio verificable. Claude Code lo toma sin preguntar."},
 {"name":"En curso",   "color":"YELLOW","description":"Hay rama y una sesión trabajando."},
 {"name":"En revisión","color":"ORANGE","description":"PR abierto o ya mergeado a dev. Falta salir a staging."},
 {"name":"A validar",  "color":"PURPLE","description":"Está en staging. Le toca al que lo reportó. ÚNICA columna donde el cuello de botella es humano."},
 {"name":"Hecho",      "color":"GREEN", "description":"En producción y validado."},
 {"name":"Descartado", "color":"RED",   "description":"No se hace. El comentario de cierre dice por qué."}
]'

FIELDS=$(fields_json)

# --- Producto: el repo no alcanza (una lib compartida se cambia POR un producto)
upsert_select "Producto" '[
 {"name":"XIAgenda",        "color":"BLUE",  "description":"Turnos"},
 {"name":"XNómina",         "color":"GREEN", "description":"Sueldos y recibos"},
 {"name":"Reception",       "color":"PURPLE","description":"Primer contacto"},
 {"name":"Libs compartidas","color":"GRAY",  "description":"llm-saas-core, payments-core, whatsapp-core"},
 {"name":"Infra",           "color":"ORANGE","description":"Deploy, CI, Cloudflare, boxes"},
 {"name":"Sitios",          "color":"PINK",  "description":"Sitios estáticos y centro de ayuda"}
]'

FIELDS=$(fields_json)

# --- Área: reemplaza a las labels `area:*`, que se multiplican por combinación --
upsert_select "Área" '[
 {"name":"Turnos",              "color":"BLUE",  "description":""},
 {"name":"Pacientes",           "color":"BLUE",  "description":""},
 {"name":"WhatsApp y canales",  "color":"GREEN", "description":""},
 {"name":"Agente IA",           "color":"PURPLE","description":""},
 {"name":"Pagos y suscripción", "color":"YELLOW","description":""},
 {"name":"Panel y UX",          "color":"PINK",  "description":""},
 {"name":"Liquidación",         "color":"ORANGE","description":"XNómina"},
 {"name":"Recibos y firma",     "color":"ORANGE","description":"XNómina"},
 {"name":"Auth y permisos",     "color":"RED",   "description":""},
 {"name":"Infra y deploy",      "color":"GRAY",  "description":""},
 {"name":"Marketing y sitio",   "color":"PINK",  "description":""},
 {"name":"Otros",               "color":"GRAY",  "description":""}
]'

FIELDS=$(fields_json)

# --- Prioridad: sólo 3. Con un dev, "cuarta prioridad" y "backlog" son lo mismo.
upsert_select "Prioridad" '[
 {"name":"P0 Ahora",    "color":"RED",   "description":"Clientes reales afectados ahora, o riesgo legal/de datos."},
 {"name":"P1 Próximo",  "color":"YELLOW","description":"Duele seguido pero hay workaround."},
 {"name":"P2 Algún día","color":"GRAY",  "description":"Todo lo demás. Es más barato subir una prioridad que bajar cinco."}
]'

FIELDS=$(fields_json)

# --- Tamaño IA: la unidad real es la sesión de contexto, no la hora-hombre ------
upsert_select "Tamaño IA" '[
 {"name":"S — 1 sesión",    "color":"GREEN", "description":"Entra en una sesión de Claude Code de punta a punta."},
 {"name":"M — 2-3 sesiones","color":"YELLOW","description":"Necesita handoff entre sesiones."},
 {"name":"L — dividir",     "color":"RED",   "description":"No es una estimación: es un pedido de partirlo antes de marcarlo ready."}
]'

echo
echo "Campos listos. Falta lo que la API no expone (vistas y automatizaciones):"
echo "  → SETUP-PROJECT.md, en la raíz de este repo."
