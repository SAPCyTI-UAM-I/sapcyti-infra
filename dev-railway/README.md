# SAPCyTI Railway Dev Deployment

Esta guia documenta como desplegar SAPCyTI en Railway usando imagenes publicadas en Docker Hub. El objetivo es mantener un flujo parecido al stack local, pero adaptado al modelo de Railway: servicios separados para PostgreSQL, API y SPA/edge.

> Nota: Flyway no se despliega como servicio aparte. El backend `sapcyti-api` ejecuta Flyway automaticamente al arrancar porque `spring.flyway.enabled=true` y las migraciones viven en `classpath:db/migration`.

## Arquitectura

```text
Usuario
  -> Dominio publico Railway del servicio spa
    -> nginx dentro de sapcyti-spa
      -> /api hacia api.railway.internal:8080
        -> PostgreSQL Railway
```

Servicios recomendados en Railway:

| Servicio | Fuente | Exposicion |
| --- | --- | --- |
| `postgres` | Railway PostgreSQL | Privado |
| `api` | Docker Hub: `sapcyti-api` | Privado |
| `spa` | Docker Hub: `sapcyti-spa` | Publico |

Archivos de ejemplo incluidos en esta carpeta:

| Archivo | Uso |
| --- | --- |
| [`api.env.example`](api.env.example) | Variables para el servicio Railway `api` |
| [`spa.env.example`](spa.env.example) | Variables para el servicio Railway `spa` |

Los archivos son plantillas. No guardes llaves JWT reales ni secretos reales en el repositorio.

## 1. Preparar Docker Hub

Inicia sesion:

```bash
docker login
```

Define usuario y version:

```bash
export DOCKERHUB_USER=tu_usuario
export VERSION=0.1.0
```

Construye y publica la API:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t $DOCKERHUB_USER/sapcyti-api:$VERSION \
  -t $DOCKERHUB_USER/sapcyti-api:latest \
  /home/hrlm/SAPCyTI/sapcyti-api \
  --push
```

Construye y publica la SPA:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t $DOCKERHUB_USER/sapcyti-spa:$VERSION \
  -t $DOCKERHUB_USER/sapcyti-spa:latest \
  /home/hrlm/SAPCyTI/sapcyti-spa \
  --push
```

Usa tags versionados para despliegues reproducibles. `latest` sirve para pruebas rapidas, pero no debe ser la unica referencia.

## 2. Crear Proyecto En Railway

1. Crea un proyecto nuevo en Railway.
2. Agrega una base PostgreSQL usando el servicio administrado de Railway.
3. Crea un servicio desde Docker image para la API:

   ```text
   tu_usuario/sapcyti-api:0.1.0
   ```

4. Crea un servicio desde Docker image para la SPA:

   ```text
   tu_usuario/sapcyti-spa:0.1.0
   ```

5. Nombra los servicios de forma estable:

   ```text
   postgres
   api
   spa
   ```

El nombre `api` importa porque se usara como dominio privado `api.railway.internal` desde nginx.

## 3. Variables Del Servicio API

Configura estas variables en el servicio `api`. Puedes copiar la plantilla [`api.env.example`](api.env.example):

```env
SPRING_PROFILES_ACTIVE="docker,prod"
SERVER_PORT="8080"
PORT="8080"
SERVER_ADDRESS="::"
DB_URL="jdbc:postgresql://${{postgres.PGHOST}}:${{postgres.PGPORT}}/${{postgres.PGDATABASE}}"
DB_USER="${{postgres.PGUSER}}"
DB_PASS="${{postgres.PGPASSWORD}}"
CORS_ALLOWED_ORIGINS="https://spa-production-7348.up.railway.app"
JWT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----"
JWT_PUBLIC_KEY="-----BEGIN PUBLIC KEY-----"
```

Valores pendientes y de donde salen:

