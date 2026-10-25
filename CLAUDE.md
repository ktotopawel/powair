# PowAir

Polish air quality browser (GIOŚ data). Spring Boot + PostgreSQL + MongoDB backend, React + Vite frontend.

**Read [docs/HANDOFF.md](docs/HANDOFF.md) before making changes.** It defines the fixed scope (F1–F7), the stack, the schema and the ground rules. Ideas outside that scope go in `docs/ideas.md`, not in code.

Key rules (details in HANDOFF §9):
- Never fabricate measurements; missing values are no row, never 0.
- Schema changes only via new Flyway migrations, with `docs/schema.dbml` updated in the same commit. Ask before changing the schema after V1.
- No new dependencies or services without saying why.
- Frontend is mobile-first: design and build every view for a phone first (375 px), then add `sm:`/`md:` breakpoints for larger screens. Touch targets at least 44 px, no hover-only interactions, no horizontal page scroll. Not a PWA (no service worker, manifest or offline mode).

## Dev commands

```bash
cp .env.example .env          # first time only, then set passwords
docker compose up -d          # start postgres + mongo
docker compose ps             # check health
docker compose down           # stop (add -v to wipe data volumes)
```

Backend (Java 25, Spring Boot 4.1; run from `backend/`, Maven only via the wrapper):

```bash
./mvnw spring-boot:run        # needs compose running; reads credentials from ../.env
./mvnw test                   # Testcontainers starts its own Postgres/Mongo (Docker must be running)
./mvnw -DskipTests package    # build target/powair-backend-*.jar
```

Health check: `curl localhost:8080/actuator/health` (shows `db` and `mongo` status).

API requests live in the Bruno collection in `bruno/` (open the folder in Bruno, pick the `local` environment). Add a `.bru` request under `bruno/PowAir/` for each new endpoint. Never put tokens or passwords in `.bru` files; use Bruno secret variables.

Frontend (React 19, Vite 8, Tailwind 4, React Router 8, TanStack Query; run from `frontend/`):

```bash
npm install
npm run dev                   # http://localhost:5173, proxies /api to localhost:8080
npm run build                 # type-check + production build to dist/
npm run lint                  # oxlint
```

`docker compose up -d --build frontend` serves the production build via nginx on http://localhost:3000.
