#!/usr/bin/env bash
set -Eeuo pipefail

# setup-shellgpt.sh - Install and configure ShellGPT with multi-provider support
# Creates wrapper functions for provider/model switching that also work with askall

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_BIN="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/shell_gpt"
SGPT_PROFILES="${HOME}/.config/shell_gpt/profiles"
SGPT_WRAPPER="${LOCAL_BIN}/ask"

# ── Colors ────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${GREEN}[+]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
err()   { printf "${RED}[✗]${NC} %s\n" "$*" >&2; }
header(){ printf "\n${BOLD}${CYAN}── %s ──${NC}\n" "$*"; }

# ── Provider definitions ──────────────────────────────────

declare -A PROVIDER_URLS=(
  [openai]="https://api.openai.com/v1"
  [anthropic]="https://api.anthropic.com/v1"
  [ollama]="http://localhost:11434/v1"
  [openrouter]="https://openrouter.ai/api/v1"
  [groq]="https://api.groq.com/openai/v1"
  [local]="http://localhost:1234/v1"
)

declare -A PROVIDER_MODELS=(
  [openai]="gpt-4o gpt-4o-mini gpt-4-turbo gpt-4 gpt-3.5-turbo o1 o1-mini o3-mini"
  [anthropic]="claude-sonnet-4-20250514 claude-haiku-4-5-20251001 claude-3-5-sonnet-20241022 claude-3-haiku-20240307"
  [ollama]="llama3 llama3:70b mistral mixtral codellama phi3 gemma2 qwen2.5"
  [openrouter]="anthropic/claude-sonnet-4-20250514 openai/gpt-4o google/gemini-2.0-flash meta-llama/llama-3-70b"
  [groq]="llama-3.3-70b-versatile llama-3.1-8b-instant mixtral-8x7b-32768 gemma2-9b-it"
  [local]="default"
)

declare -A PROVIDER_KEYVAR=(
  [openai]="OPENAI_API_KEY"
  [anthropic]="ANTHROPIC_API_KEY"
  [ollama]=""
  [openrouter]="OPENROUTER_API_KEY"
  [groq]="GROQ_API_KEY"
  [local]=""
)

DEFAULT_PROVIDER="openai"
DEFAULT_MODEL="gpt-4o"

# ── Helpers ───────────────────────────────────────────────

usage() {
  cat <<'EOF'
setup-shellgpt.sh - Install & configure ShellGPT with multi-provider support

Usage: ./setup-shellgpt.sh [OPTIONS]

Options:
  --install          Install shell-gpt via pipx
  --configure        Interactive provider/model configuration
  --write-wrapper    Write the 'ask' wrapper to ~/.local/bin
  --write-profiles   Write provider profiles
  --all              Do everything (default if no flags)
  --provider NAME    Set default provider (openai|anthropic|ollama|openrouter|groq|local)
  --model NAME       Set default model
  --list-providers   List available providers and models
  -h, --help         Show this help

After setup, use:
  ask "question"                    # Use default provider/model
  ask -p anthropic "question"       # Use specific provider
  ask -m gpt-4o-mini "question"     # Use specific model
  ask -p ollama -m llama3 "question"# Combine provider + model
  askall "question"                 # Multi-AI (respects sgpt provider setting)
EOF
}

list_providers() {
  header "Available providers"
  for provider in openai anthropic ollama openrouter groq local; do
    local keyvar="${PROVIDER_KEYVAR[$provider]}"
    local status="○"
    if [[ -z "$keyvar" ]]; then
      status="●"  # No key needed
    elif [[ -n "${!keyvar:-}" ]]; then
      status="●"  # Key is set
    fi
    printf "  ${BOLD}%s${NC} %s\n" "$status" "$provider"
    printf "    URL: %s\n" "${PROVIDER_URLS[$provider]}"
    printf "    Key: %s\n" "${keyvar:-none required}"
    printf "    Models: %s\n\n" "${PROVIDER_MODELS[$provider]}"
  done
  echo "● = ready  ○ = needs API key"
}

# ── Install ───────────────────────────────────────────────

