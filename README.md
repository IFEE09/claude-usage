# Claude Usage

App de barra de menús para macOS que muestra los límites de uso de tu cuenta de Claude:
los mismos que ves en claude.ai → Ajustes → Uso (sesión de 5 h, semanal, por modelo, etc.).

> **Proyecto no oficial.** No está afiliado, respaldado ni patrocinado por Anthropic.
> "Claude" es una marca de Anthropic, PBC. Lee el [aviso](#aviso) antes de usarla.

*English: an unofficial macOS menu bar app that shows your claude.ai usage limits
(5-hour session, weekly, per model). You sign in to claude.ai inside the app, and it
reads the same data as the claude.ai usage page. Everything stays on your Mac.
Licensed under Apache 2.0. UI in Spanish.*

## Qué hace

- Muestra en la barra de menús el % usado de la sesión actual (5 h).
- Al abrir el menú, ves cada límite con su barra de progreso y cuándo se reinicia.
  La barra se pone naranja desde el 75 % y roja desde el 90 %.
- Se actualiza sola: cada minuto mientras el uso cambia, cada vez menos seguido (hasta
  cada 5 minutos) si no cambia, al abrir el menú, al despertar el Mac y justo después
  de que se reinicia un límite.
- Opción para abrirse al iniciar sesión en el Mac.

## Requisitos

- macOS 13 (Ventura) o posterior.
- Para compilar: Swift 5.9 o posterior (Xcode o las Command Line Tools:
  `xcode-select --install`).

## Compilar e instalar

    git clone https://github.com/IFEE09/claude-usage.git
    cd claude-usage
    ./build.sh

Esto genera `build/Claude Usage.app` y `build/ClaudeUsage.dmg`. Abre el DMG y arrastra
**Claude Usage** a Aplicaciones.

Para compilar e instalar directo en /Applications (cierra y reemplaza la versión anterior):

    ./build.sh --install

La primera vez que se abre desde Aplicaciones, la app se configura para abrirse al iniciar
sesión en el Mac. Puedes desactivarlo desde su menú.

**Si recibiste el DMG de otra persona:** la app solo tiene una firma ad-hoc y no está
notarizada por Apple, así que macOS la bloqueará la primera vez. Ábrela, cierra el aviso y
ve a Ajustes del Sistema → Privacidad y seguridad → **Abrir de todos modos**. Solo instala
compilaciones de fuentes en las que confíes; lo más seguro es compilarla tú.

## Cómo funciona

1. Inicias sesión en claude.ai en una ventana dentro de la app (correo, Google o Apple).
   La app nunca ve tu contraseña: el login lo hace la página oficial de claude.ai.
2. La sesión (cookies) se guarda en el almacenamiento WebKit propio de la app, igual que
   en un navegador.
3. Un `WKWebView` oculto consulta `claude.ai/api/organizations` y
   `claude.ai/api/organizations/{id}/usage`, los mismos endpoints que usa la página de uso.
4. "Cerrar sesión" borra todos los datos web de la app.

### Privacidad

- La app solo se conecta a `claude.ai` (y a los proveedores de login que elijas en la
  ventana de inicio de sesión).
- No tiene analíticas ni telemetría y no envía datos a terceros.
- No lee ni guarda tus conversaciones: solo los porcentajes de uso.
- En `UserDefaults` solo guarda el ID de la organización elegida y si ya se configuró el
  inicio automático.

## Estructura

| Archivo | Qué hace |
|---|---|
| `Sources/ClaudeUsage/ClaudeUsageApp.swift` | Punto de entrada; el ícono y el texto de la barra de menús. |
| `Sources/ClaudeUsage/MenuView.swift` | El panel que se abre desde la barra de menús. |
| `Sources/ClaudeUsage/UsageStore.swift` | Estado, refresco adaptativo, lectura de los límites e inicio automático. |
| `Sources/ClaudeUsage/ClaudeClient.swift` | Peticiones a claude.ai desde un `WKWebView` oculto. |
| `Sources/ClaudeUsage/LoginWindowController.swift` | Ventana de inicio de sesión y sus ventanas emergentes (Google / Apple). |
| `scripts/make_icon.swift` | Dibuja el ícono de la app. |
| `build.sh` | Compila, arma el `.app`, lo firma ad-hoc y crea el DMG. |

## Aviso

- **No oficial.** Los endpoints que usa la app son internos de claude.ai y no están
  documentados. Anthropic puede cambiarlos en cualquier momento y la app dejaría de
  funcionar hasta ajustar `UsageStore.swift`.
- **Tu cuenta, tu responsabilidad.** La app consulta claude.ai de forma automática con tu
  sesión, como máximo una vez por minuto. Revisa los
  [Términos de Anthropic](https://www.anthropic.com/legal/consumer-terms) y decide si
  quieres usarla. Los autores no se hacen responsables de ninguna consecuencia sobre tu
  cuenta.
- Se ofrece "tal cual", sin garantías (ver la licencia).

## Contribuir

Issues y pull requests son bienvenidos. Si Anthropic cambia la respuesta del endpoint de
uso, lo más probable es que solo haya que ajustar `parseLimits` y `title(for:)` en
`UsageStore.swift`.

## Licencia

[Apache License 2.0](LICENSE). Proyecto gratuito y sin fines de lucro.
