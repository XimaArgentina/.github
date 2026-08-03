# Cómo reportar

Hay dos caminos. **Los dos terminan en el mismo lugar** y ninguno te obliga a escribir prolijo.

---

## Camino 1 — el formulario (30 segundos, sin instalar nada)

| Producto | Link |
|---|---|
| **XIAgenda** | https://github.com/XimaArgentina/xiagenda/issues/new/choose |
| **XNómina** | https://github.com/XimaArgentina/xnomina/issues/new/choose |

Elegí **🗣️ Contalo como salga**, escribí lo que pasó, arrastrá las capturas, mandá.
Anda igual desde el celular con la app de GitHub.

Después una IA lo lee, lo reescribe prolijo, lo clasifica y lo pone en el tablero.

**Este es el camino recomendado**, incluso si te sentís cómodo con el Camino 2: no requiere
cuenta paga de nada, funciona offline-ish desde el celular y nunca se rompe.

---

## Camino 2 — hablarle a una IA

Le contás a ChatGPT o a Claude lo que viste, y **la IA crea el ticket sola**. Sirve sobre todo
cuando estás en medio de una conversación con la IA y no querés cortar para ir a GitHub.

Requiere: una cuenta paga de ChatGPT o Claude, y unos 5 minutos de configuración **una sola vez**.

### 2.a Conectar GitHub a tu IA

GitHub publica un servidor MCP remoto. La dirección es:

```
https://api.githubcopilot.com/mcp/
```

**En Claude** (es el camino documentado y probado):

1. Entrá a [claude.ai](https://claude.ai) → tu avatar → **Settings** → **Connectors**.
2. **Add custom connector** → pegá la URL de arriba → **Add**.
3. Te va a pedir iniciar sesión con GitHub (**OAuth**): aceptá.
   No hace falta crear ni guardar ningún token.
4. Autorizá el acceso a la organización **XimaArgentina** cuando te lo pregunte.

> Si usás **Claude Desktop** en vez de la web, es el mismo servidor: Settings → Connectors.

**En ChatGPT**: ⚠️ GitHub **no lista a ChatGPT** entre los clientes soportados de su servidor
MCP. Se puede intentar como *custom connector* (Settings → Connectors, modo desarrollador), pero
**no está verificado que funcione**. Si sos el primero en probarlo, avisá cómo te fue antes de
que lo intente el resto — y si no anda, usá el Camino 1, que es más rápido igual.

### 2.b Darle las reglas de la casa a tu IA

Sin esto la IA arma tickets genéricos que después hay que reescribir. **Pegale este texto** al
empezar (en Claude podés dejarlo fijo como *Project instructions* y no repetirlo nunca más):

````text
Sos mi asistente para reportar problemas y mejoras en los productos de xima.
Tenés acceso a GitHub por MCP.

REPOS
- XIAgenda (turnos para consultorios) -> XimaArgentina/xiagenda
- XNómina (sueldos y recibos)         -> XimaArgentina/xnomina
Si no está claro cuál, preguntame en UNA línea.

ANTES DE CREAR NADA
1. Buscá si ya existe un issue parecido (abierto o cerrado). Si existe, NO crees
   uno nuevo: agregá un comentario con lo que aporto de nuevo y decime cuál era.
2. Faltan dos datos casi siempre y son los que más valen. Si no te los di,
   pedímelos ANTES de crear el issue, juntos y en una sola pregunta:
   - la URL exacta de la barra del navegador donde lo vi
   - con qué usuario y rol estaba (y de qué consultorio/empresa)

CÓMO CREAR EL ISSUE
- Título: <verbo en infinitivo> <objeto concreto> [en <dónde>], en español,
  máximo 80 caracteres. Tiene que decir QUÉ HAY QUE HACER.
  Bien: "Evitar que se dupliquen turnos al guardar dos veces en el picker"
  Mal:  "Bug en turnos" / "Mejorar la UX"
- Cuerpo, exactamente estas secciones y en este orden:

  ## Qué pasa
  ## Qué debería pasar
  ## Reproducción
  ## Criterio de aceptación
  - [ ] (verificable por mí desde la pantalla)
  ## Contexto técnico
  ## Fuera de alcance

  ---
  <details><summary>Texto original del reporte</summary>

  (acá va TEXTUAL lo que yo te escribí, sin editar ni resumir)

  </details>

- Etiquetas: el tipo (`bug`, `feat`, `chore` o `docs`) MÁS la etiqueta `triage`.
  `triage` va SIEMPRE: es lo que hace que el equipo lo revise.
  Agregá `urgente` sólo si te dije que estoy frenado o que hay un cliente afectado.

REGLAS
- Nunca inventes pasos de reproducción, mensajes de error ni datos que no te di.
  Si no lo sé, escribí "no lo pude reproducir" y qué falta para lograrlo.
- Nunca borres ni "mejores" mi texto original: va textual en el <details>.
- No asignes a nadie ni toques el estado del tablero: de eso se encarga el equipo.
- Cuando termines, pasame el link del issue y nada más.
````

### 2.c Si el login con GitHub no te alcanza

Algunos clientes piden un token en vez de OAuth. Si te pasa, creá un
**fine-grained personal access token** (no uno clásico) en
[Settings → Developer settings → Fine-grained tokens](https://github.com/settings/personal-access-tokens/new):

- **Resource owner**: `XimaArgentina`
- **Repository access**: *Only select repositories* → `xiagenda` y `xnomina`
- **Repository permissions**: `Issues` = **Read and write** · `Metadata` = Read
- **Organization permissions**: `Projects` = **Read and write**
- **NO marques `Contents`.**

Ese último punto importa: sin `Contents`, tu IA puede crear y comentar issues pero **no puede
leer el código fuente**. Es el permiso justo, ni uno más.

Puede que el token quede *pendiente de aprobación* por el dueño de la organización. Avisale.

---

## Y después, ¿qué pasa?

```
tu reporte ──▶ Inbox ──▶ la IA lo ordena ──▶ se implementa ──▶ A validar ──▶ Hecho
                                                                   │
                                                             te toca a vos
```

Cuando el cambio llega a staging te llega **un comentario en tu propio issue** con la URL, el
usuario que necesitás y los pasos exactos. Probás y respondés ahí mismo:

- **`ok`** → se cierra cuando salga a producción.
- **`no`** + qué viste → vuelve a la cola con lo que contaste.

**El que reporta es el que valida.** No hace falta asignar nada a nadie.

Tu vista: [🧪 Para validar](https://github.com/orgs/XimaArgentina/projects/1/views/9).

---

## Urgencias

Producción caída o un cliente frenado: **WhatsApp al dueño primero**. Un issue no despierta a
nadie. Después abrilo tildando "esto me impide seguir trabajando".
