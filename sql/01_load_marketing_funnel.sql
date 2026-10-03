-- 01_load_marketing_funnel.sql  (DuckDB)
-- Loads the two Marketing Funnel files and builds one analysis view.
-- Run from the project root so the relative data/ paths resolve.

CREATE OR REPLACE TABLE mql AS
SELECT * FROM read_csv_auto('data/olist_marketing_qualified_leads_dataset.csv');

CREATE OR REPLACE TABLE closed_deals AS
SELECT * FROM read_csv_auto('data/olist_closed_deals_dataset.csv');

-- One row per lead; won = 1 if the lead appears in closed_deals.
CREATE OR REPLACE VIEW funnel AS
SELECT
    m.mql_id,
    m.first_contact_date,
    m.landing_page_id,
    COALESCE(m.origin, 'missing')                          AS origin,   -- NULL kept distinct from 'unknown'
    (d.mql_id IS NOT NULL)::INT                            AS won,
    d.won_date,
    date_diff('day', m.first_contact_date, d.won_date::DATE) AS days_to_close,
    d.seller_id, d.business_segment, d.lead_type,
    d.lead_behaviour_profile, d.business_type
FROM mql m
LEFT JOIN closed_deals d USING (mql_id);
