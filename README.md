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
- `BASIC_AUTH_USER` y `BASIC_AUTH_PASS` (obligatorio cambiar valores por defecto)
- `SPA_INSECURE_TLS_BUILD` (default `0`, usar `1` solo ante problemas de CA en redes internas)
- `SPA_REPO_URL` y `SPA_REF`
- `REPORTES_REPO_URL` y `REPORTES_REF`

Defaults de guardias en SPA (si no se definen vars en entorno):

- `GUARDIAS=FERRARI,ARCE,CARO,DONATO`
- `FECHA_REFERENCIA=2025-01-07`
- `GUARDIA_REFERENCIA=DONATO`
- `CELULAR_CORPORATIVO=+54 280 123-4567`

`reportespiolis` toma `EMAIL_USER`, `EMAIL_PASS` y `EMAIL_DIFUSION` desde `sources/telecom-reportespiolis/.env`.

Politica de secretos:

- `.env.example` es solo plantilla (sin secretos reales).
- `.env` local no se versiona (`.gitignore`).
- No usar credenciales debiles o de ejemplo (placeholders, valores legacy conocidos).
- Si detecta esos valores, `./setup` y `./actualizar` muestran advertencia para rotacion.

## Deploy desde cero

```bash
git clone https://github.com/mferrari98/telecom-deploy.git
cd telecom-deploy
cp .env.example .env
./setup
docker compose -p webtelecom up -d --build --remove-orphans
```

El script hace todo esto automaticamente:

- clona/actualiza `telecom-spa` en `sources/telecom-spa`
- clona/actualiza `telecom-reportespiolis` en `sources/telecom-reportespiolis`
- crea `.env` faltantes

Al finalizar `./setup`, el entorno queda preparado y muestra el comando para arrancar contenedores.

Los builds se realizan desde esos fuentes clonados usando Dockerfiles controlados por este repo en `dockerfiles/`.

## Redeploy (actualizar codigo y reconstruir)

```bash
./actualizar --update --deploy
```

## Scripts principales

- `./setup`: clona/actualiza repos (HTTPS), prepara `.env` faltantes y deja el entorno listo sin arrancar contenedores.
- `./actualizar`: revisa cambios entre local y remoto en `telecom-deploy`, `telecom-spa` y `telecom-reportespiolis`.

Opciones de `actualizar`:

```bash
./actualizar --update          # hace pull --ff-only donde haya updates
./actualizar --update --deploy # ademas reconstruye y levanta stack
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

## Carga de internos.xlsx desde la web

Con el stack levantado y usuario autenticado por Basic Auth:

1. Abrir `https://HOST/`.
2. Entrar en `Busqueda internos`.
3. Hacer click en `Cargar documento` y seleccionar un archivo `.xlsx`.

La SPA sube el archivo a `INTERNALS_XLSX_PATH` (por defecto `/app/data/internos.xlsx`) y refresca el cache de internos automaticamente.

## Nota

El deploy usa URLs HTTPS de GitHub. Si el repo es privado, necesitas credenciales git configuradas en el host para permitir el `git clone`/`git pull` del script.
