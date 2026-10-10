# sapcyti-infra

Infraestructura, Nginx y flujos de CI/CD para SAPCyTI.

## Estructura

- `server/`: Configuracion estatica del servidor (`~/nginx-proxy` y estructura de entornos).
- `production/`: Plantillas que GitHub Actions transfiere al servidor (`docker-compose.yml`, `env_build.sh`).
- `local-dev/`: Stack local de desarrollo con Docker Compose.
- `scripts/`: Scripts de soporte (`setup-env.sh`, `smoke-stack.sh`).
- `.github/workflows/`: Workflow reusable de despliegue (`cd-deploy.yml`).
- `docs/`: Documentacion tecnica detallada.

## Documentacion

- [Arquitectura](docs/architecture.md): Topologia de red, aislamiento y puertos por entorno.
- [CI/CD](docs/ci-cd.md): Pipeline de despliegue automatizado con GitHub Actions.
- [Reverse Proxy y Cloudflare](docs/reverse-proxy.md): Nginx global, certificados Origin, modo Full Strict y dominios.
- [Correo Transaccional (Resend)](docs/email-resend.md): Registros DNS en Cloudflare (SPF, DKIM) y variables de entorno.
- [Operaciones](docs/operations.md): Comandos cotidianos, logs y resolucion de problemas.
- [Almacenamiento de Documentos (RustFS/S3)](docs/document-storage.md): Bucket privado, aislamiento y respaldos pareados.

## Desarrollo local

```bash
cp local-dev/.env.example local-dev/.env
docker compose -f local-dev/docker-compose.stack.yml up -d --build
./scripts/smoke-stack.sh
```
