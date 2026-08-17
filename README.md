# Global Market Expansion & Cost-of-Living Intelligence

A full-stack Business Analyst project: **SQL → Excel → Power BI → Tableau**, built on a
real, messy Kaggle dataset combining World Bank inflation data with a cost-of-living
index (217 countries).

## Business framing
*"Where should our company expand next / where should we set salary bands for remote
hires / which markets carry the highest economic risk?"*

This project answers that with a custom **Expansion Affordability Score**, regional and
income-tier cost comparisons, and an inflation-risk screen — the kind of decision-support
analysis a market-entry, People/Comp, or FP&A team would actually use.

## Dataset
- **Source:** Kaggle — inflation & cost-of-living mashup (World Bank inflation figures +
  Numbeo-style cost-of-living index), 217 countries, 20 columns
- **Reality check:** Only 45 countries have full cost-of-living detail; 179 have inflation
  figures; all 217 have region/income/geo reference data. That coverage gap is real and is
  handled explicitly (see Data Quality below), not hidden or faked.

## Repo structure
```
data/
  raw/        inflation_cost_of_living_dataset.csv       (as downloaded from Kaggle)
  clean/      market_analysis_clean.csv                  (SQL-cleaned, analysis-ready)
sql/
  01_schema_and_cleaning.sql   normalizes the flat file into dim_country / fact_inflation /
                                 fact_cost_of_living + builds the vw_market_analysis view
  02_analysis_queries.sql      11 business-question queries (rankings, regional comparisons,
                                 inflation risk, "best value" screen, etc.)
excel/
  Global_Cost_of_Living_Market_Expansion_Analysis.xlsx
                                Raw_Data, Clean_Data, Regional_Summary (live AVERAGEIFS
                                formulas + chart), Dashboard (KPIs + Top 10 ranking, all
                                formula-driven, zero hardcoded results)
tableau/
  market_analysis_clean.csv    data extract
  TABLEAU_BUILD_GUIDE.md       calculated fields + sheet-by-sheet + dashboard layout
powerbi/
  market_analysis_clean.csv    data extract
  POWERBI_BUILD_GUIDE.md       DAX measures + visual-by-visual + dashboard layout
docs/
  DATA_DICTIONARY.md
  BUSINESS_QUESTIONS.md
  INSIGHTS_SUMMARY.md
  query_results_raw.txt        raw output of every SQL query, for reference
```

## How the pipeline works
1. **SQL** (`sql/01_schema_and_cleaning.sql`, run via SQLite): loads the raw CSV, splits it
   into a proper 3-table relational model (`dim_country`, `fact_inflation`,
   `fact_cost_of_living`), fixes whitespace/casing issues, and builds an analysis view with
   a `data_completeness` flag and a custom scoring formula.
2. **`sql/02_analysis_queries.sql`** answers 11 concrete business questions against that view.
3. The cleaned view is exported to `data/clean/market_analysis_clean.csv` — this single file
   feeds Excel, Power BI, and Tableau, so all four tools are working from the same
   single source of truth.
4. **Excel** rebuilds the key summaries with live formulas (not pasted values) so the
   workbook recalculates if the source data changes.
5. **Tableau** and **Power BI** guides give exact calculated fields/DAX and dashboard
   layouts to reproduce the same analysis visually — build these locally with the provided
   CSV extract, since these are binary desktop-app files this environment can't generate.

## Data quality & limitations (worth stating up front)
- Only 43 countries (19.8%) have complete cost-of-living data — this is a genuine coverage
  gap in the source, called out via the `data_completeness` column rather than papered over.
- The `country_code_x` column in the raw file is 100% null (a dead artifact from however the
  source merged two datasets) — dropped during cleaning.
- No missing cost/price values were imputed — a missing rent figure stays missing rather than
  being fabricated with a regional average, since presenting invented prices as real data
  would undermine the analysis' credibility.
- The **Expansion Affordability Score** is an analyst-defined weighted formula (35% cost
  index, 35% purchasing power, 15% rent, 15% inflation stability) — a documented judgment
  call, not a market-standard metric. It also has a known blind spot: it doesn't account for
  political stability, safety, or infrastructure, so a very cheap, low-inflation country can
  score deceptively high (Afghanistan appears in the top 5 for exactly this reason) —
  a good real-world example of why a single score should never be read without its inputs.

## Tools used
SQL (SQLite) · Excel (openpyxl, live formulas) · Power BI (DAX) · Tableau (calculated fields)
