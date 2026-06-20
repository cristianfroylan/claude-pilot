# Requirements: claude-pilot

**Defined:** 2026-06-19
**Core Value:** Enviar un prompt a Claude Code desde el teléfono y ver la respuesta llegar — sin abrir la laptop.

## v1.0 Requirements (Validated — Phases 1–3)

### Machine Manager

- [x] **MACH-01**: Usuario puede agregar una máquina con nombre, IP, puerto SSH (default 22), usuario y contraseña
- [x] **MACH-02**: Usuario ve la lista de máquinas guardadas con estado de conexión (disponible / sin conexión)
- [x] **MACH-03**: Usuario puede editar los datos de una máquina existente
- [x] **MACH-04**: Usuario puede eliminar una máquina guardada
- [x] **MACH-05**: Las credenciales SSH se almacenan cifradas en el dispositivo (flutter_secure_storage)

### Conexión SSH

- [x] **SSH-01**: Usuario puede conectarse a una máquina vía SSH con un tap
- [x] **SSH-02**: La app muestra el estado de la conexión (conectando / conectado / error)
- [x] **SSH-03**: La app maneja el cierre inesperado de la conexión sin crashear (SSHStateError)
- [x] **SSH-04**: El PTY se dimensiona dinámicamente al ancho de pantalla y se actualiza si el teclado aparece/desaparece

### Terminal View

- [x] **TERM-01**: El output de Claude Code se muestra en tiempo real con colores ANSI completos (256 colores)
- [x] **TERM-02**: Secuencias de cursor (spinners, diffs en-lugar) se renderizan correctamente mediante xterm.dart
- [x] **TERM-03**: El terminal tiene fondo oscuro, fuente monospace y scroll hacia el historial
- [x] **TERM-04**: El texto se adapta al ancho de pantalla sin cortar caracteres

### Input

- [x] **INP-01**: Usuario puede escribir un prompt en un campo de texto y enviarlo con un botón
- [x] **INP-02**: Usuario puede ejecutar Ctrl+C con un tap (interrumpir proceso)
- [x] **INP-03**: Usuario puede ejecutar Ctrl+D con un tap (EOF / cerrar sesión)
- [x] **INP-04**: Usuario puede enviar ESC con un tap

### Comandos Rápidos

- [x] **CMD-01**: Panel colapsable con slash commands de Claude Code (/clear, /compact, /gsd, /help, /cost)
- [x] **CMD-02**: Panel incluye comandos de navegación (cd ~, cd .., ls, pwd)
- [x] **CMD-03**: Panel incluye señales de salida (\q, q)
- [x] **CMD-04**: Panel incluye comandos de sesión (claude, claude ., exit)
- [x] **CMD-05**: Usuario puede navegar el historial de comandos (↑ y ↓ del shell)

### Dictado de Voz

- [x] **VOZ-01**: Usuario puede mantener presionado el botón de micrófono para dictar un prompt
- [x] **VOZ-02**: Al soltar, el texto transcrito aparece en el campo de input para revisión
- [x] **VOZ-03**: El texto transcrito no se envía automáticamente — el usuario revisa y toca enviar
- [x] **VOZ-04**: Si el reconocimiento de voz no está disponible, el botón se oculta gracefully

### Aprobación de Acciones

- [x] **APRO-01**: Cuando Claude Code muestra un prompt de permiso, aparece una card con [Aprobar] y [Rechazar]
- [x] **APRO-02**: Tap en Aprobar envía "y" + Enter a la terminal
- [x] **APRO-03**: Tap en Rechazar envía "n" + Enter a la terminal

## v2.0 Requirements

### Reconexión robusta (RECON)

- [x] **RECON-01**: Al fallar la conexión inicial, la app reintenta automáticamente hasta 5 veces con backoff exponencial (1s→2s→4s→8s→16s) mostrando número de intento y tiempo de espera
- [x] **RECON-02**: Al caerse una sesión activa (mid-session), la app reintenta automáticamente hasta 3 veces con un banner inline en el terminal
- [x] **RECON-03**: El usuario puede cancelar los reintentos en curso con un botón visible
- [x] **RECON-04**: Tras agotar los reintentos automáticos, el usuario puede forzar un reintento manual
- [x] **RECON-05**: El historial del terminal (scrollback) se preserva durante y después de la reconexión — no se limpia el buffer de xterm

