# Acceso por Tailscale y firewall del host

Informe de la sesión del 13 al 14 de octubre de 2026 sobre el Tema 1 de [seguridad del servidor](https://github.com/SAPCyTI-UAM-I/Docs/blob/main/tests/seguridad-servidor.md) en `servidopcyti`. El cambio de las llaves JWT de desarrollo está en Docs: `implementation/notes/2026-10-14-claves-jwt-dev.md`.

## Resultado

| Punto | Estado |
|---|---|
| 1.1 Arquitectura (api y db sin puertos publicados) | Comprobado en el host |
| 1.2 SSH de operadores y de CI por Tailscale | Hecho y verificado con un deploy de dev |
| 1.3 Firewall y SSH del host | Hecho |
| 1.4 nmap desde fuera | 80 y 443 abiertos; 22 filtrado. El 53 que vio el escaneo de la laptop no lo publica el servidor |
| 1.5 Llave Origin CA en el servidor | `sapcyti.site.key` en `600`. El par JWT de desarrollo sigue en `main` de `sapcyti-api` hasta fusionar el PR 60 |

## Servidor

Tailscale ya estaba unido a la cuenta `cursor.uami@`. El nodo es `servidopcyti`, dirección `100.114.197.29`, etiqueta `tag:server`. La laptop del operador quedó en la misma Tailnet (`100.125.4.50`).

SSH del sistema, en `/etc/ssh/sshd_config.d/00-sapcyti-hardening.conf`:

- `PasswordAuthentication no`
- `KbdInteractiveAuthentication no`
- `PermitRootLogin no`
- `PubkeyAuthentication yes`

El archivo se llama `00-` porque OpenSSH usa la primera aparición de cada opción y `50-cloud-init.conf` dejaba `PasswordAuthentication yes`.

UFW quedó activo con entrada denegada. Entran 80/tcp y 443/tcp desde cualquier sitio, y el 22/tcp solo por la interfaz `tailscale0`. Una sesión nueva a `148.206.49.238:22` agota el tiempo. `ssh valente@100.114.197.29` entra.

Política SSH de Tailscale: `tag:ci` puede entrar al servidor etiquetado `tag:server` como usuario `deployment`, sin confirmación en el navegador. Los miembros de la cuenta siguen pudiendo entrar a ese tag. Un destino que es un usuario (`cursor.uami@`) no acepta como origen un tag: Tailscale responde `users in dst are only allowed from the same user`.

`api` y `db` no publican puertos al host. Cada `edge` escucha solo en `127.0.0.1`. Lo único en `0.0.0.0` es `global-reverse-proxy` (80 y 443). QA no estaba levantado durante la revisión.

`systemd-resolved` escucha el puerto 53 solo en `127.0.0.53` y `127.0.0.54`. El `53/tcp open` del nmap hecho desde la laptop no corresponde a un servicio del host. Falta repetir ese puerto desde datos móviles.

Certificados en `/home/deployment/nginx-proxy/certs/`: `sapcyti.site.key` es `600` y pertenece a `root`. El certificado del sitio y el CA de origin pull son `644`.

## Repositorio `sapcyti-infra`

En `main`:

- `ae19e46` conecta el runner a Tailscale antes de copiar archivos.
- `419acbe` deja de usar `appleboy/scp-action` y `appleboy/ssh-action`.

Esas acciones corren dentro de un contenedor y no ven la interfaz Tailscale del runner. Contra la IP `100.x` el saludo SSH terminaba en `handshake failed: EOF`. `scp` y `ssh` del propio runner sí usan la Tailnet. Los secretos del deploy viajan por la entrada estándar de SSH, no por la línea de comandos.

La auth key del runner es reusable, ephemeral y lleva `tag:ci`. Está guardada como `TAILSCALE_AUTHKEY` en `sapcyti-api` y `sapcyti-spa`. El step avisa que Tailscale prefiere un cliente OAuth; la key sigue siendo válida.

`SSH_HOST` de esos dos repositorios es `100.114.197.29`. El workflow de deploy hereda los secretos del repositorio que lo llama, no los de `sapcyti-infra`.

## Verificación

El deploy de dev [run 37248891615](https://github.com/SAPCyTI-UAM-I/sapcyti-api/actions/runs/37248891615) terminó en verde después de cerrar el 22 público: Tailscale, copia y `env_build.sh`.

nmap desde la laptop contra `148.206.49.238`: 65532 puertos TCP `filtered`, `80/tcp` y `443/tcp` `open`. El 22 no aparece abierto.

## Pendiente

- Repetir el puerto 53 desde datos móviles.
- Fusionar el [PR 60](https://github.com/SAPCyTI-UAM-I/sapcyti-api/pull/60) para que el par JWT de desarrollo salga de Git. El detalle está en el informe de Docs.
