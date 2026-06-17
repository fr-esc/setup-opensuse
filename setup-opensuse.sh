#!/bin/bash
# ============================================================
# setup-opensuse.sh
# INSTALACIÓN COMPLETA openSUSE Tumbleweed desde cero
# ============================================================
# USO:
#   bash setup-opensuse.sh              ← INSTALACION (nuevo sistema)
#   bash setup-opensuse.sh --force      ← INSTALACION (saltar advertencias)
#   bash setup-opensuse.sh backup       ← RESPALDAR configs ANTES de formatear
# ============================================================
# Un solo script, dos modos:
#   1. Modo normal: instala todo desde cero (+27 pasos)
#   2. Modo backup: respalda configs antes de formatear
# ============================================================

set -euo pipefail

# ─── Colores ───
R='\e[1;31m'; G='\e[1;32m'; Y='\e[1;33m'; B='\e[1;34m'; C='\e[1;36m'; N='\e[0m'
log()  { echo -e "${G}[✓]${N} $1"; }
warn() { echo -e "${Y}[!]${N} $1"; }
err()  { echo -e "${R}[✗]${N} $1"; }
sec()  { echo -e "\n${B}══════════════════════════════════════════════════════════════${N}"; echo -e "${C}$1${N}"; echo -e "${B}══════════════════════════════════════════════════════════════${N}"; }
prompt_yes() { echo -e -n "${Y}¿$1? [s/N]:${N} "; read -r r; [[ "$r" =~ ^[sSyY] ]]; }

