# telecom-deploy

Repositorio de despliegue para `telecom-spa` + `telecom-reportespiolis`.

## Servicios

- `nginx` (unica puerta de entrada publica)
- `spa` (build local desde codigo fuente)
- `reportespiolis` (build local desde codigo fuente)

Solo `nginx` publica puerto al host (HTTPS). `spa` y `reportespiolis` quedan dentro de la red Docker.

## Variables

```bash
cp .env.example .env
```

Variables principales:

- `WEB_HTTPS_PORT` (default `443`)
- `BASIC_AUTH_USER` y `BASIC_AUTH_PASS` (default `comu` / `adminwiz`)
- `SPA_REPO_URL` y `SPA_REF`
- `REPORTES_REPO_URL` y `REPORTES_REF`

## Deploy desde cero

```bash
git clone https://github.com/mferrari98/telecom-deploy.git
cd telecom-deploy
cp .env.example .env
./scripts/bootstrap-and-deploy.sh
```

El script hace todo esto automaticamente:

- clona/actualiza `telecom-spa` en `sources/telecom-spa`
- clona/actualiza `telecom-reportespiolis` en `sources/telecom-reportespiolis`
- crea `.env` faltantes
- ejecuta `docker compose up -d --build`

Los builds se realizan desde esos fuentes clonados usando Dockerfiles controlados por este repo en `dockerfiles/`.

## Redeploy (actualizar codigo y reconstruir)

```bash
./scripts/bootstrap-and-deploy.sh
```

## Comandos utiles

Levantar/reconstruir sin bootstrap:

```bash
docker compose -p webtelecom up -d --build
```

Bajar stack:

```bash
docker compose -p webtelecom down
```

Ver logs:

```bash
docker compose -p webtelecom logs -f nginx
```

## Nota

El deploy usa URLs HTTPS de GitHub. Si el repo es privado, necesitas credenciales git configuradas en el host para permitir el `git clone`/`git pull` del script.
