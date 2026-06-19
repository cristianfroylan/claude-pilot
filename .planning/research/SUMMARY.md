# Research Summary — claude-pilot

## Stack Confirmado

| Paquete | Versión | Rol |
|---------|---------|-----|
| dartssh2 | 2.18.0 | Cliente SSH — shell session, PTY, streams |
| xterm (pub.dev/packages/xterm) | 4.0.0 | Terminal ANSI — renderizado 60fps, buffer VT100 completo |
| flutter_riverpod | 3.3.2 | State management — AsyncNotifier.autoDispose para sesión SSH |
| flutter_secure_storage | 10.3.1 | Contraseñas SSH cifradas (Android minSdk 23+) |
| speech_to_text | 7.4.0 | Dictado de voz on-device API (ASR via OS del teléfono) |
| shared_preferences | 2.5.5 | Metadata de máquinas (IP, puerto, nombre) — no cifrado |

**Todo local — sin BD remota, sin servidores externos, solo LAN.**

---

## Decisiones Clave de Arquitectura

1. **xterm, no parser custom.** Claude Code usa secuencias `\x1b[A` + `\x1b[K` para spinners y diffs en-lugar. Un appender de líneas produce output corrupto. xterm.dart tiene buffer VT100 correcto con cell-grid 2D.

2. **Riverpod `AsyncNotifier.autoDispose.family(machineId)`.** El SSHClient y SSHSession son propietarios del notifier y se cierran solos cuando el usuario sale de la pantalla de sesión (`ref.onDispose`). No singleton global.

3. **`Terminal` de xterm ES el estado.** Extiende `ChangeNotifier` internamente. El provider retorna `AsyncValue<Terminal>`. `TerminalView` lo consume directamente. Sin wrapper extra.

4. **No isolate para el stream.** dartssh2 es Dart puro no-bloqueante. El overhead de serialización costaría más de lo que ahorra. Añadir batching con rxdart solo si aparecen frame drops en Phase 3.

5. **Voz nunca auto-envía.** El transcript final de speech_to_text va al campo de texto para revisión del usuario. El usuario toca enviar explícitamente.

---

## Orden de Build (estricto)

```
Phase 1:
1. Machine model + shared_preferences storage
2. flutter_secure_storage para contraseñas
3. MachineRepository + Riverpod provider
4. Machine Manager UI (lista, agregar, editar, eliminar)
5. SshService — conexión, PTY, streams (dartssh2)
6. Terminal view — xterm.dart TerminalView con fondo oscuro
7. Wiring: SSH stdout → terminal.write(), terminal.onOutput → SSH stdin
8. Input bar — texto + enviar
9. Señales de control — Ctrl+C, Ctrl+D, ESC

Phase 2:
10. Panel de comandos rápidos (slash commands, navegación, historial ↑↓)
11. Dictado de voz (speech_to_text → texto → campo editable)
12. Cards de aprobación (detección regex de prompts de Claude Code)
13. Reconexión + tmux reattach

Phase 3:
14. Resize de PTY en rotación/teclado
15. iOS keepAlive (keepAliveInterval: 30s)
16. Pulido visual y personalización
```

---

## Pitfalls Críticos — Resolver en Phase 1

| Pitfall | Qué hacer |
|---------|-----------|
| `SSHStateError: Transport is closed` — crash no manejado cuando la PC se apaga | Wrap `session.done` y `client.done` en try-catch desde el primer día |
| flutter_secure_storage backup → `InvalidKeyException` en restore Android | Añadir `android:allowBackup="false"` al AndroidManifest.xml |
| PTY columns fijos → diff y permission cards de Claude Code se cortan | Wiring `terminal.onResize → session.resizeTerminal()` desde Phase 1 |
| speech_to_text falla silenciosamente en Android 11+ sin `<queries>` intent | Añadir bloque de manifest antes de escribir código de reconocimiento |

---

## Pitfalls Phase 2+

| Pitfall | Cuándo |
|---------|--------|
| iOS mata sesión SSH en background (sin callback) | Phase 2 — `keepAliveInterval: Duration(seconds: 30)` + probe en `AppLifecycleState.resumed` |
| Regex de permisos Claude Code (`Allow [Tool] for "..."?`) sensible a versiones | Phase 2 — mantener patrón en constante fácil de actualizar |
| speech_to_text timeout ~3-5s OS-enforced | Phase 2 — UX de hold-to-record necesita prototype |

---

## Hallazgos Relevantes

- **xterm.dart y dartssh2 son del mismo autor (TerminalStudio).** El repo oficial tiene un ejemplo SSH completo en `example/lib/ssh.dart` — el wiring es ~5 líneas.
- **tmux reattach es bajo costo, alto valor.** Un botón "Reconectar sesión" que envía `tmux attach -t [last]` tras reconectar → conexiones caídas se recuperan en 3 segundos.
- **La native `claude remote` feature (Feb 2026) existe** pero requiere cuenta Anthropic y relay en la nube. La ventaja de claude-pilot: sin cloud, funciona en LAN air-gapped, acceso SSH terminal real para power users.

---

## Preguntas Abiertas para Planning

1. PTY columns iniciales antes del primer `autoResize` — usar 80x24 como default seguro
2. Detección automática de prompts de permisos vs UI manual en Phase 2 — preferir detección automática pero con fallback
3. Verificar si flutter_secure_storage issue #1037 (minSdk 23 vs 24) fue resuelto en 10.3.1
