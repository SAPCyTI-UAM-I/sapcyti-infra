# SAPCyTI infra

Compose, Nginx, scripts y CI de despliegue. Sin reglas de negocio ni codigo de API/SPA.

## Proposito

Arrancar o cambiar infraestructura (local o produccion) sin editar Java ni Angular.

## Estructura

| Area | Que hay |
|---|---|
| `local-dev/` | Stack Compose local (`db`, `api`, `edge`) |
| `server/` | Configuracion estatica del host (`nginx-proxy` + SSL) |
| `production/` | Blueprints de aplicacion para CI/CD (`docker-compose.yml`, `env_build.sh`) |
| `scripts/` | `setup-env.sh`, `smoke-stack.sh` |
| `.github/workflows/` | Despliegue remoto (`cd-deploy.yml`) |
| `docs/` | Documentacion tecnica de arquitectura, CI/CD, proxy y operaciones |

## Documentacion

- Arquitectura del servidor: `docs/architecture.md`
- Flujo de CI/CD: `docs/ci-cd.md`
- Proxy global y SSL: `docs/reverse-proxy.md`
- Correo transaccional (Resend): `docs/email-resend.md`
- Operaciones y diagnostico: `docs/operations.md`

## Limites

- No edites Java (`sapcyti-api`) ni Angular (`sapcyti-spa`) desde aqui.
- No inventes servicios ni puertos: leelos en Compose / `.env.example`.
- No commits de `.env`. Plantilla: `local-dev/.env.example`.
- `local-dev/README.md` esta vacio; fuente humana: `README.md`.

## Comandos (local)

```bash
cp local-dev/.env.example local-dev/.env
docker compose -f local-dev/docker-compose.stack.yml up -d --build
./scripts/smoke-stack.sh
```

## Restricciones

- Repos hermanos `sapcyti-api` y `sapcyti-spa` junto a este repo (build local).
- Smoke por defecto: `http://localhost` (`SMOKE_BASE_URL` si cambias el puerto del edge).
- Produccion != local: imagenes GHCR + `proxy-net`; ver `docs/architecture.md` y `docs/ci-cd.md`.