do_install() {
  header "Installing ShellGPT"

  if ! command -v python3 >/dev/null 2>&1; then
    err "Python 3 is required. Install it first."
    exit 1
  fi

  local py_ver
  py_ver="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  info "Python version: $py_ver"

  if command -v pipx >/dev/null 2>&1; then
    info "Installing shell-gpt via pipx..."
    pipx install shell-gpt 2>/dev/null || pipx upgrade shell-gpt 2>/dev/null || true
    pipx ensurepath 2>/dev/null || true
  elif command -v pip >/dev/null 2>&1; then
    warn "pipx not found, falling back to pip"
    pip install --user shell-gpt 2>/dev/null || pip install --user --upgrade shell-gpt
  else
    err "Neither pipx nor pip found. Cannot install."
    exit 1
  fi

  if command -v sgpt >/dev/null 2>&1; then
    info "sgpt installed: $(sgpt --version 2>/dev/null || echo 'ok')"
  else
    warn "sgpt not in PATH yet - may need to restart shell or add ~/.local/bin to PATH"
  fi
}

# ── Configure ─────────────────────────────────────────────

do_configure() {
  header "Configure ShellGPT"

  mkdir -p "$CONFIG_DIR"

  # Select provider
  echo "Available providers:"
  local i=1
  local providers=(openai anthropic ollama openrouter groq local)
  for p in "${providers[@]}"; do
    printf "  %d) %s\n" "$i" "$p"
    ((i++))
  done
  echo ""
  read -rp "Select provider [1-${#providers[@]}] (default: 1/openai): " choice
  choice="${choice:-1}"

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#providers[@]} )); then
    DEFAULT_PROVIDER="${providers[$((choice-1))]}"
  fi
  info "Provider: $DEFAULT_PROVIDER"

  # Select model
  echo ""
  echo "Available models for $DEFAULT_PROVIDER:"
  local models
  IFS=' ' read -ra models <<< "${PROVIDER_MODELS[$DEFAULT_PROVIDER]}"
  i=1
  for m in "${models[@]}"; do
    printf "  %d) %s\n" "$i" "$m"
    ((i++))
  done
  echo ""
  read -rp "Select model [1-${#models[@]}] or type custom (default: 1/${models[0]}): " mchoice
  mchoice="${mchoice:-1}"

  if [[ "$mchoice" =~ ^[0-9]+$ ]] && (( mchoice >= 1 && mchoice <= ${#models[@]} )); then
    DEFAULT_MODEL="${models[$((mchoice-1))]}"
  else
    DEFAULT_MODEL="$mchoice"
  fi
  info "Model: $DEFAULT_MODEL"

  # API key check
  local keyvar="${PROVIDER_KEYVAR[$DEFAULT_PROVIDER]}"
  if [[ -n "$keyvar" ]]; then
    if [[ -z "${!keyvar:-}" ]]; then
      echo ""
      warn "$keyvar is not set."
      read -rp "Enter API key (or press Enter to skip): " apikey
      if [[ -n "$apikey" ]]; then
        echo "export $keyvar=\"$apikey\"" >> "$HOME/.config/shell_gpt/env"
        info "Saved to ~/.config/shell_gpt/env (source it in your shell profile)"
      else
        warn "Remember to set $keyvar before using sgpt"
      fi
    else
      info "$keyvar is configured"
    fi
  fi

  # Write .sgptrc
  local api_url="${PROVIDER_URLS[$DEFAULT_PROVIDER]}"
  cat > "$CONFIG_DIR/.sgptrc" <<EOF
# ShellGPT configuration - managed by setup-shellgpt.sh
OPENAI_API_HOST=$api_url
DEFAULT_MODEL=$DEFAULT_MODEL
OPENAI_USE_FUNCTIONS=true
CACHE=true
REQUEST_TIMEOUT=60
ROLE_STORAGE_PATH=$CONFIG_DIR/roles
DEFAULT_COLOR=blue
EOF

  info "Config written to $CONFIG_DIR/.sgptrc"
}

# ── Write provider profiles ──────────────────────────────

do_write_profiles() {
  header "Writing provider profiles"

  mkdir -p "$SGPT_PROFILES"

  for provider in openai anthropic ollama openrouter groq local; do
    local first_model
    IFS=' ' read -r first_model _ <<< "${PROVIDER_MODELS[$provider]}"
    local api_url="${PROVIDER_URLS[$provider]}"

    cat > "$SGPT_PROFILES/$provider.conf" <<EOF
# Profile: $provider
OPENAI_API_HOST=$api_url
DEFAULT_MODEL=$first_model
API_KEY_VAR=${PROVIDER_KEYVAR[$provider]:-none}
EOF
    info "Profile: $provider -> $SGPT_PROFILES/$provider.conf"
  done
}

# ── Write ask wrapper ────────────────────────────────────

do_write_wrapper() {
  header "Writing 'ask' wrapper"

  mkdir -p "$LOCAL_BIN"

  cat > "$SGPT_WRAPPER" <<'WRAPEOF'
#!/usr/bin/env bash
set -Eeuo pipefail

# ask - ShellGPT wrapper with provider/model switching
# Usage: ask [-p provider] [-m model] [-s] [-c] [--] "prompt"
#        ask --providers     List available providers
#        ask --models        List models for current/given provider

SGPT_CONFIG="${HOME}/.config/shell_gpt"
SGPT_PROFILES="${SGPT_CONFIG}/profiles"
SGPT_ENV="${SGPT_CONFIG}/env"

# Source env file if exists (API keys etc.)
[[ -f "$SGPT_ENV" ]] && source "$SGPT_ENV"

# Read defaults from .sgptrc
CURRENT_HOST=""
CURRENT_MODEL=""
if [[ -f "$SGPT_CONFIG/.sgptrc" ]]; then
  CURRENT_HOST="$(grep -oP '^OPENAI_API_HOST=\K.*' "$SGPT_CONFIG/.sgptrc" 2>/dev/null || true)"
  CURRENT_MODEL="$(grep -oP '^DEFAULT_MODEL=\K.*' "$SGPT_CONFIG/.sgptrc" 2>/dev/null || true)"
fi

# Provider URL map
declare -A URLS=(
  [openai]="https://api.openai.com/v1"
  [anthropic]="https://api.anthropic.com/v1"
  [ollama]="http://localhost:11434/v1"
  [openrouter]="https://openrouter.ai/api/v1"
  [groq]="https://api.groq.com/openai/v1"
  [local]="http://localhost:1234/v1"
)

declare -A KEYVARS=(
  [openai]="OPENAI_API_KEY"
  [anthropic]="ANTHROPIC_API_KEY"
  [ollama]=""
  [openrouter]="OPENROUTER_API_KEY"
  [groq]="GROQ_API_KEY"
  [local]=""
)

# Parse flags
PROVIDER=""
MODEL=""
SGPT_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--provider)
      PROVIDER="$2"; shift 2 ;;
    -m|--model)
      MODEL="$2"; shift 2 ;;
    -s|--shell)
      SGPT_ARGS+=("--shell"); shift ;;
    -c|--code)
      SGPT_ARGS+=("--code"); shift ;;
    -d|--describe-shell)
      SGPT_ARGS+=("--describe-shell"); shift ;;
    --chat)
      SGPT_ARGS+=("--chat" "$2"); shift 2 ;;
    --providers)
      echo "Available providers:"
      for p in openai anthropic ollama openrouter groq local; do
        local kv="${KEYVARS[$p]}"
        local status="○"
        [[ -z "$kv" ]] && status="●"
        [[ -n "$kv" && -n "${!kv:-}" ]] && status="●"
        printf "  %s %-12s %s\n" "$status" "$p" "${URLS[$p]}"
      done
      echo "● = ready  ○ = needs API key"
      exit 0
      ;;
    --models)
      echo "Use: sgpt --list-models (with current provider config)"
      exit 0
      ;;
    --)
      shift; break ;;
    -h|--help)
      cat <<'EOF'
