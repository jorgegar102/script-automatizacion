#!/bin/bash
sudo apt update && sudo apt upgrade -y

IFACE="enp0s8"

# Rutas de configuración
CONF_APT="/etc/dnsmasq.conf"
CONF_DOCKER="/etc/dnsmasq.d/docker.conf"
CONT="dnsmasq"
IMAGE="jpillora/dnsmasq"

# ================= FUNCIONES =================

red() {
  ip a show $IFACE
}

# ---------- APT ----------
instalar_apt() {
  # Arregla el error "imposible resolver el anfitrión nodo1"
  if ! grep -q "$(hostname)" /etc/hosts; then
      echo "127.0.1.1 $(hostname)" | sudo tee -a /etc/hosts > /dev/null
  fi

  # Libera el puerto 53 (Evita "La dirección ya se está usando")
  sudo systemctl stop systemd-resolved 2>/dev/null
  sudo systemctl disable systemd-resolved 2>/dev/null

  # Asegura internet temporal para descargar el paquete
  echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
  # -----------------------------------------------------

  sudo apt update
  sudo apt install -y dnsmasq
  
  # Aplicar la configuración exacta solicitada
  sudo tee "$CONF_APT" >/dev/null <<EOF
port=53
domain-needed
no-dhcp-interface=enp0s8
bogus-priv
expand-hosts
domain=dns.asir
local=/dns.asir/
no-resolv
server=8.8.8.8
listen-address=127.0.0.1,192.168.1.10
EOF

  sudo systemctl enable --now dnsmasq
  sudo systemctl restart dnsmasq
  echo "✅ dnsmasq instalado y configurado sin errores (APT)"
}

estado_apt() { systemctl status dnsmasq --no-pager; }
arrancar_apt() { sudo systemctl start dnsmasq; echo "✅ arrancado (APT)"; }
parar_apt() { sudo systemctl stop dnsmasq; echo "✅ parado (APT)"; }
reiniciar_apt() { sudo systemctl restart dnsmasq; echo "✅ reiniciado (APT)"; }

# Función de logs con opción de fecha
logs_apt() { 
    echo "1) Ver últimos 50 logs"
    echo "2) Ver logs por fecha (YYYY-MM-DD)"
    read -p "Opción: " optlog
    case $optlog in
        1) journalctl -u dnsmasq --no-pager | tail -n 50 ;;
        2) read -p "Introduce la fecha (YYYY-MM-DD): " FECHA
           journalctl -u dnsmasq --since "$FECHA" --no-pager ;;
        *) echo "Opción no válida" ;;
    esac
}

editar_apt() {
  sudo nano "$CONF_APT"
  sudo systemctl restart dnsmasq
  echo "✅ guardado y reiniciado (APT)"
}

borrar_apt() {
  sudo systemctl stop dnsmasq 2>/dev/null
  sudo apt remove -y dnsmasq
  sudo apt autoremove -y
  echo "✅ eliminado (APT)"
}

# ---------- DOCKER ----------


# ================= MENÚS =================
