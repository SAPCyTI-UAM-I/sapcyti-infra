# sapcyti-infra

Infrastructure and deployment assets for the SAPCyTI platform.

This repository contains the Docker Compose files, Nginx configuration, helper scripts, and CI workflow used to run the SAPCyTI stack in local development and production.

## What’s in this repo

- `local-dev/` — local Docker Compose setup for PostgreSQL, the API, and the SPA edge proxy
- `production/` — production Docker Compose and Nginx config
- `scripts/` — setup and smoke-test helpers
- `.github/workflows/` — deployment workflow

## Prerequisites

- Docker and Docker Compose
- Bash for the `.sh` scripts or PowerShell for the `.ps1` scripts
- The sibling repositories `sapcyti-api` and `sapcyti-spa` checked out next to this repo

## Local development

The main local stack is defined in `local-dev/docker-compose.stack.yml` and includes:

- PostgreSQL
- `sapcyti-api` built from `../../sapcyti-api`
- `sapcyti-spa` built from `../../sapcyti-spa`
- Nginx edge proxy that serves the SPA and forwards `/api/*` to the API

Typical flow:

1. Copy `local-dev/.env.example` to `local-dev/.env` and adjust values if needed.
2. Start the stack:

   ```bash
   docker compose -f local-dev/docker-compose.stack.yml up -d --build
   ```

3. If you only need the database, use:

   ```bash
   docker compose -f local-dev/docker-compose.db.yml up -d
   ```

4. Run the smoke test to check the edge proxy, health endpoint, and program CRUD flow:

   ```bash
   ./scripts/smoke-stack.sh
   ```

## Setup helper

`scripts/setup-env.sh` bootstraps the local environment by checking required tools, setting up Node via NVM, starting the local database, and preparing the sibling app repositories.

## Production

`production/docker-compose.yml` defines the production stack:

- PostgreSQL with persistent data
- API image pulled from GHCR by default
- SPA edge image pulled from GHCR by default
- Nginx config in `production/default.conf`

The deployment workflow in `.github/workflows/deploy.yml` uses SSH to connect to the target host, change into `/opt/sapcyti/sapcyti-infra/production`, pull images, and restart the stack.

## Smoke test behavior

`scripts/smoke-stack.sh` expects the stack to be reachable at `http://localhost` by default and checks:

- `GET /api/actuator/health`
- the SPA shell at `/`
- `POST /api/programs`
- `GET /api/programs`
- `GET /api/programs/{id}`

## Related docs

- `local-dev/README.md`
- `local-dev/.env.example`

