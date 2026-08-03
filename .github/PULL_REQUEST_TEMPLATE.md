<!--
  Este template lo completa la IA, no vos. Tres secciones, ninguna opcional.
  La sección "Cómo validarlo" se copia automáticamente al issue cuando esto llega
  a staging: es lo único que el tester va a leer. Escribila para esa persona.
-->

## Qué cambia

<!-- 1 a 3 bullets. Qué hace distinto el sistema después de este merge. -->

Closes #

## Cómo validarlo

<!--
  Pasos numerados, desde el login, con la URL de staging y el rol necesario.
  Si no se puede validar desde la UI, decí explícitamente cómo se verifica
  (comando, log, dato en base) y por qué no hay camino por pantalla.
-->

1.
2.
3. Deberías ver:

## Riesgo

<!--
  Marcá lo que aplique y borrá el resto. Si no aplica ninguno, dejá "Ninguno".
  - Migraciones: <cuáles, y si son reversibles>
  - Feature flag: <nombre, y en qué estado queda>
  - Datos de clientes / pagos / permisos / aislamiento entre tenants
  - Cambia contratos compartidos (llm-saas-core, payments-core, whatsapp-core)
-->

Ninguno.
