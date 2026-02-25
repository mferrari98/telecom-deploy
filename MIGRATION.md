# Migracion a 3 repos

## Objetivo

Separar por responsabilidades:

1. `telecom-spa`: SPA + design system
2. `telecom-reportespiolis`: servicio de reportes
3. `telecom-deploy`: este repo (compose + nginx + env)

## Flujo recomendado

1. Crear los tres repos remotos vacios.
2. Subir `web-telecom` a `telecom-spa`.
3. Subir `telecom-reportespiolis` a su repo remoto dedicado.
4. Subir `telecom-deploy` a su repo.
5. En el host de despliegue, clonar `telecom-deploy` y crear `.env`.
6. Configurar en `.env`:
   - `SPA_REPO_URL` y `SPA_REF`
   - `REPORTES_REPO_URL` y `REPORTES_REF`
7. Desplegar (clona repos + build + up):

```bash
./scripts/bootstrap-and-deploy.sh
```

## Validacion post-deploy

- `https://HOST/` (401 sin credenciales, 200 con basic auth)
- `https://HOST/pedidos/`
- `https://HOST/deudores/`
- `https://HOST/guardias/`
- `https://HOST/monitor/`
- `https://HOST/reporte/`
