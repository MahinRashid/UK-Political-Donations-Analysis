-- 01_load.sql
-- Loads the cleaned donations (from python/01_clean.py) into SQLite.
DROP TABLE IF EXISTS donations;
CREATE TABLE donations (
  ec_ref TEXT PRIMARY KEY, donation_date TEXT, year INTEGER, quarter TEXT,
  reported_date TEXT, report_lag_days INTEGER, lag_status TEXT,
  recipient TEXT, recipient_type TEXT, recipient_group TEXT, donee_type TEXT,
  donor_name TEXT, donor_key TEXT, donor_status TEXT, donation_type TEXT,
  nature_of_donation TEXT, value_gbp REAL, is_public_funds INTEGER, is_returned INTEGER,
  donation_action TEXT, is_aggregation INTEGER, is_bequest INTEGER, is_sponsorship INTEGER,
  register TEXT
);
.mode csv
.import --skip 1 data/clean/donations_clean.csv donations
.mode list
UPDATE donations SET report_lag_days = NULL WHERE report_lag_days = '';
UPDATE donations SET year = NULL WHERE year = '';

-- Private money accepted by political parties: the base for most of the analysis
DROP VIEW IF EXISTS party_private;
CREATE VIEW party_private AS
SELECT * FROM donations
WHERE recipient_type = 'Political Party' AND is_public_funds = 0 AND is_returned = 0;

CREATE INDEX ix_group ON donations(recipient_group);
CREATE INDEX ix_donor ON donations(donor_key);