| Variable | De donde sale |
| --- | --- |
| `PORT` | Puerto que Railway puede usar como referencia del servicio; debe coincidir con `SERVER_PORT` para la API. |
| `SERVER_ADDRESS` | `::` hace que Spring Boot escuche en todas las interfaces, incluyendo IPv6, necesario para red privada Railway. |
| `DB_URL` | Railway la resuelve desde el servicio `postgres` usando `${{postgres.PGHOST}}`, `${{postgres.PGPORT}}` y `${{postgres.PGDATABASE}}`. No la escribas a mano si el servicio se llama `postgres`. |
| `DB_USER` | Referencia a `${{postgres.PGUSER}}` del servicio PostgreSQL de Railway. |
| `DB_PASS` | Referencia a `${{postgres.PGPASSWORD}}` del servicio PostgreSQL de Railway. |
| `CORS_ALLOWED_ORIGINS` | Dominio publico generado para el servicio `spa`, por ejemplo `https://spa-production-7348.up.railway.app`. |
| `JWT_PRIVATE_KEY` | Llave privada generada por ti con `openssl`; pegar PEM completo. |
| `JWT_PUBLIC_KEY` | Llave publica generada desde la llave privada; pegar PEM completo. |

Despues de generar el dominio publico del servicio `spa`, reemplaza `https://spa-production-7348.up.railway.app` por el dominio real.

### Llaves JWT

Para dev remoto no uses las llaves `dev-*.pem` del repositorio si el entorno sera compartido. Genera llaves nuevas:

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out jwt-private.pem
openssl rsa -pubout -in jwt-private.pem -out jwt-public.pem
```

Copia el contenido completo en variables Railway del servicio `api`:

```env
JWT_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----

JWT_PUBLIC_KEY=-----BEGIN PUBLIC KEY-----
...
-----END PUBLIC KEY-----
```

El backend soporta estas variables porque `JwtService` lee `jwt.private-key` y `jwt.public-key` desde propiedades Spring. Spring Boot mapea variables `JWT_PRIVATE_KEY` y `JWT_PUBLIC_KEY` a esas propiedades.

## 4. Variables Del Servicio SPA

Configura estas variables en el servicio `spa`. Puedes copiar la plantilla [`spa.env.example`](spa.env.example):

```env
API_UPSTREAM="http://api.railway.internal:8080"
```

`API_UPSTREAM` sale del nombre del servicio Railway de la API. Si el servicio se llama `api`, Railway expone la red privada como `api.railway.internal`; por eso el valor queda `http://api.railway.internal:8080`.

No agregues slash final. Correcto:

```env
API_UPSTREAM=http://api.railway.internal:8080
```

Incorrecto:

```env
API_UPSTREAM=http://api.railway.internal:8080/
```

La SPA ya esta compilada con:

```ts
apiBaseUrl: '/api'
```

Por eso el navegador llama al dominio publico de la SPA:

```text
https://spa-production-7348.up.railway.app/api/auth/login
```

nginx dentro del contenedor `sapcyti-spa` proxifica esa ruta al backend privado:

```text
http://api.railway.internal:8080/api/auth/login
```

### Puerto

El contenedor SPA usa la variable `PORT` si Railway la inyecta. Si Railway no detecta el puerto correctamente, define:

```env
PORT=8080
```

## 5. Dominio Publico

Genera dominio publico solo para `spa`.

No expongas `api` publicamente si no es necesario. La API puede quedar accesible solo por red privada Railway, mediante:

```text
api.railway.internal:8080
```

Cuando tengas el dominio publico de `spa`, vuelve al servicio `api` y actualiza:

```env
CORS_ALLOWED_ORIGINS=https://spa-production-7348.up.railway.app
```

## 6. Orden De Despliegue

1. Despliega `postgres`.
2. Despliega `api`.
3. Revisa logs de `api` y confirma Flyway.
4. Despliega `spa`.
5. Genera dominio publico para `spa`.
6. Actualiza `CORS_ALLOWED_ORIGINS` en `api` con el dominio real.
7. Redeploy de `api`.
8. Prueba login desde el dominio publico de `spa`.

## 7. Validacion

En logs de `api`, verifica:

- conexion exitosa a PostgreSQL;
- migraciones Flyway aplicadas;
- aplicacion escuchando en `8080`;
- healthcheck disponible en `/actuator/health`.

En navegador, verifica en Network:

- `POST /api/auth/login` se hace contra el dominio de la SPA;
- la respuesta contiene cookie `refreshToken`;
- requests posteriores llevan `Authorization: Bearer ...`;
- si el usuario tiene `graduateProgramId`, se envia `X-Graduate-Id`.

