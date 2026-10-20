#!/usr/bin/env bash
# Run a SonarQube scan on a local project directory.
#
# Usage:
#   ./scripts/scan.sh <project-dir> [extra scanner args...]
#
# Examples:
#   ./scripts/scan.sh ../my-app
#   ./scripts/scan.sh ~/Desktop/Projects/my-app
#   ./scripts/scan.sh ../my-app -Dsonar.branch.name=main
#
# The target project must contain a sonar-project.properties file, OR you can
# pass properties as extra args (see examples above).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <project-dir> [extra scanner args...]" >&2
  exit 1
fi

PROJECT_DIR="$1"
shift || true

# Expand a leading ~ (in case the user quoted the path) and resolve to an
# absolute path so Docker can mount it.
PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"
PROJECT_DIR="$(cd "${PROJECT_DIR}" 2>/dev/null && pwd)" || {
  echo "Error: project directory not found: $1" >&2
  exit 1
}

if [[ ! -f "${REPO_DIR}/.env" ]]; then
  echo "Error: .env not found. Run: cp .env.example .env" >&2
  exit 1
fi

echo "==> Scanning: ${PROJECT_DIR}"

# Export PROJECT_DIR for the HOST shell so docker compose picks it up during
# variable interpolation (the compose file mounts `${PROJECT_DIR}:/usr/src`).
# Note: `-e` on `docker compose run` would only set it INSIDE the container,
# which happens too late — the volume mount has already been resolved.
export PROJECT_DIR

# Hide tool state the scanner must never walk. A sensor that walks the whole project root,
# whatever sonar.sources says, crashes on a live Unix socket: the Docker Desktop file share cannot
# stat a socket from inside the container (NoSuchFileException). sonar-python's
# PackageRootResolver does that walk (looking for pyproject.toml/setup.py) as soon as one .py file
# is indexed, and the CodeGraph daemon keeps .codegraph/daemon.sock open while it runs — so the
# scan failed only while the daemon was up. An empty anonymous volume over the directory hides it.
# Mounted only when the directory exists, so scanning a project without one does not create it.
MASKS=()
for dir in .codegraph; do
  if [[ -d "${PROJECT_DIR}/${dir}" ]]; then
    MASKS+=(-v "/usr/src/${dir}")
  fi
done

# `${MASKS[@]+…}`: macOS ships bash 3.2, where an empty array trips `set -u` as unbound.
docker compose \
  --env-file "${REPO_DIR}/.env" \
  -f "${REPO_DIR}/docker-compose.yml" \
  --profile scan \
  run --rm \
  ${MASKS[@]+"${MASKS[@]}"} \
  scanner "$@"
