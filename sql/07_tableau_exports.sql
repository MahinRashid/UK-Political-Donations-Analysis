-- 07_tableau_exports.sql
-- Small, tidy tables for the Tableau Public dashboard (tableau/data/).
.headers on
.mode csv

.output tableau/data/donations.csv
SELECT ec_ref, donation_date, year, quarter, recipient, recipient_type, recipient_group,
       donor_name, donor_status, donation_type, value_gbp, is_public_funds, is_returned,
       report_lag_days, lag_status, register
FROM donations;

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
