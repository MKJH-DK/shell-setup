# shell-setup

Opinionated shell environment setup for Termux, Arch, Debian/Ubuntu, Fedora, macOS, WSL, Alpine og Void Linux.

## Brug

```bash
./index.sh            # interaktiv menu (fzf / fallback)
./index.sh --run-all  # kør alle non-interactive scripts
./index.sh --run install.sh  # kør ét specifikt script
```

## Scripts

### `install.sh` — Fuld shell-setup

Installerer og konfigurerer: zsh, starship prompt, atuin (history sync), fzf, zoxide (`z`), eza (`ls`/`ll`), ripgrep, fd, bat, tmux, direnv.
Opretter CLI-wrappers: `ask` (sgpt), `askall` (send prompt til alle AI CLIs parallelt), `nav` (fzf dir-navigator), `omni` (fzf-based launcher).
Skriver `.zshrc` med aliases, keybinds og plugin-setup.

```bash
./install.sh          # interaktiv — vælg komponenter
./install.sh --all    # installer alt
```

### `setup-shellgpt.sh` — ShellGPT multi-provider

Installerer ShellGPT (`sgpt`) og sætter provider-switching op (OpenAI, Anthropic, Groq, Ollama, OpenRouter).
Opretter `ask`-wrapper med `ask --provider <name>` og `ask --model <name>`. Patcher `askall` til at respektere valgt provider.

```bash
./setup-shellgpt.sh   # interaktiv guide
```

### `setup-micro-minimal.sh` — Micro editor config

Installerer micro og sætter et minimalt muted-dark tema op med touch/mouse support.

```bash
./setup-micro-minimal.sh
```

### `setup-termux-keys-layout.sh` — Termux tastatur-layout

Skriver et 2-rækket extra-keys layout til `~/.termux/termux.properties` (TAB, ESC, arrows, CTRL, ALT m.m.).

```bash
./setup-termux-keys-layout.sh
```

### `reset-zsh-history.sh` — Seed zsh history

Nulstiller zsh history og seeder med foruddefinerede kommandoer (nav, omni, cd-paths m.m.) så de dukker op i autocomplete.

```bash
./reset-zsh-history.sh
```
