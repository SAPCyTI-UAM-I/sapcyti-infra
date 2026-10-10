# local-dev

Stack local de desarrollo. Construye las imagenes desde repositorios hermanos locales; no usa imagenes de GHCR.

## Servicios

- `db`: PostgreSQL 16 (red interna, sin puerto publicado al host en el stack completo).
- `storage`: Almacenamiento S3/RustFS (puerto 9000 API y 9001 Consola Web).
- `api`: Backend Spring Boot construido desde `../../sapcyti-api`.
- `edge`: Frontend Angular con Nginx construido desde `../../sapcyti-spa`.

Para desarrollo con solo la base de datos expuesta al host, usar `docker-compose.db.yml`. Para desarrollo con solo el almacenamiento S3 expuesto al host, usar `docker-compose.storage.yml`.

## Puertos

| Servicio | Mapeo host -> contenedor |
|---|---|
| `edge` | `${EDGE_HTTP_PORT:-80}` -> 80 |
| `api` | `8081` -> 8080 |
| `storage` | `9000` -> 9000 (API S3), `9001` -> 9001 (Consola) |
| solo-DB (`docker-compose.db.yml`) | `5433` -> 5432 |
| solo-Storage (`docker-compose.storage.yml`) | `9000` -> 9000, `9001` -> 9001 |

## Variables de entorno

Copiar `local-dev/.env.example` a `local-dev/.env` antes de iniciar. No commitear `.env`.

## Comandos

Desde la raiz del repositorio:

```bash
# Iniciar stack completo (DB + Storage + API + Edge)
docker compose -f local-dev/docker-compose.stack.yml up -d --build

# Iniciar solo base de datos
docker compose -f local-dev/docker-compose.db.yml up -d

# Iniciar solo almacenamiento S3
docker compose -f local-dev/docker-compose.storage.yml up -d

# Ejecutar smoke test
./scripts/smoke-stack.sh
```
