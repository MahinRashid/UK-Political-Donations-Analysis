#!/bin/sh
# Rebuilds everything from the raw Excel file: clean data, SQL results, Tableau tables, charts.
set -e
cd "$(dirname "$0")"
PY=.venv/bin/python
$PY python/01_clean.py > outputs/01_clean_log.txt
rm -f donations.db
sqlite3 donations.db < sql/01_load.sql
for f in 02_funding_overview 03_party_funding_mix 04_donor_concentration 05_election_cycle 06_reporting_compliance; do
  echo "Running $f..."
  sqlite3 donations.db < "sql/$f.sql" > "outputs/$f.txt"
done
mkdir -p tableau/data
sqlite3 donations.db < sql/07_tableau_exports.sql
echo "Done. Results in outputs/, Tableau tables in tableau/data/."

# Charts
$PY python/build_notebook.py > /dev/null
(cd notebooks && ../$PY -m nbconvert --to notebook --execute --inplace analysis.ipynb 2> /dev/null)
echo "Charts in outputs/charts/."
