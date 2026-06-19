# claude-pilot

## What This Is

App móvil Flutter que funciona como control remoto para Claude Code sobre la red local vía SSH. La computadora corre Claude Code con todo su poder; el teléfono expone una interfaz mínima para enviar prompts, ver el output en tiempo real y aprobar acciones — sin tener que estar sentado frente al escritorio. El objetivo es la comodidad, no replicar la terminal en el teléfono.

## Core Value

Enviar un prompt a Claude Code desde el teléfono y ver la respuesta llegar — sin abrir la laptop.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Usuario puede agregar, listar y eliminar máquinas (nombre, IP, puerto, usuario, contraseña)
- [ ] Usuario puede conectarse a una máquina vía SSH y ver el estado de conexión
- [ ] Usuario ve el output de Claude Code en tiempo real con colores ANSI fieles
- [ ] Usuario puede escribir un prompt y enviarlo a la terminal
- [ ] Usuario puede dictar un prompt por voz, revisarlo y enviarlo
- [ ] Usuario puede ejecutar comandos rápidos (Ctrl+C, /clear, /gsd, cd ~, etc.) con un tap
- [ ] Usuario puede aprobar o rechazar acciones que Claude solicita permiso
- [ ] Usuario puede navegar el historial de comandos (↑↓)

### Out of Scope

- Transferencia de archivos (SFTP) — fuera del concepto "control remoto"
- Editor de código en el teléfono — la computadora es quien edita
- Notificaciones push — v2
- Múltiples sesiones simultáneas abiertas — v2
- Acceso fuera de la red local (VPN, tunnel) — v2
- Llaves SSH con passphrase — v1 solo soporta usuario/contraseña

## Context

- El usuario (Cristian) usa Claude Code intensivamente en su escritorio Linux (Arch/CachyOS + Hyprland)
- Flujo actual: está frente a la computadora para escribir prompts y ver respuestas
- El pain point: tener que estar físicamente frente al escritorio para cada interacción
- Metáfora central: el control remoto del televisor — el TV tiene todos sus controles, pero el control te da acceso desde el sofá
- El usuario ya tiene ALIA (push-to-talk con Piper TTS) — entiende bien los flujos de voz en desktop
- Stack decidido: Flutter (Dart) + dartssh2 + flutter_secure_storage + speech_to_text
- Red: solo LAN, sin internet requerido

## Constraints

- **Tech stack**: Flutter — iOS + Android desde un solo codebase, ya familiar al usuario (tiene Semvy en Flutter)
- **Red**: Solo LAN local — sin dependencia de internet, sin servidores externos
- **Seguridad**: Credenciales SSH almacenadas con flutter_secure_storage (cifrado nativo del dispositivo)
- **Fidelidad visual**: El terminal debe renderizar colores ANSI igual a como los ve en su monitor — familiaridad como requisito

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SSH directo (no bridge) en v1 | Menos infraestructura, sin proceso extra en la PC — más simple para el MVP | — Pending |
| Flutter como plataforma | Codebase único iOS+Android, usuario ya lo conoce con Semvy | — Pending |
| Dictado on-device (speech_to_text) | Sin cloud, sin latencia de red, funciona offline | — Pending |
| Coarse granularity | Proyecto con spec claro — fases amplias son suficientes, evita sobre-fragmentar | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-19 after initialization from SPEC.md*
