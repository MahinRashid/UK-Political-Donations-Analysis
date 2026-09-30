-- 03_party_funding_mix.sql
-- Where does each party's private money come from?
.headers on
.mode column

SELECT recipient_group AS party,
       round(sum(value_gbp) / 1e6, 1) AS gbp_m,
       count(DISTINCT donor_key) AS donors,
       round(100.0 * coalesce(sum(CASE WHEN donor_status = 'Individual' THEN value_gbp END), 0) / sum(value_gbp), 0) AS pct_individual,
       round(100.0 * coalesce(sum(CASE WHEN donor_status = 'Company' THEN value_gbp END), 0) / sum(value_gbp), 0) AS pct_company,
       round(100.0 * coalesce(sum(CASE WHEN donor_status = 'Trade Union' THEN value_gbp END), 0) / sum(value_gbp), 0) AS pct_trade_union,
       round(100.0 * coalesce(sum(CASE WHEN donor_status NOT IN ('Individual', 'Company', 'Trade Union') THEN value_gbp END), 0) / sum(value_gbp), 0) AS pct_other
FROM party_private
GROUP BY recipient_group
ORDER BY gbp_m DESC;

-- Trade-union share of Labour's private funding, by year
SELECT year,
       round(sum(value_gbp) / 1e6, 1) AS labour_gbp_m,
       round(100.0 * coalesce(sum(CASE WHEN donor_status = 'Trade Union' THEN value_gbp END), 0) / sum(value_gbp), 0) AS pct_trade_union
FROM party_private WHERE recipient_group = 'Labour' GROUP BY year ORDER BY year;
