#!/usr/bin/env bash
# Instalace Zabbix Agent 2 (8.0) na Debian 13
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

ZBX_VER="8.0"
BASE_URL="https://repo.zabbix.com/zabbix/${ZBX_VER}/release/debian/pool/main/z/zabbix-release"
# Oficialni nazev balicku pro 8.0; druhy je zaloha (starsi/alternativni schema nazvu)
REPO_DEBS=("zabbix-release_latest+debian13_all.deb" "zabbix-release_latest_${ZBX_VER}+debian13_all.deb")

# Preskoc jen pokud uz bezi agent2 verze 8.x
if dpkg -s zabbix-agent2 >/dev/null 2>&1; then
  INSTALLED_VER="$(dpkg-query -W -f='${Version}' zabbix-agent2)"
  case "$INSTALLED_VER" in
    1:8.0.*|8.0.*)
      echo "zabbix-agent2 ${INSTALLED_VER} je uz nainstalovany, preskakuji instalaci."
      exit 0
      ;;
    *)
      echo "Nalezen zabbix-agent2 ${INSTALLED_VER}, provedu upgrade na ${ZBX_VER}."
      ;;
  esac
fi

apt-get update -y
apt-get install -y wget ca-certificates openssl

# wget https://repo.zabbix.com/zabbix/8.0/release/debian/pool/main/z/zabbix-release/zabbix-release_latest+debian13_all.deb
DOWNLOADED=""
for REPO_DEB in "${REPO_DEBS[@]}"; do
  if wget -q -O "/tmp/${REPO_DEB}" "${BASE_URL}/${REPO_DEB}"; then
    DOWNLOADED="/tmp/${REPO_DEB}"
    break
  fi
  rm -f "/tmp/${REPO_DEB}"
done

if [ -z "$DOWNLOADED" ]; then
  echo "Chyba: nepodarilo se stahnout repo balicek Zabbix ${ZBX_VER} pro Debian 13." >&2
  exit 1
fi

# Odstran stary zabbix.list (7.0), aby dpkg nahradil konfiguraci repozitare novou
rm -f /etc/apt/sources.list.d/zabbix.list

# dpkg -i zabbix-release_latest+debian13_all.deb
dpkg -i --force-confnew "$DOWNLOADED"

apt-get update -y
apt-get install -y zabbix-agent2

systemctl enable zabbix-agent2

echo "Instalace zabbix-agent2 (${ZBX_VER}) hotova."
