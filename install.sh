#!/usr/bin/env bash
# Unified shell setup - auto-detects OS and installs everywhere
# Supports: Termux, Arch, Debian/Ubuntu, Fedora/RHEL, macOS, WSL, Alpine, Void Linux
set -Eeuo pipefail

# ── XDG paths ─────────────────────────────────────────────
LOCAL_BIN="$HOME/.local/bin"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# ── Logging ───────────────────────────────────────────────
log()  { printf '\033[0;32m[%s]\033[0m %s\n' "OK" "$*"; }
info() { printf '\033[0;34m[%s]\033[0m %s\n' ".." "$*"; }
warn() { printf '\033[1;33m[%s]\033[0m %s\n' "!!" "$*" >&2; }
err()  { printf '\033[0;31m[%s]\033[0m %s\n' "!!" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# ── OS Detection ──────────────────────────────────────────

detect_os() {
  # Returns: termux, arch, debian, fedora, alpine, void, macos, wsl, linux-unknown
  if [[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == *com.termux* ]]; then
    echo "termux"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  elif [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL detected - also detect the underlying distro
    if [[ -f /etc/arch-release ]]; then echo "wsl-arch"
    elif [[ -f /etc/debian_version ]]; then echo "wsl-debian"
    elif [[ -f /etc/fedora-release ]]; then echo "wsl-fedora"
    elif [[ -f /etc/alpine-release ]]; then echo "wsl-alpine"
    else echo "wsl-debian"  # WSL default is usually Ubuntu
    fi
  elif [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/debian_version ]]; then
    echo "debian"
  elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
    echo "fedora"
  elif [[ -f /etc/alpine-release ]]; then
    echo "alpine"
  elif have xbps-install; then
    echo "void"
  else
    echo "linux-unknown"
  fi
}

OS="$(detect_os)"
IS_WSL=false
[[ "$OS" == wsl-* ]] && IS_WSL=true
# Strip wsl- prefix for package manager logic
PKG_OS="${OS#wsl-}"

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

as_root() {
  if is_root; then "$@"
  elif have sudo; then sudo "$@"
  elif have doas; then doas "$@"
  else warn "Mangler root/sudo: $*"; return 1
  fi
}

# ── Package installation ──────────────────────────────────

CORE_TOOLS="zsh micro git curl python3 fzf zoxide fd ripgrep tmux direnv bat"

install_termux() {
  info "Installerer pakker via pkg (Termux)"
  pkg update -y && pkg upgrade -y
  pkg install -y \
    zsh micro git curl python \
    fzf zoxide fd ripgrep which file \
    coreutils findutils grep gawk sed less util-linux \
    termux-api tmux direnv bat eza jq openssh
}

install_arch() {
  info "Installerer pakker via pacman (Arch)"
  as_root pacman -Sy --noconfirm --needed \
    zsh micro git curl python python-pip python-pipx \
    fzf zoxide fd ripgrep which file \
    zsh-autosuggestions zsh-syntax-highlighting \
    tmux direnv bat eza jq trash-cli openssh starship
}

install_debian() {
  info "Installerer pakker via apt (Debian/Ubuntu)"
  as_root apt-get update -qq
  as_root apt-get install -y \
    zsh micro git curl python3 python3-pip pipx \
    fzf fd-find ripgrep file \
    tmux direnv bat jq trash-cli openssh-client
  # eza might not be in older versions
  as_root apt-get install -y eza 2>/dev/null || true
  # zoxide isn't in all Debian versions
  if ! have zoxide; then
    info "Installerer zoxide via installer"
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
  fi
  # starship
  if ! have starship; then
    info "Installerer starship via installer"
    curl -sSfL https://starship.rs/install.sh | sh -s -- -y
  fi
  as_root apt-get install -y zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
}

install_fedora() {
  info "Installerer pakker via dnf (Fedora/RHEL)"
  as_root dnf install -y \
    zsh micro git curl python3 python3-pip pipx \
    fzf zoxide fd-find ripgrep which file \
    zsh-autosuggestions zsh-syntax-highlighting \
    tmux direnv bat eza jq trash-cli openssh-clients starship
}

install_alpine() {
  info "Installerer pakker via apk (Alpine)"
  as_root apk update
  as_root apk add \
    zsh micro git curl python3 py3-pip \
    fzf zoxide fd ripgrep file \
    zsh-autosuggestions zsh-syntax-highlighting \
    tmux direnv bat eza jq openssh-client starship
}

install_void() {
  info "Installerer pakker via xbps (Void Linux)"
  as_root xbps-install -Sy \
    zsh micro git curl python3 \
    fzf zoxide fd ripgrep which file \
    tmux direnv bat eza jq trash-cli openssh starship
  as_root xbps-install -y zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
}

install_macos() {
  if ! have brew; then
    info "Installerer Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  info "Installerer pakker via brew (macOS)"
  brew install \
    zsh micro git curl python3 pipx \
    fzf zoxide fd ripgrep \
    zsh-autosuggestions zsh-syntax-highlighting \
    tmux direnv bat eza jq trash-cli starship
}

install_packages() {
  case "$PKG_OS" in
    termux)  install_termux ;;
    arch)    install_arch ;;
    debian)  install_debian ;;
    fedora)  install_fedora ;;
    alpine)  install_alpine ;;
    void)    install_void ;;
    macos)   install_macos ;;
    *)
      warn "Ukendt pakkehåndtering for OS: $OS"
      warn "Installer manuelt: $CORE_TOOLS"
      return 0
      ;;
  esac
}

# ── Extra tools (cross-platform installers) ───────────────

