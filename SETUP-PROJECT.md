# El tablero — cómo está armado y por qué

Un solo Project de organización para todo el ecosistema. Los issues viven en el repo de su
producto (ahí es donde un `Closes #N` cierra solo y donde una IA tiene el código al lado); el
tablero es la única vista transversal.

**Campos y vistas**: `.github/scripts/setup-project.sh` (idempotente, corré cuando quieras).
Crea y actualiza los campos con sus opciones y colores, y las 6 vistas con su nombre, layout,
filtro y columnas visibles.

**Lo único que queda a mano** (la API de Projects v2 no lo expone): el *group by* y el *sort by*
de cada vista, y los workflows del tablero. Son ~5 minutos, una sola vez.

> Dos rarezas de la API, por si el script parece hacer cosas de más:
> - El campo `Priority` que trae el template **no se puede actualizar** (`Only custom fields can
>   be updated`). El script lo borra y crea `Prioridad` propio.
> - Al renombrar las opciones de `Status` se **preservan los IDs** de `Todo`/`In progress`/`Done`
>   → los workflows que ya venían activos siguen enganchados en vez de quedar huérfanos.

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

## Vistas

El script crea nombre, layout, filtro y columnas visibles. El `Group by` / `Sort by` **no está
en la API** y se puso a mano (queda persistido; si recreás el project, hay que rehacerlo).
Cada vista tiene un dueño: una vista que nadie abre es deuda.

| Vista | Dueño | Filtro | Group / Sort |
|---|---|---|---|
| **📥 Inbox** | la IA | `is:open label:triage` | — · `Created` ↑ |
| **🤖 Cola de la IA** | Claude Code | `is:open label:ready -label:blocked no:assignee` | `Prioridad` · `Created` ↑ |
| **🎯 Tablero** | el dueño | `is:open -status:Descartado` | `Status` · — |
| **🧪 Para validar** | los testers | `status:"A validar"` | — · `Updated` ↑ |
| **🚧 Trabado** | el dueño | `is:open label:blocked,needs-info` | — · `Updated` ↑ |
| **🗺️ Mapa por área** | el dueño | `is:open` | `Área` · `Prioridad` ↑ |

Por qué cada una:

- **📥 Inbox** — la cola de `/triage`. Debería estar vacía casi siempre; si crece, el triage no
  está corriendo.
- **🤖 Cola de la IA** — **la vista más importante del tablero**: es literalmente lo que Claude
  Code lee para decidir qué hacer. Ordenar por antigüedad *dentro* de cada prioridad hace que la
  cola drene en vez de revolverse. `no:assignee` evita que dos sesiones tomen lo mismo.
- **🎯 Tablero** — filtrar los cerrados es lo que lo mantiene legible con cientos de issues. El
  histórico se consulta con búsqueda, no scrolleando una columna de 400 tarjetas.
- **🧪 Para validar** — ordenada por *lo más viejo primero*: lo que lleva más tiempo esperando
  validación es lo que más riesgo tiene de romperse otra vez antes de que alguien lo mire.
  **Es el link que se guardan los testers**; si sólo van a abrir una vista, es esta.
- **🚧 Trabado** — para que nada quede trabado en silencio. Una mirada por semana alcanza.
- **🗺️ Mapa por área** — se abre para decidir qué construir, no en el día a día. Un área con 30
  issues abiertos casi nunca son 30 problemas: es un problema de fondo mal identificado.

---

## Automatizaciones del Project (`⋯ → Workflows`)

**No hay API para crear ni configurar workflows del tablero** (`deleteProjectV2Workflow` existe;
crear y actualizar, no). Se configuraron a mano. Estado actual — **8 activos**:

| Workflow | Configuración | Por qué |
|---|---|---|
| **Auto-add to project** | repo `xiagenda` · filtro `is:issue` | Nadie tiene que acordarse de agregar la tarjeta. Si depende de que alguien la agregue, el tablero miente. |
| **Item added to project** | `Status` = `Inbox` | Todo entra por un solo lugar. |
| **Item reopened** | `Status` = `Listo` | Un issue reabierto es trabajo pendiente, no algo para analizar de cero. |
| **Pull request linked to issue** | `Status` = `En curso` | Hay rama y PR: alguien está trabajando. |
| **Item closed** | `Status` = `Hecho` | Cerrar en GitHub y cerrar en el tablero son el mismo acto. |
| **Auto-close issue** | `Status` = `Hecho` → cerrar | El inverso: arrastrar una tarjeta a Hecho cierra el issue. |
| **Auto-archive items** | `is:issue is:closed updated:<@today-1m` | Lo que mantiene el tablero rápido con cientos de issues. Archivar no borra: el issue sigue en el repo. |
| **Auto-add sub-issues** | por defecto | Un `epic` arrastra a sus hijos al tablero. |

**Desactivados a propósito**: `Pull request merged` (lo maneja `ticket-flow.yml`, que distingue
dev / staging / main — dejar los dos pisándose es la forma más rápida de que el tablero mienta),
`Code review approved` y `Code changes requested` (con un solo implementador no dicen nada).

> Al renombrar las opciones de `Status` el script preservó los IDs de `Todo`/`In progress`/`Done`,
> así que `Item added`, `Item closed` y `Pull request linked` quedaron apuntando solos a
> `Inbox` / `Hecho` / `En curso`. Verificado uno por uno.

### El límite del plan Free (y por qué existe `project-sweep.yml`)

**El plan Free permite UN solo workflow `Auto-add to project` por Project**
(`Maximum number of auto-add workflows reached`). Ese cupo está usado por `xiagenda`.

Sin nada más, los issues de **xnomina** —y de cualquier repo que sumemos— nunca aparecerían en el
tablero. Un tablero incompleto es peor que no tener tablero: te hace creer que ya miraste todo.

La solución es `.github/workflows/project-sweep.yml`: cada 15 minutos, en el runner self-hosted,
busca `-project:XimaArgentina/1` en cada repo de la lista y agrega lo que falte. Es idempotente,
no gasta minutos de Actions, y **escala sin tocar el plan**: repo nuevo = una palabra más en
`DEFAULT_REPOS`.

El resto del movimiento (`En revisión` → `A validar` → `Hecho`) lo hace `ticket-flow.yml` en cada
repo de producto, a partir del `Closes #N` del PR. Ver abajo.

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

Las variables ya están puestas (`STAGING_URL` por repo, `PROJECT_TITLE` a nivel org):

```bash
gh variable list --org XimaArgentina
gh variable list --repo XimaArgentina/xiagenda
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
