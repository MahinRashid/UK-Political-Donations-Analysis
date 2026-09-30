-- 02_funding_overview.sql
-- How much money is in the register, and how much of it is actually private donations to parties?
.headers on
.mode column

SELECT 'All records' AS slice, count(*) AS donations, round(sum(value_gbp) / 1e6, 1) AS gbp_m FROM donations
UNION ALL SELECT 'Public funds (e.g. Short Money)', count(*), round(sum(value_gbp) / 1e6, 1) FROM donations WHERE is_public_funds = 1
UNION ALL SELECT 'Returned / forfeited', count(*), round(sum(value_gbp) / 1e6, 1) FROM donations WHERE is_returned = 1
UNION ALL SELECT 'To non-party recipients', count(*), round(sum(value_gbp) / 1e6, 1) FROM donations WHERE recipient_type <> 'Political Party' AND is_public_funds = 0 AND is_returned = 0
UNION ALL SELECT 'Private donations to parties', count(*), round(sum(value_gbp) / 1e6, 1) FROM party_private;

-- Who gave the most once public money is removed and donor spellings are merged
SELECT donor_name, donor_status, round(sum(value_gbp) / 1e6, 1) AS gbp_m, count(*) AS donations
FROM party_private GROUP BY donor_key ORDER BY sum(value_gbp) DESC LIMIT 10;

-- A few large gifts carry most of the money
SELECT CASE WHEN value_gbp < 7500 THEN '1. Under £7.5k'
            WHEN value_gbp < 50000 THEN '2. £7.5k–50k'
            WHEN value_gbp < 100000 THEN '3. £50k–100k'
            WHEN value_gbp < 500000 THEN '4. £100k–500k'
            ELSE '5. £500k+' END AS gift_size,
       count(*) AS donations,
       round(100.0 * count(*) / (SELECT count(*) FROM party_private), 1) AS pct_of_donations,
       round(100.0 * sum(value_gbp) / (SELECT sum(value_gbp) FROM party_private), 1) AS pct_of_value
FROM party_private GROUP BY 1 ORDER BY 1;
