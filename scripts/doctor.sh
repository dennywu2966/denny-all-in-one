#!/usr/bin/env bash
# Doctor script - check system health and dependencies

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_pass() { echo -e "${GREEN}✓${NC} $1"; }
check_fail() { echo -e "${RED}✗${NC} $1"; }
check_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
check_info() { echo -e "${BLUE}ℹ${NC} $1"; }

echo "=== denny-all-in-one System Check ==="
echo ""

# Check chezmoi
if command -v chezmoi &>/dev/null; then
  check_pass "chezmoi: $(chezmoi --version | head -1)"
else
  check_fail "chezmoi: not installed"
fi

# Check Claude Code
if command -v claude &>/dev/null; then
  check_pass "Claude Code CLI: installed"
else
  check_fail "Claude Code CLI: not installed"
fi

# Check Codex
if command -v codex &>/dev/null; then
  check_pass "Codex: installed"
else
  check_warn "Codex: not installed (optional)"
fi

# Check nvim
if command -v nvim &>/dev/null; then
  check_pass "Neovim: $(nvim --version | head -1)"
else
  check_warn "Neovim: not installed"
fi

# Check git
if command -v git &>/dev/null; then
  check_pass "Git: $(git --version)"
else
  check_fail "Git: not installed"
fi

# Check go
if command -v go &>/dev/null; then
  check_pass "Go: $(go version)"
else
  check_warn "Go: not installed"
fi

# Check uv
if command -v uv &>/dev/null; then
  check_pass "UV: $(uv --version)"
else
  check_warn "UV: not installed"
fi

# Check cargo
if command -v cargo &>/dev/null; then
  check_pass "Cargo: $(cargo --version)"
else
  check_warn "Cargo: not installed"
fi

echo ""
echo "=== Configuration Check ==="
echo ""

# Check configs
[[ -f "$HOME/.claude/settings.json" ]] && check_pass ".claude/settings.json" || check_fail ".claude/settings.json"
[[ -f "$HOME/.claude/CLAUDE.md" ]] && check_pass ".claude/CLAUDE.md" || check_fail ".claude/CLAUDE.md"
[[ -d "$HOME/.claude/skills" ]] && check_pass ".claude/skills/" || check_fail ".claude/skills/"
[[ -f "$HOME/.codex/config.toml" ]] && check_pass ".codex/config.toml" || check_warn ".codex/config.toml"
[[ -d "$HOME/.config/nvim" ]] && check_pass ".config/nvim/" || check_warn ".config/nvim/"
[[ -f "$HOME/.gitconfig" ]] && check_pass ".gitconfig" || check_fail ".gitconfig"

echo ""
echo "=== Suggestions ==="
echo ""

if ! command -v chezmoi &>/dev/null; then
  check_info "Install chezmoi: curl -fsSL https://chezmoi.io/get | bash"
fi

if ! command -v nvim &>/dev/null; then
  check_info "Install Neovim: https://github.com/neovim/neovim/wiki/Installing-Neovim"
fi

if ! command -v uv &>/dev/null; then
  check_info "Install UV: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi
