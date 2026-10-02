# Tableau Public Build Guide

> **Using Tableau Public in the browser?** Follow the step-by-step walkthrough in [`build_walkthrough.html`](build_walkthrough.html) instead. It uses a single data file (`tableau/data/donations.csv`) with most fields pre-calculated.

This guide builds two dashboards from the tables in `tableau/data/`. They're created by `./run_all.sh`, which you need to run once before starting.

| File | What it holds |
|---|---|
| `donations.csv` | One row per donation (65,278 rows), with dates and donor names already cleaned |
| `party_donor_totals.csv` | One row per party × donor: total given, share of the party's money, and rank |
| `quarterly_party_funding.csv` | Private donations per party per quarter, with an election-quarter flag |

Each step ends with a ✅ **checkpoint**, a number you should see if everything is right.

---

## Step 1: Connect the data

1. Open **Tableau Public** → **Connect** → **Text file** → `donations.csv`.
2. On the Data Source page, check the data types (click the icon above each column):
   - `donation_date` → **Date**
   - `value_gbp` and `report_lag_days` → **Number (decimal)** and **Number (whole)**
   - `year` → **Number (whole)**, then in the worksheet drag it from Measures to **Dimensions**
3. Add the other two files as **separate data sources**: **Data** → **New Data Source** → **Text file**. Don't join them. Each one feeds different sheets.

✅ Checkpoint: in a blank sheet, drag `value_gbp` onto **Text**. It should show **1,091,979,899**, which is £1.09B.

## Step 2: Calculated fields (in `donations`)

**Analysis** → **Create Calculated Field** for each:

```
// Is Private Party Donation
[recipient_type] = "Political Party" AND [is_public_funds] = 0 AND [is_returned] = 0
```

```
// Donor Type
IF [donor_status] = "Individual" OR [donor_status] = "Company" OR [donor_status] = "Trade Union"
THEN [donor_status] ELSE "Other" END
```

```
// Gift Size
IF [value_gbp] < 7500 THEN "1. Under £7.5k"
ELSEIF [value_gbp] < 50000 THEN "2. £7.5k–50k"
ELSEIF [value_gbp] < 100000 THEN "3. £50k–100k"
ELSEIF [value_gbp] < 500000 THEN "4. £100k–500k"
ELSE "5. £500k+" END
```

```
// Is Late (over ~4 months)
IF [lag_status] = "4-12 months" OR [lag_status] = "Over a year" THEN 1 ELSE 0 END
```

```
// Late %
SUM([Is Late (over ~4 months)]) / COUNT([ec_ref])
```

```
// Money Bucket
IF [is_public_funds] = 1 THEN "Public money (Short Money etc.)"
ELSEIF [is_returned] = 1 THEN "Returned or forfeited"
ELSEIF [recipient_type] = "Political Party" THEN "Private donations to parties"
ELSE "Campaigns, MPs and other recipients" END
```

In **`party_donor_totals`**, add:

```
// Top 10 Share
SUM(IF [donor_rank] <= 10 THEN [gbp] END) / SUM([gbp])
```

✅ Checkpoint: filter `donations` to **Is Private Party Donation = True**. SUM(value_gbp) should be **£796.9M** across **55,064** rows.

## Step 3: Formatting that applies everywhere

- **Colors:** one default blue `#2A78D6`, orange `#EB6834` for "focus here", red `#D03B3B` for "problem". Donor types: Individual `#2A78D6`, Company `#EB6834`, Trade Union `#1BAF7A`, Other `#B4B2A9`.
- **Don't color by party.** Every bar is labelled with the party's name, and a neutral palette keeps the dashboard visibly non-partisan.
- Currency format: **£**, display units **Millions (M)**, 1 decimal.
- **Titles state the finding**: "Labour runs on trade unions", not "Funding by donor type".
- Turn off gridlines and zero lines on bar charts, and show mark labels instead.

---

## Dashboard 1: "Who funds UK political parties?"

Size: **Fixed, 1200 × 900**.

| # | Sheet | How to build it | Title |
|---|---|---|---|
| 1 | **KPI: private donations** | Text: SUM(value_gbp). Filter Is Private Party Donation = True | "£797M in private donations, 2001–2019" |
| 2 | **KPI: public money** | Text: SUM(value_gbp). Filter is_public_funds = 1 | "£164M of 'donations' is public money" |
| 3 | **Funding mix** | Rows: recipient_group. Columns: SUM(value_gbp) → Quick table calculation → **Percent of total**, Compute using **Table (across)**. Color: Donor Type. Filter: Is Private Party Donation = True; recipient_group in the six main parties | "Labour runs on trade unions; the others run on individuals and companies" |
| 4 | **Top 10 donors** (from `party_donor_totals`) | Rows: donor_name. Columns: SUM(gbp). Filter: donor_rank ≤ 10. Sort descending | "Top 10 donors: [party]" |
| 5 | **Donor concentration** (from `party_donor_totals`) | Rows: party. Columns: Top 10 Share. Color: orange if ≥ 50%, else blue | "SNP, Labour and UKIP get over half their money from 10 donors" |
| 6 | **Money by quarter** (from `quarterly_party_funding`) | Columns: quarter. Rows: SUM(gbp). Line, with a dual mark or reference line: Analysis → Reference line → **Median** | "Election quarters bring in about 3x a typical quarter" |

**Make it interactive (the part that impresses):**
- **Dashboard** → **Actions** → **Add Action** → **Filter**. Source: the Funding mix sheet. Target: Top 10 donors and Money by quarter. Run on: **Select**. Now clicking a party shows *its* top donors and *its* quarterly funding.
- Match the fields across data sources: `recipient_group` in donations = `party` in the other two. Set this in **Data** → **Edit Blend Relationships** → **Custom**.
- Add a sub-title: *"Click a party to see its top donors and funding timeline."*

## Dashboard 2: "Can the data be trusted?"

| # | Sheet | How to build it | Title |
|---|---|---|---|
| 1 | **Where the money goes** | Rows: Money Bucket. Columns: SUM(value_gbp). Labels: value and percent of total | "15% of the 'donations' register is public money" |
| 2 | **Gift size** | Rows: Gift Size. Columns: CNT(ec_ref) and SUM(value_gbp) as **Percent of total**, side by side. Filter: Is Private Party Donation = True | "Gifts of £100k+ are 2.7% of donations but 53% of the money" |
| 3 | **Reporting delay** | Rows: recipient_type. Columns: Late %. Filter: lag_status ≠ "Date error" | "Referendum campaigners reported most donations over 4 months late" |
| 4 | **Text box: data fixes** | Write 3 lines: a third of dates were mangled by Excel (fixed); 942 donors spelled several ways (merged); £164M of public money separated | "What I fixed before analysing" |

✅ Checkpoints:

| Sheet | Should show |
|---|---|
| Donor concentration | SNP **72%**, Labour **60%**, UKIP **55%**, Green **45%**, Lib Dems **29%**, Conservative **13%** |
| Top 10 donors, Labour | Unite the Union **£39.7M** first |
| Funding mix, Labour | Trade Union **66%** |
| Reporting delay | Permitted Participant **61%**, Political Party **5%** |

## Step 4: Publish

1. **File** → **Save to Tableau Public As…** → name it *"Who Funds UK Political Parties"*.
2. On your Tableau Public profile, open the viz → ⚙ **Settings** → tick **Show sheets as tabs** so both dashboards are reachable.
3. Copy the link and send it to me. I'll add it to the README, with a screenshot of each dashboard saved in `tableau/screenshots/`.
4. Your 2024 dashboard can stay on your profile. Recruiters seeing both versions side by side shows how you've grown.
