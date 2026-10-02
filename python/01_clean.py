"""Cleans the Electoral Commission donations register.

Reads  data/raw/donations_raw.xlsx
Writes data/clean/donations_clean.csv   one row per donation, analysis-ready
       data/clean/data_quality_log.csv  every issue found and what was done about it

Run from the project root:  .venv/bin/python python/01_clean.py
"""
import re
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw" / "donations_raw.xlsx"
OUT = ROOT / "data" / "clean"
OUT.mkdir(parents=True, exist_ok=True)

MAIN_PARTIES = {
    "Conservative and Unionist Party": "Conservative",
    "Labour Party": "Labour",
    "Liberal Democrats": "Liberal Democrats",
    "Scottish National Party (SNP)": "SNP",
    "UK Independence Party (UKIP)": "UKIP",
    "Green Party": "Green",
    "Plaid Cymru - The Party of Wales": "Plaid Cymru",
    "Co-operative Party": "Co-operative",
}

log = []


def note(issue, rows, action):
    log.append({"issue": issue, "rows_affected": int(rows), "action": action})


df = pd.read_excel(RAW)
n = len(df)

# --- Dates -------------------------------------------------------------------
# The file stores dates as dd/mm/yyyy text. Excel silently converted every date whose
# day was 12 or less into a real date, reading it as mm/dd. Evidence: converted cells
# never have a day above 12, and text cells never have a day below 13.
# Fix: parse text as dd/mm/yyyy, and swap day and month back on converted cells.
def is_converted(x):
    return isinstance(x, pd.Timestamp) or hasattr(x, "isoformat") and not isinstance(x, str)


def parse_date(x):
    if isinstance(x, str):
        return pd.to_datetime(x.strip(), format="%d/%m/%Y", errors="coerce")
    if pd.isna(x):
        return pd.NaT
    x = pd.Timestamp(x)
    return pd.Timestamp(year=x.year, month=x.day, day=x.month)


for col in ["AcceptedDate", "ReceivedDate", "ReportedDate"]:
    converted = df[col].map(is_converted)
    assert pd.to_datetime(df.loc[converted, col]).dt.day.max() <= 12, f"{col}: unexpected converted date"
    note(f"{col}: day and month swapped by Excel", converted.sum(),
         "Swapped day and month back on every Excel-converted cell")
    df[col] = df[col].map(parse_date)

# Accepted date is the legal reference date; fall back to received date where it is missing
missing_accepted = df.AcceptedDate.isna()
note("AcceptedDate missing", missing_accepted.sum(), "Used ReceivedDate instead; if both missing, used ReportedDate")
df["donation_date"] = df.AcceptedDate.fillna(df.ReceivedDate).fillna(df.ReportedDate)

# --- Value -------------------------------------------------------------------
df["value_gbp"] = pd.to_numeric(df.Value.astype(str).str.replace(",", "").str.replace("£", ""), errors="raise")
zero = df.value_gbp.eq(0)
note("Donation value is £0", zero.sum(), "Kept (mostly aggregated or returned entries); they do not affect totals")

# --- Donor names ---------------------------------------------------------------
# DonorId is not a reliable key: the same donor is often registered under several IDs.
# Group donors by a normalised name instead (case, punctuation, 'The', 'Ltd' removed).
def donor_key(name):
    if pd.isna(name):
        return None
    s = str(name).lower().replace("&", " and ")
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    s = re.sub(r"\b(the|ltd|limited|plc|llp|inc)\b", " ", s)
    return re.sub(r"\s+", " ", s).strip()


df["donor_key"] = df.DonorName.map(donor_key)
spellings = df.assign(name=df.DonorName.str.strip()).groupby("donor_key").name.nunique()
merged_keys = spellings[spellings > 1].index
note("Same donor spelled several ways", df.donor_key.isin(merged_keys).sum(),
     f"Merged {len(merged_keys):,} donors by normalised name")
ids_per_name = df.dropna(subset=["DonorId"]).groupby("donor_key").DonorId.nunique()
note("Same donor under several DonorIds", (ids_per_name > 1).sum(),
     "Did not use DonorId as a donor key")
# Display name = the most common original spelling for each donor
display = (df.dropna(subset=["DonorName"]).assign(DonorName=df.DonorName.str.strip())
           .groupby("donor_key").DonorName.agg(lambda s: s.value_counts().index[0]))