install_extras() {
  # atuin - better shell history
  if ! have atuin; then
    info "Installerer atuin (shell history)"
    curl -sSfL https://setup.atuin.sh | sh -s -- --yes 2>/dev/null || \
      warn "atuin installation fejlede - installer manuelt: https://atuin.sh"
  fi

  # starship - prompt (fallback if not installed via package manager)
  if ! have starship; then
    info "Installerer starship (prompt)"
    curl -sSfL https://starship.rs/install.sh | sh -s -- -y 2>/dev/null || \
      warn "starship installation fejlede"
  fi

  # trash-cli fallback (pip)
  if ! have trash-put && have pip3; then
    pip3 install --user trash-cli 2>/dev/null || true
  fi
}

# ── Zsh plugins (git fallback) ────────────────────────────

install_zsh_plugins_fallback() {
  # Only clone if system packages didn't provide them
  local base="$DATA_HOME/zsh/plugins"
  mkdir -p "$base"

  # Check common system paths
  local found_auto=false found_syntax=false
  for p in \
    "${PREFIX:-/usr}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
    [[ -r "$p" ]] && found_auto=true && break
  done

  for p in \
    "${PREFIX:-/usr}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
    "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
    [[ -r "$p" ]] && found_syntax=true && break
  done

  if ! $found_auto && [[ ! -d "$base/zsh-autosuggestions" ]]; then
    info "Henter zsh-autosuggestions via git"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$base/zsh-autosuggestions"
  fi

  if ! $found_syntax && [[ ! -d "$base/zsh-syntax-highlighting" ]]; then
    info "Henter zsh-syntax-highlighting via git"
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$base/zsh-syntax-highlighting"
  fi
}

# ── Directory setup ───────────────────────────────────────

ensure_dirs() {
  mkdir -p "$LOCAL_BIN" "$CONFIG_HOME" "$CACHE_HOME" "$DATA_HOME"
  mkdir -p "$CONFIG_HOME/zsh" "$CONFIG_HOME/micro/colorschemes" "$CONFIG_HOME/omni"
  mkdir -p "$CACHE_HOME/zsh" "$DATA_HOME/zsh/plugins"
}

# ── Platform-specific setup ───────────────────────────────

setup_termux() {
  if have termux-setup-storage; then
    info "Sikrer Termux storage-adgang"
    termux-setup-storage || warn "termux-setup-storage fejlede eller blev afvist"
  fi

  mkdir -p "$HOME/.termux"
  cat > "$HOME/.termux/termux.properties" <<'EOF'
extra-keys-text-all-caps = false
extra-keys = [ \
  [{key: 'TAB', display: 'TAB'}, 'ESC', {key: 'BACKSPACE', display: 'DEL'}, 'END', 'DRAWER', 'PGUP', 'UP', 'PGDN'], \
  ['SHIFT', 'CTRL', {key: 'SUPER', display: 'SUP'}, 'ALT', 'ALTGR', 'LEFT', 'DOWN', 'RIGHT'] \
]
EOF
  log "Termux extra-keys konfigureret"
}

setup_wsl() {
  # Make Windows drives accessible
  if [[ ! -e "$HOME/win" ]] && [[ -d "/mnt/c/Users" ]]; then
    local winuser
    winuser="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')" || true
    if [[ -n "$winuser" ]] && [[ -d "/mnt/c/Users/$winuser" ]]; then
      ln -sf "/mnt/c/Users/$winuser" "$HOME/win"
      log "Symlink: ~/win -> /mnt/c/Users/$winuser"
    fi
  fi

  # WSL-specific aliases added to zsh config
  info "WSL detected - Windows interop aktiveret"
}

setup_storage_symlink() {
  # If running inside PRoot/chroot on Android, link back to Termux storage
  if [[ "$OS" != "termux" ]]; then
    local termux_home="/data/data/com.termux/files/home"
    if [[ -d "$termux_home/storage" ]] && [[ ! -e "$HOME/storage" ]]; then
      ln -s "$termux_home/storage" "$HOME/storage" || true
      log "Symlink: ~/storage -> Termux storage"
    fi
  fi
}

# ── Navmenu (Python curses file browser) ──────────────────