### Autenticación biométrica (BIO)

- [ ] **BIO-01**: La app requiere autenticación biométrica (Face ID / huella / PIN del dispositivo) al iniciarse en frío
- [ ] **BIO-02**: La app requiere autenticación biométrica antes de editar las credenciales de una máquina guardada
- [ ] **BIO-03**: La app se vuelve a bloquear si estuvo en background más de 10 minutos
- [ ] **BIO-04**: En dispositivos sin biométrico disponible, el PIN/contraseña del dispositivo funciona como fallback automático (manejado por el OS, sin código extra)

### Session start picker (PICK)

- [ ] **PICK-01**: Al iniciar una nueva sesión con carpetas configuradas, el usuario puede elegir entre sesión en blanco o cargar un proyecto
- [ ] **PICK-02**: El usuario puede configurar una lista de rutas de carpetas de trabajo por máquina en la pantalla de edición
- [ ] **PICK-03**: Al seleccionar un proyecto, la sesión envía automáticamente `cd <ruta>` como primer comando
- [ ] **PICK-04**: Si no hay carpetas configuradas, la sesión inicia en blanco directamente sin mostrar el picker

### Sesiones múltiples con tabs (SESS)

- [ ] **SESS-01**: El usuario puede abrir múltiples sesiones SSH simultáneamente (misma o diferente máquina) y navegar entre ellas mediante una barra de pestañas
- [ ] **SESS-02**: Cada pestaña muestra el nombre de la máquina y tiene un botón de cierre independiente; las pestañas son scrolleables horizontalmente cuando hay muchas
- [ ] **SESS-03**: Cerrar una pestaña desconecta limpiamente esa sesión SSH sin afectar las demás
- [ ] **SESS-04**: Si la sesión de una pestaña cae, esa pestaña permanece abierta con el último output visible y un banner de error — las otras pestañas no se ven afectadas

## v3 Requirements (Deferred)

### Acceso remoto
- **REMOTE-01**: Acceso SSH desde fuera de la red local (VPN / tunnel)

### Notificaciones
- **NOTIF-01**: Notificaciones push cuando Claude Code completa una tarea larga

### Personalización
- **PERS-01**: Comandos rápidos configurables por el usuario
- **PERS-02**: Tema visual personalizable (colores terminal)

### Autenticación avanzada
- **AUTH-ADV-01**: Soporte para llaves SSH con passphrase

## Out of Scope

| Feature | Razón |
|---------|-------|
| Transferencia de archivos (SFTP UI) | Fuera del concepto "control remoto" — la PC edita |
| Editor de código en el teléfono | La computadora es quien edita, el teléfono solo controla |
| tmux reattach automático | v3 — requiere tmux instalado y configurado en servidor |
| BD remota o sync en la nube | Todo es local al dispositivo — sin dependencias externas |
| Múltiples máquinas en el mismo tab | Complejidad sin valor claro |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MACH-01..05 | Phase 1 | Complete |
| SSH-01..04 | Phase 1 | Complete |
| TERM-01..04 | Phase 1 | Complete |
| INP-01..04 | Phase 1 | Complete |
| CMD-01..05 | Phase 2 | Complete |
| VOZ-01..04 | Phase 2 | Complete |
| APRO-01..03 | Phase 2 | Complete |
| (cross-cutting polish) | Phase 3 | Complete |
| RECON-01 | Phase 4 | Complete |
| RECON-02 | Phase 4 | Complete |
| RECON-03 | Phase 4 | Complete |
| RECON-04 | Phase 4 | Complete |
| RECON-05 | Phase 4 | Complete |
| BIO-01 | Phase 5 | Pending |
| BIO-02 | Phase 5 | Pending |
| BIO-03 | Phase 5 | Pending |
| BIO-04 | Phase 5 | Pending |
| PICK-01 | Phase 6 | Pending |
| PICK-02 | Phase 6 | Pending |
| PICK-03 | Phase 6 | Pending |
| PICK-04 | Phase 6 | Pending |
| SESS-01 | Phase 7 | Pending |
| SESS-02 | Phase 7 | Pending |
| SESS-03 | Phase 7 | Pending |
| SESS-04 | Phase 7 | Pending |

**Coverage:**
- v2.0 requirements: 17 total
- Mapped to phases: 17 (Phases 4–7)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-19*
*Last updated: 2026-06-20 after v2.0 milestone requirements definition*
