#!/usr/bin/env bash
# deploy.sh - pull image from Docker Hub and bring up docker-compose
# Usage:
#   ./deploy.sh [image-tag-or-full-image]
# Examples:
#   ./deploy.sh latest
#   ./deploy.sh jegadeeshanjeggy/dev-app:dev-abc123
set -euo pipefail

# Directory where docker-compose.yml lives on the app server
DEPLOY_DIR="/opt/production-app"
COMPOSE_FILE="${DEPLOY_DIR}/docker-compose.yml"

REPO="jegadeeshanjeggy"
IMAGE_NAME="dev-app"

# Parameter handling
if [ $# -ge 1 ]; then
  PROVIDED="$1"
else
  PROVIDED="latest"
fi

# Determine full image name
if [[ "$PROVIDED" == *"/"*":"* ]] || [[ "$PROVIDED" == *"/"* ]]; then
  # user passed a full image (e.g. user/repo:tag)
  FULL_IMAGE="$PROVIDED"
elif [[ "$PROVIDED" == *":"* ]]; then
  FULL_IMAGE="${REPO}/${IMAGE_NAME}:${PROVIDED}"
else
  FULL_IMAGE="${REPO}/${IMAGE_NAME}:${PROVIDED}"
fi

echo "=== deploy.sh starting ==="
echo "Deploy directory: ${DEPLOY_DIR}"
echo "Compose file: ${COMPOSE_FILE}"
echo "Image to deploy: ${FULL_IMAGE}"

# Ensure we are in deploy directory
if [ ! -d "${DEPLOY_DIR}" ]; then
  echo "Deploy directory ${DEPLOY_DIR} does not exist. Creating..."
  sudo mkdir -p "${DEPLOY_DIR}"
  sudo chown "$(id -u):$(id -g)" "${DEPLOY_DIR}"
fi
cd "${DEPLOY_DIR}"

# Optional: ensure docker login if private repo (use env vars or previously-run docker login)
if [ -n "${DOCKERHUB_USER:-}" ] && [ -n "${DOCKERHUB_PASS:-}" ]; then
  echo "Logging into Docker Hub using DOCKERHUB_USER env var"
  echo "${DOCKERHUB_PASS}" | docker login --username "${DOCKERHUB_USER}" --password-stdin
fi

# Update docker-compose.yml to point to the new image if file exists,
# otherwise create a simple compose file and run it.
if [ -f "${COMPOSE_FILE}" ]; then
  echo "Existing docker-compose.yml found. Updating image entry..."
  # Back up the compose file first
  cp "${COMPOSE_FILE}" "${COMPOSE_FILE}.bak-$(date +%s)"

  # Replace the image line in docker-compose.yml
  sed -i "s|image:.*|image: ${FULL_IMAGE}|g" "${COMPOSE_FILE}"

  echo "Pulling image ${FULL_IMAGE} ..."
  docker compose pull || true

  echo "Bringing up containers..."
  docker compose up -d --remove-orphans
else
  echo "No docker-compose.yml found. Creating a minimal compose file..."
  cat > "${COMPOSE_FILE}" <<EOF
version: "3.8"

services:
  production-app:
    image: ${FULL_IMAGE}
    container_name: production-app
    restart: always
    ports:
      - "80:80"
    environment:
      - NODE_ENV=production
EOF

  echo "Pulling image ${FULL_IMAGE} ..."
  docker compose pull || true

  echo "Starting via docker compose..."
  docker compose up -d
fi

echo "Waiting 3 seconds for container to initialize..."
sleep 3

# Show container status
echo "Container status:"
docker ps --filter "name=production-app" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo "=== deploy.sh finished: ${FULL_IMAGE} deployed ==="