write_navmenu() {
  cat > "$LOCAL_BIN/navmenu.py" <<'PYEOF'
#!/usr/bin/env python3
import curses
import os
from pathlib import Path

def list_entries(path: Path):
    try:
        items = list(path.iterdir())
    except Exception:
        return []
    items.sort(key=lambda p: (not p.is_dir(), p.name.lower()))
    result = []
    if path.parent != path:
        result.append(path.parent)
    result.extend(items)
    return result

def display_name(cur: Path, item: Path):
    if item == cur.parent and cur.parent != cur:
        return ".."
    return item.name + ("/" if item.is_dir() else "")

def main(stdscr):
    current = Path.cwd()
    entries = list_entries(current)
    idx = 0

    curses.noecho()
    curses.cbreak()
    stdscr.keypad(True)
    try:
        curses.curs_set(0)
    except Exception:
        pass

    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
        curses.init_pair(2, curses.COLOR_WHITE, curses.COLOR_BLACK)

    try:
        curses.mousemask(curses.ALL_MOUSE_EVENTS | curses.REPORT_MOUSE_POSITION)
    except Exception:
        pass

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()

        if not entries:
            entries = list_entries(current)
            idx = 0

        idx = max(0, min(idx, max(0, len(entries) - 1)))

        top = 0
        if idx >= h:
            top = idx - h + 1

        visible = entries[top:top + h]

        for row, item in enumerate(visible):
            name = display_name(current, item)
            name = name[:max(1, w - 1)]
            if top + row == idx:
                attr = curses.color_pair(1) if curses.has_colors() else curses.A_REVERSE
            else:
                attr = curses.color_pair(2) if curses.has_colors() else 0
            stdscr.addnstr(row, 0, name.ljust(max(1, w - 1)), max(1, w - 1), attr)

        stdscr.refresh()
        ch = stdscr.getch()

        if ch in (27, ord('q')):
            print("")
            return

        if ch == curses.KEY_DOWN:
            idx = min(len(entries) - 1, idx + 1) if entries else 0
            continue

        if ch == curses.KEY_UP:
            idx = max(0, idx - 1)
            continue

        if ch == curses.KEY_LEFT:
            if current.parent != current:
                current = current.parent
                entries = list_entries(current)
                idx = 0
            else:
                print("")
                return
            continue

        if ch in (curses.KEY_RIGHT, ord('\n'), ord('\r')):
            if not entries:
                continue
            item = entries[idx]
            if item == current.parent and current.parent != current:
                current = current.parent
                entries = list_entries(current)
                idx = 0
            elif item.is_dir():
                current = item
                entries = list_entries(current)
                idx = 0
            else:
                print(f"OPEN\t{item}")
                return
            continue

        if ch == ord('.'):
            print(f"CD\t{current}")
            return

        if ch == curses.KEY_MOUSE:
            try:
                _, _, my, _, bstate = curses.getmouse()
                if 0 <= my < len(visible):
                    idx = top + my
                    if bstate & (curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED | curses.BUTTON1_RELEASED):
                        item = entries[idx]
                        if item == current.parent and current.parent != current:
                            current = current.parent
                            entries = list_entries(current)
                            idx = 0
                        elif item.is_dir():
                            current = item
                            entries = list_entries(current)
                            idx = 0
                        else:
                            print(f"OPEN\t{item}")
                            return
            except Exception:
                pass

if __name__ == "__main__":
    curses.wrapper(main)
PYEOF

  chmod +x "$LOCAL_BIN/navmenu.py"
}

# ── Omni selector (fzf-based launcher) ────────────────────

write_omni() {
  # Platform-aware apps.tsv
  cat > "$CONFIG_HOME/omni/apps.tsv" <<EOF
# label<TAB>command
Home	cd "\$HOME"
EOF

  # Add platform-specific entries
  case "$OS" in
    termux)
      cat >> "$CONFIG_HOME/omni/apps.tsv" <<EOF
Shared	cd "\$HOME/storage/shared"
Downloads	cd "\$HOME/storage/downloads"
Pictures	cd "\$HOME/storage/pictures"
EOF
      ;;
    wsl-*)
      cat >> "$CONFIG_HOME/omni/apps.tsv" <<EOF
Windows Home	cd "\$HOME/win"
Downloads	cd "\$HOME/win/Downloads"
Documents	cd "\$HOME/win/Documents"
EOF
      ;;
    macos)
      cat >> "$CONFIG_HOME/omni/apps.tsv" <<EOF
Downloads	cd "\$HOME/Downloads"
Documents	cd "\$HOME/Documents"
Desktop	cd "\$HOME/Desktop"
EOF
      ;;
    *)
      cat >> "$CONFIG_HOME/omni/apps.tsv" <<EOF
Downloads	cd "\$HOME/Downloads"
Documents	cd "\$HOME/Documents"
EOF
      ;;
  esac

  cat > "$LOCAL_BIN/omni-select" <<'OMNIEOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
APPS_FILE="$CONFIG_HOME/omni/apps.tsv"
HISTFILE_PATH="${HISTFILE:-$HOME/.zsh_history}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

add_line() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$TMP"
}

# App aliases
if [[ -f "$APPS_FILE" ]]; then
  while IFS=$'\t' read -r label cmd; do
    [[ -z "${label:-}" ]] && continue
    [[ "${label:0:1}" == "#" ]] && continue
    add_line "RUN" "[app] $label" "$cmd"
  done < "$APPS_FILE"
fi

# Android packages (Termux only)
if command -v cmd >/dev/null 2>&1 && command -v monkey >/dev/null 2>&1; then
  while IFS= read -r pkg; do
    pkg="${pkg#package:}"
    [[ -n "$pkg" ]] || continue
    add_line "RUN" "[pkg] $pkg" "monkey -p '$pkg' -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1"
  done < <(cmd package list packages 2>/dev/null || true)
fi

# Zoxide directories
if command -v zoxide >/dev/null 2>&1; then
  while IFS= read -r dir; do
    [[ -d "$dir" ]] && add_line "CD" "[dir] $dir" "$dir"
  done < <(zoxide query -l 2>/dev/null || true)
fi

# Shell history
if [[ -f "$HISTFILE_PATH" ]]; then
  awk '{line=$0; sub(/^: [0-9]+:[0-9]+;/, "", line); if (length(line)>0) print line}' \
    "$HISTFILE_PATH" | tail -n 1500 | awk '!seen[$0]++' | while IFS= read -r cmd; do
    add_line "RUN" "[hist] $cmd" "$cmd"
  done
fi

# Filesystem entries
ROOTS=("$PWD" "$HOME")
[[ -d "$HOME/storage/shared" ]] && ROOTS+=("$HOME/storage/shared")
[[ -d "$HOME/win" ]] && ROOTS+=("$HOME/win")
[[ -d "$HOME/Downloads" ]] && ROOTS+=("$HOME/Downloads")

# Deduplicate
UNIQ_ROOTS=()
for r in "${ROOTS[@]}"; do
  skip=0
  for u in "${UNIQ_ROOTS[@]:-}"; do
    [[ "$u" == "$r" ]] && skip=1 && break
  done
  [[ $skip -eq 0 ]] && [[ -d "$r" ]] && UNIQ_ROOTS+=("$r")