ask - ShellGPT wrapper with provider/model switching

Usage: ask [-p provider] [-m model] [-s] [-c] "prompt"

Flags:
  -p, --provider NAME    Provider (openai|anthropic|ollama|openrouter|groq|local)
  -m, --model NAME       Model name
  -s, --shell            Get shell command
  -c, --code             Get code only
  -d, --describe-shell   Describe a shell command
  --chat NAME            Named chat session
  --providers            List providers with status
  -h, --help             This help

Environment:
  ASK_PROVIDER           Default provider override
  ASK_MODEL              Default model override

Examples:
  ask "explain docker networking"
  ask -p anthropic -m claude-sonnet-4-20250514 "explain monads"
  ask -p ollama -m llama3 "write a haiku"
  ask -s "find large files"
  ask -c "python fibonacci"
EOF
      exit 0
      ;;
    *)
      break ;;
  esac
done

# Apply env overrides
PROVIDER="${PROVIDER:-${ASK_PROVIDER:-}}"
MODEL="${MODEL:-${ASK_MODEL:-}}"

# If provider specified, set up environment for this invocation
if [[ -n "$PROVIDER" ]]; then
  url="${URLS[$PROVIDER]:-}"
  if [[ -z "$url" ]]; then
    echo "Error: Unknown provider '$PROVIDER'" >&2
    echo "Available: ${!URLS[*]}" >&2
    exit 1
  fi
  export OPENAI_API_HOST="$url"

  # Set API key from provider's env var
  keyvar="${KEYVARS[$PROVIDER]:-}"
  if [[ -n "$keyvar" && -n "${!keyvar:-}" ]]; then
    export OPENAI_API_KEY="${!keyvar}"
  fi
