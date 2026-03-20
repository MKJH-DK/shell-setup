#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
BACKUP="${HISTFILE}.bak-$(date +%Y%m%d-%H%M%S)"

cp -a "$HISTFILE" "$BACKUP" 2>/dev/null || true

# Vælg dine foretrukne kommandoer her.
# De nederste bliver "mest recente" og dermed typisk foreslået først.
seed_commands=(
  "ls"
  "ll"
  "cd /storage/emulated/0"
  "cd /storage/DACE-470F"
  "cd /storage/emulated/0/obsidian-vault"
  "cd /storage/emulated/0/Scripts"
  "nav"
  "omni"
  "micro"
  "pwd"
)

# Ryd historikfilen helt
: > "$HISTFILE"

# Skriv seed i EXTENDED_HISTORY-format.
# Vi spreder timestamps lidt, så rækkefølgen er entydig.
now="$(date +%s)"
n=0

# Skriv hele listen et par gange, så de bliver "etableret"
for round in 1 2 3; do
  for cmd in "${seed_commands[@]}"; do
    printf ': %d:0;%s\n' "$((now + n))" "$cmd" >> "$HISTFILE"
    n=$((n + 1))
  done
done

# Læg de vigtigste kommandoer til sidst, så de bliver mest "recent"
priority_commands=(
  "nav"
  "omni"
  "micro"
  "cd /storage/emulated/0/obsidian-vault"
  "cd /storage/emulated/0/Scripts"
  "ls"
  "ll"
)

for cmd in "${priority_commands[@]}"; do
  printf ': %d:0;%s\n' "$((now + n))" "$cmd" >> "$HISTFILE"
  n=$((n + 1))
done

echo
echo "History reset complete."
echo "Backup: $BACKUP"
echo "New HISTFILE: $HISTFILE"
echo
echo "Next step:"
echo "  exec zsh -l"
echo
echo "Optional checks after restart:"
echo "  tail -n 20 \"$HISTFILE\""
echo "  type a prefix, then press Up"
