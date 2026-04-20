# kong_gateway

Gateway Kong en modo DB-less para enrutar trafico a los microservicios `inventario`, `pedidos`, `envios` y `notificaciones` bajo el contrato operativo definido en IaC.

## Contrato IaC relevante

- El servicio Kong corre en ECS/Fargate con trafico por puerto 8000.
- `KONG_DATABASE=off` (DB-less).
- ALB hace health check HTTP a `/`.
- Los microservicios se descubren por Cloud Map.

## Estructura

- `Dockerfile`: build de imagen runtime de Kong.
- `entrypoint.sh`: resuelve namespace de Cloud Map, renderiza config y valida.
- `kong.yml.template`: configuracion declarativa DB-less.
- `.dockerignore`: reduce contexto de build.

## Resolucion de namespace

Precedencia:

1. `KONG_SERVICE_DISCOVERY_NAMESPACE` (si viene seteada).
2. Metadata ECS (`ECS_CONTAINER_METADATA_URI_V4/task`), leyendo `Family: kong-<environment>`.

Mapeo de `environment` a namespace:

- `main` -> `smartlogix-main.local`
- `canary` -> `smartlogix-canary.local`
- `pr-*` o `ephemeral` -> `smartlogix.local`

Si ninguna de las dos formas aplica (o si metadata viene invalida), el contenedor falla en startup (fail-fast) para evitar ruteo silencioso al namespace incorrecto.

## Rutas configuradas

- `/api/inventario` -> `inventario.<namespace>:3000`
- `/api/pedidos` -> `pedidos.<namespace>:3000`
- `/api/envios` -> `envios.<namespace>:3000`
- `/api/notificaciones` -> `notificaciones.<namespace>:3000`

Adicionalmente, `GET /` responde 200 para salud del ALB.

## Variables de entorno utiles

- `KONG_SERVICE_DISCOVERY_NAMESPACE` (opcional, recomendada en produccion si quieres control explicito).
- `KONG_METADATA_RETRIES` (opcional, default `5`).
- `KONG_METADATA_RETRY_DELAY_SECONDS` (opcional, default `1`).
- `KONG_METADATA_HTTP_TIMEOUT_SECONDS` (opcional, default `2`).
- `KONG_LOG_LEVEL` (opcional, por defecto `notice` de Kong).

## Validacion local rapida

```bash
docker build -t kong-gateway-local .
docker run --rm -p 8000:8000 \
  -e KONG_SERVICE_DISCOVERY_NAMESPACE=smartlogix.local \
  kong-gateway-local
```

Luego:

```bash
curl -i http://localhost:8000/
```

Debe responder `200`.

## Nota de despliegue

Si el pipeline despliega imagen propia de este repo, la task definition ECS debe usar el tag de ECR correspondiente. Si sigue usando `kong:latest`, estos cambios de repo no se reflejaran en runtime.