fi

# Build sgpt command
CMD=(sgpt)

if [[ -n "$MODEL" ]]; then
  CMD+=(--model "$MODEL")
fi

CMD+=("${SGPT_ARGS[@]}")

# Remaining args are the prompt
if [[ $# -gt 0 ]]; then
  CMD+=("$*")
elif [[ ! -t 0 ]]; then
  # Pipe input
  exec "${CMD[@]}"
else
  echo "Error: No prompt given. Use: ask \"your question\"" >&2
  exit 1
fi

exec "${CMD[@]}"
WRAPEOF

  chmod +x "$SGPT_WRAPPER"
  info "Wrapper written to $SGPT_WRAPPER"

  # Also write the askall-compatible function snippet
  header "Zsh integration snippet"
  cat <<'SNIPPET'
# Add to your .zshrc or source from ~/.config/zsh/local.zsh:

# Source ShellGPT env (API keys)
[[ -f "$HOME/.config/shell_gpt/env" ]] && source "$HOME/.config/shell_gpt/env"

# ask - wrapper with provider/model switching
[[ -x "$HOME/.local/bin/ask" ]] && alias ask='$HOME/.local/bin/ask'

# Quick provider aliases
alias ask-openai='ask -p openai'
alias ask-claude='ask -p anthropic'
alias ask-ollama='ask -p ollama'
alias ask-groq='ask -p groq'
alias ask-or='ask -p openrouter'

# Set default provider/model via env
# export ASK_PROVIDER=anthropic
# export ASK_MODEL=claude-sonnet-4-20250514
SNIPPET
}

# ── Update askall for provider awareness ──────────────────

do_update_askall() {
  header "Updating askall for provider-aware sgpt"

  local askall_path="$LOCAL_BIN/askall"
  if [[ ! -f "$askall_path" ]]; then
    warn "askall not found at $askall_path - run install.sh first"
    return 0
  fi

  # Patch the sgpt case in askall to use the ask wrapper if available
  if grep -q 'ask --provider' "$askall_path" 2>/dev/null; then
    info "askall already patched for provider support"
    return 0
  fi

  # Replace the sgpt case block to use the ask wrapper
  local tmpfile
  tmpfile="$(mktemp)"
  sed '/^      sgpt)$/,/^        ;;$/{
    s|sgpt "$PROMPT"|if [[ -x "$HOME/.local/bin/ask" ]]; then "$HOME/.local/bin/ask" "$PROMPT"; else sgpt "$PROMPT"; fi|
  }' "$askall_path" > "$tmpfile"

  if [[ -s "$tmpfile" ]]; then
    mv "$tmpfile" "$askall_path"
    chmod +x "$askall_path"
    info "askall patched to use 'ask' wrapper (respects provider/model settings)"
  else
    rm -f "$tmpfile"
    warn "Could not patch askall automatically"
  fi
}

# ── Main ──────────────────────────────────────────────────

main() {
  local do_all=true
  local do_install=false
  local do_configure=false
  local do_wrapper=false
  local do_profiles=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install)      do_install=true; do_all=false; shift ;;
      --configure)    do_configure=true; do_all=false; shift ;;
      --write-wrapper) do_wrapper=true; do_all=false; shift ;;
      --write-profiles) do_profiles=true; do_all=false; shift ;;
      --all)          do_all=true; shift ;;
      --provider)     DEFAULT_PROVIDER="$2"; shift 2 ;;
      --model)        DEFAULT_MODEL="$2"; shift 2 ;;
      --list-providers) list_providers; exit 0 ;;
      -h|--help)      usage; exit 0 ;;
      *) err "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  if $do_all; then
    do_install
    do_configure
    do_write_profiles
    do_write_wrapper
    do_update_askall
  else
    $do_install    && do_install
    $do_configure  && do_configure
    $do_profiles   && do_write_profiles
    $do_wrapper    && do_write_wrapper
  fi

  echo ""
  info "ShellGPT setup complete!"
  echo ""
  echo "  ask \"your question\"                  # default provider"
  echo "  ask -p anthropic \"explain monads\"     # specific provider"
  echo "  ask -p ollama -m llama3 \"haiku\"       # provider + model"
  echo "  askall \"compare answers\"              # all AIs at once"
}

main "$@"
