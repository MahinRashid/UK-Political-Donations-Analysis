-- 06_reporting_compliance.sql
-- Is the reporting system working? Lag = days from donation to publication in the register.
-- Parties report quarterly, so ~120 days (one quarter plus the filing window) is the normal upper range.
.headers on
.mode column

SELECT lag_status, count(*) AS donations, round(100.0 * count(*) / (SELECT count(*) FROM donations), 1) AS pct,
       round(sum(value_gbp) / 1e6, 1) AS gbp_m
FROM donations GROUP BY lag_status ORDER BY donations DESC;

-- Late reports by recipient type
SELECT recipient_type, count(*) AS donations,
       sum(lag_status = 'Over a year') AS over_a_year,
       round(100.0 * sum(lag_status IN ('4-12 months', 'Over a year')) / count(*), 1) AS pct_over_4_months
FROM donations WHERE lag_status NOT IN ('Date error', 'Unknown') GROUP BY recipient_type ORDER BY pct_over_4_months DESC;

-- Donations reported more than a year late, by year of donation
-- (2018-2019 look low only because the data ends in Sep 2019)
SELECT year, count(*) AS over_a_year FROM donations WHERE lag_status = 'Over a year' GROUP BY year ORDER BY year;

-- Impermissible and unidentified donors: were they dealt with?
SELECT donation_type, count(*) AS donations, sum(is_returned) AS returned_or_forfeited,
       round(sum(value_gbp) / 1e3, 0) AS gbp_k
FROM donations WHERE donation_type IN ('Impermissible Donor', 'Unidentified Donor') GROUP BY donation_type;
