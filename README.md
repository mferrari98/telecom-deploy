# telecom-deploy

Repositorio de despliegue para `telecom-spa` + `telecom-reportespiolis`.

## Servicios

- `nginx` (unica puerta de entrada publica)
- `spa` (por imagen Docker)
- `reportespiolis` (por imagen Docker)

Solo `nginx` publica puerto al host (HTTPS). `spa` y `reportespiolis` quedan dentro de la red Docker.

## Variables

```bash
cp .env.example .env
```

Variables principales:

- `WEB_HTTPS_PORT` (default `443`)
- `BASIC_AUTH_USER` y `BASIC_AUTH_PASS` (default `comu` / `adminwiz`)
- `SPA_IMAGE`
- `REPORTES_IMAGE`

## Levantar stack

```bash
docker compose -p webtelecom up -d --build
```

## Flujo de deploy recomendado

1. `telecom-spa` publica imagen versionada.
2. `telecom-reportespiolis` publica imagen versionada.
3. Actualizar `SPA_IMAGE` y `REPORTES_IMAGE` en este repo.
4. Ejecutar:

```bash
docker compose -p webtelecom pull spa reportespiolis
docker compose -p webtelecom up -d --build nginx
```

## Uso local (sin registry)

Si ya construiste localmente:

- `webtelecom-spa:latest`
- `webtelecom-reportespiolis:latest`

puedes dejar los defaults y levantar directo con compose.

Tambien puedes construir ambas imagenes con:

```bash
./scripts/build-local-images.sh
```
