#!/usr/bin/env bash
set -Eeuo pipefail

# index.sh - Main menu for shell-setup scripts
# Provides a unified entry point to select and run setup scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ── Load .env API keys ──────────────────────────────────
load_env() {
  local env_file=""
  local search_paths=(
    "$SCRIPT_DIR/.env"
    "$HOME/.env"
    "/storage/emulated/0/vault/03-personal/04-secrets/.env"
    "/storage/emulated/0/vault/.env"
  )
  for p in "${search_paths[@]}"; do
    if [[ -f "$p" ]]; then
      env_file="$p"
      break
    fi
  done

  if [[ -z "$env_file" ]]; then
    return 0
  fi

  local count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// /}" ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.+)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local val="${BASH_REMATCH[2]}"
      export "$key=$val"
      ((++count))
    fi
  done < "$env_file"

  printf "${GREEN}✓ Loaded %d env vars from %s${NC}\n" "$count" "$env_file"
}

load_env

# ── Script registry ──────────────────────────────────────
# Format: "filename|description|requires_interaction"
SCRIPTS=(
  "install.sh|Full shell environment setup (zsh, tools, config)|yes"
  "setup-shellgpt.sh|ShellGPT with multi-provider/model support|yes"
  "setup-micro-minimal.sh|Micro editor minimal configuration|no"
  "setup-termux-keys-layout.sh|Termux extra keyboard layout|no"
  "reset-zsh-history.sh|Seed zsh history with useful commands|no"
)

# ── Helpers ───────────────────────────────────────────────

draw_header() {
  clear 2>/dev/null || true
  printf "${BOLD}${CYAN}"
  cat <<'BANNER'
  ┌──────────────────────────────────┐
  │         shell-setup              │
  │      Setup Script Index          │
  └──────────────────────────────────┘
BANNER
  printf "${NC}\n"
}

draw_menu() {
  local selected="$1"
  local count="${#SCRIPTS[@]}"

  for i in "${!SCRIPTS[@]}"; do
    IFS='|' read -r filename desc interactive <<< "${SCRIPTS[$i]}"

    # Check if script exists
    local exists=true
    [[ ! -f "$SCRIPT_DIR/$filename" ]] && exists=false

    local prefix="  "
    local color="$NC"
    local marker=" "

    if [[ "$i" -eq "$selected" ]]; then
      prefix="${BOLD}${GREEN}▸ "
      color="${BOLD}${GREEN}"
      marker=""
    fi

    if ! $exists; then
      color="${DIM}"
      marker=" (missing)"
    fi

    printf "${prefix}${color}%d) %-35s${DIM} %s${NC}%s\n" \
      "$((i + 1))" "$filename" "$desc" "$marker"
  done

  echo ""
  printf "  ${DIM}q) Quit${NC}\n"
  printf "  ${DIM}a) Run all (non-interactive only)${NC}\n"
  echo ""
}

run_script() {
  local idx="$1"
  IFS='|' read -r filename desc interactive <<< "${SCRIPTS[$idx]}"

  local script_path="$SCRIPT_DIR/$filename"

  if [[ ! -f "$script_path" ]]; then
    printf "${RED}Script not found: %s${NC}\n" "$script_path"
    return 1
  fi

  if [[ ! -x "$script_path" ]]; then
    chmod +x "$script_path"
  fi

  echo ""
  printf "${BOLD}${CYAN}── Running: %s ──${NC}\n\n" "$filename"
  bash "$script_path" "${@:2}"
  local rc=$?
  echo ""

  if [[ $rc -eq 0 ]]; then
    printf "${GREEN}✓ %s completed successfully${NC}\n" "$filename"
  else
    printf "${RED}✗ %s exited with code %d${NC}\n" "$filename" "$rc"
  fi

  return $rc
}

run_all_noninteractive() {
  printf "${BOLD}${CYAN}Running all non-interactive scripts...${NC}\n\n"

  local failed=0
  for i in "${!SCRIPTS[@]}"; do
    IFS='|' read -r filename desc interactive <<< "${SCRIPTS[$i]}"

    if [[ "$interactive" == "no" ]] && [[ -f "$SCRIPT_DIR/$filename" ]]; then
      run_script "$i" || ((failed++))
      echo ""
    fi
  done

  if [[ $failed -eq 0 ]]; then
    printf "${GREEN}All scripts completed successfully${NC}\n"
  else
    printf "${YELLOW}%d script(s) had errors${NC}\n" "$failed"
  fi
}

