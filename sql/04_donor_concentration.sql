-- 04_donor_concentration.sql
-- How dependent is each party on a handful of donors?
-- Top-10 share: share of the party's private money from its 10 biggest donors.
-- HHI (Herfindahl-Hirschman Index): sum of squared donor shares x 10,000.
--   Under 1,500 = unconcentrated, 1,500-2,500 = moderate, over 2,500 = highly concentrated.
.headers on
.mode column

WITH donor_totals AS (
  SELECT recipient_group AS party, donor_key, max(donor_name) AS donor_name, sum(value_gbp) AS gbp
  FROM party_private GROUP BY recipient_group, donor_key
),
ranked AS (
  SELECT *, gbp / sum(gbp) OVER (PARTITION BY party) AS share,
         row_number() OVER (PARTITION BY party ORDER BY gbp DESC) AS rnk
  FROM donor_totals
)
SELECT party,
       count(*) AS donors,
       round(100 * max(CASE WHEN rnk = 1 THEN share END), 0) AS top1_pct,
       max(CASE WHEN rnk = 1 THEN donor_name END) AS top_donor,
       round(100 * sum(CASE WHEN rnk <= 10 THEN share END), 0) AS top10_pct,
       round(10000 * sum(share * share), 0) AS hhi
FROM ranked
WHERE party IN ('Conservative', 'Labour', 'Liberal Democrats', 'SNP', 'UKIP', 'Green')
GROUP BY party
ORDER BY top10_pct DESC;
