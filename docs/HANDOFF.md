# PowAir — Project Handoff for Claude Code

You are starting a new project from scratch. Read this whole file before writing code. Put a copy of it in the repo as `docs/HANDOFF.md`, and create a short `CLAUDE.md` that points to it and lists the commands from "Dev commands" once they exist.

## 1. What we are building

**PowAir** is a web app for browsing Polish air quality data from GIOŚ (Główny Inspektorat Ochrony Środowiska): stations, current readings, historical charts, and personal threshold alerts.

It is a university project for two courses: databases in web/mobile apps, and frontend in web/mobile apps. It should also look good in a portfolio. The developer works professionally with Python/AWS and wants this to show a different, solid stack.

**Scope is fixed to the 7 features in section 3. Do not add features. If something seems useful but is not in section 3, list it in `docs/ideas.md` and move on.**

## 2. Stack (decided)

| Layer | Choice |
|---|---|
| Frontend | React + TypeScript + Vite, React Router, TanStack Query, Recharts, Tailwind CSS |
| Backend | Java (current LTS, 21 or 25) + Spring Boot (current stable), Maven |
| Relational DB | PostgreSQL 16+, migrations with Flyway |
| Document DB | MongoDB, raw GIOŚ API responses only (see 5.3) |
| Auth | Spring Security, bcrypt, stateless JWT |
| Local env | Docker Compose: postgres, mongo, backend, frontend |
| Tests | JUnit 5 + Testcontainers (Postgres, Mongo) for backend; Vitest + Testing Library for key frontend components |

Check current stable versions before pinning them. Do not use Lombok-heavy magic or code generators beyond what Spring Initializr gives by default. Keep the code readable for a student project defense.

## 3. Definition of Done

### Features

**F1. Station browser (public)**
- Paginated station list, filter by city and voivodeship, search by name.
- Station page: address, coordinates, list of measured pollutants.
- Done when: filters combine, pagination works, and empty results show a message.

**F2. Current air quality at a station (public)**
- Latest value per pollutant with unit and timestamp.
- Shows data age ("3 h ago") and source label ("GIOŚ, unverified data").
- Done when: a missing value shows "no data" (never 0), and data older than 6 h is visibly marked stale.

**F3. Measurement history with chart (public)**
- Pick station, pollutant and date range; line chart and table.
- Done when: gaps render as breaks, not interpolated lines; the range is validated (max 1 year per request); it works for both archival and live data.

**F4. Registration and login**
- Register (email + password), log in, log out.
- Done when: passwords use bcrypt; failed login returns a generic message; private endpoints return 401 without a valid token.

