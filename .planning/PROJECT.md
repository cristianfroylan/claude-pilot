# claude-pilot

## What This Is

App móvil Flutter que funciona como control remoto para Claude Code sobre la red local vía SSH. La computadora corre Claude Code con todo su poder; el teléfono expone una interfaz mínima para enviar prompts, ver el output en tiempo real y aprobar acciones — sin tener que estar sentado frente al escritorio. El objetivo es la comodidad, no replicar la terminal en el teléfono.

## Core Value

Enviar un prompt a Claude Code desde el teléfono y ver la respuesta llegar — sin abrir la laptop.

## Current Milestone: v2.0 Power User Features

**Goal:** Hacer la app utilizable como herramienta diaria sin fricción — sesiones múltiples con tabs, proyectos rápidos, seguridad biométrica al abrir la app y al editar máquinas, y reconexión robusta.

**Target features:**
- Múltiples sesiones SSH simultáneas con navegación por pestañas (estilo Chrome mobile)
- Session start picker: sesión en blanco o cargar proyecto (lista de carpetas configurables por máquina, `ls` al conectar, `cd` al seleccionar)
- Autenticación biométrica (Face ID / huella) al abrir la app y al editar máquinas guardadas
- Reconexión automática con backoff y UI de progreso/cancelar al fallar conexión inicial o caída mid-session

## Requirements

### Validated

- ✓ Usuario puede agregar, listar y eliminar máquinas — v1.0 Phase 1
- ✓ Usuario puede conectarse a una máquina vía SSH y ver el estado de conexión — v1.0 Phase 1
- ✓ Usuario ve el output de Claude Code en tiempo real con colores ANSI fieles — v1.0 Phase 1
- ✓ Usuario puede escribir un prompt y enviarlo a la terminal — v1.0 Phase 1
- ✓ Usuario puede dictar un prompt por voz, revisarlo y enviarlo — v1.0 Phase 2
- ✓ Usuario puede ejecutar comandos rápidos (Ctrl+C, /clear, /gsd, cd ~, etc.) con un tap — v1.0 Phase 2
- ✓ Usuario puede aprobar o rechazar acciones que Claude solicita permiso — v1.0 Phase 2
- ✓ SSH keepalive, PTY resize robusto, SafeArea iOS — v1.0 Phase 3

### Active

- ✓ Usuario puede tener múltiples sesiones SSH abiertas simultáneamente y navegar entre ellas con tabs — v2.0 Phase 7
- ✓ Al iniciar una nueva sesión, el usuario puede elegir empezar en blanco o cargar un proyecto — v2.0 Phase 6
- ✓ Usuario puede configurar una lista de carpetas de trabajo por máquina — v2.0 Phase 6
- ✓ La app requiere autenticación biométrica al lanzarse (Face ID / huella / PIN) — v2.0 Phase 5
- ✓ La app requiere autenticación biométrica al editar credenciales de una máquina guardada — v2.0 Phase 5
- ✓ La app reintenta la conexión automáticamente con backoff y muestra progreso al usuario — v2.0 Phase 4
- ✓ El usuario puede cancelar reintentos o forzar uno manualmente — v2.0 Phase 4

### Out of Scope

- Transferencia de archivos (SFTP) — fuera del concepto "control remoto"
- Editor de código en el teléfono — la computadora es quien edita
- Notificaciones push — v3
- Acceso fuera de la red local (VPN, tunnel) — v3
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
*Last updated: 2026-06-21 after Phase 7 complete (multiple sessions with tabs) — all v2.0 phases executed*
