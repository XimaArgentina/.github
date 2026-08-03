# `.github` — configuración compartida del ecosistema xima

Este repo no tiene código de producto. Contiene la configuración que **todos** los repos de
`XimaArgentina` heredan automáticamente, y las piezas de la automatización IA-first.

> Existe para resolver un problema concreto: los issue templates sólo tienen efecto desde la
> rama por defecto de un repo, y en `xiagenda`/`xnomina` la rama por defecto es `main`, que
> **deploya a producción en cada push**. Poner los formularios acá evita tocar `main` de los
> repos de producto para cambiar un texto de un formulario.

## Qué hereda cada repo

| Archivo | Efecto |
|---|---|
| `.github/ISSUE_TEMPLATE/*.yml` | Los formularios que ve cualquiera en "New issue" en **cualquier** repo de la org que no tenga los suyos. |
| `.github/ISSUE_TEMPLATE/config.yml` | Desactiva el issue en blanco y agrega los links de contacto. |
| `.github/PULL_REQUEST_TEMPLATE.md` | El cuerpo por defecto de todo PR de la org. |
| `CONTRIBUTING.md` | Cómo se trabaja. Es lo que lee un tester nuevo. |

Un repo que necesite algo distinto pone su propia versión y gana la local.

## Qué NO se hereda

`AGENTS.md` y `CLAUDE.md` **no** son community health files: viven en cada repo y son
específicos de su código. El contrato transversal (ramas, commits, tickets) está en
`CONTRIBUTING.md` y se resume dentro de cada `AGENTS.md`.

## Labels as code

`.github/labels.json` es la única fuente de verdad de las 11 labels del ecosistema.

```bash
.github/scripts/sync-labels.sh                 # aplica a todos los repos de la org
.github/scripts/sync-labels.sh xiagenda        # a uno solo
```

Es idempotente y **destructivo por diseño**: borra de los repos cualquier label que no esté en
el manifiesto. Editar labels a mano en la UI es un no-op: se revierte en el próximo sync.

El workflow `sync-labels.yml` lo corre solo cuando cambia el manifiesto. Necesita el secret
`ORG_ADMIN_TOKEN` (PAT con scope `repo` + `admin:org`) para alcanzar a los demás repos; sin él
sólo toca este repo y deja un warning.

## Por qué 11 labels y no 40

Las labels se multiplican por combinación (`area:*` × `prioridad:*` × `tipo:*` = decenas) y
nadie las mantiene. Acá las labels sólo llevan lo que tiene que ser **filtrable desde afuera del
tablero y desde la línea de comandos** (`gh issue list -l ready`); todo el resto — producto,
área, prioridad, tamaño — vive como campo del GitHub Project, donde no hay combinatoria y donde
un cambio de taxonomía no toca ningún issue.
