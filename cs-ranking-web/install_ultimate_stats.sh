#!/bin/bash

# Installer UltimateStats CS 1.6
# Pega stats do CS e grava no MySQL

set -e

echo "=== UltimateStats Installer ==="
echo ""

# Instalar dependências AMXX
apt-get install -y libmariadb-dev

# Compilar plugin AMXX (Pawn)
cd /opt/cstrike/cstrike/addons/amxmodx/

# Baixar source do UltimateStats
wget -q https://github.com/sufficit/UltimateStats/archive/refs/heads/main.zip -O ultimate_stats.zip
unzip -q ultimate_stats.zip -d /tmp/
mv /tmp/UltimateStats-main ultimate_stats_source

# Compilar com amxxpc
if [ -f /opt/cstrike/cstrike/addons/amxmodx/scripting/amxxpc ]; then
    /opt/cstrike/cstrike/addons/amxmodx/scripting/amxxpc \
        -i/opt/cstrike/cstrike/addons/amxmodx/scripting/include \
        ultimate_stats_source/ultimate_stats.sma
    mv ultimate_stats.amxx plugins/
else
    # Copiar binário compilado
    cp ultimate_stats_source/ultimate_stats.amxx plugins/
fi

# Limpar
rm -rf ultimate_stats.zip ultimate_stats_source

echo "Plugin instalado: /opt/cstrike/cstrike/addons/amxmodx/plugins/ultimate_stats.amxx"