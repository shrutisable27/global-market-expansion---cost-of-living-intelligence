/* =========================================================================
   01_schema_and_cleaning.sql
   Project : Global Market Expansion & Cost-of-Living Intelligence
   Source  : inflation_cost_of_living_dataset.csv (Kaggle, World Bank +
             cost-of-living index mashup — 217 countries)
   Engine  : SQLite (syntax notes for MySQL/Postgres in comments)
   Purpose : Load the raw flat file, then NORMALIZE it into three related
             tables (this file arrives as one wide CSV; splitting it is a
             deliberate modeling choice so the SQL analysis demonstrates
             real joins instead of just querying one flat table).
   ========================================================================= */

DROP TABLE IF EXISTS raw_import;
CREATE TABLE raw_import (
    country                     TEXT,
    country_code_x               TEXT,   -- dead column in source file: 100% NULL, dropped downstream
    region                        TEXT,
    income_level                  TEXT,
    capital_city                   TEXT,
    latitude                        REAL,
    longitude                        REAL,
    country_code_y                    TEXT,   -- the real ISO-3 code
    inflation_year                     REAL,
    inflation_annual_pct                REAL,
    cost_living_index                    REAL,
    rent_index                            REAL,
    groceries_index                        REAL,
    restaurants_index                       REAL,
    purchasing_power_index                   REAL,
    bread_price_usd                           REAL,
    transport_oneway_usd                       REAL,
    transport_monthly_pass_usd                  REAL,
    rent_monthly_usd                             REAL,
    utilities_monthly_usd                         REAL
);
-- populated by load_and_run.py via pandas .to_sql()

/* -------------------------------------------------------------------------
   1) DIM_COUNTRY  — one row per country, the master/reference table.
      Cleaning: trim whitespace in region names (source has trailing
      spaces e.g. "Sub-Saharan Africa " ), standardize country_code.
   ------------------------------------------------------------------------- */
DROP TABLE IF EXISTS dim_country;
CREATE TABLE dim_country AS
SELECT DISTINCT
    country,
    TRIM(region)              AS region,
    income_level,
    capital_city,
    latitude,
    longitude,
    NULLIF(TRIM(country_code_y), '') AS country_code
FROM raw_import;

/* -------------------------------------------------------------------------
   2) FACT_INFLATION — one row per country with a reported inflation figure.
      179 of 217 countries have this; rows with NULL inflation are dropped
      here (they carry no information) rather than imputed — inflation is
      too volatile/country-specific to safely fill with an average.
   ------------------------------------------------------------------------- */
DROP TABLE IF EXISTS fact_inflation;
CREATE TABLE fact_inflation AS
SELECT
    country,
    NULLIF(TRIM(country_code_y), '')  AS country_code,
    CAST(inflation_year AS INTEGER)   AS inflation_year,
    ROUND(inflation_annual_pct, 2)    AS inflation_annual_pct
FROM raw_import
WHERE inflation_annual_pct IS NOT NULL;

/* -------------------------------------------------------------------------
   3) FACT_COST_OF_LIVING — one row per country with cost-of-living data.
      Only 45 of 217 countries carry this (Numbeo-style index coverage is
      sparse for smaller economies). Kept as its own fact table rather than
      imputing fabricated price data into the other 172 countries — a
      documented scope limitation, not a defect.
   ------------------------------------------------------------------------- */
DROP TABLE IF EXISTS fact_cost_of_living;
CREATE TABLE fact_cost_of_living AS
SELECT
    country,
    NULLIF(TRIM(country_code_y), '')  AS country_code,
    cost_living_index,
    rent_index,
    groceries_index,
    restaurants_index,
    purchasing_power_index,
    bread_price_usd,
    transport_oneway_usd,
    transport_monthly_pass_usd,
    rent_monthly_usd,
    utilities_monthly_usd
FROM raw_import
WHERE cost_living_index IS NOT NULL;

CREATE INDEX idx_country_region ON dim_country(region);
CREATE INDEX idx_inflation_country ON fact_inflation(country);
CREATE INDEX idx_col_country ON fact_cost_of_living(country);

/* -------------------------------------------------------------------------
   4) VW_MARKET_ANALYSIS — the analysis-ready view joining all three.
      This is the table Excel / Power BI / Tableau will connect to.
      A data_completeness flag makes the coverage gap visible to any
      dashboard user instead of hiding it.
   ------------------------------------------------------------------------- */
DROP VIEW IF EXISTS vw_market_analysis;
CREATE VIEW vw_market_analysis AS
SELECT
    c.country,
    c.region,
    c.income_level,
    c.capital_city,
    c.latitude,
    c.longitude,
    i.inflation_year,
    i.inflation_annual_pct,
    col.cost_living_index,
    col.rent_index,
    col.groceries_index,
    col.restaurants_index,
    col.purchasing_power_index,
    col.bread_price_usd,
    col.transport_oneway_usd,
    col.transport_monthly_pass_usd,
    col.rent_monthly_usd,
    col.utilities_monthly_usd,
    CASE
        WHEN col.cost_living_index IS NOT NULL AND i.inflation_annual_pct IS NOT NULL THEN 'Full data'
        WHEN i.inflation_annual_pct IS NOT NULL THEN 'Inflation only'
        WHEN col.cost_living_index IS NOT NULL THEN 'Cost data only'
        ELSE 'Reference only'
    END AS data_completeness,
    -- Custom "Expansion Affordability Score" (0-100, higher = more attractive
    -- for cost-sensitive expansion): rewards low cost-of-living & rent,
    -- high purchasing power, and low/stable inflation. Weights are a
    -- documented analyst judgment call, not derived from the source data.
    ROUND(
        (100 - COALESCE(col.cost_living_index, 50)) * 0.35 +
        COALESCE(col.purchasing_power_index, 50) * 0.35 +
        (100 - COALESCE(col.rent_index, 50)) * 0.15 +
        (100 - (CASE WHEN COALESCE(i.inflation_annual_pct, 10) < 50
                      THEN COALESCE(i.inflation_annual_pct, 10)
                      ELSE 50 END) * 2) * 0.15
    , 1) AS expansion_affordability_score
FROM dim_country c
LEFT JOIN fact_inflation i ON c.country = i.country
LEFT JOIN fact_cost_of_living col ON c.country = col.country;
