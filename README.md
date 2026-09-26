# Claude Usage

App de barra de menús para macOS que muestra los límites de uso de tu cuenta de Claude
(los mismos de claude.ai → Ajustes → Uso): sesión de 5 h, semanal, etc.

## Compilar

    ./build.sh

Genera `build/ClaudeUsage.dmg`. Ábrelo y arrastra **Claude Usage** a Aplicaciones.
La primera vez: clic derecho → **Abrir** (la app no está firmada por Apple).

## Cómo funciona

- Inicias sesión en claude.ai dentro de la app; la sesión se guarda como en un navegador.
- Consulta el endpoint interno que usa la página de uso: cada minuto mientras el uso cambia,
  espaciando hasta cada 5 minutos si no cambia, al abrir el menú, al despertar el Mac
  y justo después de que se reinicia un límite.
- Ese endpoint no es oficial: si Anthropic lo cambia, hay que ajustar `UsageStore.swift`.
