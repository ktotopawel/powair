# GIOŚ data sources

Verified by calling the API and reading the 2025 archive on 2026-10-25. Sample responses are in
`backend/src/test/resources/gios/`. Where GIOŚ documentation and real data disagree, this file follows the data.

## Sources

| Source | Used for | Notes |
|---|---|---|
| API v1, `https://api.gios.gov.pl/pjp-api/v1/rest/` | stations, sensors, hourly live import | No key. Swagger: `https://api.gios.gov.pl/pjp-api/swagger-ui/index.html` |
| Yearly zip archives, `https://powietrze.gios.gov.pl/pjp/archives` | one-off archival import | "Wyniki pomiarów z XXXX roku", 2000–2025 available. ~50 MB per year |
| Metadata xlsx (same page) | sensor code → averaging, measurement type | `Metadane oraz kody stacji i stanowisk pomiarowych.xlsx`, ~0.5 MB |

Download ids on the archive page (`/pjp/archives/downloadFile/{id}`): 2024 = 582, 2025 = 644, metadata = 643. Ids change when GIOŚ republishes files; read them from the page.

## API v1

### Response envelope
Every response is JSON-LD with Polish keys:
```
{ "@context": ..., "<list key>": [...], "meta": ..., "links": {...}, "totalPages": n }
```
- `@context` appears twice in the same object. Jackson keeps the last one by default; we ignore it anyway.
- Pagination: `page` (0-based), `size` (default 20, max 500). Use `totalPages` to decide whether to fetch the next page; `links.next` is present even on the last page.

### Endpoints

**`station/findAll`**, list key `Lista stacji pomiarowych` (287 active stations, one page at `size=500`):
```json
{ "Identyfikator stacji": 814, "Kod stacji": "SlKatoKossut", "Nazwa stacji": "Katowice, ul. Kossutha",
  "WGS84 φ N": "50.264611", "WGS84 λ E": "18.975028", "Identyfikator miasta": 350,
  "Nazwa miasta": "Katowice", "Gmina": "Katowice", "Powiat": "Katowice",
  "Województwo": "ŚLĄSKIE", "Ulica": "ul. Kossutha 6" }
```
Coordinates are strings. `Ulica` is null for some stations.

**`station/sensors/{stationId}`**, list key `Lista stanowisk pomiarowych dla podanej stacji`:
```json
{ "Identyfikator stanowiska": 5376, "Identyfikator stacji": 814, "Wskaźnik": "pył zawieszony PM10",
  "Wskaźnik - wzór": "PM10", "Wskaźnik - kod": "PM10", "Id wskaźnika": 3 }
```
No sensor code and no averaging. A station can have two sensors for the same indicator (automatic hourly and manual daily), indistinguishable here.

**`data/getData/{sensorId}`**, list key `Lista danych pomiarowych`, last ~3 days, newest first:
```json
{ "Kod stanowiska": "SlKatoKossut-PM10-1g", "Data": "2026-10-25 14:00:00", "Wartość": 6.7 }
```
`Wartość` can be null. For manual sensors it returns HTTP 400 with `"error_code": "API-ERR-100003"` (manual results are published 4–8 weeks late, via archival endpoints only). Treat this as "skip", not as an outage.

**`archivalData/getDataBySensor/{sensorId}?dateFrom=YYYY-MM-DD HH:mm&dateTo=...`**, list key `Lista archiwalnych wyników pomiarów`, max 366 days:
```json
{ "Nazwa stacji": "Katowice, ul. Kossutha", "Kod stanowiska": "SlKatoKossut-PM10-1g",
  "Data": "2026-03-28 00:00:00", "Wartość": 10.6 }
```
Also returns recent, still unverified data, not only verified history.

**`archivalData/getDataForAllStationsByYearAndVoivodeship?year=&voivodeship=&pollution=`** exists but is unusable: one page of 500 rows took 7 minutes, and PM10 for Śląskie 2025 is 361 pages.

### Limits
- Current data: 1500 requests/min. Archival data and metadata (`station/*`): 2 requests/min.
- Archival responses are slow (10 s for a few rows, minutes for large pages).

## Zip archive

