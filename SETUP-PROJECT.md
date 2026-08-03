# El tablero — cómo está armado y por qué

Un solo Project de organización para todo el ecosistema. Los issues viven en el repo de su
producto (ahí es donde un `Closes #N` cierra solo y donde una IA tiene el código al lado); el
tablero es la única vista transversal.

**Campos**: `.github/scripts/setup-project.sh` (idempotente, corré cuando quieras).
**Vistas y automatizaciones**: a mano — la API de Projects v2 no expone mutaciones para
ninguna de las dos. Es 10 minutos, una sola vez.

---

## Las columnas (campo `Status`)

Una columna por **quién está bloqueado**. Si dos estados los destraba la misma persona con la
misma acción, son la misma columna. Por eso no hay "En análisis", "Priorizado" ni "Listo para
QA": nadie hace nada distinto en esos estados.

| Columna | Quién tiene la pelota | Qué falta |
|---|---|---|
| **Inbox** | la IA | Normalizar el reporte, o falta una decisión del dueño |
| **Listo** | la IA | Nada. Hay `ready`, se puede tomar ya |
| **En curso** | la IA | Se está implementando |
| **En revisión** | la IA | PR abierto o mergeado a `dev`; falta salir a staging |
| **A validar** | **el tester** | Está en staging: probarlo |
| **Hecho** | nadie | En producción y validado |
| **Descartado** | nadie | El comentario de cierre dice por qué |

> **A validar es la única columna donde el cuello de botella es un humano.** Si crece, el
> problema del equipo no es la velocidad de desarrollo. Ese es todo el valor de separarla.

## Los campos y por qué no son labels

| Campo | Por qué campo y no label |
|---|---|
| **Producto** | El repo no alcanza: un cambio en `payments-core` se hace *para* XIAgenda. |
| **Área** | Como label serían 12 `area:*` que se combinan con todo lo demás. Como campo son una columna que se agrupa y se cambia sin tocar el issue. |
| **Prioridad** | Sólo 3 valores. Con un dev, "cuarta prioridad" y "backlog" son indistinguibles; fingir que no lo son es trabajo administrativo puro. |
| **Tamaño IA** | La unidad real no es la hora-hombre: es **la sesión de contexto**. `L` no es una estimación, es un pedido de partir la tarea antes de marcarla `ready`. |

Las labels quedaron sólo con lo que tiene que ser filtrable **desde afuera del tablero**
(`gh issue list -l ready`, notificaciones, búsqueda cross-repo). Todo lo demás vive acá.

---

## Vistas (crear a mano — `+ New view`)

Cada vista tiene un dueño. Una vista que nadie abre es deuda.

### 1. 📥 Inbox — *dueño: la IA*
- **Layout** Table · **Filter** `is:open label:triage` · **Sort** `Created` ascendente
- **Campos visibles** Title, Repository, Assignees, Created
- Es la cola de `/triage`. Debería estar vacía casi siempre; si crece, el triage no está corriendo.

### 2. 🤖 Cola de la IA — *dueño: Claude Code*
- **Layout** Table · **Filter** `is:open label:ready -label:blocked no:assignee`
- **Group by** `Prioridad` · **Sort** `Created` ascendente
- **Campos** Title, Producto, Área, Tamaño IA, Repository
- **La vista más importante del tablero.** Es literalmente lo que Claude Code lee para decidir
  qué hacer. Ordenar por antigüedad dentro de cada prioridad hace que la cola drene en vez de
  revolverse.

### 3. 🎯 Tablero — *dueño: el dueño del producto*
- **Layout** Board · **Group by** `Status`
- **Filter** `is:open -status:Descartado`
- **Campos en la tarjeta** Prioridad, Producto, Tamaño IA
- Filtrar los cerrados es lo que mantiene el tablero legible con cientos de issues. El histórico
  se consulta con búsqueda, no scrolleando una columna de 400 tarjetas.

### 4. 🧪 Para validar — *dueño: los testers*
- **Layout** Table · **Filter** `status:"A validar"` · **Sort** `Last updated` ascendente
- **Campos** Title, Assignees, Producto, Last updated
- Ordenado por *lo más viejo primero*: lo que lleva más tiempo esperando validación es lo que
  más riesgo tiene de volver a romperse antes de que alguien lo mire.
- **Este es el link que se guardan los testers.** Si sólo van a abrir una vista, es esta.

### 5. 🚧 Trabado — *dueño: el dueño del producto*
- **Layout** Table · **Filter** `is:open label:blocked,needs-info` · **Sort** `Last updated` asc
- Existe para que nada quede trabado en silencio. Revisarla una vez por semana alcanza.

