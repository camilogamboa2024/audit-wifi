# ⚡ Audit-WiFi / Auto-Crack

Script Bash que recorre la carpeta **captures/** y crackea automáticamente todos los handshakes `.cap` usando **aircrack-ng** y un diccionario proporcionado por el usuario.  
Cada intento guarda un log individual en **crack-logs/**.

---

## 🚀 Características

- Verificación de root.
- Pregunta interactivamente la ruta del diccionario.
- Busca todos los archivos `.cap` dentro de `./captures`.
- Ejecuta `aircrack-ng` por cada captura y guarda la salida (`.log`).
- Colores ANSI para mejor legibilidad.

---

## 📋 Requisitos

| Paquete      | Versión recomendada |
|--------------|--------------------|
| Bash         | ≥ 4 |
| aircrack-ng  | ≥ 1.6 |
| GNU find     | — |

Instalación rápida en Debian/Parrot:

```bash
sudo apt update && sudo apt install aircrack-ng


sudo bash audit-wifi.sh