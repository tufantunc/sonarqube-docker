# SonarQube Docker

A best-practice, self-hosted SonarQube setup for scanning locally developed
projects and tracking their code quality. Spin up SonarQube + PostgreSQL with a
single command, scan any local project on demand, and follow results in the web
UI and logs.

- 📦 **Pinned versions** — SonarQube 26.x (community), PostgreSQL 17, Scanner 12
- 🔒 **Secure** — no `privileged: true`; secrets are read from `.env`
- 🩺 **Healthchecks** — the scanner never starts before SonarQube is ready
- 🚀 **On-demand scanning** — `./scripts/scan.sh <project-dir>`
- 📂 **Persistent data** — named volumes survive restarts

## Quick Start

### 1. Create your `.env`

```bash
cp .env.example .env
```

Open `.env` and at least set:

```dotenv
POSTGRES_PASSWORD=a-strong-password            # PostgreSQL password
SONAR_TOKEN=squ_xxxxxxxxxxxxxxxxx              # SonarQube token (see below)
```

### 2. Start the services

```bash
docker compose up -d
```

SonarQube takes ~1 minute to start up on first run. Confirm it is healthy:

```bash
docker compose ps
```

Do not trigger a scan until the `sonarqube` service shows `(healthy)`.

### 3. First login & generate a token

Open **http://localhost:9000** in your browser.

Default credentials:
- User: `admin`
- Password: `admin` (you'll be prompted to change it on first login)

Then generate a token:

> **My Account → Security → Generate Tokens**

Paste the generated token into the `SONAR_TOKEN` value in your `.env`:

```dotenv
SONAR_TOKEN=sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

> **Note:** The legacy `sonar.login` property has been **deprecated since
> SonarQube 8.x**. Authentication is done via the `SONAR_TOKEN` environment
> variable instead.

### 4. Scan a project

Place a `sonar-project.properties` in the **root** of the project you want to
scan (use the one in this repo as a template). At minimum, set `sonar.projectKey`:

```properties
sonar.projectKey=my-app
sonar.projectName=My App
sonar.sources=.
```

Then run the scan:

```bash
./scripts/scan.sh ../my-app
```

You can also pass extra parameters on the command line:

```bash
./scripts/scan.sh ../my-app -Dsonar.branch.name=main
```

### 5. View the results

- **Web UI:** http://localhost:9000 → your project appears here with full details
- **Live logs:**
  ```bash
  docker compose logs -f sonarqube    # SonarQube server logs
  docker compose logs -f db           # PostgreSQL logs
  ```

## Everyday Commands

```bash
# Start services in the background
docker compose up -d

# Status & health
docker compose ps

# Tail logs
docker compose logs -f sonarqube

# Run a scan
./scripts/scan.sh ../project-dir

# Stop services (data is preserved)
docker compose down

# Wipe all data and start from scratch (destructive!)
docker compose down -v
```

## Scanning Multiple Projects

You can scan as many projects as you like — each must have its own
`sonar-project.properties`:

```bash
./scripts/scan.sh ~/projects/web-api
./scripts/scan.sh ~/projects/mobile-app
./scripts/scan.sh ~/projects/data-pipeline
```

Each one shows up as a separate project in the SonarQube UI.

## Configuration (`.env`)

All settings are controlled via `.env`. See `.env.example` for the full list:

| Variable | Description | Default |
|---|---|---|
| `SONARQUBE_VERSION` | SonarQube image tag | `community` |
| `POSTGRES_VERSION` | PostgreSQL image tag | `17` |
| `SCANNER_VERSION` | Scanner image tag | `12` |
| `POSTGRES_USER` | DB user | `sonar` |
| `POSTGRES_PASSWORD` | DB password (**required**) | — |
| `POSTGRES_DB` | DB name | `sonar` |
| `SONARQUBE_PORT` | Web port on the host | `9000` |
| `SONAR_TOKEN` | Scan token (**required**) | — |

## Linux: Required Kernel Settings

SonarQube embeds Elasticsearch, which requires raised kernel limits
(not needed on Docker Desktop / macOS):

```bash
sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072
```

To make them permanent, add the lines to `/etc/sysctl.conf`.

## Troubleshooting

**`max virtual memory areas vm.max_map_count [65530] is too low`**
→ Run the `sysctl` commands above (Linux only).

**`Service 'scanner' failed to start: condition service_healthy was not met`**
→ SonarQube is not ready yet. Wait for `(healthy)` in `docker compose ps`.

**`401 Unauthorized` during a scan**
→ Make sure `SONAR_TOKEN` in `.env` is correct.

**Port 9000 is already in use**
→ Change `SONARQUBE_PORT=9001` (or any free port) in `.env`.

## Architecture

```
Host
├── .env                      # secrets (not committed to git)
├── docker-compose.yml        # 3 services: sonarqube, db, scanner
├── sonar-project.properties  # template (copy into each project)
└── scripts/scan.sh           # scan helper

Docker
├── sonarqube  (web :9000)  ──►  db (postgres:17)
└── scanner    (profile=scan, on demand)
```

The `scanner` service belongs to the `scan` profile, so a plain
`docker compose up` does not start it — it only runs via `scripts/scan.sh` or
`--profile scan`. This keeps resources idle when you are not scanning.

## License

MIT — see `LICENSE`.

