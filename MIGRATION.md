# Migracion a 3 repos

## Objetivo

Separar por responsabilidades:

1. `telecom-spa`: SPA + design system
2. `telecom-reportespiolis`: servicio de reportes
3. `telecom-deploy`: este repo (compose + nginx + env)

## Flujo recomendado

1. Crear los tres repos remotos vacios.
2. Subir `web-telecom` a `telecom-spa`.
3. Subir `servicios-telecom/cont-reportespiolis` a `telecom-reportespiolis`.
4. Subir `telecom-deploy` a su repo.
5. Configurar CI para publicar imagenes en registry:
   - `ghcr.io/<org>/telecom-spa:<tag>`
   - `ghcr.io/<org>/telecom-reportespiolis:<tag>`
6. En `telecom-deploy/.env`, fijar:
   - `SPA_IMAGE`
   - `REPORTES_IMAGE`
7. Desplegar:

```bash
docker compose -p webtelecom pull spa reportespiolis
docker compose -p webtelecom up -d --build nginx
```

## Validacion post-deploy

- `https://HOST/` (401 sin credenciales, 200 con basic auth)
- `https://HOST/pedidos/`
- `https://HOST/deudores/`
- `https://HOST/guardias/`
- `https://HOST/monitor/`
- `https://HOST/reporte/`