done

FD_BIN="fd"
if ! command -v fd >/dev/null 2>&1; then
  if command -v fdfind >/dev/null 2>&1; then
    FD_BIN="fdfind"
  else
    FD_BIN=""
  fi
fi

if [[ -n "$FD_BIN" ]]; then
  for root in "${UNIQ_ROOTS[@]:-}"; do
    while IFS= read -r p; do
      [[ -d "$p" ]] && add_line "CD"   "[fs] $p" "$p"
      [[ -f "$p" ]] && add_line "OPEN" "[fs] $p" "$p"
    done < <("$FD_BIN" . "$root" -H -E .git -E node_modules -E .cache 2>/dev/null | head -n 3000)
  done
fi

sort -u "$TMP" -o "$TMP"

if ! command -v fzf >/dev/null 2>&1; then
  echo ""
  exit 0
fi

selected="$(
  awk -F '\t' '{print $2 "\t" $1 "\t" $3}' "$TMP" |
    fzf \
      --delimiter=$'\t' \
      --with-nth=1 \
      --height=100% \
      --layout=reverse \
      --border=none \
      --info=hidden \
      --prompt='omni> ' \
      --bind='ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
      --preview='
        kind=$(printf "%s" {} | awk -F "\t" "{print \$2}");
        payload=$(printf "%s" {} | awk -F "\t" "{print \$3}");
        if [ "$kind" = "OPEN" ] && [ -f "$payload" ]; then
          head -120 "$payload" 2>/dev/null
        else
          printf "%s\n" "$payload"
        fi
      ' \
      --color='bg:#000000,fg:#ffffff,hl:#ffffff,bg+:#ffffff,fg+:#000000,hl+:#000000,prompt:#ffffff,pointer:#ffffff,info:#ffffff,marker:#ffffff,spinner:#ffffff,header:#ffffff'
)" || true

[[ -n "${selected:-}" ]] || exit 0

kind="$(printf '%s' "$selected" | awk -F '\t' '{print $2}')"
payload="$(printf '%s' "$selected" | awk -F '\t' '{print $3}')"

printf '%s\t%s\n' "$kind" "$payload"
OMNIEOF

  chmod +x "$LOCAL_BIN/omni-select"
}

# ── Micro editor config ───────────────────────────────────

write_micro_config() {
  cat > "$CONFIG_HOME/micro/settings.json" <<'EOF'
{
  "autosave": 0,
  "backup": false,
  "clipboard": "external",
  "colorscheme": "voidbw",
  "cursorline": false,
  "diffgutter": false,
  "eofnewline": true,
  "fastdirty": true,
  "hidehelp": true,
  "hlsearch": false,
  "ignorecase": true,
  "incsearch": true,
  "keepautoindent": true,
  "matchbrace": true,
  "mkparents": true,
  "mouse": true,
  "paste": false,
  "permbackup": false,
  "pluginchannels": [],
  "readonly": false,
  "rmtrailingws": false,
  "ruler": true,
  "savecursor": true,
  "savehistory": true,
  "saveundo": true,
  "scrollbar": false,
  "smartpaste": true,
  "softwrap": true,
  "splitbottom": true,
  "splitright": true,
  "statusformatl": "$(filename)",
  "statusformatr": "$(line):$(col)",
  "statusline": true,
  "syntax": true,
  "tabbar": false,
  "tabmovement": false,
  "tabsize": 2,
  "tabstospaces": true
}
EOF

  cat > "$CONFIG_HOME/micro/bindings.json" <<'EOF'
{
  "CtrlQ": "Quit",
  "CtrlS": "Save",
  "CtrlO": "CommandMode",
  "CtrlF": "Find",
  "CtrlG": "JumpLine",
  "CtrlE": "CommandMode",
  "CtrlLeft": "WordLeft",
  "CtrlRight": "WordRight",
  "AltLeft": "WordLeft",
  "AltRight": "WordRight"
}
EOF

  cat > "$CONFIG_HOME/micro/colorschemes/voidbw.micro" <<'EOF'
color-link default "#ffffff,#000000"
color-link comment "#ffffff,#000000"
color-link identifier "#ffffff,#000000"
color-link constant "#ffffff,#000000"
color-link statement "#ffffff,#000000"
color-link symbol "#ffffff,#000000"
color-link preproc "#ffffff,#000000"
color-link type "#ffffff,#000000"
color-link special "#ffffff,#000000"
color-link underlined "#ffffff,#000000"
color-link error "#000000,#ffffff"
color-link todo "#000000,#ffffff"
color-link statusline "#000000,#ffffff"
color-link tabbar "#ffffff,#000000"
color-link indent-char "#ffffff,#000000"
color-link line-number "#ffffff,#000000"
color-link current-line-number "#000000,#ffffff"
color-link diff-added "#ffffff,#000000"
color-link diff-modified "#ffffff,#000000"
color-link diff-deleted "#ffffff,#000000"
color-link gutter-error "#000000,#ffffff"
color-link gutter-warning "#000000,#ffffff"
EOF
}

# ── Starship prompt config ────────────────────────────────

write_starship_config() {
  cat > "$CONFIG_HOME/starship.toml" <<'EOF'
# Void-inspired minimal starship prompt - monochrome
format = """$directory$git_branch$git_status$python$nodejs$rust$golang$cmd_duration$line_break$character"""

[character]
success_symbol = "[%](white)"
error_symbol = "[%](white)"

[directory]
style = "bold white"
truncation_length = 3
truncate_to_repo = true

[git_branch]
format = " [$branch]($style)"
style = "white"

[git_status]
format = "[$all_status$ahead_behind]($style) "
style = "white"
modified = "*"
untracked = "?"
staged = "+"
deleted = "-"
ahead = "↑"
behind = "↓"

[python]
format = " [py$version]($style)"
style = "dimmed white"

[nodejs]
format = " [node$version]($style)"
style = "dimmed white"

[rust]
format = " [rs$version]($style)"
style = "dimmed white"

[golang]
format = " [go$version]($style)"
style = "dimmed white"

[cmd_duration]
format = " [$duration]($style)"
style = "dimmed white"
min_time = 2000
EOF
}

