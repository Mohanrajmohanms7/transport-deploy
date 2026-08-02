# Transport ERP — Deploy (DevOps)

Production Docker stack for **Frontend + Backend + PostgreSQL**.

## Related GitHub repos (private)

| Repo | URL |
|------|-----|
| Frontend (Angular + nginx) | https://github.com/Mohanrajmohanms7/transport-frontend |
| Backend (Spring Boot) | https://github.com/Mohanrajmohanms7/transport-backend |
| Deploy (this repo) | https://github.com/Mohanrajmohanms7/transport-deploy |

## Folder layout on the server

Clone all three as **siblings** (same parent folder):

```text
fleetflow/
├── transport-frontend/     # git clone .../transport-frontend.git
├── transport-backend/      # git clone .../transport-backend.git
└── transport-deploy/       # git clone .../transport-deploy.git  (you are here)
    ├── docker-compose.prod.yml
    ├── .env.prod.example
    ├── .env.prod                 # create locally — DO NOT commit
    └── docs/DEPLOY_FREE_ORACLE.md
```

```bash
mkdir -p ~/fleetflow && cd ~/fleetflow
git clone https://github.com/Mohanrajmohanms7/transport-frontend.git
git clone https://github.com/Mohanrajmohanms7/transport-backend.git
git clone https://github.com/Mohanrajmohanms7/transport-deploy.git
cd transport-deploy
```

## Configure secrets

```bash
cp .env.prod.example .env.prod
nano .env.prod
```

Set strong values for:

- `POSTGRES_PASSWORD`
- `JWT_SECRET` (e.g. `openssl rand -base64 48`)
- `APP_BOOTSTRAP_ADMIN_PASSWORD`
- First deploy: `APP_BOOTSTRAP_ENABLED=true`

## Deploy

```bash
cd ~/fleetflow/transport-deploy
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f backend
```

App URL: `http://SERVER_PUBLIC_IP`  
API is same-origin via nginx: `/api/...` → backend `:8080` (no public backend port).

Default login after bootstrap: user `admin` + password from `APP_BOOTSTRAP_ADMIN_PASSWORD`.

## Update after code changes

```bash
cd ~/fleetflow/transport-frontend && git pull
cd ~/fleetflow/transport-backend && git pull
cd ~/fleetflow/transport-deploy && git pull
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

## Architecture

| Service | Public | Notes |
|---------|--------|--------|
| frontend (nginx) | **:80** | Serves Angular; proxies `/api` |
| backend | internal only | Spring Boot `:8080` |
| postgres | internal only | Volume `postgres-data` |

## More detail

See [docs/DEPLOY_FREE_ORACLE.md](docs/DEPLOY_FREE_ORACLE.md) for Oracle Always Free VM setup, firewall, seed data, and HTTPS notes.

## Security

- Never commit `.env.prod`
- Do not expose ports `5432` or `8080` on the firewall
- After real seed data: set `APP_BOOTSTRAP_ENABLED=false` and recreate backend