- One zip per year with one xlsx per indicator and averaging, e.g. `2025_PM10_1g.xlsx`, `2025_BaP(PM10)_24g.xlsx`. One sheet each.
- Wide layout: six header rows, then one row per hour (or day), one column per sensor.
  ```
  Nr               | 1                       | 2                    | ...
  Kod stacji       | DsChojnowMalMOB         | DsCzerStraza         |
  Wskaźnik         | PM10                    | PM10                 |
  Czas uśredniania | 1g                      | 1g                   |
  Jednostka        | ug/m3                   | ug/m3                |
  Kod stanowiska   | DsChojnowMalMOB-PM10-1g | DsCzerStraza-PM10-1g |
  45658.0416666666 | 220.7                   | 8.8000000000000007   |
  ```
- Column A is an Excel serial date in CET. It drifts by up to ~45 s by the end of the year (`45658.125000057873`), so round to the nearest hour, not minute.
- Hourly files run from `YYYY-01-01 01:00` to `YYYY+1-01-01 00:00`, 8760 rows: the label is the end of the averaging hour.
- An empty cell means no measurement.
- Indicator codes match the API (`PM2.5`, `BaP(PM10)`); only file names differ (`PM25`).
- Files with a different layout, not imported: `Depozycja_1m` (deposition, µg/m²/day), `Jony_PM25_24g` (PM2.5 composition), `PrekursoryZielonka_1g` (29 ozone precursors from one research station).
- The archive contains stations that are not in the API (mobile `...MOB` and closed stations). They get a `code` but no `external_id`.

## Metadata xlsx

- Sheet `STACJE`: 1148 stations including closed ones (code, international code, old code, start/end dates, type, voivodeship, address, coordinates).
- Sheet `STANOWISKA`: 5849 sensors: `Kod stanowiska`, `Kod stacji`, `Wskaźnik - kod`, `Czas uśredniania` (`1-godzinny`/`24-godzinny`), `Typ pomiaru` (`automatyczny`/`manualny`), start/end dates.
- No API numeric ids.

## Time zones

**All GIOŚ timestamps are fixed CET (UTC+01:00) all year: API (`getData` and archival) and zip.**

Evidence: API and zip values for the same sensor match row for row across both 2025 DST nights, and `getData` has no duplicated or missing hour on 2026-10-25.

One GIOŚ formatting bug: on the spring DST day the CET `02:00` row is labelled `03:00`, so `03:00` appears twice and `02:00` is missing (2025-03-30: `03:00` = 53.2 and `03:00` = 59.2, which the zip has as `02:00` and `03:00`). The autumn DST day is clean.

## Units

The API documentation says all values are in µg/m³, including CO. Real data disagrees for at least BaP: API and zip both return 3.09 for `SlKatoKossut-BaP(PM10)-24g` on 2025-01-13, which is ng/m³.

| Unit in zip | Indicators |
|---|---|
| µg/m³ | PM10, PM2.5, NO, NO2, NOx, SO2, O3, C6H6, Pb(PM10), formaldehyd |
| ng/m³ | As, Cd, Ni (in PM10), BaP, BaA, BbF, BjF, BkF, DBahA, IP (in PM10), Hg(TGM) |
| mg/m³ | CO |

CO in the API is unverified: the stations with CO in the 2025 zip that were checked (Legnica, Wałbrzych) have no CO sensor in the API anymore.

## Sensor identification

API sensors have numeric ids but no code; archive and metadata have codes but no ids. Linking:
1. `getData` returns `Kod stanowiska` for automatic sensors: store it as `sensors.code`, averaging from the suffix.
2. `API-ERR-100003` marks a manual sensor: if the metadata has exactly one `-24g` code for that station and indicator, use it.
3. Otherwise `code` and `averaging` stay NULL until known.

## Decisions

| # | Topic | Decision | Status |
|---|---|---|---|
| 1 | Archival source | Yearly zip (2024–2025), not the archival API | decided |
| 2 | Units | Store values in the API's units, one unit per pollutant in `pollutants.unit`. Only CO differs from the zip: convert mg/m³ → µg/m³ (×1000) at import | decided; CO unit in API to verify with the first real CO reading |
| 3 | Unknown sensor code/averaging | `sensors.code` and `sensors.averaging` nullable, filled when known (see Sensor identification) | decided; applied in V1 |
| 4 | Indicators | All indicators, not only the original 7. Skip the three special files (deposition, ions, precursors) | decided |
| 5 | MongoDB | Raw API responses only. Zip files are not stored in Mongo; reprocessing the archive means re-importing the file | decided |
| 6 | Time zones | Parse every GIOŚ timestamp as fixed UTC+01:00. If an API response has two rows with the same label, drop both and log it; the next yearly zip fills the gap (archive overwrites live) | decided |
