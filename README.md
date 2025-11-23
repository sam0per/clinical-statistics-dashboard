# Comprehensive Guide for Designing Auditable Clinical Aggregated Statistics Tables

**Version 2.0 - Statistically Corrected and Architecturally Enhanced**

This documentation is designed for data engineers, analysts, report designers, and tooling (including scripts or Language Models) responsible for consuming and producing standardized clinical aggregated statistics tables.

---

## I. Data Foundation: Conceptual Database Overview

The reports (Prevalence and Incidence) must be derived from the underlying clinical data structure, which provides necessary dimensions and source facts.

### Key Tables for Reporting

| Table Name                                             | Purpose / Use Case                                                                                                                                                                                                                                                 | Key Columns                                                                  |
| :----------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------- |
| **PERSON**                                             | Central identity management; unique patient identification for counting distinct patients in analyses.                                                                                                                                                             | `person_id`, `gender`, `birth_date`, `age_group`                             |
| **OBSERVATION_PERIOD**                                 | Defines the spans of time when clinical events are expected to be recorded. Essential for determining eligibility, time-at-risk, and calculating incidence/prevalence rates.                                                                                       | `person_id`, `observation_period_start_date`, `observation_period_end_date`  |
| **CONDITION_OCCURRENCE / DRUG_EXPOSURE / MEASUREMENT** | Serve as the input sources for defining cases and clinical events.                                                                                                                                                                                                 | Contain event start/end dates and links back to `person_id`.                 |
| **COHORT_DEFINITION / COHORT**                         | **Essential for reproducible reporting**; stores the exact criteria used for defining the risk set and the actual results of executing that definition (subjects satisfying the criteria for a duration). Links to both denominators and person-time calculations. | `cohort_definition_id`, `cohort_start_date`, `cohort_end_date`, `person_id`. |
| **CONCEPT / CONCEPT_ANCESTOR**                         | Links all facts (diseases, drugs) to a Standardized Terminology. **Essential for grouping diagnoses or drugs** in analyses.                                                                                                                                        | `concept_id`, `concept_name`, `ancestor_concept_id`.                         |

---

## II. Reporting Blueprint and Metric Definitions

The following definitions and formulas must be applied when generating Prevalence and Incidence reports based on patient data.

### A. Core Constraints and Definitions

| Concept                             | Definition                                                                                                           | Constraint / Requirement                                                                                                                                                                                                           |
| :---------------------------------- | :------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Prevalence Denominator**          | Number of patients in a stratum with sufficient observation time during the reporting period.                        | Requires at least **365 days of observation** during or prior to the reporting period.                                                                                                                                             |
| **Incidence Denominator**           | Person-years at-risk: the sum of time each person contributes to the at-risk population.                             | Calculate from cohort entry until the **earliest** of: (1) incident case occurrence, (2) death, (3) loss to follow-up, (4) end of observation period, or (5) end of reporting period.                                              |
| **Prevalent Case**                  | A patient with the condition present during the reporting period (includes both new and existing cases).             | Count each patient once regardless of multiple occurrences. Includes patients who had the condition before the reporting period begins.                                                                                            |
| **Incident Case**                   | The first-ever occurrence of a case-defining event after a clean lookback window.                                    | Requires: (1) ≥365 days of prior observation, AND (2) no occurrence of the case-defining event in the prior 365 days (washout period).                                                                                             |
| **Person-Years at-Risk (PYAR)**     | Sum of observation time (in years) for the eligible population while still at risk of developing the incident event. | **Critical**: Once a patient experiences the incident event, they immediately stop contributing person-time. Also censor at death, loss to follow-up, end of observation period, or end of reporting period—whichever comes first. |
| **Minimum Observation Requirement** | Minimum duration of continuous observation required for eligibility.                                                 | **365 days** of observation before or during the reporting period.                                                                                                                                                                 |
| **Washout/Lookback Window**         | Period examined to ensure incident cases are truly "new" (first-ever occurrence).                                    | **365 days** prior to the reporting period with no occurrence of the case-defining event.                                                                                                                                          |
| **Reporting Period**                | The time window used for aggregation.                                                                                | **Calendar Year** (January 1 to December 31). Person-specific contributions are calculated as the intersection of: (1) calendar year boundaries, (2) individual observation periods, and (3) at-risk time (for incidence only).    |
| **Missing Data**                    | Treatment for demographic variables.                                                                                 | Missing age or gender must be classified as **"Unknown"** and reported as a separate category.                                                                                                                                     |

### B. Detailed Censoring Rules for Incidence Calculations

**Person-years at-risk must be censored (stopped) at the earliest occurrence of any of the following events:**