# ── Tmux config ───────────────────────────────────────────

write_tmux_config() {
  cat > "$HOME/.tmux.conf" <<'EOF'
# Void-style tmux - minimal monochrome

# Better prefix (Ctrl-a instead of Ctrl-b)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Modern defaults
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g mouse on
set -g history-limit 50000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -s escape-time 0
set -g focus-events on
set -g set-clipboard on

# Vim-style pane navigation
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Split with | and -
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# New window in current path
bind c new-window -c "#{pane_current_path}"

# Reload config
bind r source-file ~/.tmux.conf \; display "Reloaded"

# Monochrome status bar
set -g status-style "bg=black,fg=white"
set -g status-left " #S "
set -g status-left-style "bg=white,fg=black,bold"
set -g status-right " %H:%M "
set -g status-right-style "bg=black,fg=white"
set -g window-status-format " #I:#W "
set -g window-status-current-format " #I:#W "
set -g window-status-current-style "bg=white,fg=black,bold"
set -g window-status-separator ""

# Pane borders
set -g pane-border-style "fg=brightblack"
set -g pane-active-border-style "fg=white"

# Message style
set -g message-style "bg=black,fg=white,bold"
EOF
}

# ── askall: Multi-AI prompt tool ──────────────────────────

write_askall() {
  cat > "$LOCAL_BIN/askall" <<'ASKEOF'
#!/usr/bin/env bash
set -Eeuo pipefail

# askall - Send same prompt to multiple AI CLIs, collect responses
# Usage: askall "your question here"
#        askall -f prompt.txt
#        echo "question" | askall

OUTDIR="${ASKALL_DIR:-$HOME/askall-responses}"
mkdir -p "$OUTDIR"

# Parse arguments
PROMPT=""
OUTPUT_BASE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      if [[ -r "${2:-}" ]]; then
        PROMPT="$(cat "$2")"
        shift 2
      else
        echo "Error: cannot read file '${2:-}'"
        exit 1
      fi
      ;;
    -o)
      OUTPUT_BASE="${2:-}"
      [[ -z "$OUTPUT_BASE" ]] && { echo "Error: -o requires a base name"; exit 1; }
      # Strip .txt extension if provided
      OUTPUT_BASE="${OUTPUT_BASE%.txt}"
      shift 2
      ;;
    *)
      PROMPT="$*"
      break
      ;;
  esac
done
if [[ -z "$PROMPT" ]] && [[ ! -t 0 ]]; then
  PROMPT="$(cat)"
fi

# ── Inline file paths ──────────────────────────────────
# Auto-detect file paths (/, ~/) in the prompt and inline their contents
inline_files() {
  local text="$1"
  local result=""
  local inlined=0

  while IFS= read -r line; do
    local new_line=""
    for word in $line; do
      local expanded="${word/#\~/$HOME}"
      if [[ "$expanded" =~ ^/ ]] && [[ -f "$expanded" ]] && [[ -r "$expanded" ]]; then
        local fname
        fname="$(basename "$expanded")"
        local contents
        contents="$(cat "$expanded")"
        new_line+="<file: ${fname}>
${contents}
</file> "
        ((++inlined))
      else
        new_line+="$word "
      fi
    done
    result+="${new_line%% }
"
  done <<< "$text"

  if [[ $inlined -gt 0 ]]; then
    echo "  Inlined $inlined file(s) into prompt" >&2
  fi
  printf '%s' "${result%$'\n'}"
}

PROMPT="$(inline_files "$PROMPT")"

if [[ -z "$PROMPT" ]]; then
  echo "Usage: askall \"your question\""
  echo "       askall -f prompt.txt"
  echo "       askall -o basename \"your question\""
  echo "       echo \"question\" | askall"
  echo ""
  echo "Options:"
  echo "  -f FILE       Load prompt from file"
  echo "  -o BASENAME   Output as BASENAME_model.txt (e.g. -o report → report_claude.txt)"
  echo ""
  echo "Sends the same prompt to all available AI CLIs and saves responses."
  echo "Output: $OUTDIR/"
  echo ""
  echo "Available CLIs:"
  for cli in claude gemini sgpt; do
    if command -v "$cli" >/dev/null 2>&1; then
      echo "  [x] $cli"
    else
      echo "  [ ] $cli (not installed)"
    fi
  done
  exit 0
fi

# Timestamp for this run
TS="$(date +%Y%m%d-%H%M%S)"
RUNDIR="$OUTDIR/$TS"
mkdir -p "$RUNDIR"

# Save the prompt
printf '%s\n' "$PROMPT" > "$RUNDIR/prompt.txt"

# Collect available CLIs (skip tools known to be broken on this platform)
TOOLS=()
command -v claude >/dev/null 2>&1 && TOOLS+=("claude")
command -v gemini >/dev/null 2>&1 && TOOLS+=("gemini")
command -v sgpt   >/dev/null 2>&1 && TOOLS+=("sgpt")

