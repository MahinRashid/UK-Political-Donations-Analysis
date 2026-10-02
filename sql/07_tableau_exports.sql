-- 07_tableau_exports.sql
-- Small, tidy tables for the Tableau Public dashboard (tableau/data/).
.headers on
.mode csv

.output tableau/data/donations.csv
-- One file for the whole dashboard (works in Tableau Public's browser editor, which handles a single source best).
-- Fields that would otherwise need Tableau formulas are calculated here.
WITH donor_party AS (
  SELECT recipient_group, donor_key,
         row_number() OVER (PARTITION BY recipient_group ORDER BY sum(value_gbp) DESC) AS donor_rank_in_party
  FROM party_private GROUP BY recipient_group, donor_key
)
SELECT d.ec_ref, d.donation_date, d.year, d.quarter,
       CASE WHEN d.quarter = 'NaT' THEN NULL
            ELSE substr(d.quarter, 1, 4) || '-' || printf('%02d', (CAST(substr(d.quarter, 6, 1) AS INTEGER) - 1) * 3 + 1) || '-01' END AS quarter_start,
       CASE WHEN d.quarter IN ('2001Q2', '2005Q2', '2010Q2', '2015Q2', '2017Q2') THEN 1 ELSE 0 END AS is_election_quarter,
       d.recipient, d.recipient_type, d.recipient_group,
       d.donor_name, d.donor_status,
       CASE WHEN d.donor_status IN ('Individual', 'Company', 'Trade Union') THEN d.donor_status ELSE 'Other' END AS donor_type,
       d.donation_type, d.value_gbp,
       CASE WHEN d.recipient_type = 'Political Party' AND d.is_public_funds = 0 AND d.is_returned = 0 THEN 1 ELSE 0 END AS is_private_party,
       dp.donor_rank_in_party,
       CASE WHEN d.value_gbp < 7500 THEN '1. Under £7.5k' WHEN d.value_gbp < 50000 THEN '2. £7.5k–50k'
            WHEN d.value_gbp < 100000 THEN '3. £50k–100k' WHEN d.value_gbp < 500000 THEN '4. £100k–500k'
            ELSE '5. £500k+' END AS gift_size,
       CASE WHEN d.is_public_funds = 1 THEN 'Public money (Short Money etc.)'
            WHEN d.is_returned = 1 THEN 'Returned or forfeited'
            WHEN d.recipient_type = 'Political Party' THEN 'Private donations to parties'
            ELSE 'Campaigns, MPs and other recipients' END AS money_bucket,
       d.is_public_funds, d.is_returned, d.report_lag_days, d.lag_status,
       CASE WHEN d.lag_status IN ('4-12 months', 'Over a year') THEN 1 ELSE 0 END AS is_late,
       d.register
FROM donations d
LEFT JOIN donor_party dp
  ON d.recipient_type = 'Political Party' AND d.is_public_funds = 0 AND d.is_returned = 0
 AND dp.recipient_group = d.recipient_group AND dp.donor_key = d.donor_key;

.output tableau/data/party_donor_totals.csv
WITH t AS (
  SELECT recipient_group AS party, donor_key, max(donor_name) AS donor_name, max(donor_status) AS donor_status,
         sum(value_gbp) AS gbp, count(*) AS donations
  FROM party_private GROUP BY recipient_group, donor_key
)
SELECT party, donor_name, donor_status, round(gbp, 2) AS gbp, donations,
       round(gbp / sum(gbp) OVER (PARTITION BY party), 6) AS share_of_party,
       row_number() OVER (PARTITION BY party ORDER BY gbp DESC) AS donor_rank
FROM t;

.output tableau/data/quarterly_party_funding.csv
SELECT quarter, substr(quarter, 1, 4) AS year, recipient_group AS party,
       round(sum(value_gbp), 2) AS gbp, count(*) AS donations,
       CASE WHEN quarter IN ('2001Q2', '2005Q2', '2010Q2', '2015Q2', '2017Q2') THEN 1 ELSE 0 END AS is_election_quarter
FROM party_private WHERE quarter <> 'NaT' GROUP BY quarter, recipient_group;
.output stdout
