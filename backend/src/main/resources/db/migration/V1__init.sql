CREATE TYPE source_type AS ENUM ('archive', 'live_api');

CREATE TYPE comparison_operator AS ENUM ('gt', 'gte', 'lt', 'lte');

CREATE TYPE averaging_period AS ENUM ('1g', '24g');

CREATE TABLE data_sources (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        varchar(100) NOT NULL UNIQUE,
    source_type source_type  NOT NULL,
    url         varchar(500),
    created_at  timestamptz  NOT NULL DEFAULT now()
);

CREATE TABLE stations (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    external_id integer UNIQUE,
    code        varchar(50) UNIQUE,
    name        varchar(200) NOT NULL,
    city        varchar(100),
    voivodeship varchar(100),
    street      varchar(200),
    latitude    numeric(9, 6) CHECK (latitude BETWEEN -90 AND 90),
    longitude   numeric(9, 6) CHECK (longitude BETWEEN -180 AND 180),
    is_active   boolean NOT NULL DEFAULT true
);

CREATE TABLE pollutants (
    id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(20)  NOT NULL UNIQUE,
    name varchar(100) NOT NULL,
    unit varchar(20)  NOT NULL DEFAULT 'µg/m3'
);

CREATE TABLE sensors (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_id   integer NOT NULL REFERENCES stations (id) ON DELETE CASCADE,
    pollutant_id integer NOT NULL REFERENCES pollutants (id),
    external_id  integer UNIQUE,
    code         varchar(80) UNIQUE,
    averaging    averaging_period
);

CREATE INDEX idx_sensors_station_id ON sensors (station_id);

CREATE TABLE measurements (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sensor_id      integer       NOT NULL REFERENCES sensors (id) ON DELETE CASCADE,
    data_source_id integer       NOT NULL REFERENCES data_sources (id),
    measured_at    timestamptz   NOT NULL,
    value          numeric(10, 3) NOT NULL,
    imported_at    timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT uq_measurements_sensor_time UNIQUE (sensor_id, measured_at)
);

CREATE TABLE users (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email         varchar(255) NOT NULL,
    password_hash varchar(255) NOT NULL,
    created_at    timestamptz  NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_users_email_lower ON users (lower(email));

CREATE TABLE alert_rules (
    id           integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      integer NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    pollutant_id integer NOT NULL REFERENCES pollutants (id),
    station_id   integer REFERENCES stations (id) ON DELETE RESTRICT,
    operator     comparison_operator NOT NULL DEFAULT 'gt',
    threshold    numeric(10, 3) NOT NULL,
    enabled      boolean     NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_alert_rules_id_user UNIQUE (id, user_id)
);

CREATE INDEX idx_alert_rules_user_id ON alert_rules (user_id);

CREATE TABLE notifications (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alert_rule_id  integer      NOT NULL,
    user_id        integer      NOT NULL,
    measurement_id bigint       NOT NULL REFERENCES measurements (id) ON DELETE CASCADE,
    message        varchar(500) NOT NULL,
    is_read        boolean      NOT NULL DEFAULT false,
    created_at     timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT fk_notifications_rule_user FOREIGN KEY (alert_rule_id, user_id)
        REFERENCES alert_rules (id, user_id) ON DELETE CASCADE,
    CONSTRAINT uq_notifications_rule_measurement UNIQUE (alert_rule_id, measurement_id)
);

CREATE INDEX idx_notifications_user_unread ON notifications (user_id) WHERE is_read = false;

INSERT INTO data_sources (name, source_type, url) VALUES
    ('GIOŚ archival data', 'archive', 'https://powietrze.gios.gov.pl/'),
    ('GIOŚ API v1', 'live_api', 'https://api.gios.gov.pl/pjp-api/v1/rest/');
