# Documentacion de Infraestructura

Indice de documentos tecnicos de despliegue y operacion en el servidor `servidopcyti`.

## Documentos

| Documento | Descripcion |
|---|---|
| [Arquitectura](architecture.md) | Topologia del servidor, redes Docker (`proxy-net`, `internal-net`) y puertos. |
| [CI/CD](ci-cd.md) | Flujo automatizado de despliegue con GitHub Actions (`cd-deploy.yml`). |
| [Reverse Proxy y Cloudflare](reverse-proxy.md) | Nginx global, certificados Origin de Cloudflare, modo Full Strict y enrutamiento por host. |
| [Correo Transaccional](email-resend.md) | Integracion con Resend, registros DNS en Cloudflare (SPF, DKIM) y variables de entorno. |
| [Operaciones](operations.md) | Comandos cotidianos, administracion de logs y resolucion de fallas. |

## Mapa de rutas

- `server/nginx-proxy/` -> Se monta en `/home/deployment/nginx-proxy/`.
- `production/` -> Se copia por SCP a `/home/deployment/sapcyti/<entorno>/`.
