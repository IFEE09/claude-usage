# Claude Usage

App de barra de menús para macOS que muestra los límites de uso de tu cuenta de Claude
(los mismos de claude.ai → Ajustes → Uso): sesión de 5 h, semanal, etc.

## Compilar

    ./build.sh

Genera `build/ClaudeUsage.dmg`. Ábrelo y arrastra **Claude Usage** a Aplicaciones.
La primera vez: clic derecho → **Abrir** (la app no está firmada por Apple).

## Cómo funciona

- Inicias sesión en claude.ai dentro de la app; la sesión se guarda como en un navegador.
- Cada 5 minutos (y al abrir el menú) consulta el endpoint interno que usa la página de uso.
- Ese endpoint no es oficial: si Anthropic lo cambia, hay que ajustar `UsageStore.swift`.