if [[ ${#TOOLS[@]} -eq 0 ]]; then
  echo "Error: No AI CLI tools found. Install at least one of: claude, gemini, sgpt"
  exit 1
fi

echo "Prompt: $(head -c 80 <<< "$PROMPT")$([ ${#PROMPT} -gt 80 ] && echo '...')"
echo "Tools:  ${TOOLS[*]}"
echo "Output: $RUNDIR/"
echo ""

# Run each tool in background, collect results
PIDS=()
for tool in "${TOOLS[@]}"; do
  (
    if [[ -n "$OUTPUT_BASE" ]]; then
      outfile="$RUNDIR/${OUTPUT_BASE}_${tool}.txt"
    else
      outfile="$RUNDIR/${tool}.txt"
    fi
    echo "--- $tool ---" > "$outfile"
    echo "Timestamp: $(date -Iseconds)" >> "$outfile"
    echo "" >> "$outfile"

    case "$tool" in
      claude)
        # Claude Code: --print for non-interactive single-shot
        claude --print "$PROMPT" >> "$outfile" 2>&1 || echo "[ERROR] claude failed" >> "$outfile"
        ;;
      gemini)
        # Gemini CLI: -p for non-interactive single-shot
        gemini -p "$PROMPT" >> "$outfile" 2>&1 || echo "[ERROR] gemini failed" >> "$outfile"
        ;;
      sgpt)
        # ShellGPT
        sgpt "$PROMPT" >> "$outfile" 2>&1 || echo "[ERROR] sgpt failed" >> "$outfile"
        ;;
    esac
  ) &
  PIDS+=($!)
  echo "  Started: $tool (PID $!)"
done

# Wait for all to finish
echo ""
FAILED=0
for i in "${!PIDS[@]}"; do
  pid="${PIDS[$i]}"
  tool="${TOOLS[$i]}"
  if wait "$pid"; then
    echo "  Done: $tool"
  else
    echo "  FAIL: $tool"
    FAILED=$((FAILED + 1))
  fi
done

# Build combined output file
if [[ -n "$OUTPUT_BASE" ]]; then
  COMBINED="$RUNDIR/${OUTPUT_BASE}_combined.txt"
else
  COMBINED="$RUNDIR/combined.txt"
fi
{
  echo "═══════════════════════════════════════════════════════"
  echo "  askall - Multi-AI Response"
  echo "  Date: $(date -Iseconds)"
  echo "═══════════════════════════════════════════════════════"
  echo ""
  echo "PROMPT:"
  echo "───────────────────────────────────────────────────────"
  cat "$RUNDIR/prompt.txt"
  echo ""
  echo "───────────────────────────────────────────────────────"

  for tool in "${TOOLS[@]}"; do
    if [[ -n "$OUTPUT_BASE" ]]; then
      outfile="$RUNDIR/${OUTPUT_BASE}_${tool}.txt"
    else
      outfile="$RUNDIR/${tool}.txt"
    fi
    echo ""
    echo ""
    echo "╔═══════════════════════════════════════════════════════"
    echo "║ $(echo "$tool" | tr '[:lower:]' '[:upper:]')"
    echo "╚═══════════════════════════════════════════════════════"
    echo ""
    if [[ -f "$outfile" ]]; then
      # Skip the header lines we added
      tail -n +4 "$outfile"
    else
      echo "[No response]"
    fi
  done

  echo ""
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Tools: ${TOOLS[*]}"
  echo "  Failed: $FAILED / ${#TOOLS[@]}"
  echo "═══════════════════════════════════════════════════════"
} > "$COMBINED"

echo ""
echo "Results saved to:"
echo "  Combined: $COMBINED"
if [[ -n "$OUTPUT_BASE" ]]; then
  echo "  Individual: $RUNDIR/${OUTPUT_BASE}_{$(IFS=,; echo "${TOOLS[*]}")}.txt"
else
  echo "  Individual: $RUNDIR/{$(IFS=,; echo "${TOOLS[*]}")}.txt"
fi
echo ""

# Print combined to stdout as well
cat "$COMBINED"
ASKEOF

  chmod +x "$LOCAL_BIN/askall"
}

# ── Zsh configuration ─────────────────────────────────────

write_zsh_config() {
  cat > "$CONFIG_HOME/zsh/interactive-void.zsh" <<'ZSHEOF'
# Managed by shell-setup/install.sh

# ── Environment ───────────────────────────────────────────
export EDITOR="${EDITOR:-micro}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS='-RFX'
export PATH="$HOME/.local/bin:$HOME/.atuin/bin:$PATH"
[[ -d "/opt/homebrew/bin" ]] && export PATH="/opt/homebrew/bin:$PATH"

# Silent startup
unsetopt BEEP
export HUSHLOGIN=1

# ── History ───────────────────────────────────────────────
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt NO_BG_NICE
setopt CORRECT

# ── Completion ────────────────────────────────────────────
autoload -Uz compinit
zmodload zsh/complist
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump-$ZSH_VERSION"

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-ZæøåÆØÅ}={A-Za-zæøåÆØÅ}'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*' original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

bindkey -e
bindkey '^I' expand-or-complete
bindkey '^[[Z' reverse-menu-complete
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# ── Prompt ────────────────────────────────────────────────
# Use starship if available, otherwise minimal prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  PROMPT='%F{white}%~%f %# '
  RPROMPT=''
fi

# ── Core aliases ──────────────────────────────────────────
alias e='$EDITOR'
alias q='exit'
alias c='clear'
alias m='micro'
alias h='history -20'
alias hg='history 0 | grep'

# ── Navigation ────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias d='dirs -v | head -10'

# ── Git aliases ───────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit'
alias gcm='git commit -m'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias glo='git log --oneline --graph --all -30'
alias gp='git push'
alias gpl='git pull'
alias gb='git branch'
alias gco='git checkout'
alias gsw='git switch'
alias gst='git stash'
alias gstp='git stash pop'