# ============================================================
# MODO BACKUP — respaldar configs antes de formatear
# ============================================================
if [ "${1:-}" = "backup" ]; then
    echo "============================================"
    echo "  MODO BACKUP — Respaldando configs actuales"
    echo "============================================"
    echo ""
    echo "  Este modo respalda tus configuraciones antes de"
    echo "  formatear e instalar el sistema desde cero."
    echo "  El backup se guarda en la misma carpeta que el script."
    echo "  Cuando ejecutes el script en el sistema nuevo,"
    echo "  te preguntara la ruta del backup y lo restaurara."
    echo ""

    REAL_HOME="$HOME"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    BACKUP_FILE="$SCRIPT_DIR/backup-configs.tar.gz"
    BACKUP_DIR="/tmp/backup-configs-$$"
    mkdir -p "$BACKUP_DIR"

    ITEMS=(
        "$REAL_HOME/.config/opencode"
        "$REAL_HOME/.config/warp-terminal"
        "$REAL_HOME/.config/shell_gpt"
        "$REAL_HOME/.config/yt-dlp"
        "$REAL_HOME/.local/share/fonts"
        "$REAL_HOME/.config/gtk-3.0/settings.ini"
        "$REAL_HOME/.config/gtk-4.0/settings.ini"
        "$REAL_HOME/.inputrc"
        "$REAL_HOME/.p10k.zsh"
    )

    echo "Respaldando:"
    for item in "${ITEMS[@]}"; do
        if [ -e "$item" ]; then
            echo "  ✅ ${item#$REAL_HOME/}"
            dest_dir="$BACKUP_DIR/$(dirname "${item#$REAL_HOME/}")"
            mkdir -p "$dest_dir"
            cp -a "$item" "$dest_dir/" 2>/dev/null || true
        fi
    done

    cd "$BACKUP_DIR"
    tar -czf "$BACKUP_FILE" . 2>/dev/null
    cd "$REAL_HOME"
    rm -rf "$BACKUP_DIR"

    echo ""
    echo "============================================"
    echo "  ✅ BACKUP CREADO: $BACKUP_FILE"
    echo "     Tamaño: $(du -h "$BACKUP_FILE" | cut -f1)"
    echo "============================================"
    echo ""
    echo "  El backup está dentro de la misma carpeta que el script."
    echo "  Cuando ejecutes el script en el sistema nuevo,"
    echo "  te preguntará la ruta del backup."
    echo ""
    echo "  Puedes responder: $BACKUP_FILE"
    echo "  O simplemente copia la carpeta entera y el script lo detectará."
    echo ""
    exit 0
fi

# ─── Detectar usuario real ───
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[ -z "$REAL_HOME" ] && REAL_HOME="$HOME"

if [ "$(id -u)" -ne 0 ]; then
    err "Este script debe ejecutarse con sudo:"
    err "  sudo bash $0                (instalacion desde cero)"
    err "  sudo bash $0 --force        (saltar advertencia de sobrescritura)"
    err "  bash $0 backup              (solo respaldar configs, sin sudo)"
    exit 1
fi

# ============================================================
# SURVEY INICIAL — SOLICITAR VARIABLES AL USUARIO
# ============================================================
sec "BIENVENIDO — ASISTENTE DE INSTALACION"
echo ""
echo -e "${C}  Este asistente prepara tu openSUSE Tumbleweed recien instalado${N}"
echo -e "${C}  con todo lo necesario para trabajar: desarrollo, multimedia,${N}"
echo -e "${C}  cloud, gaming y productividad.${N}"
echo ""
echo -e "${Y}  Tiempo estimado: 20-40 min (segun conexion y opciones elegidas)${N}"
echo -e "${Y}  Se requiere conexion a internet${N}"
echo -e "${Y}  Proceso dividido en +25 pasos. Puedes dejar que se ejecute solo.${N}"
echo ""
echo -e "${C}  A continuacion responde 15 preguntas para personalizar.${N}"
echo -e "${Y}  Las marcadas como Recomendado aparecen al lado de cada opcion.${N}"
echo ""

sec "ENCUESTA INICIAL — CONFIGURACION DEL USUARIO"
echo -e "${Y}Responde cada pregunta segun tu caso.${N}\n"

# ── Git config (obligatorio) ──
echo -e "${C}--- Git (Recomendado) ---${N}"
echo -e "${Y}  Tus credenciales se usaran para los commits desde VS Code y terminal.${N}"
read -r -p "  Git user name: " GIT_NAME
while [ -z "$GIT_NAME" ]; do
    read -r -p "  Git user name (obligatorio): " GIT_NAME
done
read -r -p "  Git email (obligatorio): " GIT_EMAIL
while [ -z "$GIT_EMAIL" ]; do
    read -r -p "  Git email (obligatorio): " GIT_EMAIL
done

# ── Hostname (opcional, tiene valor por defecto) ──
echo -e "${C}--- Hostname ---${N}"
echo -e "${Y}  Nombre con el que tu equipo se identificara en la red.${N}"
CURRENT_HOSTNAME=$(hostname)
read -r -p "  Hostname del equipo [$CURRENT_HOSTNAME]: " NEW_HOSTNAME
NEW_HOSTNAME="${NEW_HOSTNAME:-$CURRENT_HOSTNAME}"

# ── YT_ROOT (obligatorio) ──
echo -e "${C}--- Directorio de descargas yt-dlp (Recomendado) ---${N}"
echo -e "${Y}  Donde se guardaran las descargas de video/audio. Recomendado: un disco externo si tienes.${N}"
echo "  Ejemplo: /mnt/MiDisco/DESCARGAS/yt-dlp  (disco externo)"
echo "  Ejemplo: \$HOME/YT_DESCARGAS                (disco local)"
read -r -p "  YT_ROOT (ruta completa): " YT_ROOT
while [ -z "$YT_ROOT" ]; do
    read -r -p "  YT_ROOT (ruta completa): " YT_ROOT
done

# ── Etiquetas de discos de datos (opcional) ──
echo -e "${C}--- Discos de datos (automontaje) ---${N}"
echo -e "${Y}  Si tienes discos con etiquetas (LABEL), el script los montara automaticamente.${N}"
echo -e "${Y}  Recomendado: si usas discos externos para datos. Si no, puedes configurarlo despues.${N}"
echo "  Ejemplo: DiscoDatos DiscoBackup  (separados por espacio)"
echo "  Si no tienes, deja vacio."
read -r -p "  LABELs de discos de datos (Enter para saltar): " DISK_LABELS
DISK_LABELS="${DISK_LABELS:-}"

# ── Google Drive API (opcional) ──
echo -e "${C}--- Google Drive API (opcional) ---${N}"
echo -e "${Y}  Recomendado: dejalo vacio. rclone usara los limites por defecto de Google.${N}"
echo "  Solo si tienes tu propio proyecto en Google Cloud Console, ingresalos."
read -r -p "  GDrive client_id (Enter para saltar): " GD_CLIENT_ID
read -r -s -p "  GDrive client_secret (Enter para saltar): " GD_CLIENT_SECRET
echo ""

# ── Impresora de red (opcional) ──
echo -e "${C}--- Impresora de red (opcional) ---${N}"
echo -e "${Y}  Recomendado: si tienes impresora en red. Para obtener la URI ejecuta: lpinfo -v${N}"
echo "  Ejemplo: ipps://MiImpresora._ipps._tcp.local/"
read -r -p "  URI de impresora (Enter para saltar): " PRINTER_URI

# ── Teclado Keychron (opcional) ──
echo -e "${C}--- Teclado Keychron (opcional) ---${N}"
INSTALL_KEYCHRON=false
prompt_yes "¿Tienes un teclado Keychron (regla udev para permisos)" && INSTALL_KEYCHRON=true

# ── Secciones opcionales ──
echo ""
echo -e "${C}--- Secciones opcionales (elige segun tu caso) ---${N}"
echo -e "${Y}  Responde s/n a cada una. Al final se mostrara un resumen de tus elecciones.${N}"
echo ""
INSTALL_NVIDIA=false
INSTALL_FLATPAK=false
INSTALL_JETBRAINS=false
INSTALL_LMSTUDIO=false
INSTALL_OLLAMA_MODELS=false

echo -e "${C}  Drivers graficos:${N}"
echo -e "    Recomendado:${Y} Si${N} si GPU NVIDIA |${Y} No${N} si AMD/Intel (vienen incluidos)"
prompt_yes "  Instalar drivers NVIDIA (solo si GPU NVIDIA)" && INSTALL_NVIDIA=true
echo ""
echo -e "${C}  Aplicaciones Flatpak:${N}"
echo -e "    Recomendado:${Y} Si${N} (Discord, Slack, Zoom, Obsidian, GIMP, OBS, OnlyOffice...)"
prompt_yes "  Instalar apps Flatpak (~3-5 min)" && INSTALL_FLATPAK=true
echo ""
echo -e "${C}  IDEs JetBrains:${N}"
echo -e "    Recomendado:${Y} Si${N} si usas IntelliJ, PyCharm, etc. Descarga ~350MB)"
prompt_yes "  Instalar JetBrains Toolbox" && INSTALL_JETBRAINS=true
echo ""
echo -e "${C}  IA Local (Opcional):${N}"
echo -e "    LM Studio CLI: interfaz para ejecutar modelos localmente"
prompt_yes "  Instalar LM Studio CLI" && INSTALL_LMSTUDIO=true
echo -e "    Modelos Ollama: qwen2.5-coder:3b, llama3.2, qwen3.5:2b (~5-10GB en total)"
prompt_yes "  Descargar modelos Ollama" && INSTALL_OLLAMA_MODELS=true

# ── Backup de configs (opcional, recomendado si migras) ──
echo -e "${C}--- Restaurar configs desde un backup (Recomendado) ---${N}"
echo -e "${Y}  Si migras desde tu sistema anterior, especifica la ruta al backup.${N}"
echo -e "${Y}  Restaura: opencode, warp-terminal, shell_gpt, yt-dlp, fuentes,${N}"
echo -e "${Y}  temas GTK, .inputrc y .p10k.zsh.${N}"
echo "  Creado con: bash setup-opensuse.sh backup"
read -r -p "  Ruta al backup .tar.gz (Enter para saltar): " CONFIG_BACKUP_PATH

# ── Comprobar si hay configs existentes (sistema ya usado) ──
FORCE_MODE=false
[ "${1:-}" = "--force" ] && FORCE_MODE=true

CONFIG_FILES_TO_CHECK=(
    "$REAL_HOME/.zshrc"
    "$REAL_HOME/.bashrc"
    "$REAL_HOME/.profile"
    "$REAL_HOME/.gitconfig"
    "$REAL_HOME/.config/Code/User/settings.json"
    "$REAL_HOME/.config/yt-dlp/config"
    "$REAL_HOME/.config/gtk-3.0/settings.ini"
    "$REAL_HOME/.p10k.zsh"
)

EXISTING_FILES=()
for f in "${CONFIG_FILES_TO_CHECK[@]}"; do
    [ -f "$f" ] && EXISTING_FILES+=("$f")
done

if [ ${#EXISTING_FILES[@]} -gt 0 ] && ! $FORCE_MODE; then
    echo ""
    echo -e "${R}══════════════════════════════════════════════════════════════${N}"
    echo -e "${R}  ATENCION: Se detectaron configuraciones existentes${N}"
    echo -e "${R}══════════════════════════════════════════════════════════════${N}"
    echo ""
    echo -e "${Y}  Este script esta disenado para INSTALACION DESDE CERO.${N}"
    echo -e "${Y}  Los siguientes archivos SERAN SOBREESCRITOS:${N}"
    echo ""
    for f in "${EXISTING_FILES[@]}"; do
        echo "    • ${f#$REAL_HOME/}"
    done
    echo ""
    echo -e "${Y}  El backup NO restaura estos archivos (se generan desde las${N}"
    echo -e "${Y}  respuestas del survey para que sean portables).${N}"
    echo ""
    echo -e "${Y}  Si solo quieres anadir paquetes o servicios, es mejor hacerlo manualmente.${N}"
    echo ""
    echo -e "${R}  Escribe 'si' para confirmar la sobrescritura o Enter para cancelar.${N}"
    read -r -p "  Confirmar: " _confirm
    if [ "$_confirm" != "si" ]; then
        echo -e "${Y}Instalacion cancelada. No se realizaron cambios.${N}"
        exit 0
    fi
    echo ""
fi

echo ""
sec "RESUMEN DE TUS ELECCIONES"
echo -e "${C}  Has configurado:${N}"
echo -e "  Git:     ${G}$GIT_NAME${N} <${G}$GIT_EMAIL${N}>"
echo -e "  Hostname:${G}${NEW_HOSTNAME}${N}"
echo -e "  YT_ROOT: ${G}$YT_ROOT${N}"
[ -n "$DISK_LABELS" ] && echo -e "  Discos:  ${G}$DISK_LABELS${N}" || echo -e "  Discos:  ${Y}ninguno${N}"
[ -n "$PRINTER_URI" ] && echo -e "  Impresora: ${G}$PRINTER_URI${N}" || echo -e "  Impresora: ${Y}ninguna${N}"
echo -e "  NVIDIA:  ${G}$([ $INSTALL_NVIDIA = true ] && echo 'SI' || echo 'NO')${N}"
echo -e "  Flatpak: ${G}$([ $INSTALL_FLATPAK = true ] && echo 'SI' || echo 'NO')${N}"
echo -e "  JetBrains:${G}$([ $INSTALL_JETBRAINS = true ] && echo 'SI' || echo 'NO')${N}"
echo -e "  LM Studio:${G}$([ $INSTALL_LMSTUDIO = true ] && echo 'SI' || echo 'NO')${N}"
echo -e "  Ollama:  ${G}$([ $INSTALL_OLLAMA_MODELS = true ] && echo 'SI' || echo 'NO')${N}"
echo -e "  Keychron:${G}$([ $INSTALL_KEYCHRON = true ] && echo 'SI' || echo 'NO')${N}"
echo ""
echo -e "${Y}  Presiona Enter para comenzar la instalacion (o Ctrl+C para cancelar)...${N}"
read -r
echo ""
echo -e "${G}Iniciando instalacion...${N}"
sleep 1

# ============================================================
# DETECCIÓN DE DISCOS CONECTADOS
# ============================================================
sec "DETECCIÓN DE DISCOS CONECTADOS"

log "Discos detectados:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT 2>/dev/null | grep -v "^loop"
echo ""

# Buscar discos de datos por etiqueta (definidas por el usuario en el survey)
declare -A DISK_MAP=()
if [ -n "$DISK_LABELS" ]; then
    for label in $DISK_LABELS; do
        if lsblk -o LABEL 2>/dev/null | grep -qi "$label"; then
            UUID=$(blkid -L "$label" 2>/dev/null || true)
            if [ -n "$UUID" ]; then
                DISK_MAP["$label"]="$UUID"
                log "Disco '$label' detectado: UUID=$UUID"
            fi
        else
            warn "Disco '$label' NO detectado. Conéctalo y configúralo manualmente."
        fi
    done
else
    log "No se configuraron discos de datos. Se omite fstab adicional."
fi

# ============================================================
# 1. ACTUALIZACIÓN DEL SISTEMA (~2-5 min)
# ============================================================
sec "1. ACTUALIZACION INICIAL"
echo -e "${Y}  Actualiza todos los paquetes del sistema a la ultima version de Tumbleweed.${N}"
echo -e "${Y}  Es normal que tarde si hace tiempo que no actualizas.${N}\n"

log "Refresh de repositorios..."
zypper --non-interactive refresh 2>/dev/null || true

log "Actualización del sistema (dup)..."
zypper --non-interactive dup --no-allow-vendor-change 2>/dev/null || \
    zypper --non-interactive dup 2>/dev/null || \
    warn "zypper dup encontró conflictos. Puedes resolverlos con: sudo zypper dup"

# ============================================================
# 2. REPOSITORIOS ADICIONALES
# ============================================================
sec "2. REPOSITORIOS ADICIONALES"
echo -e "${Y}  Anade repositorios: packman (codecs), Brave, VS Code, Warp,${N}"
echo -e "${Y}  zsh-plugins, MySQL, y NVIDIA si seleccionaste.${N}\n"

# Packman
zypper --non-interactive addrepo --refresh --priority 90 \
    https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman 2>/dev/null && \
    log "Repositorio packman añadido" || warn "packman ya existe"

# NVIDIA
if $INSTALL_NVIDIA; then
    zypper --non-interactive addrepo --refresh \
        https://download.nvidia.com/opensuse/tumbleweed NVIDIA 2>/dev/null && \
        log "Repositorio NVIDIA añadido" || warn "NVIDIA repo ya existe"
fi

# Brave
zypper --non-interactive addrepo --refresh \
    https://brave-browser-rpm-release.s3.brave.com/x86_64 brave-browser 2>/dev/null || true
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-browser-release.asc 2>/dev/null || true

# VS Code
zypper --non-interactive addrepo --refresh \
    https://packages.microsoft.com/yumrepos/vscode vscode 2>/dev/null || true
rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true

# Warp Terminal
zypper --non-interactive addrepo --refresh \
    https://releases.warp.dev/linux/rpm/stable warpdotdev 2>/dev/null || true

# Zsh plugins
zypper --non-interactive addrepo --refresh \
    https://download.opensuse.org/repositories/shells:/zsh-users:/zsh-autosuggestions/openSUSE_Tumbleweed/ zsh-autosuggestions 2>/dev/null || true
zypper --non-interactive addrepo --refresh \
    https://download.opensuse.org/repositories/shells:/zsh-users:/zsh-syntax-highlighting/openSUSE_Tumbleweed/ zsh-syntax-highlighting 2>/dev/null || true

# MySQL (server_database)
zypper --non-interactive addrepo --refresh \
    https://download.opensuse.org/repositories/server:/database/openSUSE_Tumbleweed/ server_database 2>/dev/null || true

zypper --non-interactive refresh 2>/dev/null || true
log "Repositorios configurados."

# ============================================================
# 3. INSTALACIÓN PAQUETES BASE (RPM) (~5-10 min)
# ============================================================
sec "3. PAQUETES RPM"
echo -e "${Y}  Instala 200+ paquetes: shell, navegadores, lenguajes, multimedia,${N}"
echo -e "${Y}  cloud, virtualizacion, gaming, ofimatica, impresion y KDE PIM.${N}"
echo -e "${Y}  Es la parte mas pesada de la instalacion.${N}\n"

BASE_PKGS=(
    # Shell / Terminal
    zsh zsh-autosuggestions zsh-syntax-highlighting konsole warp-terminal

    # Sistema
    openssh firewalld chrony smartmontools avahi NetworkManager
    bluetooth ModemManager power-profiles-daemon upower udisks2
    polkit snapper snapper-rollback screen git gh curl wget
    htop fastfetch ncdu duf lm_sensors tldr fortune

    # Navegadores
    brave-browser firefox

    # Desarrollo base
    python3 python3-pip nodejs nodejs-devel npm
    java-25-openjdk java-25-openjdk-devel
    gcc gcc-c++ gdb make cmake ruby ruby-devel
    vim

    # Multimedia
    vlc audacious audacious-plugins audacious-plugins-extra
    ffmpeg-8 ffmpegthumbs yt-dlp

    # Cloud
    rclone fuse fuse3 gvfs samba samba-client samba-winbind

    # Impresión
    cups hplip hplip-cups hplip-sane hplip-ppds-postscript
    system-config-printer

    # Virtualización
    libvirt-client libvirt-daemon-qemu libvirt-daemon-driver-qemu
    virt-manager qemu-x86 qemu-tools qemu-ui-gtk qemu-ui-curses
    podman distrobox

    # Gaming
    steam gamemode

    # Comunicación
    telegram-desktop

    # Ofimática
    libreoffice libreoffice-writer

    # KDE PIM
    akonadi-calendar-tools akregator kaddressbook kalendarac
    kdepim-addons kdepim-runtime kmail kontact korganizer ktnef
    pim-data-exporter pim-sieve-editor

    # Otros
    kernel-devel kernel-default-devel
)

zypper --non-interactive install --no-recommends "${BASE_PKGS[@]}" 2>/dev/null || \
    zypper --non-interactive install "${BASE_PKGS[@]}" 2>/dev/null || \
    warn "Algunos paquetes no se instalaron. Revisa el output."

# KDE Plasma (por separado por si falla)
zypper --non-interactive install --no-recommends \
    plasma6-desktop dolphin gwenview ark kate kcalc spectacle \
    kwalletmanager krunner kinfocenter plasma6-systemmonitor \
    kcharselect filelight kdenetwork-filesharing kio-extras \
    kdeplasma6-addons plasma6-browser-integration \
    kde-gtk-config6 breeze6 2>/dev/null || true

# Instalar pipx globalmente
zypper --non-interactive install python3-pipx 2>/dev/null || \
    pip3 install pipx 2>/dev/null || true

log "Paquetes RPM instalados."

# ============================================================
# 4. NVIDIA
# ============================================================
if $INSTALL_NVIDIA; then
    sec "4. DRIVERS NVIDIA"
    echo -e "${Y}  Instalando drivers NVIDIA de codigo abierto (nvidia-open).${N}"
    echo -e "${Y}  Incluye drivers, compute, EGL para Wayland y persistencia.${N}\n"
    zypper --non-interactive install --no-recommends \
        nvidia-open-driver-G07-signed-kmp-default \
        nvidia-video-G07 nvidia-compute-G07 nvidia-gl-G07 \
        nvidia-compute-utils-G07 nvidia-common-G07 \
        nvidia-modprobe nvidia-persistenced \
        libnvidia-egl-wayland1 libnvidia-egl-wayland1-32bit \
        nvidia-open-driver-G07-signed-kmp-meta 2>/dev/null || \
        warn "NVIDIA: algunos paquetes fallaron. Verifica compatibilidad con tu kernel."

    systemctl enable nvidia-persistenced 2>/dev/null || true
    log "NVIDIA instalado."
fi

# ============================================================
# 5. FLATPAK
# ============================================================
if $INSTALL_FLATPAK; then
    sec "5. APLICACIONES FLATPAK (~3-5 min)"
    echo -e "${Y}  Descargando e instalando 14 apps Flatpak desde Flathub.${N}"
    echo -e "${Y}  Incluye Discord, Slack, Zoom, Obsidian, GIMP, OBS, OnlyOffice y mas.${N}\n"
    zypper --non-interactive install flatpak 2>/dev/null || true
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    FLATPAK_APPS=(
        com.discordapp.Discord
        com.github.tchx84.Flatseal
        com.heroicgameslauncher.hgl
        com.jeffser.Alpaca
        com.obsproject.Studio
        com.slack.Slack
        com.usebruno.Bruno
        io.dbeaver.DBeaverCommunity
        io.podman_desktop.PodmanDesktop
        md.obsidian.Obsidian
        org.gimp.GIMP
        org.onlyoffice.desktopeditors
        org.videolan.VLC
        us.zoom.Zoom
    )

    for app in "${FLATPAK_APPS[@]}"; do
        flatpak install --noninteractive flathub "$app" 2>/dev/null && \
            log "Flatpak: $app" || warn "Falló flatpak: $app (se salta)"
    done
    log "Flatpaks instalados."
fi

# ============================================================
# 6. PIPX / NPM
# ============================================================
sec "6. PIPX / NPM"
echo -e "${Y}  Instala herramientas Python/Node globales: shell-gpt, opencode-cli, ollama-mcp-server.${N}\n"

if command -v pipx &>/dev/null; then
    sudo -u "$REAL_USER" pipx install shell-gpt 2>/dev/null || \
        warn "shell-gpt ya instalado o falló"
else
    warn "pipx no disponible, saltando instalación de shell-gpt y opencode"
fi

# OpenCode
if command -v pipx &>/dev/null && ! command -v opencode &>/dev/null; then
    sudo -u "$REAL_USER" pipx install opencode-cli 2>/dev/null || \
        warn "opencode-cli no se pudo instalar"
fi

# NPM global
npm list -g ollama-mcp-server &>/dev/null || \
    sudo -u "$REAL_USER" npm install -g ollama-mcp-server 2>/dev/null || true

log "Pipx/NPM configurados."

# ============================================================
# 7. OLLAMA
# ============================================================
sec "7. OLLAMA + MODELOS DE IA"
echo -e "${Y}  Instala Ollama y, si elegiste, descarga modelos locales.${N}"
echo -e "${Y}  Los modelos se descargan en segundo plano (~2-10 min segun conexion).${N}\n"

zypper --non-interactive install ollama 2>/dev/null || true
systemctl enable ollama 2>/dev/null || true
systemctl start ollama 2>/dev/null || true

if $INSTALL_OLLAMA_MODELS; then
    log "Descargando modelos Ollama (esto puede tomar varios minutos)..."
    MODELS=("qwen2.5-coder:3b" "llama3.2" "qwen3.5:2b")
    for m in "${MODELS[@]}"; do
        log "  Pulling $m..."
        sudo -u "$REAL_USER" ollama pull "$m" 2>/dev/null || warn "  Falló $m"
    done
    log "Modelos Ollama descargados."
fi

# ============================================================
# 8. REGLAS UDEV — KEYCHRON (opcional)
# ============================================================
if $INSTALL_KEYCHRON; then
    sec "8. REGLAS UDEV — KEYCHRON"
    echo -e "${Y}  Instalando regla udev para permisos de teclado Keychron (idVendor 3434).${N}\n"
    cat > /etc/udev/rules.d/99-keychron.rules << 'UDEV'
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", MODE="0666", TAG+="uaccess", TAG+="udev-acl"
UDEV
    udevadm control --reload-rules 2>/dev/null || true
    udevadm trigger 2>/dev/null || true
    log "Reglas udev Keychron instaladas."
fi

# ============================================================
# 9. SHELL: ZSH + OH-MY-ZSH + POWERLEVEL10K
# ============================================================
sec "9. CONFIGURACION DE SHELL"
echo -e "${Y}  Instala Oh My Zsh con Powerlevel10k, plugins de autosugerencias${N}"
echo -e "${Y}  y resaltado de sintaxis. Cambia el shell por defecto a Zsh.${N}\n"

# Oh My Zsh
if [ ! -d "$REAL_HOME/.oh-my-zsh" ]; then
    sudo -u "$REAL_USER" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null || \
        warn "Oh My Zsh falló. Instálalo manualmente."
fi

# Powerlevel10k
if [ ! -d "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    sudo -u "$REAL_USER" git clone --depth=1 \
        https://github.com/romkatv/powerlevel10k.git \
        "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null || \
        warn "Powerlevel10k falló."
fi

# Zsh por defecto
if [ "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh "$REAL_USER" 2>/dev/null && log "Shell cambiado a zsh" || \
        warn "No se pudo cambiar el shell"
fi

# ============================================================
# 10. .ZSHRC (con menú de descargas yt-dlp)
# ============================================================
sec "10. .ZSHRC — CONFIGURACION COMPLETA"
echo -e "${Y}  Escribe .zshrc con alias, PATH, menu de descargas yt-dlp (descargar/descargar-video/descargar-audio)${N}"
echo -e "${Y}  y configuracion de Powerlevel10k.${N}\n"

sudo -u "$REAL_USER" tee "$REAL_HOME/.zshrc" > /dev/null << ZSHRC
# ============================================================
# .zshrc — Generado por setup-opensuse.sh
# ============================================================

# --- Powerlevel10k instant prompt ---
if [[ -r "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh" ]]; then
  source "\${XDG_CACHE_HOME:-\$HOME/.cache}/p10k-instant-prompt-\${(%):-%n}.zsh"
fi

# --- Oh My Zsh ---
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source \$ZSH/oh-my-zsh.sh

source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*:default' list-colors \${(s.:.)LS_COLORS}

# --- PATH ---
export PATH="\$HOME/.opencode/bin:\$PATH"
export PATH="\$PATH:\$HOME/.local/share/JetBrains/Toolbox/scripts"
export PATH="\$PATH:\$HOME/.lmstudio/bin"
export PATH="\$PATH:\$HOME/.local/bin"

# --- Aliases ---
alias tldr="LANGUAGE=es:en tldr"
alias stopmodels="ollama ps | awk 'NR>1 {print \\\$1}' | xargs -r -L1 ollama stop"

# --- YT-DLP Config ---
export YT_ROOT="$YT_ROOT"

_limpiar_listas_yt() {
    local h="\$YT_ROOT/historial.txt"
    local l_v="\$YT_ROOT/lista_video.txt"
    local l_a="\$YT_ROOT/lista_audio.txt"
    [ ! -s "\$h" ] && return
    echo -ne "\e[1;33m🧹 Limpiando listas... \e[0m"
    local ids=\$(awk '{print \$2}' "\$h" | sort -u | xargs | tr ' ' '|')
    if [ -n "\$ids" ]; then
        sed -i -E "/(\$ids)/d" "\$l_v" 2>/dev/null
        sed -i -E "/(\$ids)/d" "\$l_a" 2>/dev/null
    fi
    echo -e "\e[1;32mOK\e[0m"
}

descargar-video() {
    trap 'echo -e "\n\e[1;31m🛑 PARADA TOTAL FORZADA\e[0m"; kill -TERM 0 2>/dev/null; return 130' INT
    local list="\$YT_ROOT/lista_video.txt"
    local rate="\${1:-10M}"
    [ ! -s "\$list" ] && { echo -e "🎬 \e[1;33mLista de vídeo vacía.\e[0m"; return 0; }
    local intento=1; local max=3
    local is_nitro=""; [[ "\$rate" != "10M" ]] && is_nitro="[\e[1;31mNITRO\e[0m]"
    local R=\$'\e[1;31m'; local G=\$'\e[0m'
    echo -e "🎬 Iniciando VÍDEO \$is_nitro (Modo Multihilo)..."
    while [ \$intento -le \$max ]; do
        local tmp_list="/tmp/yt_v_\$(date +%s).txt"
        shuf "\$list" > "\$tmp_list"
        local threads="2"; local frags="4"
        [[ -n "\$is_nitro" ]] && { threads="4"; frags="12"; }
        systemd-inhibit --why="Descargando vídeos" \
            xargs -a "\$tmp_list" -P \$threads -r -I {} yt-dlp -N \$frags --limit-rate "\$rate" \
            --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
            --extractor-args "youtube:player-client=web,android" \
            --progress-template "🎬 \${R}[%(title,display_id,id).35s]\${G} %(progress._percent_str)s | %(progress._speed_str)s | ETA: %(progress._eta_str)s" \
            --progress-delta 2 --console-title --ignore-errors -- "{}"
        local exit_rc=\$?; rm -f "\$tmp_list"
        if [[ \$exit_rc -ge 128 ]] || [[ \$exit_rc -eq 125 ]] || [[ \$exit_rc -eq 123 ]] || [[ \$exit_rc -eq 2 ]]; then
            echo -e "\n\e[1;31m🛑 DETENCIÓN TOTAL: Volviendo a consola...\e[0m"
            kill -TERM 0 2>/dev/null; return 130
        fi
        _limpiar_listas_yt
        local n=\$(grep -c "^http" "\$list" 2>/dev/null || echo 0)
        [ "\$n" -eq 0 ] && { echo "✅ Finalizado."; return 0; }
        local pausa=\$((RANDOM % 10 + 3))
        echo "⚠️  Vuelta \$intento fallida. Reintentando en \${pausa}s..."
        ((intento++)); [ \$intento -le \$max ] && sleep \$pausa
    done
}

descargar-audio() {
    trap 'echo -e "\n\e[1;31m🛑 PARADA TOTAL FORZADA\e[0m"; kill -TERM 0 2>/dev/null; return 130' INT
    local list="\$YT_ROOT/lista_audio.txt"
    [ ! -s "\$list" ] && { echo -e "🎵 \e[1;33mLista de audio vacía.\e[0m"; return 0; }
    local intento=1; local max=3
    local R=\$'\e[1;31m'; local G=\$'\e[0m'
    echo -e "🎵 Iniciando \e[1;33mAUDIO\e[0m (YouTube Safe Mode)..."
    while [ \$intento -le \$max ]; do
        local tmp_list="/tmp/yt_a_\$(date +%s).txt"
        shuf "\$list" > "\$tmp_list"
        systemd-inhibit --why="Descargando audio" \
            xargs -a "\$tmp_list" -P 2 -r -I {} yt-dlp -N 4 -x --audio-format mp3 --audio-quality 0 \
            --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
            --extractor-args "youtube:player-client=web,android" \
            --progress-template "🎵 \${R}[%(title,display_id,id).35s]\${G} %(progress._percent_str)s | %(progress._speed_str)s | ETA: %(progress._eta_str)s" \
            --progress-delta 2 --console-title --ignore-errors -- "{}"
        local exit_rc=\$?; rm -f "\$tmp_list"
        if [[ \$exit_rc -ge 128 ]] || [[ \$exit_rc -eq 125 ]] || [[ \$exit_rc -eq 123 ]] || [[ \$exit_rc -eq 2 ]]; then
            echo -e "\n\e[1;31m🛑 DETENCIÓN TOTAL: Volviendo a consola...\e[0m"
            kill -TERM 0 2>/dev/null; return 130
        fi
        _limpiar_listas_yt
        local n=\$(grep -c "^http" "\$list" 2>/dev/null || echo 0)
        [ "\$n" -eq 0 ] && { echo "✅ Finalizado."; return 0; }
        local pausa=\$((RANDOM % 41 + 10))
        echo "⚠️  Reintentando audio en \${pausa}s..."
        ((intento++)); [ \$intento -le \$max ] && sleep \$pausa
    done
}

descargar() {
    local l_v="\$YT_ROOT/lista_video.txt"
    local l_a="\$YT_ROOT/lista_audio.txt"
    local opcion_directa="\${1:-}"
    if [[ -n "\$opcion_directa" ]]; then
        case "\$opcion_directa" in
            1) descargar-audio; return \$? ;;
            2) descargar-video "10M"; return \$? ;;
            3) descargar-video "1G"; return \$? ;;
            4) descargar-audio && descargar-video "10M"; return \$? ;;
            5) [ -f "\$l_a" ] && xdg-open "\$l_a" </dev/null &>/dev/null; return 0 ;;
            6) [ -f "\$l_v" ] && xdg-open "\$l_v" </dev/null &>/dev/null; return 0 ;;
            7) local a_c=\$(grep -c "^http" "\$l_a" 2>/dev/null || echo 0)
               local v_c=\$(grep -c "^http" "\$l_v" 2>/dev/null || echo 0)
               echo -e "\n\e[1;34m>>> ESTADO <<< 🎵:\e[1;33m\$a_c\e[0m | 🎬:\e[1;33m\$v_c\e[0m"; return 0 ;;
            8) sudo zypper update yt-dlp 2>/dev/null || pipx upgrade yt-dlp 2>/dev/null; return 0 ;;
            9) return 0 ;;
        esac
    fi
    while true; do
        echo -e "\n\e[1;36m=============================\e[0m"
        echo -e "      \e[1;33mMENÚ DE DESCARGAS\e[0m"
        echo -e "\e[1;36m=============================\e[0m"
        echo -e "  \e[1;32m1\e[0m - Descargar \e[1;33mAudio\e[0m (YouTube)"
        echo -e "  \e[1;32m2\e[0m - Descargar \e[1;33mVídeo\e[0m (Sigilo 10M)"
        echo -e "  \e[1;31m3\e[0m - Descargar \e[1;33mVídeo (NITRO 🚀)\e[0m"
        echo -e "  \e[1;32m4\e[0m - Descargar \e[1;33mAmbos\e[0m (Secuencial)"
        echo -e "  \e[1;36m-----------------------------\e[0m"
        echo -e "  \e[1;32m5\e[0m - Abrir lista Audio"
        echo -e "  \e[1;32m6\e[0m - Abrir lista Vídeo"
        echo -e "  \e[1;32m7\e[0m - Ver estado de las colas"
        echo -e "  \e[1;32m8\e[0m - Actualizar yt-dlp"
        echo -e "  \e[1;31m9\e[0m - Salir"
        echo -e "\e[1;36m=============================\e[0m"
        echo -ne "\e[1;32mSelecciona [1-9]: \e[0m "; read "opcion"
        case "\$opcion" in
            1) descargar-audio ;; 2) descargar-video "10M" ;;
            3) descargar-video "1G" ;; 4) descargar-audio && descargar-video "10M" ;;
            5) xdg-open "\$l_a" </dev/null &>/dev/null ;;
            6) xdg-open "\$l_v" </dev/null &>/dev/null ;;
            7) descargar 7; echo -ne "\n\e[1;33m↵ [Enter]\e[0m"; read -r _p ;;
            8) descargar 8 ;; 9|q|Q) return 0 ;;
            *) echo -e "\n\e[1;31m❌ Opción no válida.\e[0m"; sleep 1 ;;
        esac
    done
}

