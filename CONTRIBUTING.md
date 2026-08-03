# Cómo trabajamos en xima

> Vale para **todos** los repos de la organización. Si un repo dice otra cosa, manda el repo.

La regla que explica todo lo demás:

> **Ningún humano formatea tickets. Los humanos aportan observación y criterio; la IA aporta
> estructura y ejecución.**

Si algo de este documento te obliga a hacer trabajo administrativo, está mal escrito: avisá.

---

## Si sos tester o Product Owner

Hacés dos cosas. Nada más.

### 1. Reportar

Abrís un issue en el repo del producto que estabas usando:

| Producto | Reportar acá |
|---|---|
| XIAgenda (turnos) | https://github.com/XimaArgentina/xiagenda/issues/new/choose |
| XNómina (sueldos) | https://github.com/XimaArgentina/xnomina/issues/new/choose |

Guardate esos dos links. Es lo único que tenés que recordar.

> ¿Preferís **dictárselo a una IA** en vez de llenar un formulario? Se puede: conectás GitHub a
> ChatGPT o Claude una sola vez y después le contás el problema y ella crea el ticket.
> Guía completa: **[REPORTAR-CON-IA.md](REPORTAR-CON-IA.md)**.

#### Contalo como salga

Elegí **🗣️ Contalo como salga** salvo que ya sepas exactamente cómo reproducir el problema.
Escribí como le contarías a un compañero, pegá capturas, no ordenes nada. Una IA lo lee, lo
reescribe prolijo, lo clasifica, le pone etiquetas y lo pone en el tablero.

Dos datos valen más que todo el resto:

- **La URL** de la barra del navegador donde lo viste.
- **Con qué usuario estabas** (rol y consultorio/empresa). El sistema hace cosas distintas
  según quién sos, así que "no anda" sin el usuario no se puede reproducir.

Si te equivocaste de repo, no pasa nada: el ticket se mueve solo.

### 2. Validar

Cuando algo pasa a la columna **A validar** del tablero, ya está en staging y te toca probarlo.
El issue va a tener un comentario con los pasos exactos y el link. Probás y respondés en el
mismo issue:

- **`ok`** (o cualquier confirmación) → se cierra.
- **`no`** + qué pasó → vuelve a la cola con lo que contaste.

**El que reporta es el que valida.** No hace falta asignar a nadie: es la convención.

> Si nunca te llega nada para validar, algo está roto en el proceso. Decilo.

### Urgencias

Producción caída o un cliente frenado: avisá por WhatsApp **primero**, y después abrí el issue
tildando "esto me impide seguir trabajando". Un issue no despierta a nadie.

---

## Las etiquetas (11, y no van a ser más)

No tenés que ponerlas vos: las pone la IA. Están acá para que entiendas el tablero.

**Qué es** (siempre exactamente una): `bug` · `feat` · `chore` · `docs` · `epic`

**En qué estado está** (las pone la IA):

| Etiqueta | Significa |
|---|---|
| `triage` | Reporte crudo. La IA todavía no lo procesó. |
| `ready` | Spec completa. Claude Code puede implementarlo **sin preguntarle nada a nadie**. |
| `needs-info` | Falta un dato que sólo un humano tiene. Si te mencionan acá, respondé. |
| `blocked` | Depende de algo externo (Meta, un proveedor, una decisión del dueño). |

**Señales**: `urgente` (se toma ahora) · `regression` (antes funcionaba)

`ready` es la etiqueta central de todo el sistema: es el contrato entre "un humano dijo algo"
y "una máquina puede actuar". Un issue sin `ready` no se toma; un issue con `ready` no necesita
una conversación previa.

Todo lo demás — producto, área, prioridad, tamaño — vive como **campo del tablero**, no como
etiqueta. Las etiquetas se multiplican; los campos no.

---

## El tablero

https://github.com/orgs/XimaArgentina/projects — una sola columna importa por actor:

```
Inbox ──▶ Listo ──▶ En curso ──▶ En revisión ──▶ A validar ──▶ Hecho
  │          │          │             │              │
 IA         IA      Claude Code   Claude Code     ┌────────┐
                                                  │ TESTER │
                                                  └────────┘
```

**A validar es la única columna donde el cuello de botella es un humano.** Si crece, el problema
no es la velocidad de desarrollo.

---

## Si programás (vos o una IA)

El contrato operativo completo está en el `AGENTS.md` de cada repo. Resumen:

- **Ramas**: `feat/…`, `fix/…`, `chore/…`, `docs/…` — en inglés, kebab-case, salen de `dev`.
- **Commits y PRs**: en **inglés**. Copy de cara al usuario en español (es_AR, voseo, vía `__()`).
- **Cada PR cierra un issue**: `Closes #123` en el cuerpo. Sin eso, el tablero no se mueve solo.
- **Flujo**: `feature → dev → staging → main`, siempre por PR o por el helper `land`.
- La sección **"Cómo validarlo"** del PR se copia al issue cuando llega a staging. Escribila
  pensando en el tester, no en vos.

### Convención de títulos de issue

```
<verbo en infinitivo> <objeto concreto> [en <dónde>]
```

`Evitar que se dupliquen turnos al guardar dos veces en el picker`

No: "Bug en turnos", "Mejorar la UX", "Problema con WhatsApp". Un título que no dice qué hay que
hacer obliga a abrir el issue para saber si es relevante — y eso, con cientos de issues, es el
costo real.

---

## Urgencias

1. WhatsApp al dueño.
2. Issue con el tilde de "me impide trabajar" (queda `urgente`).
3. El arreglo sale de `main`, no de `dev`.