# ── FZF mode (if available) ──────────────────────────────

run_fzf_mode() {
  local entries=""
  for i in "${!SCRIPTS[@]}"; do
    IFS='|' read -r filename desc interactive <<< "${SCRIPTS[$i]}"
    local status="✓"
    [[ ! -f "$SCRIPT_DIR/$filename" ]] && status="✗"
    entries+="$(printf "%s  %-35s  %s" "$status" "$filename" "$desc")\n"
  done

  local choice
  choice="$(printf "$entries" | fzf \
    --header="shell-setup: Select script to run" \
    --reverse \
    --height=50% \
    --border=rounded \
    --prompt="▸ " \
    --no-multi 2>/dev/null)" || return 0

  # Extract filename from selection
  local selected_file
  selected_file="$(echo "$choice" | awk '{print $2}')"

  # Find matching index
  for i in "${!SCRIPTS[@]}"; do
    IFS='|' read -r filename _ _ <<< "${SCRIPTS[$i]}"
    if [[ "$filename" == "$selected_file" ]]; then
      run_script "$i"
      return $?
    fi
  done
}

# ── Simple menu mode ─────────────────────────────────────

run_simple_menu() {
  while true; do
    draw_header
    draw_menu -1
    read -rp "$(printf "${BOLD}Select [1-${#SCRIPTS[@]}/a/q]: ${NC}")" choice

    case "$choice" in
      q|Q|quit|exit)
        echo "Bye!"
        exit 0
        ;;
      a|A|all)
        run_all_noninteractive
        echo ""
        read -rp "Press Enter to continue..."
        ;;
      [1-9]|[1-9][0-9])
        local idx=$((choice - 1))
        if (( idx >= 0 && idx < ${#SCRIPTS[@]} )); then
          run_script "$idx"
          echo ""
          read -rp "Press Enter to continue..."
        else
          printf "${RED}Invalid choice${NC}\n"
          sleep 1
        fi
        ;;
      *)
        printf "${RED}Invalid choice${NC}\n"
        sleep 1
        ;;
    esac
  done
}

# ── CLI mode (direct execution) ──────────────────────────

usage() {
  cat <<EOF
index.sh - Shell-setup script launcher

Usage: ./index.sh [OPTIONS]

Options:
  (no args)         Interactive menu (fzf if available, otherwise numbered)
  --list            List available scripts
  --run SCRIPT      Run a specific script by name
  --run-all         Run all non-interactive scripts
  --fzf             Force fzf mode
  --simple          Force simple numbered menu
  -h, --help        Show this help

Examples:
  ./index.sh                              # Interactive menu
  ./index.sh --run setup-shellgpt.sh      # Run specific script
  ./index.sh --run install.sh --all       # Pass flags to script
  ./index.sh --run-all                    # All non-interactive scripts
EOF
}

# ── Main ──────────────────────────────────────────────────

main() {
  case "${1:-}" in
    -h|--help)
      usage
      exit 0
      ;;
    --list)
      printf "${BOLD}Available scripts:${NC}\n\n"
      for i in "${!SCRIPTS[@]}"; do
        IFS='|' read -r filename desc interactive <<< "${SCRIPTS[$i]}"
        local status="${GREEN}✓${NC}"
        [[ ! -f "$SCRIPT_DIR/$filename" ]] && status="${RED}✗${NC}"
        printf "  %b %-35s %s\n" "$status" "$filename" "$desc"
      done
      ;;
    --run)
      shift
      local target="${1:?Script name required}"
      shift
      for i in "${!SCRIPTS[@]}"; do
        IFS='|' read -r filename _ _ <<< "${SCRIPTS[$i]}"
        if [[ "$filename" == "$target" ]]; then
          run_script "$i" "$@"
          exit $?
        fi
      done
      err "Script not found: $target"
      exit 1
      ;;
    --run-all)
      run_all_noninteractive
      ;;
    --fzf)
      run_fzf_mode
      ;;
    --simple)
      run_simple_menu
      ;;
    "")
      # Auto-select: fzf if available, otherwise simple menu
      if command -v fzf >/dev/null 2>&1; then
        run_fzf_mode
      else
        run_simple_menu
      fi
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
}

main "$@"