# --- Powerlevel10k ---
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# --- Terminal tweaks ---
autoload -Uz bracketed-paste-magic
zle -N bracketed-paste bracketed-paste-magic
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history)
[[ -t 0 ]] && stty -ixon 2>/dev/null
ZSHRC

log ".zshrc escrito con menú de descargas."

# ============================================================
# 11. .BASHRC / .PROFILE
# ============================================================
sec "11. CONFIGURACIÓN BASH"

sudo -u "$REAL_USER" tee "$REAL_HOME/.bashrc" > /dev/null << BASHRC
# .bashrc
test -s ~/.alias && . ~/.alias || true
export PATH="\$PATH:\$HOME/.lmstudio/bin"
export PATH="\$PATH:\$HOME/.local/share/JetBrains/Toolbox/scripts"
export PATH="\$PATH:\$HOME/.opencode/bin"
export PATH="\$PATH:\$HOME/.local/bin"
alias tldr="LANGUAGE=es:en tldr"
BASHRC

sudo -u "$REAL_USER" tee "$REAL_HOME/.profile" > /dev/null << PROFILE
# .profile
test -z "\$PROFILEREAD" && . /etc/profile || true
export PATH="\$PATH:\$HOME/.local/share/JetBrains/Toolbox/scripts"
export PATH="\$PATH:\$HOME/.lmstudio/bin"
PROFILE