# ── File operations ───────────────────────────────────────
# Safe rm via trash-cli (if available)
if command -v trash-put >/dev/null 2>&1; then
  alias rm='trash-put'
  alias rmr='command rm'  # escape hatch for real rm
  alias trash='trash-list'
  alias untrash='trash-restore'
  alias empty-trash='trash-empty'
fi

alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'

# ── fd compatibility (Debian/Ubuntu ships fdfind) ─────────
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

# ── bat as cat replacement ────────────────────────────────
if command -v bat >/dev/null 2>&1; then
  alias cat='bat --plain --paging=never'
  alias catp='bat'  # with paging and syntax
  export BAT_THEME="base16"
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat --plain --paging=never'
  alias catp='batcat'
  export BAT_THEME="base16"
  export MANPAGER="sh -c 'col -bx | batcat -l man -p'"
fi

# ── eza/exa as ls replacement ─────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --group-directories-first --git'
  alias la='eza -a --group-directories-first'
  alias lt='eza --tree --level=2'
  alias tree='eza --tree'
  alias lS='eza -lah --sort=size'
  alias lT='eza -lah --sort=modified'
elif command -v exa >/dev/null 2>&1; then
  alias ls='exa --group-directories-first'
  alias ll='exa -lah --group-directories-first'
  alias la='exa -a --group-directories-first'
  alias tree='exa --tree'
else
  alias ll='ls -lah'
  alias la='ls -A'
  alias l='ls'
fi

# ── Grep ──────────────────────────────────────────────────
alias grep='grep --color=auto'
alias rg='rg --smart-case'

# ── Network ───────────────────────────────────────────────
alias ip4='curl -s ifconfig.me'
alias ip6='curl -s ifconfig.co'
alias ports='ss -tlnp'
alias myip='echo "Public: $(curl -s ifconfig.me) | Local: $(hostname -I 2>/dev/null | awk "{print \$1}" || echo "N/A")"'
alias ping='ping -c 5'
alias wget='wget -c'

# ── System ────────────────────────────────────────────────
alias df='df -h'
alias du='du -h --max-depth=1'
alias free='free -h'
alias top='htop 2>/dev/null || top'
alias psg='ps aux | grep -v grep | grep'

# ── Quick edit ────────────────────────────────────────────
alias zshrc='$EDITOR ~/.config/zsh/interactive-void.zsh'
alias zshlocal='$EDITOR ~/.config/zsh/local.zsh'
alias reload='exec zsh -l'

# ── Useful functions ──────────────────────────────────────
# mkcd - create dir and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# extract - universal archive extractor
extract() {
  if [[ ! -f "$1" ]]; then echo "'$1' not found"; return 1; fi
  case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz)  tar xzf "$1" ;;
    *.tar.xz)  tar xJf "$1" ;;
    *.bz2)     bunzip2 "$1" ;;
    *.rar)     unrar x "$1" ;;
    *.gz)      gunzip "$1" ;;
    *.tar)     tar xf "$1" ;;
    *.tbz2)    tar xjf "$1" ;;
    *.tgz)     tar xzf "$1" ;;
    *.zip)     unzip "$1" ;;
    *.7z)      7z x "$1" ;;
    *.xz)      xz -d "$1" ;;
    *.zst)     zstd -d "$1" ;;
    *)         echo "Unknown format: '$1'" ;;
  esac
}

# serve - quick HTTP server
serve() { python3 -m http.server "${1:-8000}"; }

# weather
wttr() { curl -s "wttr.in/${1:-}" | head -27; }

# cheat.sh - command cheatsheets
cheat() { curl -s "cheat.sh/$1"; }

# ── Tool integrations ─────────────────────────────────────

# zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# atuin (replaces Ctrl-R with better history search)
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow --disable-down-arrow)"
fi

# ── Plugin loader ─────────────────────────────────────────
__source_first() {
  local p
  for p in "$@"; do
    [[ -r "$p" ]] && source "$p" && return 0
  done
  return 1
}

# fzf
export FZF_DEFAULT_OPTS="--height=100% --layout=reverse --border=none --info=hidden --color=bg:#000000,fg:#ffffff,hl:#ffffff,bg+:#ffffff,fg+:#000000,hl+:#000000,prompt:#ffffff,pointer:#ffffff,info:#ffffff,marker:#ffffff,spinner:#ffffff,header:#ffffff"

# fzf keybindings (Ctrl-T files, Alt-C dirs - Ctrl-R handled by atuin if present)
__source_first \
  "${PREFIX:-/usr}/share/fzf/key-bindings.zsh" \
  "/usr/share/doc/fzf/examples/key-bindings.zsh" \
  "/opt/homebrew/opt/fzf/shell/key-bindings.zsh" \
  "/usr/share/fzf/shell/key-bindings.zsh"

# Autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=250'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
__source_first \
  "${PREFIX:-/usr}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/data/data/com.termux/files/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$HOME/.local/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Syntax highlighting
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[default]='fg=white'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=white,underline'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=white,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=white,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=white,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=white,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=white,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=white'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=white'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=white'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=white'
ZSH_HIGHLIGHT_STYLES[comment]='fg=250'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=white'
__source_first \
  "${PREFIX:-/usr}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/data/data/com.termux/files/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$HOME/.local/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# ── AI CLI aliases ────────────────────────────────────────
command -v claude >/dev/null 2>&1 && alias ai='claude'
command -v sgpt   >/dev/null 2>&1 && alias ask='sgpt'

# askall - send prompt to all AI CLIs
[[ -x "$HOME/.local/bin/askall" ]] && alias aa='askall'

# ── Omni & Nav dispatchers ────────────────────────────────

