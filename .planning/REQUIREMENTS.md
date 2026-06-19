# Requirements: claude-pilot

**Defined:** 2026-06-19
**Core Value:** Enviar un prompt a Claude Code desde el teléfono y ver la respuesta llegar — sin abrir la laptop.

## v1 Requirements

### Machine Manager

- [ ] **MACH-01**: Usuario puede agregar una máquina con nombre, IP, puerto SSH (default 22), usuario y contraseña
- [ ] **MACH-02**: Usuario ve la lista de máquinas guardadas con estado de conexión (disponible / sin conexión)
- [ ] **MACH-03**: Usuario puede editar los datos de una máquina existente
- [ ] **MACH-04**: Usuario puede eliminar una máquina guardada
- [ ] **MACH-05**: Las credenciales SSH se almacenan cifradas en el dispositivo (flutter_secure_storage)

### Conexión SSH

- [ ] **SSH-01**: Usuario puede conectarse a una máquina vía SSH con un tap
- [ ] **SSH-02**: La app muestra el estado de la conexión (conectando / conectado / error)
- [ ] **SSH-03**: La app maneja el cierre inesperado de la conexión sin crashear (SSHStateError)
- [ ] **SSH-04**: El PTY se dimensiona dinámicamente al ancho de pantalla y se actualiza si el teclado aparece/desaparece

### Terminal View

- [ ] **TERM-01**: El output de Claude Code se muestra en tiempo real con colores ANSI completos (256 colores)
- [ ] **TERM-02**: Secuencias de cursor (spinners, diffs en-lugar) se renderizan correctamente mediante xterm.dart
- [ ] **TERM-03**: El terminal tiene fondo oscuro, fuente monospace y scroll hacia el historial
- [ ] **TERM-04**: El texto se adapta al ancho de pantalla sin cortar caracteres

### Input

- [ ] **INP-01**: Usuario puede escribir un prompt en un campo de texto y enviarlo con un botón
- [ ] **INP-02**: Usuario puede ejecutar Ctrl+C con un tap (interrumpir proceso)
- [ ] **INP-03**: Usuario puede ejecutar Ctrl+D con un tap (EOF / cerrar sesión)
- [ ] **INP-04**: Usuario puede enviar ESC con un tap

### Comandos Rápidos

- [x] **CMD-01**: Panel colapsable con slash commands de Claude Code (/clear, /compact, /gsd, /help, /cost)
- [x] **CMD-02**: Panel incluye comandos de navegación (cd ~, cd .., ls, pwd)
- [x] **CMD-03**: Panel incluye señales de salida (\q, q)
- [x] **CMD-04**: Panel incluye comandos de sesión (claude, claude ., exit)
- [x] **CMD-05**: Usuario puede navegar el historial de comandos (↑ y ↓ del shell)

### Dictado de Voz

- [ ] **VOZ-01**: Usuario puede mantener presionado el botón de micrófono para dictar un prompt
- [ ] **VOZ-02**: Al soltar, el texto transcrito aparece en el campo de input para revisión
- [ ] **VOZ-03**: El texto transcrito no se envía automáticamente — el usuario revisa y toca enviar
- [ ] **VOZ-04**: Si el reconocimiento de voz no está disponible, el botón se oculta gracefully

### Aprobación de Acciones

- [ ] **APRO-01**: Cuando Claude Code muestra un prompt de permiso, aparece una card con [Aprobar] y [Rechazar]
- [ ] **APRO-02**: Tap en Aprobar envía "y" + Enter a la terminal
- [ ] **APRO-03**: Tap en Rechazar envía "n" + Enter a la terminal

## v2 Requirements

### Reconexión

- **RECON-01**: La app detecta sesiones caídas y ofrece reconectar con un tap
- **RECON-02**: Al reconectar, botón de "reattach tmux" para recuperar sesión anterior
- **RECON-03**: iOS keepAlive (keepAliveInterval: 30s) para mantener conexión en background

### Personalización

- **PERS-01**: Usuario puede agregar sus propios slash commands al panel
- **PERS-02**: Tema visual ajustable (fondo, fuente, colores)

### Sesiones múltiples

- **MULT-01**: Usuario puede tener múltiples sesiones abiertas simultáneamente
- **MULT-02**: Switcher entre sesiones activas

## Out of Scope

| Feature | Razón |
|---------|-------|
| Transferencia de archivos (SFTP) | Fuera del concepto "control remoto" — la PC edita |
| Editor de código en el teléfono | La computadora es quien edita, el teléfono solo controla |
| Notificaciones push cuando Claude termina | v2 — requiere proceso en background en la PC |
| Acceso fuera de LAN (VPN, tunnel) | v2 — complejidad de red fuera del scope inicial |
| Llaves SSH con passphrase | v1 solo usuario/contraseña — simplifica UX inicial |
| BD remota o sync en la nube | Todo es local al dispositivo — sin dependencias externas |
| Reconocimiento de voz offline puro | speech_to_text usa ASR del SO (Google/Apple) — aceptable para LAN |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MACH-01 | Phase 1 | Pending |
| MACH-02 | Phase 1 | Pending |
| MACH-03 | Phase 1 | Pending |
| MACH-04 | Phase 1 | Pending |
| MACH-05 | Phase 1 | Pending |
| SSH-01 | Phase 1 | Pending |
| SSH-02 | Phase 1 | Pending |
| SSH-03 | Phase 1 | Pending |
| SSH-04 | Phase 1 | Pending |
| TERM-01 | Phase 1 | Pending |
| TERM-02 | Phase 1 | Pending |
| TERM-03 | Phase 1 | Pending |
| TERM-04 | Phase 1 | Pending |
| INP-01 | Phase 1 | Pending |
| INP-02 | Phase 1 | Pending |
| INP-03 | Phase 1 | Pending |
| INP-04 | Phase 1 | Pending |
| CMD-01 | Phase 2 | Complete |
| CMD-02 | Phase 2 | Complete |
| CMD-03 | Phase 2 | Complete |
| CMD-04 | Phase 2 | Complete |
| CMD-05 | Phase 2 | Complete |
| VOZ-01 | Phase 2 | Pending |
| VOZ-02 | Phase 2 | Pending |
| VOZ-03 | Phase 2 | Pending |
| VOZ-04 | Phase 2 | Pending |
| APRO-01 | Phase 2 | Pending |
| APRO-02 | Phase 2 | Pending |
| APRO-03 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28 (Phase 1: 17, Phase 2: 11, Phase 3: 0 — cross-cutting polish)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-19*
*Last updated: 2026-06-19 after roadmap creation (3 phases)*
