-- 05_election_cycle.sql
-- Does money follow elections? General elections in the data: 2001, 2005, 2010, 2015, 2017 (all in Q2).
.headers on
.mode column

WITH q AS (
  SELECT quarter, sum(value_gbp) AS gbp FROM party_private WHERE quarter <> 'NaT' GROUP BY quarter
)
SELECT CASE WHEN quarter IN ('2001Q2', '2005Q2', '2010Q2', '2015Q2', '2017Q2') THEN 'General-election quarter'
            WHEN quarter IN ('2001Q1', '2005Q1', '2010Q1', '2015Q1', '2017Q1') THEN 'Quarter before an election'
            ELSE 'Other quarters' END AS period,
       count(*) AS quarters,
       round(avg(gbp) / 1e6, 1) AS avg_gbp_m_per_quarter
FROM q GROUP BY 1 ORDER BY 3 DESC;

-- The biggest quarters on record
SELECT quarter, round(sum(value_gbp) / 1e6, 1) AS gbp_m
FROM party_private GROUP BY quarter ORDER BY sum(value_gbp) DESC LIMIT 8;

-- The 2016 EU referendum: money to registered campaign groups ('permitted participants')
SELECT recipient, round(sum(value_gbp) / 1e6, 1) AS gbp_m
FROM donations WHERE recipient_type = 'Permitted Participant' AND year = 2016 AND is_returned = 0
GROUP BY recipient ORDER BY gbp_m DESC LIMIT 5;
