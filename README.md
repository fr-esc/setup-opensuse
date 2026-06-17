# Reinstalar openSUSE Tumbleweed desde 0

Script único para reinstalar **todo** tu sistema openSUSE Tumbleweed con
exactamente los mismos programas y configuraciones que tenías.

**Completamente agnóstico:** funciona en cualquier ordenador con openSUSE
Tumbleweed. Durante la instalación te pregunta los datos de tu máquina actual
(git, discos, impresora, etc.) y cada sección opcional se puede aceptar o
saltar.

---

## Índice

1. [Uso básico](#uso)
2. [Preguntas durante la instalación](#3-ejecutar-instalación-en-el-sistema-nuevo)
3. [Post-instalación manual](#4-post-instalación-manual)
4. [Qué instala](#qué-instala)
5. [Estructura del script](#estructura-del-script)
6. [Notas técnicas](#notas)

---

## Uso

### 1. Respaldar configs actuales

**Ejecutar en el sistema actual ANTES de formatear.**

```bash
bash setup-opensuse.sh backup
```

Esto crea `backup-configs.tar.gz` **en la misma carpeta del script** (junto
al README) con:

| Contenido del backup | Para qué sirve |
|----------------------|----------------|
| `~/.config/opencode/` | Configuración del asistente OpenCode |
| `~/.config/warp-terminal/` | Preferencias de Warp Terminal |
| `~/.config/shell_gpt/` | Config de ShellGPT (sgpt) |
| `~/.config/yt-dlp/` | Config optimizada de yt-dlp |
| `~/.local/share/fonts/` | Fuentes MesloLGS Nerd Font (Powerlevel10k) |
| `gtk-3.0/` y `gtk-4.0/settings.ini` | Tema oscuro GTK |
| `~/.inputrc` | Config de readline |
| `~/.p10k.zsh` | Config de Powerlevel10k |

Al estar dentro de la misma carpeta, puedes mover la carpeta entera al disco
externo y todo viaja junto: script + backup.

> **Si no haces backup:** el script igual funciona. Solo que estas configs
> se pondrán con valores por defecto (salvo fuentes MesloLGS y yt-dlp, que
> el script las instala y configura igualmente).

### 2. Instalar openSUSE Tumbleweed

Usa el instalador oficial de openSUSE Tumbleweed. Particiona como desees y
elige **KDE Plasma** como escritorio.

### 3. Ejecutar instalación en el sistema nuevo

> 💡 **¿Ya tienes openSUSE y solo quieres probar el script?**
> El script detectará archivos existentes (`.zshrc`, `.gitconfig`...) y te
> preguntará antes de sobrescribirlos. Usa `--force` para saltar esa advertencia.

```bash
sudo bash setup-opensuse.sh           # con protección anti-sobrescritura
sudo bash setup-opensuse.sh --force   # sin preguntar (para re-ejecuciones)
```

Si detecta archivos de configuración existentes (`.zshrc`, `.gitconfig`, etc.),
el script **avisará y pedirá confirmación** antes de sobrescribirlos (usa
`--force` para saltar esta comprobación).

El script te hará las siguientes preguntas **en orden**. Prepara las
respuestas antes de empezar:

| # | Pregunta | Recomendado | Ejemplo / formato |
|--:|----------|:-----------:|-------------------|
| 1 | **Git user name** | ✅ Sí | `Tu Nombre` |
| 2 | **Git email** | ✅ Sí | `tu@email.com` |
| 3 | **Hostname** | Valor por defecto | `mi-pc` |
| 4 | **YT_ROOT** (carpeta descargas) | ✅ Sí | `/mnt/MiDisco/DESCARGAS/yt-dlp` |
| 5 | **LABELs de discos** a automontar | Si tienes discos externos | `DiscoDatos DiscoBackup` |
| 6 | **Google Drive API** (client_id) | ❌ (usar defecto) | `123456...apps.googleusercontent.com` |
| 7 | **Google Drive API** (client_secret) | ❌ (usar defecto) | (cadena secreta) |
| 8 | **Impresora** (URI IPP) | Si tienes impresora red | `ipps://mi-impresora._ipps._tcp.local/` |
| 9 | **Teclado Keychron** | s / N | `s` si tienes Keychron |
| 10 | **Drivers NVIDIA** | Si GPU NVIDIA / No si AMD | `s` o `n` |
| 11 | **Flatpaks** (Discord, Slack, Zoom...) | ✅ Sí (14 apps) | `s` o `n` |
| 12 | **JetBrains Toolbox** | Si usas IDEs JetBrains | `s` o `n` |
| 13 | **LM Studio CLI** | Opcional | `s` o `n` |
| 14 | **Modelos Ollama** | Opcional (~5-10GB) | `s` o `n` |
| 15 | **Ruta del backup** (.tar.gz) | Si migras desde otro sistema | `./backup-configs.tar.gz` |

Puedes dejar vacío (Enter) en las opcionales y configurarlas después.

### 4. Post-instalación manual

Al terminar, el script muestra las **acciones pendientes**. Esto es lo que
**no se puede automatizar** y debes hacer tú:

| # | Tarea | Por qué | Comando |
|--:|-------|---------|---------|
| 1 | **Reiniciar el sistema** | Cargar drivers, servicios y shell | `sudo reboot` |
| 2 | **Autenticar Google Drive** | Tokens expiran, no se respaldan | `rclone config reconnect Gdrive:` |
| 3 | **Autenticar Mega.nz** | Sesión no transferible | `rclone config reconnect Mega:` |
| 4 | **Iniciar montajes cloud** | Servicios creados pero detenidos | `systemctl --user start gdrive.service rclone-mega.service` |
| 5 | **Montar discos de datos** | Solo si los conectas después | `sudo mount -a` |
| 6 | **Iniciar sesión en apps** | Sesiones no transferibles | Brave, Discord, Slack, Zoom, Steam, Telegram... |

(si elegiste JetBrains, además: abrir Toolbox desde el menú de aplicaciones e instalar los IDEs)

---

## ¿Qué instala?

| Categoría | Programas | ¿Opcional? |
|-----------|-----------|:----------:|
| **Shell** | Zsh + Oh My Zsh + Powerlevel10k + MesloLGS fonts | No |
| **Terminal** | menú interactivo `descargar()` (yt-dlp) + Warp + Konsole | No |
| **Navegadores** | Brave, Firefox | No |
| **Desarrollo** | VS Code (31 extensions), Git, Python 3, Node.js, Java 25, GCC, Ruby, MySQL | No |
| **Multimedia** | VLC, Audacious, yt-dlp (config optimizada con anti-bot) | No |
| **Cloud** | rclone (Gdrive + Mega) con servicios systemd automontables | No |
| **Virtualización** | Podman, Distrobox, QEMU/KVM + virt-manager | No |
| **Juegos** | Steam + gamemode | No |
| **Ofimática** | LibreOffice | No |
| **Impresión** | CUPS + HPLIP (drivers HP) | No |
| **NVIDIA** | Drivers 595 + CUDA | Sí (pregunta) |
| **Flatpaks** | Discord, Slack, Zoom, Obsidian, OBS, GIMP, OnlyOffice, DBeaver, Heroic Games, Bruno, Alpaca, NetBeans, VLC | Sí (pregunta) |
| **JetBrains Toolbox** | Descarga e instala Toolbox | Sí (pregunta) |
| **LM Studio** | CLI `lms` | Sí (pregunta) |
| **Ollama** | Modelos: qwen2.5-coder, llama3.2, qwen3.5 | Sí (pregunta) |
| **Keychron udev** | Regla de permisos para teclado | Sí (pregunta) |

---

## Estructura del script

```
setup-opensuse.sh (1311 líneas)
├── ▶ Modo backup        → bash setup-opensuse.sh backup
│                          (se ejecuta en el sistema actual, antes de formatear)
│
├── ▶ Survey inicial      → 15 preguntas al usuario (git, discos, secciones...)
│
├── ▶ Detección de discos → busca las LABELs que indicaste en el survey
│                          y obtiene sus UUIDs dinámicamente
│
├── ▶ 27 secciones de instalación:
│   ├── 1.  Actualización del sistema (zypper dup)
│   ├── 2.  Repositorios adicionales (packman, nvidia, brave, vscode...)
│   ├── 3.  Paquetes RPM (200+ programas)
│   ├── 4.  Drivers NVIDIA (condicional)
│   ├── 5.  Aplicaciones Flatpak (condicional)
│   ├── 6.  Pipx / NPM global (shell-gpt, opencode, ollama-mcp-server)
│   ├── 7.  Ollama + descarga de modelos (condicional)
│   ├── 8.  Reglas udev Keychron (condicional)
│   ├── 9.  Oh My Zsh + Powerlevel10k
│   ├── 10. .zshrc completo con menú de descargas yt-dlp
│   ├── 11. .bashrc / .profile
│   ├── 12. Git config
│   ├── 13. VS Code (31 extensiones + settings.json)
│   ├── 14. Fstab (discos de datos detectados por LABEL)
│   ├── 15. Servicios systemd rclone (Gdrive + Mega)
│   ├── 16. Directorios de trabajo y YT_ROOT
│   ├── 17. Servicios del sistema (firewalld, cups, bluetooth...)
│   ├── 18. Snapper (snapshots Btrfs)
│   ├── 19. Hostname
│   ├── 20. Temas GTK (oscuro)
│   ├── 21. Fuentes MesloLGS Nerd Font (Powerlevel10k)
│   ├── 22. Configuración yt-dlp optimizada
│   ├── 23. Restaurar configs desde backup (opencode, warp, shell_gpt)
│   ├── 24. CUPS / Impresora (condicional)
│   ├── 25. JetBrains Toolbox (condicional)
│   ├── 26. LM Studio CLI (condicional)
│   └── 27. Powerlevel10k .p10k.zsh
│
└── ▶ Post-instalación    → resume lo instalado y lista acciones pendientes
```

---

## Notas

- **Seguridad:** El script no contiene API keys, contraseñas ni tokens.
  Tampoco tiene valores hardcodeados del sistema original (email, discos,
  impresora...).
- **Portabilidad:** Funciona en cualquier PC con openSUSE Tumbleweed. Las
  rutas usan `$HOME`, los UUIDs se detectan por LABEL, y cada usuario
  responde sus propios datos durante el survey.
- **fstab:** Solo se añaden discos de datos (los que indicaste por LABEL).
  Las particiones del sistema (/, /home, /boot) no se tocan — las crea el
  instalador de openSUSE.
- **rclone:** Las credenciales de Google Drive y Mega.nz se autentican
  manualmente después de la instalación (los tokens expiran).
- **Backup:** El backup captura configs de usuario (opencode, warp,
  shell_gpt, yt-dlp, fuentes, gtk). Las sesiones de apps, perfiles de
  navegador y el layout de KDE no se respaldan.