1. **Incident case onset**: The moment the patient experiences their first case-defining event
2. **Death**: Date of death from any cause
3. **Loss to follow-up**: Last contact date when patient is lost to observation
4. **End of observation period**: The end date of the patient's observation_period record
5. **End of reporting period**: December 31 of the reporting year

**Example Calculation:**
- Patient enters cohort on March 1, 2024
- Reporting period is calendar year 2024 (Jan 1 - Dec 31, 2024)
- Patient develops incident case on September 15, 2024
- **Person-years at-risk contributed**: (September 15, 2024 - March 1, 2024) = 198 days = 0.54 years
- **Note**: Patient contributes NO time after September 15, 2024

### C. Integration with COHORT Tables

The COHORT and COHORT_DEFINITION tables are integral to calculations:

**For Prevalence:**
- Denominator = COUNT(DISTINCT person_id) from COHORT where cohort meets minimum observation requirement
- Link COHORT to OBSERVATION_PERIOD to verify ≥365 days of observation

**For Incidence:**
- Person-years at-risk = SUM(time from cohort_start_date to earliest censoring event) for all COHORT members
- Calculate using intersection of COHORT dates and OBSERVATION_PERIOD dates
- Apply all five censoring rules listed above

### D. Table Schemas and Calculation Logic

The aggregated tables must adhere to the following calculation specifications:

| Report Type    | Metric Name / Column            | Formula / Logic                                                                                                                                   | Rounding Requirement                              | Additional Notes                                                                    |
| :------------- | :------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------ | :---------------------------------------------------------------------------------- |
| **Prevalence** | Prevalence (%)                  | **(prevalent_cases / denominator) × 100**                                                                                                         | **Round to 1 decimal place** (final display only) | Denominator = eligible patient count with ≥365 days observation                     |
|                | Denominator                     | Total number of eligible patients with sufficient observation time during reporting period.                                                       | N/A                                               | Must have ≥365 days of observation                                                  |
|                | Prevalent Cases                 | Number of unique patients with ≥1 occurrence of the condition during the reporting period (includes both incident and pre-existing cases).        | N/A                                               | Count each person once only                                                         |
| **Incidence**  | Incidence Rate (per 1,000 PYAR) | **(incident_cases / person_years_at_risk) × 1000**                                                                                                | **Round to 2 decimals** (final display only)      | **CRITICAL**: Denominator must be person-years **at-risk** (stops at incident case) |
|                | Person-Years at-Risk (PYAR)     | Sum of observation time (in years) for the eligible population from cohort entry until earliest censoring event.                                  | Round to 2 decimals                               | Apply all five censoring rules                                                      |
|                | Incident Cases                  | Number of first-ever occurrences in the reporting period among patients with: (1) ≥365 days prior observation AND (2) no event in prior 365 days. | N/A                                               | Requires clean lookback window                                                      |

---

## III. Best Practice Guide for Table Output Design

To ensure the final aggregated tables are readable and auditable for humans and language models (LMs), follow these design and documentation rules.

### 1. Title, Caption, and Context (Traceability)

- **Table Title:** Use a clear title stating **what, when, and where**. *Example: "Table 1 – Annual Diabetes Incidence by Age Group (Calendar Year 2024)"*.
- **Caption/Footnotes:** The caption must include:
  - Reporting period (e.g., "Calendar Year 2024: January 1, 2024 to December 31, 2024")
  - **Data source** (e.g., "Source: PERSON, OBSERVATION_PERIOD, CONDITION_OCCURRENCE, COHORT tables")
  - Rounding rules applied (e.g., "Prevalence rounded to 1 decimal; Incidence rates rounded to 2 decimals")
  - Denominator definitions (e.g., "Prevalence denominator = patients with ≥365 days observation; Incidence denominator = person-years at-risk with censoring at incident case")
  - Any specific caveats (e.g., "Excludes patients with <365 days observation")
- **Traceability:** Provide metric formulas and the **path to the raw data or query** used for validation.
  - *Example*: "Incidence Rate = (Incident Cases / Person-Years at-Risk) × 1,000; Query: incidence_diabetes_2024.sql"
- **LM Optimization:** Prefer explicit key:value statements for LMs, such as:
  - "Metric: diabetes_incidence_rate; Unit: per 1,000 PYAR; Period: 2024-01-01 to 2024-12-31; Denominator: person_years_at_risk"

### 2. Metrics and Granularity

- **Clarity:** Use precise metric names and **include units** (e.g., "Incidence Rate (per 1,000 PYAR)" not just "Incidence Rate").
- **Denominator Transparency:** Always specify what the denominator represents:
  - For prevalence: "per 1,000 eligible patients"
  - For incidence: "per 1,000 person-years at-risk"
