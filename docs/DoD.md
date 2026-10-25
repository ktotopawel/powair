# Definition of Done

The project is done when every box below is ticked. Nothing else gets built.
Anything that is not on this list goes to [ideas.md](ideas.md), not into code.

## Features

### F1. Station browser (public)
- [ ] Paginated station list
- [ ] Filter by city and voivodeship, search by name; filters combine
- [ ] Station page: address, coordinates, measured pollutants
- [ ] Empty results show a message

### F2. Current air quality at a station (public)
- [ ] Latest value per pollutant with unit and timestamp
- [ ] Data age ("3 h ago") and source label ("GIOŚ, unverified data")
- [ ] Missing value shows "no data", never 0
- [ ] Data older than 6 h is visibly marked stale

### F3. Measurement history with chart (public)
- [ ] Pick station, pollutant and date range; line chart and table
- [ ] Gaps render as breaks, not interpolated lines
- [ ] Range validated: max 1 year per request
- [ ] Works for both archival and live data

### F4. Registration and login
- [ ] Register (email + password), log in, log out
- [ ] Passwords hashed with bcrypt
- [ ] Failed login returns a generic message
- [ ] Private endpoints return 401 without a valid token

### F5. Alert rules
- [ ] Create, list, edit, delete, enable/disable
- [ ] Rule = pollutant, operator (gt, gte, lt, lte), threshold, optional station
- [ ] Another user's rule returns 404
- [ ] Form validates input

### F6. Notifications
- [ ] Enabled rules evaluated after each live import, against newly inserted measurements only
- [ ] List, unread count, mark as read
- [ ] At most one notification per rule per measurement
- [ ] Archival imports never create notifications

### F7. Data import
- [ ] One-off archival import
- [ ] Hourly live import from GIOŚ
- [ ] Raw GIOŚ responses stored in MongoDB; data can be reprocessed without calling GIOŚ
- [ ] Re-running any import creates no duplicates
- [ ] Missing values never stored as 0
- [ ] GIOŚ outage is logged and retried next cycle, app keeps running

## Cross-cutting
- [ ] Schema documented in `docs/schema.dbml`, applied only via Flyway migrations
- [ ] `docker compose up` starts the whole stack
- [ ] Mobile-first: every view designed for 375 px first, touch targets ≥ 44 px, no horizontal scroll
- [ ] Every view has loading, empty and error states
- [ ] GIOŚ credited as the data source in the UI
- [ ] README covers setup, data import and known limitations
- [ ] Integration tests: import (dedup, missing values) and user data isolation

## Out of scope
Forecasting/ML, computing our own AQI, interactive maps, email/SMS/push notifications,
native mobile app, PWA/offline mode, data sources other than GIOŚ, admin roles or panel,
password reset, OAuth login.