log "Bash configurado."

# ============================================================
# 12. GIT CONFIG
# ============================================================
sec "12. GIT"

sudo -u "$REAL_USER" tee "$REAL_HOME/.gitconfig" > /dev/null << GITCFG
[user]
	name = $GIT_NAME
	email = $GIT_EMAIL
[credential "https://github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
[credential "https://gist.github.com"]
	helper =
	helper = !/usr/bin/gh auth git-credential
[credential]
	helper = cache
GITCFG
log "Git configurado: $GIT_NAME <$GIT_EMAIL>"

# ============================================================
# 13. VS CODE — EXTENSIONES + SETTINGS
# ============================================================
sec "13. VS CODE"
echo -e "${Y}  Instala 31 extensiones (Python, Java, C#, Docker, Gemini, Continue, Ollama)${N}"
echo -e "${Y}  y configura settings.json con tema One Dark Vivid y modelo Ollama por defecto.${N}\n"

VSCODE_EXTENSIONS=(
    continue.continue dbaeumer.vscode-eslint
    dracula-theme.theme-dracula esbenp.prettier-vscode
    formulahendry.code-runner google.geminicodeassist
    ms-azuretools.vscode-containers ms-dotnettools.csdevkit
    ms-dotnettools.csharp ms-dotnettools.vscode-dotnet-runtime
    ms-python.autopep8 ms-python.debugpy ms-python.python
    ms-python.vscode-pylance ms-python.vscode-python-envs
    ms-vscode-remote.remote-containers ms-vscode.live-server
    mskelton.one-dark-theme oderwat.indent-rainbow
    oracle.oracle-java pkief.material-icon-theme
    redhat.java saoudrizwan.claude-dev
    t3dotgg.vsc-material-theme-but-i-wont-sue-you
    usernamehw.errorlens vscjava.vscode-gradle
    vscjava.vscode-java-debug vscjava.vscode-java-dependency
    vscjava.vscode-java-pack vscjava.vscode-java-test vscjava.vscode-maven
)

if command -v code &>/dev/null; then
    for ext in "${VSCODE_EXTENSIONS[@]}"; do
        sudo -u "$REAL_USER" code --install-extension "$ext" --force 2>/dev/null || true
    done
    log "Extensiones VS Code instaladas."
fi

sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/Code/User"
sudo -u "$REAL_USER" tee "$REAL_HOME/.config/Code/User/settings.json" > /dev/null << 'VSSET'
{
    "editor.minimap.enabled": false,
    "livePreview.notifyOnOpenLooseFile": false,
    "containers.containerClient": "com.microsoft.visualstudio.containers.podman",
    "containers.orchestratorClient": "com.microsoft.visualstudio.orchestrators.podmancompose",
    "git.autofetch": true,
    "workbench.colorTheme": "One Dark Vivid",
    "chat.viewSessions.orientation": "stacked",
    "inlineChat.defaultModel": "qwen2.5-coder:3b (ollama)"
}
VSSET
log "VS Code settings configurados."

# ============================================================
# 14. FSTAB — SOLO DISCOS DE DATOS
# ============================================================
sec "14. FSTAB — DISCOS DE DATOS"
echo -e "${Y}  Anade los discos de datos a /etc/fstab para montaje automatico al arrancar.${N}"
echo -e "${Y}  Detecta el tipo de filesystem (ext4/ntfs/xfs/btrfs) y usa las opciones adecuadas.${N}\n"

FSTAB_ADD=""
declare -A FSTAB_TYPE=(
    ["ext4"]="ext4 defaults,data=ordered 0 2"
    ["ntfs"]="ntfs-3g uid=1000,gid=100,fmask=022,dmask=022,utf8,nofail 0 0"
    ["xfs"]="xfs defaults 0 2"
    ["btrfs"]="btrfs defaults 0 0"
)

for label in "${!DISK_MAP[@]}"; do
    uuid="${DISK_MAP[$label]}"
    [ -z "$uuid" ] && continue
    mountpoint="/mnt/$label"
    
    # Detectar tipo de filesystem
    fstype=$(blkid -o value -s TYPE "/dev/disk/by-uuid/$uuid" 2>/dev/null || echo "ext4")
    fstab_opts="${FSTAB_TYPE[$fstype]:-${FSTAB_TYPE[ext4]}}"
    
    FSTAB_ADD+="UUID=$uuid $mountpoint $fstab_opts"$'\n'
    mkdir -p "$mountpoint"
    log "Disco '$label' ($fstype) añadido a fstab → $mountpoint"
done

if [ -n "$FSTAB_ADD" ]; then
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
    echo "" >> /etc/fstab
    echo "# Discos de datos — añadidos por setup-opensuse.sh" >> /etc/fstab
    echo "$FSTAB_ADD" >> /etc/fstab
    mount -a 2>/dev/null || warn "mount -a falló. Verifica que los discos estén conectados."
fi

if [ ${#DISK_MAP[@]} -eq 0 ]; then
    warn "No se configuraron discos de datos."
    warn "Cuando los conectes, ejecuta: lsblk -f para ver los UUIDs y añádelos a /etc/fstab"
fi

# ============================================================
# 15. SYSTEMD — RCLONE (solo crear servicios, sin credenciales)
# ============================================================
sec "15. SERVICIOS SYSTEMD — RCLONE"
echo -e "${Y}  Crea servicios systemd para montar Google Drive y Mega.nz al iniciar sesion.${N}"
echo -e "${Y}  NOTA: Debes autenticarte manualmente tras la instalacion (ver acciones pendientes).${N}\n"

mkdir -p "$REAL_HOME/GoogleDrive" "$REAL_HOME/Mega"
chown "$REAL_USER":"$REAL_USER" "$REAL_HOME/GoogleDrive" "$REAL_HOME/Mega"

mkdir -p "$REAL_HOME/.config/systemd/user"

# Gdrive service
sudo -u "$REAL_USER" tee "$REAL_HOME/.config/systemd/user/gdrive.service" > /dev/null << 'GDRIVE'
[Unit]
Description=Google Drive (rclone)
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount Gdrive: %h/GoogleDrive \
  --vfs-cache-mode full \
  --vfs-cache-max-size 15G \
  --vfs-cache-max-age 24h \
  --vfs-read-chunk-size 64M \
  --vfs-read-chunk-size-limit 1G \
  --buffer-size 64M \
  --dir-cache-time 10m \
  --poll-interval 30s \
  --timeout 10m \
  --transfers 8 \
  --checkers 8 \
  --async-read=true
ExecStop=/bin/fusermount -u %h/GoogleDrive
Restart=on-failure

[Install]
WantedBy=default.target
GDRIVE

# Mega service
sudo -u "$REAL_USER" tee "$REAL_HOME/.config/systemd/user/rclone-mega.service" > /dev/null << 'MEGA'
[Unit]
Description=MEGA.nz Cloud Storage (rclone)
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount Mega:/ %h/Mega \
  --vfs-cache-mode full \
  --vfs-cache-max-size 5G \
  --vfs-cache-max-age 24h \
  --buffer-size 64M \
  --vfs-read-chunk-size-limit 1G \
  --dir-cache-time 5m \
  --poll-interval 30s \
  --timeout 10m \
  --transfers 8 \
  --checkers 8 \
  --async-read=true \
  --umask 022
ExecStop=/bin/fusermount -u %h/Mega
Restart=on-failure

[Install]
WantedBy=default.target
MEGA

chown -R "$REAL_USER":"$REAL_USER" "$REAL_HOME/.config/systemd"

# Rclone config template (sin secrets)
sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/rclone"
sudo -u "$REAL_USER" tee "$REAL_HOME/.config/rclone/rclone.conf" > /dev/null << RCLONE_CFG
[Gdrive]
type = drive
scope = drive
$( [ -n "$GD_CLIENT_ID" ] && echo "client_id = $GD_CLIENT_ID" || echo "# client_id = (opcional: añade tu propio client_id)")
$( [ -n "$GD_CLIENT_SECRET" ] && echo "client_secret = $GD_CLIENT_SECRET" || echo "# client_secret = (opcional: añade tu propio client_secret)")

[Mega]
type = mega
# user = tu-email@ejemplo.com
RCLONE_CFG

log "Servicios systemd rclone creados (sin autenticar)."

# ============================================================
# 16. DIRECTORIOS YT-DLP + TRABAJO
# ============================================================
sec "16. DIRECTORIOS DE TRABAJO"

# Crear YT_ROOT
sudo -u "$REAL_USER" mkdir -p "$YT_ROOT" "$YT_ROOT/audio" "$YT_ROOT/video"
sudo -u "$REAL_USER" touch "$YT_ROOT/lista_video.txt" 2>/dev/null || true
sudo -u "$REAL_USER" touch "$YT_ROOT/lista_audio.txt" 2>/dev/null || true
sudo -u "$REAL_USER" touch "$YT_ROOT/historial.txt" 2>/dev/null || true

# Crear symlink en HOME si YT_ROOT no está en home
if [[ "$YT_ROOT" != "$REAL_HOME"* ]]; then
    sudo -u "$REAL_USER" ln -sf "$YT_ROOT" "$REAL_HOME/YT_ROOT" 2>/dev/null || true
fi

# Directorios comunes
sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/projects" "$REAL_HOME/dev"

log "Directorios de trabajo creados."

# ============================================================
# 17. SERVICIOS DEL SISTEMA
# ============================================================
sec "17. ACTIVAR SERVICIOS"

systemctl enable firewalld cups sshd bluetooth avahi-daemon smartd snapperd chronyd 2>/dev/null || true
systemctl start firewalld cups bluetooth avahi-daemon smartd chronyd 2>/dev/null || true
firewall-cmd --add-service=ipp --add-service=ipp-client --permanent 2>/dev/null || true
firewall-cmd --reload 2>/dev/null || true
log "Servicios activados."

# ============================================================
# 18. SNAPPER (SNAPSHOTS)
# ============================================================
sec "18. SNAPPER"

snapper -c root set-config TIMELINE_CREATE=yes TIMELINE_CLEANUP=yes \
    NUMBER_LIMIT=10 TIMELINE_LIMIT_DAILY=7 TIMELINE_LIMIT_WEEKLY=4 2>/dev/null || true
systemctl enable snapperd 2>/dev/null || true
systemctl start snapperd 2>/dev/null || true
log "Snapper configurado."

# ============================================================
# 19. HOSTNAME
# ============================================================
sec "19. HOSTNAME"

if [ "$(hostname)" != "$NEW_HOSTNAME" ]; then
    hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null && \
        log "Hostname cambiado a: $NEW_HOSTNAME" || warn "No se pudo cambiar hostname"
fi

# ============================================================
# 20. GTK — TEMAS
# ============================================================
sec "20. TEMAS GTK"

sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/gtk-3.0" "$REAL_HOME/.config/gtk-4.0"
sudo -u "$REAL_USER" tee "$REAL_HOME/.config/gtk-3.0/settings.ini" > /dev/null << 'GTK3'
[Settings]
gtk-theme-name=Breeze
gtk-icon-theme-name=breeze-dark
gtk-font-name=Noto Sans, 10
gtk-cursor-theme-name=Breeze
gtk-application-prefer-dark-theme=true
GTK3

sudo -u "$REAL_USER" tee "$REAL_HOME/.config/gtk-4.0/settings.ini" > /dev/null << 'GTK4'
[Settings]
gtk-theme-name=Breeze
gtk-icon-theme-name=breeze-dark
gtk-font-name=Noto Sans, 10
gtk-cursor-theme-name=Breeze
gtk-application-prefer-dark-theme=true
GTK4
log "Temas GTK configurados (oscuro)."

# ============================================================
# 21. FUENTES — MESLOLGS NERD FONT (para Powerlevel10k)
# ============================================================
sec "21. FUENTES POWERLEVEL10K (MesloLGS)"

FONT_DIR="$REAL_HOME/.local/share/fonts"
sudo -u "$REAL_USER" mkdir -p "$FONT_DIR"

# Verificar si ya están instaladas (por backup o previa instalación)
if fc-list 2>/dev/null | grep -q "MesloLGS"; then
    log "MesloLGS Nerd Font ya instaladas."
else
    log "Descargando MesloLGS Nerd Font desde GitHub..."
    FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for f in "MesloLGS NF Regular.ttf" "MesloLGS NF Bold.ttf" \
             "MesloLGS NF Italic.ttf" "MesloLGS NF Bold Italic.ttf"; do
        sudo -u "$REAL_USER" wget -q --timeout=15 \
            -O "$FONT_DIR/$f" \
            "$FONT_BASE/${f// /%20}" 2>/dev/null || \
            warn "Falló descarga de: $f"
    done
    sudo -u "$REAL_USER" fc-cache -f "$FONT_DIR" 2>/dev/null || true
    log "MesloLGS Nerd Font instaladas. Reabre la terminal para ver el cambio."
fi

# ============================================================
# 22. CONFIGURACIÓN YT-DLP
# ============================================================
sec "22. YT-DLP — CONFIGURACION OPTIMIZADA"
echo -e "${Y}  Escribe config optimizada con rutas, calidad, anti-bot, retry-logic y post-procesado.${N}\n"

sudo -u "$REAL_USER" mkdir -p "$REAL_HOME/.config/yt-dlp"

# Escribimos paths correctos según YT_ROOT definido por el usuario
sudo -u "$REAL_USER" tee "$REAL_HOME/.config/yt-dlp/config" > /dev/null << YTDPLP
# ============================================================
# CONFIGURACIÓN YT-DLP OPTIMIZADA
# Generado por setup-opensuse.sh
# YT_ROOT: $YT_ROOT
# ============================================================

# 1. RUTAS Y ORGANIZACIÓN
--paths "home:$YT_ROOT/finalizados"
--paths "temp:$YT_ROOT/temp"
--download-archive "$YT_ROOT/historial.txt"
-o "%(playlist_title&{} / |)s%(playlist_index&{} - |)s%(title)s [%(id)s].%(ext)s"
--restrict-filenames
--trim-filenames 160

# 2. CALIDAD Y FORMATO
-f "bestvideo+bestaudio/best"
--merge-output-format mp4
--hls-prefer-native

# 3. RENDIMIENTO
--continue
--no-overwrites
--buffer-size 16M
--http-chunk-size 20M
--concurrent-fragments 4
# --limit-rate 10M  # Controlado desde .zshrc (modo normal/nitro)

# 4. SIGILO Y ANTI-BOT
--user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
--sleep-interval 5
--max-sleep-interval 15
--sleep-requests 2
--force-ipv4
--check-formats
--ignore-errors

# 5. GESTIÓN DE ERRORES
--retries 10
--fragment-retries 10
--retry-sleep 5

# 6. POST-PROCESADO
--embed-thumbnail
--add-metadata
YTDPLP

log "Configuración yt-dlp creada (paths apuntan a: $YT_ROOT)."

# ============================================================
# 23. RESTAURAR CONFIGS DESDE BACKUP (opcional)
# ============================================================
sec "23. RESTAURAR CONFIGS — OPENCODE / WARP / SHELLGPT"
echo -e "${Y}  Si proporcionaste un backup, restaura configs de opencode, warp-terminal, shell_gpt,${N}"
echo -e "${Y}  fuentes MesloLGS, yt-dlp, GTK, .inputrc y .p10k.zsh.${N}\n"

if [ -n "$CONFIG_BACKUP_PATH" ] && [ -f "$CONFIG_BACKUP_PATH" ]; then
    log "Restaurando configs desde: $CONFIG_BACKUP_PATH"
    sudo -u "$REAL_USER" tar -xzf "$CONFIG_BACKUP_PATH" -C "$REAL_HOME" 2>/dev/null && \
        log "Configs restauradas correctamente." || \
        warn "Error al extraer el backup. Verifica la ruta."
else
    log "No se especificó backup o no existe. Las siguientes configs pueden restaurarse manualmente:"
    echo "  • OpenCode:   ~/.config/opencode/"
    echo "  • Warp:       ~/.config/warp-terminal/"
    echo "  • ShellGPT:   ~/.config/shell_gpt/"
    echo "  • Fuentes:    ~/.local/share/fonts/ (MesloLGS ya instaladas arriba)"
    echo ""
    echo "  Si quieres restaurarlas, usa el backup generado al principio de este script:"
    echo "    tar -xzf backup-configs.tar.gz -C ~/"
fi

# ============================================================
# 24. CUPS — IMPRESORA HP (opcional, no bloquea)
# ============================================================
sec "24. IMPRESORA (opcional)"
echo -e "${Y}  Configura impresora de red via IPP Everywhere.${N}"
echo -e "${Y}  Activa administracion remota de CUPS y firewall para impresion.${N}\n"

cupsctl --remote-admin --remote-any 2>/dev/null || true
if [ -n "$PRINTER_URI" ]; then
    PRINTER_NAME="impresora_red"
    lpadmin -p "$PRINTER_NAME" -E -v "$PRINTER_URI" -m everywhere 2>/dev/null && \
        log "Impresora configurada: $PRINTER_URI" || \
        warn "No se pudo configurar la impresora. Verifica la URI."
else
    log "No se configuró impresora. Puedes hacerlo después con: hp-setup"
fi

# ============================================================
# 25. JETBRAINS TOOLBOX (opcional)
# ============================================================
if $INSTALL_JETBRAINS; then
    sec "25. JETBRAINS TOOLBOX"
    echo -e "${Y}  Descarga e instala JetBrains Toolbox para gestionar IDEs (IntelliJ, PyCharm, etc).${N}\n"
    if [ ! -d "$REAL_HOME/.local/share/JetBrains/Toolbox" ]; then
        log "Descargando JetBrains Toolbox..."
        sudo -u "$REAL_USER" wget -q --timeout=30 -O /tmp/jetbrains-toolbox.tar.gz \
            "https://data.services.jetbrains.com/products/download?code=TBA&platform=linux" 2>/dev/null || \
            warn "No se pudo descargar JetBrains Toolbox (sin conexión o timeout)"
        if [ -f /tmp/jetbrains-toolbox.tar.gz ] && [ -s /tmp/jetbrains-toolbox.tar.gz ]; then
            sudo -u "$REAL_USER" tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /tmp/ 2>/dev/null || true
            find /tmp -maxdepth 1 -name "jetbrains-toolbox-*" -type d | while read dir; do
                sudo -u "$REAL_USER" "$dir/jetbrains-toolbox" --install 2>/dev/null || true
            done
            rm -f /tmp/jetbrains-toolbox.tar.gz
            log "JetBrains Toolbox instalado."
        fi
    else
        log "JetBrains Toolbox ya instalado."
    fi
fi

# ============================================================
# 26. LM STUDIO CLI (opcional)
# ============================================================
if $INSTALL_LMSTUDIO; then
    sec "26. LM STUDIO CLI"
    echo -e "${Y}  Descarga lms (CLI de LM Studio) para ejecutar modelos de IA localmente.${N}\n"
    if [ ! -f "$REAL_HOME/.lmstudio/bin/lms" ]; then
        mkdir -p "$REAL_HOME/.lmstudio/bin"
        sudo -u "$REAL_USER" wget -q --timeout=15 -O "$REAL_HOME/.lmstudio/bin/lms" \
            "https://release.lmstudio.ai/linux/lms" 2>/dev/null || \
            warn "No se pudo descargar LM Studio CLI"
        chmod +x "$REAL_HOME/.lmstudio/bin/lms" 2>/dev/null || true
        chown -R "$REAL_USER":"$REAL_USER" "$REAL_HOME/.lmstudio"
        log "LM Studio CLI instalado."
    fi
fi

# ============================================================
# 27. POWERLEVEL10K .p10k.zsh
# ============================================================
sec "27. POWERLEVEL10K CONFIG"
echo -e "${Y}  Escribe config basica de Powerlevel10k con tema Nerd Font,${N}"
echo -e "${Y}  prompt con contexto/directorio/git y nueva linea.${N}\n"

sudo -u "$REAL_USER" tee "$REAL_HOME/.p10k.zsh" > /dev/null << 'P10K'
# Powerlevel10k
POWERLEVEL9K_MODE=nerdfont-complete
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs time)
POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
P10K

# ============================================================
# FINAL
# ============================================================
sec "INSTALACION COMPLETADA"

echo ""
log "Resumen final:"
echo "  Sistema:    openSUSE Tumbleweed actualizado"
echo "  Shell:      Zsh + Oh My Zsh + Powerlevel10k + MesloLGS"
echo "  Terminal:   menu yt-dlp (descargar/descargar-video/descargar-audio) + Warp + Konsole"
echo "  IDEs:       VS Code ($(command -v code &>/dev/null && echo "OK" || echo "NO")) + JetBrains ($([ $INSTALL_JETBRAINS = true ] && echo 'SI' || echo 'NO'))"
echo "  Desarrollo: Python, Node, Java, GCC, Ruby, MySQL, Git configurado"
echo "  Contenedores: Podman, Distrobox, QEMU/KVM"
echo "  Cloud:      rclone servicios (Gdrive + Mega) - PENDIENTE DE AUTENTICAR"
echo "  Multimedia: VLC, Audacious, yt-dlp configurado"
echo "  NVIDIA:     $([ $INSTALL_NVIDIA = true ] && echo 'drivers instalados' || echo 'no instalados (AMD/Intel stock)')"
echo "  Flatpak:    $([ $INSTALL_FLATPAK = true ] && echo '14 apps instaladas' || echo 'no instalados')"
echo "  Ollama:     $([ $INSTALL_OLLAMA_MODELS = true ] && echo 'modelos descargados' || echo 'no instalados')"
echo "  Keychron:   $([ $INSTALL_KEYCHRON = true ] && echo 'regla udev instalada' || echo 'no configurado')"
echo "  Backup:     $( [ -n \"$CONFIG_BACKUP_PATH\" ] && [ -f \"$CONFIG_BACKUP_PATH\" ] && echo 'restaurado' || echo 'no se resto (puedes hacerlo manual)')"
echo ""

echo -e "${Y}══════════════════════════════════════════════════════════════${N}"
echo -e "${Y}   QUE HACER AHORA${N}"
echo -e "${Y}══════════════════════════════════════════════════════════════${N}"
echo ""
echo -e "${C}  1. REINICIAR EL SISTEMA (recomendado)${N}"
echo "     sudo reboot"
echo "     Al reiniciar veras el prompt de Powerlevel10k para personalizar el theme."
echo ""
echo -e "${C}  2. RCLONE — AUTENTICAR (necesario para cloud)${N}"
echo "     systemctl --user daemon-reload"
echo "     rclone config reconnect Gdrive:"
echo "     rclone config reconnect Mega:"
echo "     systemctl --user start gdrive.service rclone-mega.service"
echo "     systemctl --user enable gdrive.service rclone-mega.service"
echo ""
echo -e "${C}  3. DISCOS DE DATOS${N}"
echo "     Verifica montaje: lsblk -f"
echo "     Monta todo:       sudo mount -a"
if [ ${#DISK_MAP[@]} -eq 0 ]; then
echo "     (No configuraste discos en el survey. Edita /etc/fstab si los conectas despues)"
fi
echo ""
echo -e "${C}  4. INICIAR SESION EN APPS${N}"
echo "     Brave / Firefox → sincroniza marcadores"
echo "     Discord, Slack, Zoom, Steam, Telegram, Obsidian"
if $INSTALL_JETBRAINS; then
echo ""
echo -e "${C}  5. JETBRAINS TOOLBOX${N}"
echo "     Abrelo desde el menu de aplicaciones e instala los IDEs que necesites."
fi
echo ""
echo -e "${Y}────────────────────────────────────────────────────────────${N}"
echo ""
echo -e "${G}  Sistema listo. Disfruta tu openSUSE Tumbleweed.${N}"
echo ""
echo -e "${Y}  Recordatorio: Para la proxima reinstalacion, ejecuta ANTES:${N}"
echo "    bash setup-opensuse.sh backup"
echo "  Eso respaldara tus configs (opencode, warp, shellgpt, fuentes, yt-dlp)"
echo "  y este script las restaurara automaticamente si indicas la ruta."
echo ""
