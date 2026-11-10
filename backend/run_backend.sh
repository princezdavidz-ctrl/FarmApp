#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$ROOT_DIR/app"
CRM_DIR="$(cd "$ROOT_DIR/../crm" && pwd)"
PODMAN_SERVICE_PID=""

MODE="auto"
case "${1:-}" in
  --docker|--podman|--local)
    MODE="${1#--}"
    ;;
  --help|-h)
    echo "Usage: $0 [--docker|--podman|--local]"
    echo "  auto    Use Docker or Podman when available, otherwise local development"
    echo "  docker  Start the backend stack with Docker Compose"
    echo "  podman  Start the backend stack with Podman Compose"
    echo "  local   Start Laravel and CRM development servers directly"
    exit 0
    ;;
  "")
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--docker|--podman|--local]"
    exit 2
    ;;
esac

container_ready() {
  local engine="$1"
  command -v "$engine" >/dev/null 2>&1 && "$engine" info >/dev/null 2>&1
}

compose_available() {
  local engine="$1"
  "$engine" compose version >/dev/null 2>&1
}

compose_connection_ready() {
  local engine="$1"
  cd "$ROOT_DIR"
  "$engine" compose --env-file app/.env ps >/dev/null 2>&1
}

start_podman_socket() {
  local socket_path="${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock"

  if [[ -S "$socket_path" ]]; then
    export DOCKER_HOST="unix://$socket_path"
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1 && systemctl --user start podman.socket >/dev/null 2>&1; then
    if [[ -S "$socket_path" ]]; then
      export DOCKER_HOST="unix://$socket_path"
      return 0
    fi
  fi

  mkdir -p "$(dirname "$socket_path")"
  podman system service --time=0 "unix://$socket_path" >/tmp/farm-app-podman-service.log 2>&1 &
  PODMAN_SERVICE_PID=$!

  for _ in {1..10}; do
    if [[ -S "$socket_path" ]]; then
      export DOCKER_HOST="unix://$socket_path"
      return 0
    fi
    sleep 1
  done

  echo "Unable to start the rootless Podman API socket."
  echo "See /tmp/farm-app-podman-service.log for details."
  return 1
}

prepare_engine() {
  local engine="$1"
  container_ready "$engine" && compose_available "$engine" || return 1
  if [[ "$engine" == "podman" ]]; then
    start_podman_socket || return 1
  fi
  compose_connection_ready "$engine"
}

cleanup() {
  if [[ -n "${BACKEND_PID:-}" ]]; then
    kill "$BACKEND_PID" 2>/dev/null || true
  fi
  if [[ -n "$PODMAN_SERVICE_PID" ]]; then
    kill "$PODMAN_SERVICE_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

run_containers() {
  local engine="$1"
  cd "$ROOT_DIR"

  if [[ ! -f "$APP_DIR/.env" ]]; then
    echo "Missing .env file in $APP_DIR"
    echo "Copy .env.example to .env before running this script."
    exit 1
  fi

  echo "Starting backend stack with $engine Compose..."
  "$engine" compose --env-file app/.env up --build
}

if [[ "$MODE" == "auto" ]]; then
  if prepare_engine docker; then
    MODE="docker"
  elif prepare_engine podman; then
    MODE="podman"
  else
    MODE="local"
  fi
fi

if [[ "$MODE" == "docker" || "$MODE" == "podman" ]]; then
  if ! prepare_engine "$MODE"; then
    echo "$MODE is installed but its container engine is unavailable."
    echo "Start the $MODE service or use --local."
    exit 1
  fi
  if ! compose_available "$MODE"; then
    echo "$MODE Compose is unavailable."
    exit 1
  fi
  run_containers "$MODE"
fi

cd "$APP_DIR"

if [[ ! -f ".env" ]]; then
  echo "Missing .env file in $APP_DIR"
  echo "Copy .env.example to .env before running this script."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required to run the CRM development server."
  exit 1
fi

if [[ ! -f "database/database.sqlite" ]]; then
  touch database/database.sqlite
fi

APP_ENV=local APP_DEBUG=true DB_CONNECTION=sqlite DB_DATABASE=database/database.sqlite php artisan migrate --force --seed

APP_ENV=local APP_DEBUG=true DB_CONNECTION=sqlite DB_DATABASE=database/database.sqlite php artisan serve --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

cd "$CRM_DIR"
npm run dev -- --port 5173
