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
instalar_docker() {
  sudo apt install -y docker.io
  sudo systemctl enable --now docker

  sudo mkdir -p /etc/dnsmasq.d

  if [ ! -f "$CONF_DOCKER" ]; then
    sudo tee "$CONF_DOCKER" >/dev/null <<EOF
# ===== docker.conf (dnsmasq) =====
port=53
interface=$IFACE
no-dhcp-interface=enp0s3
domain=dns.asir
local=/dns.asir/
listen-address=192.168.19.10
EOF
  fi

  sudo docker pull "$IMAGE"

  if sudo docker ps -a --format '{{.Names}}' | grep -qx "$CONT"; then
    echo "ℹ️ El contenedor $CONT ya existe"
  else
    sudo docker run -d --name "$CONT" \
      --net host \
      --restart unless-stopped \
      -v /etc/dnsmasq.d:/etc/dnsmasq.d \
      "$IMAGE" -k
    echo "✅ contenedor creado (DOCKER)"
  fi
}

estado_docker() {
  sudo docker ps -a | grep -E "(^CONTAINER|$CONT)" || echo "❌ No existe $CONT"
}

arrancar_docker() { sudo docker start "$CONT" 2>/dev/null && echo "✅ arrancado (DOCKER)"; }
parar_docker() { sudo docker stop "$CONT" 2>/dev/null && echo "✅ parado (DOCKER)"; }
reiniciar_docker() { sudo docker restart "$CONT" 2>/dev/null && echo "✅ reiniciado (DOCKER)"; }

logs_docker() { 
    echo "1) Ver últimos 50 logs"
    echo "2) Filtrar por fecha (YYYY-MM-DD)"
    read -p "Opción: " optlog
    case $optlog in
        1) sudo docker logs --tail 50 "$CONT" ;;
        2) read -p "Introduce la fecha (YYYY-MM-DD): " FECHA
           sudo docker logs "$CONT" 2>&1 | grep "$FECHA" ;;
    esac
}

editar_docker() {
  sudo nano "$CONF_DOCKER"
  sudo docker restart "$CONT" 2>/dev/null
  echo "✅ guardado y reiniciado (DOCKER)"
}

borrar_docker() {
  sudo docker rm -f "$CONT" 2>/dev/null && echo "✅ eliminado (DOCKER)"
}

# ================= MENÚS =================

menu_apt() {
  while true; do
    echo -e "\n===== MENU APT ====="
    echo "4) Estado"
    echo "5) Arrancar"
    echo "6) Parar"
    echo "7) Reiniciar"
    echo "8) Logs (Hoy/Fecha)"
    echo "9) Editar config"
    echo "10) Eliminar"
    echo "0) Volver"
    read -p "Opcion: " op

    case $op in
      4) estado_apt ;;
      5) arrancar_apt ;;
      6) parar_apt ;;
      7) reiniciar_apt ;;
      8) logs_apt ;;
      9) editar_apt ;;
      10) borrar_apt ;;
      0) break ;;
    esac
  done
}


