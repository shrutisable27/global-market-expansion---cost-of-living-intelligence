/* =========================================================================
   02_analysis_queries.sql
   Project : Global Market Expansion & Cost-of-Living Intelligence
   Purpose : Business-question-driven SQL queries, run against the cleaned
             tables / vw_market_analysis view from 01_schema_and_cleaning.sql
   ========================================================================= */

-- Q1. Data coverage audit — how complete is our data, by category?
SELECT
    data_completeness,
    COUNT(*) AS country_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM vw_market_analysis), 1) AS pct_of_total
FROM vw_market_analysis
GROUP BY data_completeness
ORDER BY country_count DESC;


-- Q2. Top 10 most affordable countries for expansion (full data only),
--     using the custom Expansion Affordability Score.
SELECT
    country, region, income_level,
    cost_living_index, purchasing_power_index, inflation_annual_pct,
    expansion_affordability_score
FROM vw_market_analysis
WHERE data_completeness = 'Full data'
ORDER BY expansion_affordability_score DESC
LIMIT 10;


-- Q3. Top 10 most expensive countries by cost-of-living index.
SELECT country, region, income_level, cost_living_index, rent_monthly_usd
FROM vw_market_analysis
WHERE cost_living_index IS NOT NULL
ORDER BY cost_living_index DESC
LIMIT 10;


-- Q4. Average cost-of-living index and rent by region (only regions with
--     at least 2 countries reporting, to avoid noisy single-country averages).
SELECT
    region,
    COUNT(*) AS countries_reporting,
    ROUND(AVG(cost_living_index), 1) AS avg_cost_living_index,
    ROUND(AVG(rent_monthly_usd), 0)  AS avg_rent_usd,
    ROUND(AVG(purchasing_power_index), 1) AS avg_purchasing_power
FROM vw_market_analysis
WHERE cost_living_index IS NOT NULL
GROUP BY region
HAVING COUNT(*) >= 2
ORDER BY avg_cost_living_index DESC;


-- Q5. Cost-of-living index vs. income-level classification — does the
--     World Bank income tier actually track cost of living?
SELECT
    income_level,
    COUNT(*) AS countries,
    ROUND(AVG(cost_living_index), 1) AS avg_cost_living_index,
    ROUND(MIN(cost_living_index), 1) AS min_cost_living_index,
    ROUND(MAX(cost_living_index), 1) AS max_cost_living_index
FROM vw_market_analysis
WHERE cost_living_index IS NOT NULL
GROUP BY income_level
ORDER BY avg_cost_living_index DESC;


-- Q6. Inflation risk leaderboard — highest annual inflation (economic
--     instability risk for any expansion decision), all 179 countries
--     with reported inflation, not just the 45 with full cost data.
SELECT country, region, income_level, inflation_annual_pct
FROM vw_market_analysis
WHERE inflation_annual_pct IS NOT NULL
ORDER BY inflation_annual_pct DESC
LIMIT 15;


-- Q7. Lowest / most stable inflation countries (deflation flagged separately).
SELECT country, region, income_level, inflation_annual_pct,
       CASE WHEN inflation_annual_pct < 0 THEN 'Deflation' ELSE 'Low inflation' END AS flag
FROM vw_market_analysis
WHERE inflation_annual_pct IS NOT NULL
ORDER BY inflation_annual_pct ASC
LIMIT 15;


-- Q8. "Best value" screen: countries with LOW cost-of-living index but
--     HIGH purchasing power — the ideal expansion/remote-hiring targets.
--     (Both dimensions matter: cheap-but-poor-purchasing-power markets are
--     a different story than cheap-and-strong markets.)
SELECT
    country, region, income_level,
    cost_living_index, purchasing_power_index,
    ROUND(purchasing_power_index - cost_living_index, 1) AS value_gap
FROM vw_market_analysis
WHERE cost_living_index IS NOT NULL AND purchasing_power_index IS NOT NULL
ORDER BY value_gap DESC
LIMIT 10;


-- Q9. Rent burden — monthly rent as a share of a assumed reference budget,
--     ranked cheapest to most expensive (useful for a remote-hiring /
--     relocation-stipend business case).
SELECT
    country, region, rent_monthly_usd, rent_index,
    RANK() OVER (ORDER BY rent_monthly_usd ASC) AS rent_rank_cheapest
FROM vw_market_analysis
WHERE rent_monthly_usd IS NOT NULL
ORDER BY rent_monthly_usd ASC;


-- Q10. Correlation sanity check via bucket comparison: does higher inflation
--      associate with a higher or lower cost-of-living index in this dataset?
--      (Simple bucketed comparison — SQLite has no native CORR() function.)
SELECT
    CASE
        WHEN inflation_annual_pct < 2  THEN '1) Under 2%'
        WHEN inflation_annual_pct < 5  THEN '2) 2-5%'
        WHEN inflation_annual_pct < 10 THEN '3) 5-10%'
        ELSE '4) 10%+'
    END AS inflation_bucket,
    COUNT(*) AS countries,
    ROUND(AVG(cost_living_index), 1) AS avg_cost_living_index
FROM vw_market_analysis
WHERE inflation_annual_pct IS NOT NULL AND cost_living_index IS NOT NULL
GROUP BY inflation_bucket
ORDER BY inflation_bucket;


-- Q11. Full ranked shortlist for a hypothetical "open our next office"
--      decision: mid/high purchasing power, low-to-moderate cost, stable
--      inflation under 6%.
SELECT
    country, region, income_level,
    cost_living_index, purchasing_power_index, inflation_annual_pct,
    expansion_affordability_score
FROM vw_market_analysis
WHERE data_completeness = 'Full data'
  AND purchasing_power_index >= 50
  AND inflation_annual_pct < 6
ORDER BY expansion_affordability_score DESC;
