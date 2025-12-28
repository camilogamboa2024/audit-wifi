#!/bin/bash

set -euo pipefail

# NEOSOFT Wi-Fi Auditor by Camilo
# Versión: 1.0 - Bash
# Script para escanear y capturar múltiples handshakes

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verifica si se está ejecutando como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[✘] Este script debe ejecutarse como root.${NC}"
        exit 1
    fi
}

check_dependencies() {
    local missing=()
    for cmd in iw ip airmon-ng airodump-ng timeout grep awk cut nl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        echo -e "${RED}[✘] Faltan dependencias: ${missing[*]}.${NC}"
        echo -e "${YELLOW}Instala las dependencias faltantes y vuelve a ejecutar el script.${NC}"
        exit 1
    fi
}

# Detecta interfaces Wi-Fi disponibles
detect_interfaces() {
    iw dev | awk '$1=="Interface"{print $2}'
}

# Permite al usuario seleccionar una interfaz
select_interface() {
    mapfile -t interfaces < <(detect_interfaces)

    if (( ${#interfaces[@]} == 0 )); then
        echo -e "${RED}[✘] No se detectaron interfaces Wi-Fi disponibles.${NC}"
        exit 1
    fi

    echo -e "${CYAN}[?] Selecciona una interfaz Wi-Fi:${NC}"
    PS3="${CYAN}Interfaz #> ${NC}"
    select iface in "${interfaces[@]}"; do
        if [[ -n "${iface:-}" ]]; then
            break
        fi
        echo -e "${YELLOW}[!] Selección inválida. Intenta nuevamente.${NC}"
    done
}

# Activa modo monitor
enable_monitor_mode() {
    echo -e "${CYAN}[~] Activando modo monitor en $iface...${NC}"
    airmon-ng check kill > /dev/null 2>&1
    ip link set "$iface" down
    iw dev "$iface" set type monitor
    ip link set "$iface" up
    echo -e "${GREEN}[✓] Modo monitor activado: $iface${NC}"
}

# Escanea redes y guarda resultados por 30 segundos
scan_networks() {
    echo -e "${CYAN}[~] Escaneando redes por 30 segundos...${NC}"
    rm -f scan-01.csv
    if ! timeout 30s airodump-ng "$iface" --output-format csv --write scan > /dev/null 2>&1; then
        echo -e "${RED}[✘] Error al ejecutar airodump-ng.${NC}"
        exit 1
    fi

    if [[ ! -s scan-01.csv ]]; then
        echo -e "${YELLOW}[!] No se encontraron redes durante el escaneo.${NC}"
        return 1
    fi

    if ! grep -aE '([0-9A-F]{2}:){5}[0-9A-F]{2}' scan-01.csv | cut -d',' -f1,14 | nl; then
        echo -e "${YELLOW}[!] No se pudieron analizar los resultados del escaneo.${NC}"
    fi
}

# Permite capturar múltiples handshakes en un ciclo
multi_capture() {
    echo -e "${YELLOW}[!] Podés capturar múltiples redes. Usa Ctrl+C para detener cada captura.${NC}"
    local count=0
    while true; do
        echo -e "\n${CYAN}[+] Captura #$((++count))${NC}"
        read -r -p "BSSID objetivo: " bssid
        read -r -p "Canal: " channel
        read -r -p "Nombre (sin espacios): " name

        if [[ -z "$bssid" || -z "$channel" || -z "$name" ]]; then
            echo -e "${YELLOW}[!] BSSID, canal y nombre son obligatorios. Intenta nuevamente.${NC}"
            ((count--))
            continue
        fi

        dir="captures/$name-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$dir"
        echo -e "${CYAN}[~] Capturando handshake de $name...${NC}"
        airodump-ng "$iface" -c "$channel" --bssid "$bssid" -w "$dir/handshake"

        read -r -p "${YELLOW}¿Deseas capturar otra red? (s/n): ${NC}" otra
        [[ ${otra,,} != "s" ]] && break
    done
}

# Restaura la interfaz al modo gestionado
reset_interface() {
    [[ -z "${iface:-}" ]] && return
    echo -e "${CYAN}[~] Restaurando interfaz a modo gestionado...${NC}"
    ip link set "$iface" down
    iw dev "$iface" set type managed
    ip link set "$iface" up
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart NetworkManager >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}[✓] Interfaz restaurada: $iface${NC}"
}

# Función principal del script
main() {
    check_root
    check_dependencies
    trap reset_interface EXIT
    select_interface
    enable_monitor_mode
    scan_networks || true
    multi_capture
    echo -e "${GREEN}[✓] Auditoría completada.${NC}"
}

main