- **Granularity:** Explicitly state the aggregation granularity (e.g., by month, by region, by age group, calendar year).
- **Consistency:** **Do not mix aggregation levels** within the same table without clear labels or separate blocks.
  - If mixing prevalence and incidence, use separate sections with clear headers.

### 3. Formatting and Readability

- **Alignment:** **Right-align numbers, and left-align text**.
- **Consistency:** Use consistent decimals and thousands separators:
  - Prevalence (%): 1 decimal place (e.g., 12.5%)
  - Incidence Rate (per 1,000 PYAR): 2 decimal places (e.g., 15.42 per 1,000 PYAR)
  - Person-Years at-Risk: 2 decimal places (e.g., 12,543.67 PYAR)
  - Counts (cases, denominators): No decimals (e.g., 1,234 patients)
- **Headers:** Make headers explicit and consistent:
  - **Column Titles:** Include metric, time dimension, and units (e.g., "Incidence Rate (per 1,000 PYAR)", "Prevalence (%) - 2024").
    - Order time series columns chronologically (e.g., 2022, 2023, 2024).
  - **Row Titles:** State clearly what each row represents (Age Group, Gender, Region, Disease Category).
- **Thousands Separators:** Use commas for numbers ≥1,000 (e.g., 12,543 not 12543).

### 4. Handling Missing Data and Pitfalls

- **Missing Data:** 
  - Use a **consistent missing-data code** (e.g., "Unknown" or "—") for demographic variables.
  - Document this code explicitly in the caption: "Missing gender/age coded as 'Unknown'"
  - Report "Unknown" as a separate category in stratified analyses.