## 8. Problemas Comunes

### La SPA marca 504 al hacer login

Si nginx muestra errores como:

```text
upstream timed out while connecting to upstream
POST /api/auth/login HTTP/1.1 504
```

la SPA esta viva, pero no puede abrir conexion TCP hacia la API por la red privada. En el servicio `api`, confirma estas variables:

```env
SERVER_PORT="8080"
PORT="8080"
SERVER_ADDRESS="::"
```

`SERVER_ADDRESS="::"` permite que Spring Boot escuche en IPv6/IPv4. Railway recomienda escuchar en `::` para que la red privada funcione correctamente en todos los entornos.

Tambien confirma que `API_UPSTREAM` en `spa` apunte al servicio correcto:

```env
API_UPSTREAM="http://api.railway.internal:8080"
```

Despues de cambiar variables, redeploy de `api` y luego de `spa`.

### `api.railway.internal` no resuelve

Confirma que el servicio se llama exactamente `api`. Si se llama distinto, actualiza:

```env
API_UPSTREAM=http://NOMBRE_REAL.railway.internal:8080
```

### La API no conecta a PostgreSQL

Revisa que las referencias apunten al servicio correcto:

```env
DB_URL=jdbc:postgresql://${{postgres.PGHOST}}:${{postgres.PGPORT}}/${{postgres.PGDATABASE}}
DB_USER=${{postgres.PGUSER}}
DB_PASS=${{postgres.PGPASSWORD}}
```

Si tu servicio PostgreSQL no se llama `postgres`, cambia el prefijo.

### Login falla por CORS

Si todo entra por `/api` desde nginx, normalmente no deberia haber CORS en el navegador porque es mismo origen. Aun asi, deja `CORS_ALLOWED_ORIGINS` con el dominio real de la SPA para pruebas directas o futuras integraciones.

### Cookie `refreshToken` no aparece

El backend marca la cookie como `Secure` cuando el perfil no es `dev` ni `local`. En Railway debe usarse HTTPS, asi que esto es esperado y correcto. Prueba desde el dominio `https://...`, no desde `http://...`.

### Flyway falla

Revisa el error exacto en logs de `api`. Usualmente es uno de estos casos:

- base ya tenia tablas creadas manualmente;
- migracion fallo a mitad de camino;
- credenciales de DB incorrectas;
- `DB_URL` apunta a otra base.

Para un primer despliegue de desarrollo, lo mas simple es usar una base Railway vacia.

## 9. Actualizar Una Version

Cuando cambie el codigo:

```bash
export DOCKERHUB_USER=tu_usuario
export VERSION=0.1.1
```

Publica nuevas imagenes:

```bash
docker buildx build --platform linux/amd64 \
  -t $DOCKERHUB_USER/sapcyti-api:$VERSION \
  -t $DOCKERHUB_USER/sapcyti-api:latest \
  /home/hrlm/SAPCyTI/sapcyti-api \
  --push

docker buildx build --platform linux/amd64 \
  -t $DOCKERHUB_USER/sapcyti-spa:$VERSION \
  -t $DOCKERHUB_USER/sapcyti-spa:latest \
  /home/hrlm/SAPCyTI/sapcyti-spa \
  --push
```

Luego cambia el tag de imagen en Railway o usa redeploy si estas siguiendo `latest`.

## 10. Checklist Final

- [ ] Imagen `sapcyti-api` publicada en Docker Hub.
- [ ] Imagen `sapcyti-spa` publicada en Docker Hub.
- [ ] Servicio `postgres` creado en Railway.
- [ ] Servicio `api` creado desde Docker image.
- [ ] Servicio `spa` creado desde Docker image.
- [ ] `API_UPSTREAM` apunta a `api.railway.internal:8080`.
- [ ] `DB_URL`, `DB_USER`, `DB_PASS` usan variables del servicio PostgreSQL.
- [ ] `JWT_PRIVATE_KEY` y `JWT_PUBLIC_KEY` configuradas.
- [ ] Dominio publico generado solo para `spa`.
- [ ] `CORS_ALLOWED_ORIGINS` actualizado con el dominio real.
- [ ] Login real validado desde el dominio publico.
