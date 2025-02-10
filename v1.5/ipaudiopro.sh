#!/bin/bash

# ---------------------------
# IPAudioPro Setup Script
# ---------------------------
# Project: IPAudioPro
# Author: zKhadiri
# ---------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

IPK=""
ARCH=""
PY_VER=""
VERSION=1.5
FFMPEG_VERSION=""
BASE_URL="https://raw.githubusercontent.com/emilnabil/ipaudiopro/refs/heads/main"

SUPPORTED_FFMPEG_VERSIONS=(
    4
    4.4.1
    6
    7
    7.1
)

welcome_message() {
    echo -e "${CYAN}##########################################${RESET}"
    echo -e "${YELLOW}###    Welcome to IPAudioPro Setup!    ###${RESET}"
    echo -e "${CYAN}##########################################${RESET}"
}

detect_python_version() {
    if command -v python3 &>/dev/null; then
        python3 --version 2>&1 | awk '{print $2}' | cut -d'.' -f1-2
    elif command -v python &>/dev/null; then
        python --version 2>&1 | awk '{print $2}' | cut -d'.' -f1-2
    else
        echo "Python is not installed. Please install Python."
        exit 1
    fi
}

detect_ffmpeg_version() {
    if opkg status ffmpeg &>/dev/null; then
        FFMPEG_VERSION=$(opkg status ffmpeg | grep -i '^Version:' | awk '{print $2}' | cut -d'-' -f1)
        MAJOR_VERSION=$(echo "$FFMPEG_VERSION" | cut -d'.' -f1)
        if (( MAJOR_VERSION > 4 )); then
            FFMPEG_VERSION=$(echo "$FFMPEG_VERSION" | cut -d'.' -f1,2)
        fi

        [[ "$MAJOR_VERSION" -eq 7 ]] && FFMPEG_VERSION=7.1

        if [[ " ${SUPPORTED_FFMPEG_VERSIONS[@]} " =~ " $MAJOR_VERSION " ]]; then
            echo -e "${GREEN}FFmpeg major version $MAJOR_VERSION is supported.${RESET}"
        else
            echo -e "${YELLOW}FFmpeg major version $MAJOR_VERSION is not supported.${RESET}"
            echo -e "${CYAN}Supported versions are: ${SUPPORTED_FFMPEG_VERSIONS[*]}${RESET}"
            exit 1
        fi
    else
        echo -e "${YELLOW}FFmpeg is not installed. Installing FFmpeg...${RESET}"
        opkg update && opkg install ffmpeg
        opkg status ffmpeg &>/dev/null && detect_ffmpeg_version || { echo -e "${RED}Failed to install FFmpeg.${RESET}"; exit 1; }
    fi
}

detect_cpu_arch() {
    echo "Checking Python version..."
    PY_VER=$(detect_python_version)
    echo "Python version: $PY_VER"

    echo "Checking FFmpeg version..."
    detect_ffmpeg_version

    echo "Detecting CPU architecture..."
    CPU_ARCH=$(uname -m)
    echo -e "CPU architecture: ${GREEN}${CPU_ARCH}${RESET}"

    case "$CPU_ARCH" in
        *arm*)
            ARCH=$(detect_arm_arch)
            [[ "$ARCH" == "unknown" ]] && { echo -e "${RED}Unsupported architecture: ${ARCH}${RESET}"; exit 1; }
            CPU_ARCH="arm"
            ;;
        *mips*)
            ARCH="mips32el"
            ;;
        *aarch64*)
            ARCH="aarch64"
            ;;
        *)
            echo -e "${RED}Unsupported architecture: ${CPU_ARCH}${RESET}"
            exit 1
            ;;
    esac

    IPK="enigma2-plugin-extensions-ipaudiopro_${VERSION}_${ARCH}_py${PY_VER}_ff${FFMPEG_VERSION}.ipk"
    echo -e "Detected architecture: ${GREEN}${ARCH}${RESET}"
}

detect_arm_arch() {
    OPKG_DIR="/etc/opkg/"
    [[ -d "$OPKG_DIR" ]] || echo "unknown"
    
    for arch in cortexa15hf-neon-vfpv4 cortexa9hf-neon cortexa7hf-vfp armv7ahf-neon; do
        ls "$OPKG_DIR" | grep -q "$arch" && echo "$arch" && return
    done

    echo "unknown"
}

install_plugin() {
    welcome_message
    detect_cpu_arch

    echo "Checking if IPAudioPro is installed..."
    INSTALLED_VERSION=$(opkg status enigma2-plugin-extensions-ipaudiopro | grep -i 'Version:' | awk '{print $2}' | sed 's/+.*//')
    
    if [[ -n "$INSTALLED_VERSION" ]]; then
        echo "Current installed version: $INSTALLED_VERSION"
        if [[ "$(echo -e "$INSTALLED_VERSION\n$VERSION" | sort -V | tail -n1)" == "$VERSION" ]]; then
            echo "Newer version found. Installing version $VERSION..."
            opkg remove enigma2-plugin-extensions-ipaudiopro
        else
            echo "IPAudioPro is already up to date (version $INSTALLED_VERSION). No action needed."
            return
        fi
    fi

    echo "Installing IPAudioPro..."
    IPK_URL="${BASE_URL}/v${VERSION}/python${PY_VER}/${CPU_ARCH}/${IPK}"
    wget -q "--no-check-certificate" -O "/tmp/${IPK}" "$IPK_URL"
    opkg install "/tmp/${IPK}"
    rm -f "/tmp/${IPK}"
}

download_additional_files() {
    echo "Downloading additional files..."
    wget -O /usr/lib/enigma2/python/Plugins/Extensions/IPaudioPro/logo.png "https://dreambox4u.com/emilnabil237/plugins/ipaudiopro/logo.png"
    wget -O /etc/enigma2/IPAudioPro.json "https://dreambox4u.com/emilnabil237/plugins/ipaudiopro/IPAudioPro.json"
}

restart_box() {
    echo "Restarting Enigma2..."
    killall -9 enigma2
}

install_plugin
download_additional_files
restart_box

exit 0




