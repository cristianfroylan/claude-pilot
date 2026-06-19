# claude-pilot — Spec inicial

## Visión

Control remoto móvil para Claude Code. La computadora corre Claude Code con todo su poder; el teléfono es una interfaz mínima y familiar que facilita la comunicación a distancia sobre la red local. No reemplaza la terminal — la hace accesible desde el sofá.

---

## Pantallas

### 1. Machine Manager (Home)

La pantalla de inicio es un administrador de máquinas. Desde aquí gestionas todas las conexiones guardadas.

```
┌─────────────────────────────┐
│  claude-pilot           [+] │
├─────────────────────────────┤
│  🟢 Escritorio              │
│     192.168.1.10 · SSH 22   │
│                  [Conectar] │
├─────────────────────────────┤
│  ⚪ Laptop trabajo          │
│     192.168.1.25 · SSH 22   │
│                  [Conectar] │
├─────────────────────────────┤
│  🔴 Servidor local          │
│     192.168.1.50 · SSH 2222 │
│               [Sin conexión]│
└─────────────────────────────┘
```

**Datos por máquina:**
- Nombre (ej. "Escritorio", "Laptop trabajo")
- IP local
- Puerto SSH (default: 22)
- Usuario
- Contraseña o llave SSH

**Estados:**
- 🟢 Conectado — sesión activa
- ⚪ Disponible — ping OK, sin sesión
- 🔴 Sin conexión — no responde

**Acciones:**
- `[+]` Agregar máquina nueva
- Tap en máquina → conectar / abrir sesión activa
- Long press → editar / eliminar

---

### 2. Sesión / Terminal View

La pantalla central del app. Una vez conectado, ves el output de Claude Code tal como aparece en tu monitor.

```
┌─────────────────────────────┐
│  ← Escritorio       [·][≡] │  ← header: máquina, estado, menú
├─────────────────────────────┤
│                             │
│  Welcome back Cristian!     │  ← output terminal con colores ANSI
│                             │
│  ● Refactorizando auth...   │
│    ├ Update(src/auth.ts)    │
│    │ -import { old }        │  ← rojo
│    │ +import { new }        │  ← verde
│    └ 2 files changed        │
│                             │
│  ✓ Tests pasando            │  ← verde
│                             │
│  ⚡ Aprobar acción?         │  ← card de permiso (ver abajo)
│  Editar: src/hooks/useX.ts  │
│         [Aprobar] [Rechazar]│
│                             │
├─────────────────────────────┤
│  [Comandos ↑]               │  ← panel colapsable
├─────────────────────────────┤
│  🎤  [_____prompt_____] [▶] │  ← barra de input
└─────────────────────────────┘
```

