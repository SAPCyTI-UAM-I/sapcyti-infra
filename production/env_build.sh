#!/bin/bash
# Exit immediately if any command fails
set -e

# 1. Assign positional parameters (No $ on the left side)
# Order must match the caller in cd-deploy.yml:
# $1=ENV_NAME $2=API_IMAGE $3=SPA_IMAGE $4=EDGE_HTTP_PORT $5=POSTGRES_PASSWORD
# $6=GHCR_TOKEN $7=SPRING_PROFILE $8=ALLOWED_ORIGIN
ENV_NAME=$1
API_IMAGE=$2
SPA_IMAGE=$3
EDGE_HTTP_PORT=$4
POSTGRES_PASSWORD=$5
GHCR_TOKEN=${6:-}
SPRING_PROFILE=$7
ALLOWED_ORIGIN=$8
SMTP_HOST=${9:-localhost}
SMTP_PORT=${10:-1025}

# 2. Define the absolute base workspace directory
BASE_DIR="$HOME/sapcyti"

# 3. Move into the environment subdirectory
cd "$BASE_DIR/$ENV_NAME"

# Ensure proxy-net network exists
if ! docker network inspect proxy-net >/dev/null 2>&1; then
  echo "🌐 Creating external network 'proxy-net'..."
  docker network create proxy-net
fi

# 4. Generate the environment file
cat << EOF > .env
COMPOSE_PROJECT_NAME=sapcyti-$ENV_NAME
ENV_NAME=$ENV_NAME
API_IMAGE=$API_IMAGE
SPA_IMAGE=$SPA_IMAGE
EDGE_HTTP_PORT=$EDGE_HTTP_PORT

POSTGRES_DB=sapcyti_$ENV_NAME
POSTGRES_USER=sapcyti
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DB_URL=jdbc:postgresql://db:5432/sapcyti_$ENV_NAME
DB_USER=sapcyti
DB_PASS=$POSTGRES_PASSWORD

SPRING_PROFILES_ACTIVE=$SPRING_PROFILE
SERVER_PORT=8080
CORS_ALLOWED_ORIGINS=$ALLOWED_ORIGIN
PASSWORD_RESET_BASE_URL=$ALLOWED_ORIGIN

SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
EOF

echo "✅ Successfully generated .env inside $BASE_DIR/$ENV_NAME"

# 5. Authenticate to GHCR so the server can pull private images
if [ -n "$GHCR_TOKEN" ]; then
  GHCR_USER=$(echo "$API_IMAGE" | cut -d'/' -f2)
  echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
fi

# 6. Run the actual Docker Lifecycle commands natively inside the script!
docker compose pull
docker compose up -d --remove-orphans

# Clean up credentials from the daemon after pull
docker logout ghcr.io

echo "🚀 Stack sapcyti-$ENV_NAME is up and running!"