**F5. Alert rules**
- CRUD + enable/disable. Rule = pollutant, operator (gt, gte, lt, lte), threshold, optional station.
- Done when: a user can only see and change their own rules (another user's rule returns 404), and the form validates input.

**F6. Notifications**
- After each live import, enabled rules are evaluated against newly inserted measurements.
- List, unread count, mark as read.
- Done when: at most one notification per rule per measurement, and archival imports never create notifications.

**F7. Data import**
- One-off archival import + hourly live import from GIOŚ.
- Raw GIOŚ responses are stored in MongoDB so data can be reprocessed without calling GIOŚ again.
- Done when: re-running any import creates no duplicates, missing values are never stored as 0, and a GIOŚ outage is logged and retried on the next cycle without crashing the app.

### Cross-cutting requirements
1. Schema documented in DBML (`docs/schema.dbml`) and applied only via Flyway migrations.
2. `docker compose up` starts the whole stack.
3. Frontend is responsive and usable at 375 px width.
4. Every view has loading, empty and error states.
5. GIOŚ is credited as the data source in the UI (required by GIOŚ terms).
6. README covers setup, data import, and known limitations.
7. Integration tests for import (dedup, missing values) and user data isolation.

### Out of scope
Forecasting/ML, computing our own AQI, interactive maps, email/SMS/push, native mobile app, data sources other than GIOŚ, admin roles/panel, password reset, OAuth login.

## 4. Data sources (verified 2026-10-25)

### 4.1 GIOŚ API v1
- Base: `https://api.gios.gov.pl/pjp-api/v1/rest/`. Swagger: `https://api.gios.gov.pl/pjp-api/swagger-ui/index.html`. No API key.
- The old `/pjp-api/rest/...` endpoints were retired on 2025-06-30. Use only `/v1/`.
- Format: **JSON-LD with Polish keys**, paginated (`page`, `size`; default 20, max 500; response has `totalPages`, `links`).
- All values in µg/m³, including CO.
- Endpoints we use:
  - `station/findAll`: station list.
  - `station/sensors/{stationId}`: sensors at a station. Item keys include `Identyfikator stanowiska`, `Identyfikator stacji`, `Wskaźnik`, `Wskaźnik - kod`, `Id wskaźnika`.
  - `data/getData/{sensorId}`: last ~3 days, **local time (Europe/Warsaw)**. List key `Lista danych pomiarowych`; items `Kod stanowiska`, `Data`, `Wartość` (can be null).
  - `archivalData/getDataBySensor/{sensorId}?dateFrom=&dateTo=`: max 366 days per request, **fixed UTC+01:00**. List key `Lista archiwalnych wyników pomiarów`.
- Rate limits: current data and index 1500 req/min; **archival data and metadata 2 req/min**.
- Manual (lab) sensors publish results 4–8 weeks late; sensor codes end in `-1g` (hourly) or `-24g` (daily).
- **Before writing the importer, call each endpoint once and save a sample response to `backend/src/test/resources/gios/`. Build DTOs from real responses, not from this description.** Exact key names for `station/findAll` were not verified.

### 4.2 Archival data (one-off import)
- **Plan A:** GIOŚ "Bank danych pomiarowych", yearly archives of measurement files for all stations (xlsx in zip, as far as we know). This was not verified; check whether it still exists on powietrze.gios.gov.pl and what format it uses. If it does, import 1–2 recent years for all stations.
- **Plan B:** the `archivalData/getDataBySensor` endpoint for a limited set of stations (suggest: Śląskie voivodeship, PM10/PM2.5/NO2 only). At 2 req/min and 500 rows per page, one sensor-year takes about 9 minutes, so run it as a resumable background job.
- Report back which plan works before building it.

### 4.3 Time zones
Store everything as `timestamptz`. Convert at import: `getData` uses Europe/Warsaw (DST-aware), archival API uses fixed +01:00. Write unit tests for both, including a DST transition hour.

## 5. Data model

### 5.1 PostgreSQL (DBML)

Key decisions:
- Stations and sensors are GIOŚ entities shared by both archival and live data, so provenance lives on `measurements.data_source_id`, not on stations.
- Archival files identify sensors by code (`SlKatoKossut-PM10-1g`); the API uses numeric ids. Store both.
- Missing values: no row. Never insert 0 for null.
- Dedup: `UNIQUE (sensor_id, measured_at)`. On conflict, archival (verified) data overwrites live (unverified) data, but live never overwrites archival.

```dbml
Project PowAir {
  database_type: 'PostgreSQL'
}

Enum source_type {
  archive   [note: 'One-off historical import. Never triggers alerts.']
  live_api  [note: 'Hourly GIOŚ import. Unverified data.']
}

Enum comparison_operator {
  gt
  gte
  lt
  lte
}

Table data_sources {
  id           integer [pk, increment]
  name         varchar(100) [not null, unique]
  source_type  source_type [not null]
  url          varchar(500)
  created_at   timestamptz [not null, default: `now()`]
}

Table stations {
  id           integer [pk, increment]
  external_id  integer [unique, note: 'GIOŚ numeric station id']
  code         varchar(50) [unique, note: 'GIOŚ station code, e.g. SlKatoKossut']
  name         varchar(200) [not null]
  city         varchar(100)
  voivodeship  varchar(100)
  street       varchar(200)
  latitude     numeric(9,6)
  longitude    numeric(9,6)
  is_active    boolean [not null, default: true]
}

Table pollutants {
  id    integer [pk, increment]
  code  varchar(20) [not null, unique, note: 'GIOŚ indicator code: PM10, PM2.5, NO2, SO2, O3, CO, C6H6']
  name  varchar(100) [not null]
  unit  varchar(20) [not null, default: 'µg/m3']
}

Table sensors {
  id            integer [pk, increment]
  station_id    integer [not null, ref: > stations.id]
  pollutant_id  integer [not null, ref: > pollutants.id]
  external_id   integer [unique, note: 'GIOŚ sensor id, used to fetch data']
  code          varchar(80) [unique, note: 'GIOŚ sensor code, e.g. SlKatoKossut-PM10-1g']
  averaging     varchar(10) [not null, default: '1g', note: '1g = hourly, 24g = daily']
}

Table measurements {
  id              bigint [pk, increment]
  sensor_id       integer [not null, ref: > sensors.id]
  data_source_id  integer [not null, ref: > data_sources.id]
  measured_at     timestamptz [not null]
  value           numeric(10,3) [not null]
  imported_at     timestamptz [not null, default: `now()`]
  Indexes {
    (sensor_id, measured_at) [unique]
  }
}

Table users {
  id             integer [pk, increment]
  email          varchar(255) [not null, unique]
  password_hash  varchar(255) [not null]
  created_at     timestamptz [not null, default: `now()`]
}

Table alert_rules {
  id            integer [pk, increment]
  user_id       integer [not null, ref: > users.id]
  pollutant_id  integer [not null, ref: > pollutants.id]
  station_id    integer [ref: > stations.id, note: 'null = any station']
  operator      comparison_operator [not null, default: 'gt']
  threshold     numeric(10,3) [not null]
  enabled       boolean [not null, default: true]
  created_at    timestamptz [not null, default: `now()`]
}

Table notifications {
  id              bigint [pk, increment]
  alert_rule_id   integer [not null, ref: > alert_rules.id]
  measurement_id  bigint [not null, ref: > measurements.id]
  message         varchar(500) [not null]
  is_read         boolean [not null, default: false]
  created_at      timestamptz [not null, default: `now()`]
  Indexes {
    (alert_rule_id, measurement_id) [unique]
  }
}
```

In the Flyway migration also add: `ON DELETE CASCADE` for sensors→stations, measurements→sensors, alert_rules→users, notifications→alert_rules and notifications→measurements; CHECK constraints on latitude/longitude ranges and on `averaging IN ('1g','24g')`; an index on `alert_rules(user_id)` and on `notifications` for the unread-count query.

### 5.2 Alert evaluation
Run it in the same transaction as the live import step that inserted the rows. Evaluate only rows actually **inserted** by that run (use `INSERT ... ON CONFLICT ... RETURNING`), only for `live_api` sources, and use `INSERT ... ON CONFLICT DO NOTHING` for notifications.

### 5.3 MongoDB (raw landing zone)
One collection, `gios_raw_responses`:
```
{ _id, endpoint, params, httpStatus, fetchedAt, importRunId, payload }
```
- Index `{ endpoint: 1, fetchedAt: -1 }`, plus a TTL index on `fetchedAt` (90 days).
- The importer first saves the raw response, then normalizes it into Postgres.
- Provide a "reprocess from raw" command that rebuilds measurements for a date range from Mongo without calling GIOŚ. This is the justification for Mongo; keep it this small.

## 6. Backend API (REST, JSON)

Public:
- `GET /api/stations?city=&voivodeship=&q=&page=&size=`
- `GET /api/stations/{id}`: includes sensors and pollutants
- `GET /api/stations/{id}/latest`: latest value per pollutant
- `GET /api/measurements?sensorId=&from=&to=`: max 366-day range
- `GET /api/pollutants`

Auth:
- `POST /api/auth/register`, `POST /api/auth/login`

Private (JWT):
- `GET/POST /api/alert-rules`, `PUT/PATCH/DELETE /api/alert-rules/{id}`
- `GET /api/notifications`, `GET /api/notifications/unread-count`, `PATCH /api/notifications/{id}/read`

Use DTOs, never return entities. Errors use one shape (RFC 7807 `ProblemDetail`). Validate with Bean Validation. Add OpenAPI docs via springdoc.

## 7. Repo layout
```
powair/
  backend/          Spring Boot app
  frontend/         Vite React app
  docs/             HANDOFF.md, schema.dbml, DoD.md, ideas.md
  docker-compose.yml
  README.md
  CLAUDE.md
```

## 8. Today's plan (session 1)

Stop after each step and show the result.

1. Create the repo layout, `.gitignore`, `docker-compose.yml` with postgres + mongo (with healthchecks and named volumes), and `.env.example`. No secrets in git.
2. Generate the Spring Boot project (web, validation, data-jpa, data-mongodb, security, flyway, postgres driver, actuator, testcontainers). Confirm it starts against compose.
3. Write `docs/schema.dbml` (section 5.1) and `V1__init.sql`. Run Flyway and confirm all tables exist.
4. Call the 4 GIOŚ endpoints once, save sample responses to test resources, and report the real JSON shapes and anything that differs from section 4.1.
5. Check whether Plan A from 4.2 works and report back.
6. Scaffold the Vite React app with routing and an empty layout (header, GIOŚ attribution footer). Add it to compose.

Do not start feature work (F1–F7) until steps 1–6 are done and confirmed.

## 9. Ground rules
- Small commits with clear messages; one feature per branch.
- No new dependencies or services without saying why.
- Never fabricate measurements. Seed data, if any, must be clearly labelled as test data and kept out of the real tables' source types.
- Ask before changing the schema after V1; every change goes in a new migration and `schema.dbml` is updated in the same commit.