**Requisitos del terminal:**
- Renderizado de colores ANSI completo (rojo, verde, naranja, cyan, blanco, gris)
- Scroll hacia arriba para ver historial
- Fuente monospace (misma sensación que la terminal real)
- Fondo oscuro (#1a1a1a o similar al tema de Claude Code)
- Texto que no se corta — wrap correcto en pantalla angosta

---

### 3. Barra de input

Siempre visible en la parte inferior de la sesión.

```
┌──────────────────────────────────────┐
│  🎤  │  Escribe un prompt...  │  [▶] │
└──────────────────────────────────────┘
```

- **🎤 Dictado** — mantener presionado → graba voz → suelta → transcribe a texto en el campo. El texto queda editable antes de enviar. No envía automáticamente.
- **Campo de texto** — teclado nativo del teléfono. Soporta múltiples líneas (prompts largos).
- **[▶] Enviar** — manda el texto como input a la terminal (Enter).

---

### 4. Panel de comandos rápidos

Panel colapsable que aparece deslizando hacia arriba desde la barra de input. Contiene los controles que más usas sin tener que tipearlos.

```
┌────────────────────────────────────────┐
│  SEÑALES DE CONTROL                    │
│  [Ctrl+C]  [Ctrl+D]  [\q]  [q]  [ESC] │
├────────────────────────────────────────┤
│  CLAUDE — slash commands               │
│  [/help]  [/clear]  [/compact]         │
│  [/gsd]   [/cost]   [/status]          │
│  [+ Personalizar]                      │
├────────────────────────────────────────┤
│  NAVEGACIÓN                            │
│  [cd ~]  [cd ..]  [ls]  [pwd]          │
│  [↑ historial]  [↓ historial]          │
├────────────────────────────────────────┤
│  SESIÓN                                │
│  [claude]   [claude .]   [exit]        │
└────────────────────────────────────────┘
```

**Secciones:**

**Señales de control** — las más críticas, siempre visibles primero:
- `Ctrl+C` — interrumpir proceso en curso
- `Ctrl+D` — cerrar sesión / EOF
- `\q` — salir de vistas tipo less/man
- `q` — salir de vistas interactivas
- `ESC` — cancelar

**Claude slash commands** — comandos frecuentes de Claude Code:
- `/help`, `/clear`, `/compact`, `/gsd`, `/cost`, `/status`
- Sección personalizable: el usuario puede agregar sus propios slash commands

**Navegación** — comandos de shell comunes:
- `cd ~`, `cd ..`, `ls`, `pwd`
- Flechas de historial (equivalente a ↑↓ en terminal)

**Sesión** — iniciar o salir de Claude Code:
- `claude` — inicia Claude Code en el directorio actual
- `claude .` — inicia en directorio actual explícito
- `exit` — cierra la sesión shell

---

### 5. Cards de acción / permiso

Cuando Claude Code pide permiso para hacer algo (editar un archivo, ejecutar un comando), aparece una card destacada en el terminal con botones de aprobación.

```
┌─────────────────────────────────────┐
│  ⚡ Claude quiere ejecutar:         │
│                                     │
│  npm run build                      │
│                                     │
│         [Rechazar]  [Aprobar]       │
└─────────────────────────────────────┘
```

- La card aparece sobre el scroll del terminal, no lo bloquea
- Tap en **Aprobar** → envía `y` + Enter
- Tap en **Rechazar** → envía `n` + Enter
- Desaparece una vez respondida

---

## Flujo principal

```
Abrir app
    │
    ▼
Machine Manager
    │
    ├─ [Agregar máquina] → formulario → guardar → volver
    │
    └─ [Conectar] → establecer SSH
            │
            ▼
        Terminal View
            │
            ├─ Ver output en tiempo real
            ├─ Escribir prompt → enviar
            ├─ Dictar prompt → transcribir → editar → enviar
            ├─ Panel comandos → tap comando → ejecutar
            └─ Aprobar/rechazar acción de Claude
```

---

## Requisitos técnicos

| Área | Decisión |
|------|----------|
| Plataforma app | Flutter (iOS + Android desde un solo codebase) |
| Protocolo | SSH directo (`dartssh2`) |
| Renderizado terminal | Parser ANSI + widget custom (colores, scroll, monospace) |
| Dictado | `speech_to_text` package de Flutter (on-device, sin cloud) |
| Almacenamiento local | `flutter_secure_storage` para credenciales SSH |
| Red | Solo LAN — sin internet requerido |

---

## Fuera de scope (MVP)

- Transferencia de archivos (SFTP)
- Editor de código en el teléfono
- Notificaciones push cuando Claude termina
- Múltiples sesiones simultáneas abiertas
- Acceso fuera de la red local (VPN, tunnel)
- Soporte para llaves SSH con passphrase en v1

---

## Fases de desarrollo

### Fase 1 — MVP
- Machine Manager (agregar, listar, eliminar)
- Conexión SSH funcional
- Terminal view con colores ANSI básicos
- Input de texto + enviar
- Ctrl+C y comandos básicos

### Fase 2 — Control completo
- Dictado de voz → texto
- Panel de comandos rápidos completo (slash commands, navegación)
- Cards de aprobación/rechazo de acciones
- Historial de comandos (flechas ↑↓)

### Fase 3 — Pulido
- Personalización de comandos rápidos
- Reconexión automática
- Tema visual ajustable (match exacto con tu terminal)
- Múltiples sesiones abiertas