### 6. 🗺️ Mapa por área — *dueño: el dueño del producto*
- **Layout** Table · **Filter** `is:open` · **Group by** `Área` · **Sort** `Prioridad`
- Se abre cuando hay que decidir qué construir, no en el día a día. Un área con 30 issues
  abiertos casi nunca son 30 problemas: es un problema de fondo mal identificado.

---

## Automatizaciones del Project (`⋯ → Workflows`)

Todas vienen desactivadas por defecto. Activá estas cinco:

| Workflow | Configuración | Por qué |
|---|---|---|
| **Auto-add to project** | Repos `xiagenda`, `xnomina` · filtro `is:issue is:open` | Nadie tiene que acordarse de agregar la tarjeta. Si depende de que alguien la agregue, el tablero miente. |
| **Item added to project** | Set `Status` = `Inbox` | Todo entra por un solo lugar. |
| **Item reopened** | Set `Status` = `Listo` | Un issue reabierto es trabajo pendiente, no algo por analizar de cero. |
| **Item closed** | Set `Status` = `Hecho` | Cerrar en GitHub y cerrar en el tablero tienen que ser el mismo acto. |
| **Auto-archive items** | `status:Hecho updated:<@today-30d` | Lo que mantiene el tablero rápido con cientos de issues. Archivar no borra: sigue en el repo. |

El resto del movimiento (`En revisión` → `A validar` → `Hecho`) lo hace el workflow
`ticket-flow.yml` de cada repo de producto, a partir del `Closes #N` del PR. Ver más abajo.

> **Auto-add** sólo acepta un repo por workflow: hay que crear uno por repo.

---

## Lo que mueve las tarjetas solo

`ticket-flow.yml` (en `xiagenda` y `xnomina`) reacciona a los pushes y lee el `Closes #N` del PR:

```
push a dev      →  "En revisión"  + comentario "integrado, falta staging"
push a staging  →  "A validar"    + copia al issue los pasos de "Cómo validarlo" del PR,
                                    mencionando a quien lo reportó
push a main     →  "Hecho"        + cierra el issue
```

Es `push` y no `pull_request` a propósito: a `dev` también se llega por
`infra/<producto>-dev land`, que mergea local sin PR.

**Requiere el secret de organización `PROJECTS_TOKEN`** — un PAT clásico con scope `project`
(los tokens de Actions no pueden escribir en Projects v2). Sin él, el workflow comenta igual y
deja un warning: nunca falla el build.

```bash
gh secret set PROJECTS_TOKEN --org XimaArgentina --visibility all
```

Y la URL de staging, para que el comentario le diga al tester dónde probar:

```bash
gh variable set STAGING_URL --repo XimaArgentina/xiagenda --body "https://…"
gh variable set PROJECT_TITLE --org XimaArgentina --body "<título exacto del project>"
```

---

## Acceso de los testers

Un tester necesita **rol `Triage`** en el repo del producto (abrir issues, etiquetar, cerrar) y
**`Write` en el Project** (para poder responder y que sus cambios de estado valgan). No necesita
acceso al código.

```bash
gh api -X PUT repos/XimaArgentina/xiagenda/collaborators/<user> -f permission=triage
gh api -X PUT repos/XimaArgentina/xnomina/collaborators/<user>  -f permission=triage
# El acceso al Project se da desde  Project → ⋯ → Settings → Manage access
```

---

## Cuando sean 10 devs y 20 testers

Nada de esto cambia de forma:

- **Las labels ya son código** (`labels.json` + `sync-labels.sh`): un repo nuevo hereda las 11 y
  nadie inventa las suyas.
- **Los formularios ya son de la organización** (`.github/ISSUE_TEMPLATE/`): se cambian una vez.
- **`ready` ya es el contrato**: con 20 testers el cuello de botella pasa a ser el triage, y el
  triage es lo único que ya está automatizado.
- **La cola de la IA ya está ordenada por prioridad**: con 10 devs, cada uno corre `/tomar` y
  saca de la misma cola sin coordinar.
- Lo único que hay que agregar el día que crezca: **`Assignees` como filtro en la vista 2** (hoy
  sobra, con un solo implementador) y una vista por dev si alguien la pide. Nada más.

Lo que **no** hay que agregar aunque el equipo crezca: sprints, story points, sub-estados de
revisión, y labels por componente. Todo eso es coordinación entre humanos, y acá la coordinación
la hace la cola.