df["donor_name"] = df.donor_key.map(display)
note("DonorName missing", df.DonorName.isna().sum(), "Labelled 'Unknown donor'")
note("DonorStatus missing", df.DonorStatus.isna().sum(), "Labelled 'Unknown'")
optional = ["CampaigningName", "DonationAction", "PurposeOfVisit", "RegulatedDoneeType", "NatureOfDonation",
            "CompanyRegistrationNumber", "AccountingUnitId", "AccountingUnitName", "IsReportedPrePoll"]
note("Optional fields blank where they don't apply (" + ", ".join(optional) + ")", df[optional].isna().any(axis=1).sum(),
     "Left blank: not errors (e.g. company number only exists for companies). DonationAction became the is_returned flag")
df["donor_name"] = df.donor_name.fillna("Unknown donor")

# --- Classification -----------------------------------------------------------
df["is_public_funds"] = df.DonationType.eq("Public Funds") | df.DonorStatus.eq("Public Fund")
note("Public money recorded as donations (e.g. House of Commons 'Short Money')", df.is_public_funds.sum(),
     "Flagged is_public_funds; excluded from private-donation analysis")

df["is_returned"] = df.DonationAction.notna()
note("Donation returned, forfeited or deferred", df.is_returned.sum(),
     "Flagged is_returned; excluded from accepted totals")

df["recipient_group"] = df.RegulatedEntityName.map(MAIN_PARTIES)
is_party = df.RegulatedEntityType.eq("Political Party")
df.loc[is_party & df.recipient_group.isna(), "recipient_group"] = "Other parties"
df.loc[~is_party, "recipient_group"] = "Not a party: " + df.RegulatedEntityType.str.lower()

df["register"] = df.RegisterName.fillna("Not recorded")
note("RegisterName missing", df.RegisterName.isna().sum(), "Labelled 'Not recorded'")
note("Postcode missing", df.Postcode.isna().sum(), "Not used for mapping: missing for half the rows, and often a party HQ address")

# --- Reporting lag ------------------------------------------------------------
df["report_lag_days"] = (df.ReportedDate - df.donation_date).dt.days
negative = df.report_lag_days < 0
no_dates = df.donation_date.isna()
note("No accepted, received or reported date", no_dates.sum(),
     f"Kept in totals (£{df.loc[no_dates, 'value_gbp'].sum():,.0f}); left off time-based charts")
note("ReportedDate missing", df.ReportedDate.isna().sum(), "lag_status = 'Unknown'; excluded from reporting-delay figures")
note("Reported before the donation date", negative.sum(), "Flagged lag_status = 'Date error'; excluded from lag statistics")
df["lag_status"] = pd.cut(df.report_lag_days, [-10**6, -1, 120, 365, 10**6],
                          labels=["Date error", "Within ~4 months", "4-12 months", "Over a year"])
df["lag_status"] = df.lag_status.astype(str).replace("nan", "Unknown")

# --- Output -------------------------------------------------------------------
clean = pd.DataFrame({
    "ec_ref": df.ECRef,
    "donation_date": df.donation_date.dt.date,
    "year": df.donation_date.dt.year.astype("Int64"),
    "quarter": df.donation_date.dt.to_period("Q").astype(str),
    "reported_date": df.ReportedDate.dt.date,
    "report_lag_days": df.report_lag_days.astype("Int64"),
    "lag_status": df.lag_status,
    "recipient": df.RegulatedEntityName.str.strip(),
    "recipient_type": df.RegulatedEntityType,
    "recipient_group": df.recipient_group,
    "donee_type": df.RegulatedDoneeType,
    "donor_name": df.donor_name,
    "donor_key": df.donor_key,
    "donor_status": df.DonorStatus.fillna("Unknown"),
    "donation_type": df.DonationType,
    "nature_of_donation": df.NatureOfDonation,
    "value_gbp": df.value_gbp,
    "is_public_funds": df.is_public_funds.astype(int),
    "is_returned": df.is_returned.astype(int),
    "donation_action": df.DonationAction,
    "is_aggregation": df.IsAggregation.astype(int),
    "is_bequest": df.IsBequest.astype(int),
    "is_sponsorship": df.IsSponsorship.astype(int),
    "register": df.register,
})
assert len(clean) == n and clean.ec_ref.is_unique
clean.to_csv(OUT / "donations_clean.csv", index=False)
pd.DataFrame(log).to_csv(OUT / "data_quality_log.csv", index=False)

print(f"{n:,} donations cleaned -> {OUT / 'donations_clean.csv'}")
print(pd.DataFrame(log).to_string(index=False, justify="left", max_colwidth=70))
