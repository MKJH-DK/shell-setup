#!/usr/bin/env bash

# Script til stabil installation af micro i Termux
echo "[INFO] Opdaterer pakker og installerer micro..."
pkg update -y && pkg install micro -y

# Opret konfigurationsmappe
mkdir -p ~/.config/micro

# Skriv de stabile indstillinger til settings.json
echo "[INFO] Konfigurerer micro med stabile indstillinger og touch-understøttelse..."
cat <<EOF > ~/.config/micro/settings.json
{
    "clipboard": "terminal",
    "mouse": true,
    "colorscheme": "muted-dark",
    "syntax": true,
    "scrollbar": true,
    "tabsize": 4,
    "autoindent": true
}
EOF

# Opret et super-dæmpet minimalistisk farvetema
echo "[INFO] Opretter super-dæmpet farvetema (muted-dark)..."
mkdir -p ~/.config/micro/colorschemes
cat <<EOF > ~/.config/micro/colorschemes/muted-dark.micro
color-link default "#a0a0a0,#121212"
color-link comment "#444444"
color-link identifier "#6a7a7a"
color-link constant "#5a6a7a"
color-link statement "#7a6a6a"
color-link symbol "#666666"
color-link preproc "#7a7a6a"
color-link type "#6a6a7a"
color-link special "#7a706a"
color-link underlined "#777777,u"
color-link error "bold #865b5b"
color-link todo "bold #86865b"
color-link hlsearch "#000000,#6a7a7a"
color-link statusline "#808080,#1a1a1a"
color-link tabbar "#808080,#1a1a1a"
color-link indent-char "#1e1e1e"
color-link line-number "#3a3a3a"
color-link current-line-number "#6a6a6a"
color-link cursor-line "#181818"
color-link color-column "#181818"
color-link selection "#2a2a2a,#a0a0a0"
EOF

echo "[SUCCESS] Micro er nu konfigureret med touch og dæmpet mørkt layout."
echo "Du kan nu køre 'micro' uden problemer."
