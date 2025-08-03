#!/bin/bash

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

# Detecta interfaces Wi-Fi disponibles
detect_interfaces() {
    iw dev | awk '$1=="Interface"{print $2}'
}

# Permite al usuario seleccionar una interfaz
select_interface() {
    interfaces=($(detect_interfaces))
    echo -e "${CYAN}[?] Selecciona una interfaz Wi-Fi:${NC}"
    select iface in "${interfaces[@]}"; do
        [[ -n "$iface" ]] && break
    done
}

# Activa modo monitor
enable_monitor_mode() {
    echo -e "${CYAN}[~] Activando modo monitor en $iface...${NC}"
    airmon-ng check kill > /dev/null 2>&1
    ip link set $iface down
    iw dev $iface set type monitor
    ip link set $iface up
    echo -e "${GREEN}[✓] Modo monitor activado: $iface${NC}"
}

# Escanea redes y guarda resultados por 30 segundos
scan_networks() {
    echo -e "${CYAN}[~] Escaneando redes por 30 segundos...${NC}"
    rm -f scan-01.csv
    timeout 30s airodump-ng $iface --output-format csv --write scan > /dev/null 2>&1
    grep -aE '([0-9A-F]{2}:){5}[0-9A-F]{2}' scan-01.csv | cut -d',' -f1,14 | nl
}

# Permite capturar múltiples handshakes en un ciclo
multi_capture() {
    echo -e "${YELLOW}[!] Podés capturar múltiples redes. Usa Ctrl+C cuando termines.${NC}"
    count=0
    while true; do
        echo -e "\n${CYAN}[+] Captura #$((++count))${NC}"
        read -p "BSSID objetivo: " bssid
        read -p "Canal: " channel
        read -p "Nombre (sin espacios): " name
        dir="captures/$name-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$dir"
        echo -e "${CYAN}[~] Capturando handshake de $name...${NC}"
        gnome-terminal -- bash -c "airodump-ng $iface -c $channel --bssid $bssid -w $dir/handshake; exec bash"
        read -p "${YELLOW}¿Deseas capturar otra red? (s/n): ${NC}" otra
        [[ $otra != "s" ]] && break
    done
}

# Restaura la interfaz al modo gestionado
reset_interface() {
    echo -e "${CYAN}[~] Restaurando interfaz a modo gestionado...${NC}"
    ip link set $iface down
    iw dev $iface set type managed
    ip link set $iface up
    systemctl restart NetworkManager
    echo -e "${GREEN}[✓] Interfaz restaurada: $iface${NC}"
}

# Función principal del script
main() {
    check_root
    select_interface
    enable_monitor_mode
    scan_networks
    multi_capture
    reset_interface
    echo -e "${GREEN}[✓] Auditoría completada.${NC}"
}

main
