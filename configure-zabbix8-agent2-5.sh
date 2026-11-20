#!/usr/bin/env bash
# Konfigurace Zabbix Agent 2 (8.0): unikatni jmeno, Server/ServerActive, HostMetadata, restart
set -euo pipefail

ZBX_URL="https://enceladus.pfsense.cz/"
SURNAME="brichacek"            # <- SEM NAPIS SVE PRIJMENI (mala pismena, bez diakritiky, napr. "novak")
HOST_METADATA="SPOS"

CONF="/etc/zabbix/zabbix_agent2.conf"
ID_FILE="/etc/zabbix/unique_id"

if [ ! -f "$CONF" ]; then
  echo "Chyba: $CONF neexistuje. Nejdriv spust install-zabbix8-agent2.sh" >&2
  exit 1
fi

# Zabbix agent v parametrech Server/ServerActive neumi URL, jen hostname/IP (+ volitelne :port)
ZBX_HOST="${ZBX_URL#*://}"
ZBX_HOST="${ZBX_HOST%%/*}"

# --- Unikatni jmeno: nahodna cast + prijmeni ---
# Nahodna cast se vygeneruje jen jednou a ulozi (pri dalsim provisioningu zustane stejna).
# machine-id se nepouziva, protoze je v Vagrant boxu casto u vsech stejne.
if [ ! -s "$ID_FILE" ]; then
  # 3 nahodne bajty -> 6 hex znaku
  od -An -N3 -tx1 /dev/urandom | tr -d ' \n' > "$ID_FILE"
fi
UNIQUE_NAME="debian-${SURNAME}-$(cat "$ID_FILE")"

# Zmena hostname systemu + oprava /etc/hosts
hostnamectl set-hostname "$UNIQUE_NAME"
if grep -qE '^127\.0\.1\.1' /etc/hosts; then
  sed -i -E "s|^127\.0\.1\.1.*|127.0.1.1 ${UNIQUE_NAME}|" /etc/hosts
else
  echo "127.0.1.1 ${UNIQUE_NAME}" >> /etc/hosts
fi

# --- Konfigurace agenta ---
set_param() {
  local key="$1" value="$2"
  if grep -qE "^[#[:space:]]*${key}=" "$CONF"; then
    sed -i -E "s|^[#[:space:]]*${key}=.*|${key}=${value}|" "$CONF"
  else
    echo "${key}=${value}" >> "$CONF"
  fi
}

set_param "Server" "$ZBX_HOST"
set_param "ServerActive" "$ZBX_HOST"
set_param "Hostname" "$UNIQUE_NAME"
set_param "HostMetadata" "$HOST_METADATA"

# --- Restart ---
systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

echo "Zabbix agent2 bezi. Hostname: ${UNIQUE_NAME}, Server/ServerActive: ${ZBX_HOST}, HostMetadata: ${HOST_METADATA}"
