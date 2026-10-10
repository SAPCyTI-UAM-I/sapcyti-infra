# Operaciones del Servidor

Comandos de gestion, diagnostico y resolucion de incidentes en `servidopcyti`.

## 1. Acceso

```bash
ssh deployment@servidopcyti
```

## 2. Monitoreo de contenedores

```bash
# Ver todos los contenedores activos
docker ps

# Filtrar por entorno
docker ps --filter "name=sapcyti-dev"
docker ps --filter "name=sapcyti-qa"
docker ps --filter "name=sapcyti-prod"

# Ver uso de recursos
docker stats --no-stream
```

## 3. Logs

```bash
# Proxy global
docker logs -f global-reverse-proxy

# Backend de un entorno
docker logs -f sapcyti-dev-api

# Edge / SPA de un entorno
docker logs -f sapcyti-dev-edge

# Base de datos
docker logs -f sapcyti-dev-db

# Almacenamiento de objetos (RustFS / S3)
docker logs -f sapcyti-dev-storage
```

## 4. Reinicio manual de stacks

### Aplicacion por entorno
```bash
cd ~/sapcyti/dev

# Parar y levantar
docker compose down
docker compose up -d

# Actualizar imagenes manualmente
docker compose pull
docker compose up -d --remove-orphans
```

### Proxy global
```bash
cd ~/nginx-proxy
docker compose restart
```

## 5. Resolucion de problemas

### Error 502 Bad Gateway
1. Verificar que el contenedor edge del entorno este corriendo:
   ```bash
   docker ps --filter "name=sapcyti-dev-edge"
   ```
2. Verificar que el contenedor este en la red `proxy-net`:
   ```bash
   docker network inspect proxy-net
   ```
3. Probar respuesta local en el host:
   ```bash
   curl -I http://127.0.0.1:8090
   ```

### El backend no inicia
Revisar logs del contenedor y estado de PostgreSQL:
```bash
docker logs --tail 100 sapcyti-dev-api
docker exec sapcyti-dev-db pg_isready -U sapcyti -d sapcyti_dev
```

### Error de autenticacion en GitHub Actions (GHCR)
Si el pull falla con `unauthorized`:
- Actualizar el secret `GHCR_PAT` en GitHub con un token que tenga permiso `read:packages`.
