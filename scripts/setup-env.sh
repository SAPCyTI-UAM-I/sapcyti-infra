#!/usr/bin/env bash
# ===================================
# SAPCyTI — Unified Local Environment Setup
# ===================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/../.."

echo "🔍 Checking prerequisites..."

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# --- Backend Prerequisites ---
if ! require_cmd java; then
  echo "❌ Java JDK 21 is not installed. See PREREQUISITES.md"
  exit 1
fi
echo "✅ Java: $(java -version 2>&1 | head -1)"

if ! require_cmd mvn; then
  echo "❌ Maven 3.9+ is not installed. See PREREQUISITES.md"
  exit 1
fi
echo "✅ Maven: $(mvn -version 2>&1 | head -1)"

if ! require_cmd docker; then
  echo "❌ Docker is not installed. See PREREQUISITES.md"
  exit 1
fi
echo "✅ Docker: $(docker --version)"

# --- Frontend Prerequisites & NVM Setup ---
missing=()
for pkg in curl git; do
  if ! require_cmd "$pkg"; then missing+=("$pkg"); fi
done
if (( ${#missing[@]} > 0 )); then
  echo "❌ Missing packages: ${missing[*]}. Please install them." >&2
  exit 1
fi

find_nvm_dir() {
  local candidates=("${NVM_DIR:-}" "$HOME/.nvm" "${XDG_CONFIG_HOME:-$HOME/.config}/nvm")
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -s "$candidate/nvm.sh" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

if ! find_nvm_dir >/dev/null 2>&1; then
  echo "📦 Installing NVM..."
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$(find_nvm_dir || true)"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "📦 Setting up Node 22..."
nvm install 22
nvm use 22
nvm alias default 22

if ! require_cmd corepack; then echo "❌ corepack not found."; exit 1; fi
corepack enable pnpm || corepack enable

export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
export PATH="$PNPM_HOME:$PATH"
pnpm setup
pnpm install -g @angular/cli

# --- Start Infrastructure ---
echo ""
echo "🐘 Starting local PostgreSQL database..."
cd "$SCRIPT_DIR/../local-dev"
docker compose -f docker-compose.db.yml up -d

echo "⏳ Waiting for PostgreSQL to be ready..."
until docker compose -f docker-compose.db.yml exec -T db pg_isready -U sapcyti -d sapcyti_dev > /dev/null 2>&1; do
  sleep 1
done
echo "✅ PostgreSQL is ready at localhost:5433"

# --- Setup Application Repositories ---
echo ""
echo "🔨 Building backend (sapcyti-api)..."
cd "$ROOT_DIR/sapcyti-api"
npm install # for husky/commitlint
mvn clean compile -q

echo ""
echo "🎨 Installing frontend dependencies (sapcyti-spa)..."
cd "$ROOT_DIR/sapcyti-spa"
pnpm install

echo ""
echo "✅ Setup complete! You can now run:"
echo "   API:  cd sapcyti-api && mvn spring-boot:run"
echo "   SPA:  cd sapcyti-spa && ng serve"
echo "   OR:   cd sapcyti-infra/local-dev && docker compose -f docker-compose.stack.yml up -d"
