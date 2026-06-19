# claude-pilot

> Control remoto para Claude Code — úsalo desde tu teléfono sin estar frente a la computadora.

## El concepto

Un televisor tiene todos sus controles directamente en él. Pero nadie quiere levantarse cada vez que quiere cambiar el canal — para eso existe el control remoto: una interfaz mínima que expone solo los botones que necesitas, desde donde estés.

**claude-pilot es el control remoto de tu Claude Code.**

La computadora corre Claude Code con todo su poder. El teléfono es el control: escribes un prompt, lo mandas, ves la respuesta llegar, apruebas o rechazas acciones — sin sentarte frente al escritorio.

No es Claude Code en el teléfono. Es una interfaz mínima que facilita la comunicación a distancia sobre la red local vía SSH.

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   📱 Teléfono (claude-pilot)                        │
│   ┌─────────────────────────┐                       │
│   │  > Refactoriza el módulo│  ← escribes aquí      │
│   │    de autenticación     │                       │
│   │                         │                       │
│   │  ✓ Editando auth.ts...  │  ← ves el output      │
│   │  ✓ Tests pasando        │                       │
│   │                         │                       │
│   │  [Aprobar] [Rechazar]   │  ← controlas acciones │
│   └─────────────────────────┘                       │
│              │ SSH / Red local                      │
│              ▼                                      │
│   🖥️  Computadora (Claude Code corriendo)           │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Funcionalidades planeadas

- **Enviar prompts** — caja de texto simple, historial de prompts recientes
- **Ver output en tiempo real** — streaming de la respuesta mientras Claude trabaja
- **Aprobar/rechazar acciones** — cuando Claude pide permiso para editar archivos, ejecutar comandos, etc.
- **Estado de sesión** — qué archivo está editando, en qué directorio está la sesión
- **Sesiones múltiples** — cambiar entre proyectos abiertos en la PC
- **Reconexión automática** — si la red cae, el app reconecta sin perder contexto

## Arquitectura

```
claude-pilot/
├── app/                  # App móvil Flutter
│   ├── lib/
│   │   ├── screens/      # Pantallas: conexión, sesión, historial
│   │   ├── services/     # SSH client, stream parser
│   │   ├── widgets/      # Terminal output, prompt input, action cards
│   │   └── models/       # Session, Message, Action
│   └── pubspec.yaml
│
├── bridge/               # Proceso ligero en la PC (opcional)
│   ├── src/
│   │   ├── server.ts     # WebSocket/HTTP local que envuelve Claude Code
│   │   ├── session.ts    # Gestión de sesiones
│   │   └── parser.ts     # Parsea output de Claude Code (permisos, estado)
│   └── package.json
│
└── docs/
    ├── setup.md          # Cómo configurar SSH en la PC
    └── architecture.md   # Decisiones de diseño
```

## Cómo funciona

1. Claude Code corre normalmente en la PC
2. El `bridge` (proceso Node ligero) corre en la PC y expone una API local
3. El app Flutter se conecta vía SSH o directamente al bridge en la red local
4. Los prompts van de teléfono → bridge → Claude Code
5. El output de Claude Code va de vuelta → bridge → teléfono en tiempo real

## Stack

| Capa | Tecnología |
|------|-----------|
| App móvil | Flutter (Dart) |
| Comunicación | SSH directo (`dartssh2`) o WebSocket local |
| Bridge PC | Node.js / TypeScript |
| Protocolo de red | Red local (Wi-Fi) — sin internet requerido |

## Setup (próximamente)

El objetivo es que la configuración sea mínima:

```bash
# En la PC
npx claude-pilot-bridge

# En el teléfono
# Abre el app → escanea QR o ingresa IP local → listo
```

## Estado

🚧 En diseño inicial — definiendo protocolo de comunicación y MVP de la app.
