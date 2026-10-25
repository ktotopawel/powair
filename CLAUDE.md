# PowAir

Polish air quality browser (GIOŚ data). Spring Boot + PostgreSQL + MongoDB backend, React + Vite frontend.

Scope is fixed by [docs/DoD.md](docs/DoD.md) (features F1–F7 and cross-cutting requirements). Anything not on that list goes to `docs/ideas.md`, not into code. The schema is documented in [docs/schema.dbml](docs/schema.dbml). Everything known about GIOŚ data (API shapes, zip format, time zones, units, import decisions) is in [docs/gios.md](docs/gios.md); read it before touching the importer.

Key rules:
- Never fabricate measurements; missing values are no row, never 0. Seed data, if any, is clearly labelled as test data.
- Backend: REST returns DTOs, never entities; errors use RFC 7807 `ProblemDetail`; validation via Bean Validation; OpenAPI via springdoc; no Lombok.
- Schema changes only via new Flyway migrations, with `docs/schema.dbml` updated in the same commit. Ask before changing the schema after V1.
- No new dependencies or services without saying why.
- Frontend is mobile-first: design and build every view for a phone first (375 px), then add `sm:`/`md:` breakpoints for larger screens. Touch targets at least 44 px, no hover-only interactions, no horizontal page scroll. Not a PWA (no service worker, manifest or offline mode).

## Dev commands

```bash
cp .env.example .env                     # first time only, then set passwords
docker compose up -d postgres mongo      # day-to-day: databases only, run backend/frontend locally
docker compose up -d --build             # whole stack: frontend :3000 (proxies /api), backend :8080
docker compose ps                        # check health
docker compose down                      # stop (add -v to wipe data volumes)
```

Local development runs the backend and frontend outside Docker against the compose databases. The full stack in compose is for checking the finished thing; stop its `backend` container before `./mvnw spring-boot:run`, since both use port 8080.

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
