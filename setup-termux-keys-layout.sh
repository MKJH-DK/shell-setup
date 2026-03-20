#!/usr/bin/env bash

# Opret .termux mappen hvis den ikke findes
mkdir -p ~/.termux

# Konfigurer extra-keys i termux.properties
# Dette er det endelige layout:
# Række 1: TAB, ESC, DEL, END, DRAWER, PGUP, UP, PGDN
# Række 2: SHIFT, CTRL, SUP, ALT, ALTGR, LEFT, DOWN, RIGHT
cat <<EOF > ~/.termux/termux.properties
extra-keys-text-all-caps = false
extra-keys = [ \
  [{key: 'TAB', display: 'TAB'}, 'ESC', {key: 'BACKSPACE', display: 'DEL'}, 'END', 'DRAWER', 'PGUP', 'UP', 'PGDN'], \
  ['SHIFT', 'CTRL', {key: 'SUPER', display: 'SUP'}, 'ALT', 'ALTGR', 'LEFT', 'DOWN', 'RIGHT'] \
]
EOF

# Genindlæs indstillingerne
termux-reload-settings

echo "[SUCCESS] Termux layout er nu permanent gemt i setup-termux-keys.sh!"
echo "Layoutet er præcis som du ønskede det."