- **Avoid Mixing Units:** Do not mix units in one column (e.g., don't combine percentages and counts).
- **Focus:** Keep tables focused and avoid overly wide tables (>10 columns); provide drill-downs or separate tables if necessary.
- **Denominator Documentation:** Always document which denominator is used:
  - "Prevalence denominator: 45,678 patients with ≥365 days observation"
  - "Incidence denominator: 23,456.78 person-years at-risk (censored at incident case)"

### 5. Quality Assurance Checks

Before finalizing any table, verify:

- **Denominator Validation:**
  - For prevalence: Confirm all patients in denominator have ≥365 days observation
  - For incidence: Confirm person-years calculation stops at incident case (or other censoring events)
- **Case Definitions:**
  - Prevalent cases: Include all patients with condition during period (new + existing)
  - Incident cases: Only first-ever occurrences with clean 365-day lookback
- **Temporal Alignment:**
  - Confirm person-time calculations use intersection of calendar year, observation period, and cohort dates
  - Verify censoring is applied correctly at all five censoring points
- **Rounding:**
  - Applied only at final display, not in intermediate calculations
  - Consistent across all metrics in the table

---

## IV. Human-friendly Final Checklist

Before publishing any aggregated table, use this checklist:

| Checkpoint                      | Requirement                                                                                              | Example / Reference                                                                       |
| :------------------------------ | :------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------- |
| ☐ **Title**                     | Descriptive & specific (what, when, where).                                                              | "Diabetes Incidence by Age Group (2024)"                                                  |
| ☐ **Metrics**                   | Names, units, calculation notes included.                                                                | "Incidence Rate (per 1,000 PYAR)"                                                         |
| ☐ **Units**                     | Explicitly stated (%, per 1,000 PYAR, count).                                                            | Always include in column headers                                                          |
| ☐ **Granularity**               | Explicitly stated (by month, by region, calendar year).                                                  | "Calendar Year 2024; Stratified by Age Group"                                             |
| ☐ **Denominators**              | Clearly differentiated and defined.                                                                      | "Prevalence: patient count; Incidence: PYAR"                                              |
| ☐ **Censoring Rules**           | Documented for incidence calculations.                                                                   | "Censored at: incident case, death, loss to follow-up, end of observation, end of period" |
| ☐ **Lookback Window**           | Specified for incident cases.                                                                            | "365-day washout period; no prior events"                                                 |
| ☐ **Observation Requirement**   | Minimum observation time documented.                                                                     | "Requires ≥365 days observation"                                                          |
| ☐ **Cohort Integration**        | Linkage to COHORT tables documented.                                                                     | "Denominator from COHORT; PYAR from COHORT intersected with OBSERVATION_PERIOD"           |
| ☐ **Layout**                    | Numeric alignment (right), whitespace, consistent formatting.                                            | Right-align all numeric columns                                                           |
| ☐ **Footnotes/Caption**         | Source, rounding rules (1 or 2 decimals), missing-data codes, denominator definitions, caveats included. | Complete caption with all documentation                                                   |
| ☐ **Validation**                | Traceability provided to raw data or auditable logic.                                                    | "Query: diabetes_incidence_2024.sql"                                                      |
| ☐ **Focus**                     | Avoid excessive rows/columns (≤10 columns preferred).                                                    | Split into multiple tables if needed                                                      |
| ☐ **Intermediate Calculations** | Rounding applied only at final display.                                                                  | Store unrounded values for calculations                                                   |
| ☐ **Missing Data**              | Coded consistently and documented.                                                                       | "Unknown category for missing demographics"                                               |

---

## V. Worked Examples

### Example 1: Prevalence Table

**Table 1 – Diabetes Prevalence by Age Group (Calendar Year 2024)**

| Age Group | Denominator (Eligible Patients) | Prevalent Cases | Prevalence (%) |
| :-------- | ------------------------------: | --------------: | -------------: |
| 18-34     |                          12,456 |             423 |            3.4 |
| 35-49     |                          15,678 |           1,254 |            8.0 |
| 50-64     |                          18,234 |           3,287 |           18.0 |
| 65+       |                           9,876 |           2,456 |           24.9 |
| Unknown   |                             234 |              12 |            5.1 |
| **Total** |                      **56,478** |       **7,432** |       **13.2** |

**Caption:** Prevalence calculated as (prevalent_cases / denominator) × 100. Denominator includes all patients with ≥365 days of observation during 2024 (January 1 - December 31, 2024). Prevalent cases include all patients with at least one diabetes diagnosis during 2024, regardless of onset date. Source: PERSON, COHORT, CONDITION_OCCURRENCE tables. Prevalence rounded to 1 decimal place. Missing age coded as "Unknown". Query: diabetes_prevalence_2024.sql.

### Example 2: Incidence Table

**Table 2 – Diabetes Incidence by Gender (Calendar Year 2024)**

| Gender    | Person-Years at-Risk (PYAR) | Incident Cases | Incidence Rate (per 1,000 PYAR) |
| :-------- | --------------------------: | -------------: | ------------------------------: |
| Female    |                   23,456.78 |            342 |                           14.58 |
| Male      |                   21,234.56 |            289 |                           13.61 |
| Unknown   |                      456.23 |              5 |                           10.96 |
| **Total** |               **45,147.57** |        **636** |                       **14.09** |

**Caption:** Incidence rate calculated as (incident_cases / person_years_at_risk) × 1,000. Person-years at-risk calculated from cohort entry until earliest of: (1) first diabetes diagnosis, (2) death, (3) loss to follow-up, (4) end of observation period, or (5) December 31, 2024. Incident cases defined as first-ever diabetes diagnosis in 2024 with: (1) ≥365 days prior observation AND (2) no diabetes diagnosis in prior 365 days (washout period). Source: PERSON, COHORT, OBSERVATION_PERIOD, CONDITION_OCCURRENCE tables. Incidence rate rounded to 2 decimal places; PYAR rounded to 2 decimal places. Missing gender coded as "Unknown". Query: diabetes_incidence_2024.sql.

---

## VI. Critical Reminders

1. **Person-Years at-Risk vs Person-Years:** These are NOT the same. Person-years at-risk must stop accumulating when a patient develops the incident event. This is the most critical distinction for accurate incidence calculations.

2. **Prevalence vs Incidence Denominators:** 
   - Prevalence uses **patient counts** (number of eligible patients)
   - Incidence uses **person-years at-risk** (time contributed while at risk)
   - Never confuse these two denominators.

3. **Eligibility vs Washout:** These are separate requirements:
   - **Eligibility**: ≥365 days observation (required for both prevalence and incidence)
   - **Washout**: 365 days with no event (required only for incident cases)

4. **Censoring Completeness:** All five censoring events must be considered:
   - Incident case occurrence
   - Death
   - Loss to follow-up
   - End of observation period
   - End of reporting period

5. **Cohort Table Integration:** COHORT tables must be integrated into all calculations—they define who is eligible, when they entered the risk set, and how long they contributed time.

6. **Rounding Discipline:** Round only at final display. Maintain full precision in intermediate calculations to avoid accumulation of rounding errors.

7. **Documentation is Mandatory:** Every table must have complete documentation including source tables, formulas, denominator definitions, censoring rules, and query references.

---

This guide provides the necessary constraints and definitions—like a **building code** for data tables—ensuring that every report generated using the foundational conceptual database structure (the **raw materials**) meets the specific epidemiological criteria (the **architectural blueprints**) and is documented according to auditable standards.