__omni_dispatch() {
  local out kind payload
  out="$("$HOME/.local/bin/omni-select" 2>/dev/null)" || return 0
  [[ -n "$out" ]] || return 0
  kind="${out%%$'\t'*}"
  payload="${out#*$'\t'}"
  case "$kind" in
    OPEN) "$EDITOR" "$payload" ;;
    CD)   cd "$payload" || return 0 ;;
    RUN)  eval "$payload" ;;
  esac
}

omni() { __omni_dispatch; }

__nav_dispatch() {
  local out kind payload
  out="$("$HOME/.local/bin/navmenu.py" 2>/dev/null)" || return 0
  [[ -n "$out" ]] || return 0
  kind="${out%%$'\t'*}"
  payload="${out#*$'\t'}"
  case "$kind" in
    OPEN) "$EDITOR" "$payload" ;;
    CD)   cd "$payload" || return 0 ;;
  esac
}

# ZLE widgets
__down_or_nav_widget() {
  if [[ -z "$BUFFER" ]]; then
    zle -I
    __nav_dispatch
    zle reset-prompt
  else
    zle down-line-or-history
  fi
}
zle -N __down_or_nav_widget

__omni_widget() {
  zle -I
  __omni_dispatch
  zle reset-prompt
}
zle -N __omni_widget

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Keybindings: terminfo-aware with fallback
[[ -n "${terminfo[kcud1]:-}" ]] && bindkey "${terminfo[kcud1]}" __down_or_nav_widget
bindkey '^[[B' __down_or_nav_widget

[[ -n "${terminfo[kcuu1]:-}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search

bindkey '^O' __omni_widget

# ── Platform-specific ─────────────────────────────────────

# Termux
[[ -d "$HOME/storage/shared" ]]    && alias shared='cd "$HOME/storage/shared"'
[[ -d "$HOME/storage/downloads" ]] && alias dl='cd "$HOME/storage/downloads"'
[[ -d "$HOME/storage/dcim" ]]      && alias photos='cd "$HOME/storage/dcim"'

# WSL
[[ -d "$HOME/win" ]] && alias win='cd "$HOME/win"'
if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
  alias explorer='explorer.exe'
  alias clip='clip.exe'
  alias pbcopy='clip.exe'
  alias pbpaste='powershell.exe -command "Get-Clipboard"'
fi

# macOS
if [[ "$(uname -s)" == "Darwin" ]]; then
  alias o='open'
  alias finder='open .'
fi

# Source local overrides if present
[[ -r "$HOME/.config/zsh/local.zsh" ]] && source "$HOME/.config/zsh/local.zsh"
ZSHEOF

  cat > "$HOME/.zshrc" <<'EOF'
[[ -r "$HOME/.config/zsh/interactive-void.zsh" ]] && source "$HOME/.config/zsh/interactive-void.zsh"
EOF

  touch "$HOME/.hushlogin"
}

# ── Set default shell ─────────────────────────────────────

set_default_shell() {
  local shell_bin
  shell_bin="$(command -v zsh || true)"
  [[ -x "$shell_bin" ]] || return 0

  case "$OS" in
    termux)
      # Termux can't use chsh - exec from bashrc/profile
      append_if_missing \
        "$HOME/.bashrc" \
        "# >>> shell-setup >>>" \
        "if [[ \$- == *i* ]] && command -v \"$shell_bin\" >/dev/null 2>&1 && [[ \${SHELL:-} != \"$shell_bin\" ]]; then
  export SHELL=\"$shell_bin\"
  exec \"$shell_bin\" -l
fi
# <<< shell-setup <<<"

      append_if_missing \
        "$HOME/.profile" \
        "# >>> shell-setup >>>" \
        "if [[ \$- == *i* ]] && command -v \"$shell_bin\" >/dev/null 2>&1 && [[ \${SHELL:-} != \"$shell_bin\" ]]; then
  export SHELL=\"$shell_bin\"
  exec \"$shell_bin\" -l
fi
# <<< shell-setup <<<"
      ;;
    *)
      if have chsh; then
        if [[ "${SHELL:-}" != "$shell_bin" ]]; then
          chsh -s "$shell_bin" "${USER:-$(whoami)}" 2>/dev/null || \
            warn "chsh fejlede - kør manuelt: chsh -s $shell_bin"
        fi
      fi
      ;;
  esac
}

# ── Main ──────────────────────────────────────────────────

main() {
  info "Detected OS: $OS"
  $IS_WSL && info "Running inside WSL"

  ensure_dirs
  install_packages
  install_zsh_plugins_fallback

  # Platform setup
  case "$OS" in
    termux) setup_termux ;;
    wsl-*)  setup_wsl ;;
  esac
  setup_storage_symlink

  # Install extras (atuin, starship)
  install_extras

  # Write configs
  write_navmenu
  write_omni
  write_micro_config
  write_starship_config
  write_tmux_config
  write_askall
  write_zsh_config
  set_default_shell

  echo ""
  log "Setup complete for: $OS"
  echo ""
  info "Genstart terminalen, eller kør: exec zsh -l"
  echo ""
  info "Genveje:"
  info "  Pil Ned (tom prompt) -> filmenu"
  info "  Ctrl-O               -> omni search"
  info "  Ctrl-R               -> historik (atuin/fzf)"
  info "  m filnavn            -> micro editor"
  info "  omni                 -> omni search"
  info "  aa 'prompt'          -> askall (alle AI CLIs)"
  echo ""
  info "Værktøjer: starship, tmux, atuin, direnv, trash-cli"
  info "Lokale overrides: $CONFIG_HOME/zsh/local.zsh"
}

main "$@"
