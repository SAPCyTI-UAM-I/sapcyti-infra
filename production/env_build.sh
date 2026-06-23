#!/bin/bash
# Exit immediately if any command fails
set -e

# 1. Assign positional parameters (No $ on the left side)
ENV_NAME=$1
API_IMAGE=$2
SPA_IMAGE=$3
EDGE_HTTP_PORT=$4
POSTGRES_PASSWORD=$5
SPRING_PROFILE=$6
ALLOWED_ORIGIN=$7
SMTP_HOST=${8:-localhost}
SMTP_PORT=${9:-1025}

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

# 5. Run the actual Docker Lifecycle commands natively inside the script!
docker compose pull
docker compose up -d --remove-orphans

echo "🚀 Stack sapcyti-$ENV_NAME is up and running!"
