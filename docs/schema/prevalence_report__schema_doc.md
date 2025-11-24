# Prevalence Report Schema Documentation

**Version:** 1.0  
**Last Updated:** November 23, 2025  
**Schema Version:** prevalence_v1  
**Based On:** Comprehensive Guide for Designing Auditable Clinical Aggregated Statistics Tables (Version 2.0)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Schema Architecture](#2-schema-architecture)
3. [Table Specifications](#3-table-specifications)
4. [Data Flow and Population](#4-data-flow-and-population)
5. [Calculation Logic](#5-calculation-logic)
6. [Quality Assurance](#6-quality-assurance)
7. [Usage Examples](#7-usage-examples)
8. [Validation Procedures](#8-validation-procedures)
9. [Maintenance and Troubleshooting](#9-maintenance-and-troubleshooting)

---

## 1. Overview

### 1.1 Purpose

This schema implements the prevalence reporting requirements defined in the *Comprehensive Guide for Designing Auditable Clinical Aggregated Statistics Tables*. It provides a complete, auditable infrastructure for calculating, storing, and reporting disease prevalence across patient populations.

### 1.2 Core Definition

**Prevalence** measures the proportion of patients with a condition during a specific time period:

```
Prevalence (%) = (Prevalent Cases / Denominator) × 100
```

Where:
- **Denominator** = Number of eligible patients with ≥365 days observation
- **Prevalent Cases** = Unique patients with ≥1 occurrence of the condition during the reporting period
- **Rounding** = 1 decimal place for final display

### 1.3 Key Principles

| Principle                     | Implementation                                                     |
| :---------------------------- | :----------------------------------------------------------------- |
| **Patient-Based Counting**    | Each patient counted once regardless of multiple occurrences       |
| **Eligibility Requirement**   | All denominator patients must have ≥365 days observation           |
| **Inclusive Case Definition** | Prevalent cases include both new (incident) and pre-existing cases |
| **Stratification Support**    | Age group, gender, region, and custom dimensions                   |
| **Complete Auditability**     | Full traceability from raw data to final metrics                   |
| **Data Quality Enforcement**  | Database constraints validate guide compliance                     |

---

## 2. Schema Architecture

### 2.1 Entity Relationship Diagram

```
┌─────────────────────────────────┐
│ prevalence_report_metadata      │
│ ─────────────────────────────── │
│ PK: report_id                   │
│     report_title                │
│     condition_concept_id        │
│     reporting_period_*          │
│     cohort_definition_id        │
└──────────────┬──────────────────┘
               │
               │ 1:N
               │
       ┌───────┴────────┬──────────────────┬─────────────────┐
       │                │                  │                 │
       ▼                ▼                  ▼                 ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ prevalence_ │  │ prevalence_ │  │ prevalence_ │  │ prevalence_ │
│ denominator │  │ cases       │  │ aggregated  │  │ quality_    │
│             │  │             │  │             │  │ checks      │
│ PK: report_ │  │ PK: report_ │  │ PK: report_ │  │             │
│     person_ │  │     person_ │  │   stratif*  │  │             │
│     id      │  │     id      │  │   stratum*  │  │             │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
       │                │
       │                │
       └────────┬───────┘
                │
                │ Links to
                ▼
         ┌─────────────┐
         │   PERSON    │
         │   COHORT    │
         │   CONCEPT   │
         └─────────────┘
         (Foundation Tables)
```

### 2.2 Table Summary

| Table Name                    | Purpose                                | Record Grain               | Key Relationships                     |
| :---------------------------- | :------------------------------------- | :------------------------- | :------------------------------------ |
| `prevalence_report_metadata`  | Report configuration and documentation | One per report             | Links to CONCEPT, COHORT_DEFINITION   |
| `prevalence_denominator`      | Eligible population tracking           | One per patient per report | Links to PERSON, COHORT               |
| `prevalence_cases`            | Prevalent case identification          | One per case per report    | Links to PERSON, CONDITION_OCCURRENCE |
| `prevalence_aggregated`       | Final calculated metrics               | One per stratum per report | Aggregates from denominator/cases     |
| `prevalence_quality_checks`   | Validation results                     | Multiple per report        | Documents compliance                  |
| `prevalence_report_footnotes` | Report documentation                   | Multiple per report        | Caption generation                    |

### 2.3 Design Patterns

**Pattern 1: Metadata-Driven**
- All reports begin with metadata record defining parameters
- Ensures reproducibility and traceability

**Pattern 2: Separate Storage for Raw and Display**
- `prevalence_rate_raw`: Full precision for calculations
- `prevalence_rate_display`: Rounded to 1 decimal for presentation
- Prevents rounding error accumulation

**Pattern 3: Built-in Quality Controls**
- Database constraints enforce guide specifications
- CHECK constraints validate calculations
- Foreign keys ensure referential integrity

---

## 3. Table Specifications

### 3.1 prevalence_report_metadata

**Purpose:** Central registry for all prevalence reports with complete documentation.

#### Critical Columns

| Column                        | Type         | Purpose                             | Guide Reference                      |
| :---------------------------- | :----------- | :---------------------------------- | :----------------------------------- |
| `report_id`                   | VARCHAR(50)  | Unique identifier (PK)              | Traceability requirement             |
| `report_title`                | VARCHAR(500) | Descriptive title                   | Section III.1: "what, when, where"   |
| `condition_concept_id`        | INTEGER      | Links to standardized terminology   | Section I: CONCEPT table             |
| `reporting_period_start_date` | DATE         | Inclusive start of reporting period | Section II.A: Calendar Year          |
| `reporting_period_end_date`   | DATE         | Inclusive end of reporting period   | Section II.A: Calendar Year          |
| `minimum_observation_days`    | INTEGER      | Required observation (default 365)  | Section II.A: Denominator constraint |
| `cohort_definition_id`        | INTEGER      | Links to cohort criteria            | Section II.C: Cohort integration     |
| `source_query_path`           | VARCHAR(500) | Path to SQL generating report       | Section III.1: Traceability          |
| `denominator_definition`      | TEXT         | Documents denominator calculation   | Section III.1: Caption requirements  |
| `case_definition`             | TEXT         | Documents case identification       | Section III.1: Caption requirements  |

#### Example Record

```sql
INSERT INTO prevalence_report_metadata VALUES (
    'PREV_DIABETES_2024',
    'Diabetes Prevalence by Age Group (Calendar Year 2024)',
    201826,  -- Type 2 Diabetes concept_id
    'Type 2 Diabetes Mellitus',
    '2024-01-01',
    '2024-12-31',
    365,
    1001,  -- cohort_definition_id for diabetes cohort
    '/queries/prevalence/diabetes_2024.sql',
    CURRENT_TIMESTAMP,
    'analytics_system',
    'Patients with ≥365 days observation during 2024',
    'Patients with at least one T2DM diagnosis during 2024'
);
```

#### Validation Rules

```sql
-- Rule 1: Valid date range
CHECK (reporting_period_end_date >= reporting_period_start_date)

-- Rule 2: Minimum observation must be positive
CHECK (minimum_observation_days > 0)

-- Rule 3: Condition must exist in CONCEPT table
FOREIGN KEY (condition_concept_id) REFERENCES concept(concept_id)
```

---

### 3.2 prevalence_denominator

**Purpose:** Tracks all patients eligible for inclusion in the prevalence denominator with complete observation history.

#### Critical Columns

| Column                          | Type         | Purpose                     | Guide Reference                     |
| :------------------------------ | :----------- | :-------------------------- | :---------------------------------- |
| `report_id`                     | VARCHAR(50)  | Links to report (PK1)       | Foreign key                         |
| `person_id`                     | INTEGER      | Patient identifier (PK2)    | Section I: PERSON table             |
| `age_group`                     | VARCHAR(20)  | Stratification dimension    | Section III.2: Granularity          |
| `gender`                        | VARCHAR(20)  | Stratification dimension    | Section II.A: Missing = "Unknown"   |
| `region`                        | VARCHAR(100) | Stratification dimension    | Section III.2: Granularity          |
| `total_observation_days`        | INTEGER      | Cumulative observation time | Section II.A: ≥365 days requirement |
| `observation_start_date`        | DATE         | First observation           | From OBSERVATION_PERIOD             |
| `observation_end_date`          | DATE         | Last observation            | From OBSERVATION_PERIOD             |
| `meets_observation_requirement` | BOOLEAN      | Eligibility flag            | Enforces ≥365 days                  |
| `cohort_start_date`             | DATE         | When patient entered cohort | Section II.C: Cohort integration    |
| `cohort_end_date`               | DATE         | When patient exited cohort  | Section II.C: Cohort integration    |

#### Population Logic

```sql
-- Step 1: Identify all patients with observation during reporting period
-- Step 2: Calculate total observation days (may span multiple periods)
-- Step 3: Determine if meets minimum observation requirement
-- Step 4: Link to cohort membership
-- Step 5: Assign stratification dimensions (age_group, gender, region)

INSERT INTO prevalence_denominator (
    report_id,
    person_id,
    age_group,
    gender,
    region,
    total_observation_days,
    observation_start_date,
    observation_end_date,
    meets_observation_requirement,
    cohort_start_date,
    cohort_end_date
)
SELECT 
    'PREV_DIABETES_2024' AS report_id,
    p.person_id,
    -- Age group calculation
    CASE 
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) BETWEEN 18 AND 34 THEN '18-34'
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) BETWEEN 35 AND 49 THEN '35-49'
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) BETWEEN 50 AND 64 THEN '50-64'
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) >= 65 THEN '65+'
        ELSE 'Unknown'
    END AS age_group,
    -- Gender handling
    COALESCE(p.gender, 'Unknown') AS gender,
    COALESCE(p.region, 'Unknown') AS region,
    -- Observation time calculation
    SUM(op.observation_period_end_date - op.observation_period_start_date + 1) AS total_observation_days,
    MIN(op.observation_period_start_date) AS observation_start_date,
    MAX(op.observation_period_end_date) AS observation_end_date,
    -- Eligibility determination
    SUM(op.observation_period_end_date - op.observation_period_start_date + 1) >= 365 AS meets_observation_requirement,
    c.cohort_start_date,
    c.cohort_end_date
FROM person p
JOIN observation_period op ON p.person_id = op.person_id
LEFT JOIN cohort c ON p.person_id = c.person_id 
    AND c.cohort_definition_id = 1001
WHERE 
    -- Observation overlaps with reporting period
    op.observation_period_start_date <= '2024-12-31'
    AND op.observation_period_end_date >= '2024-01-01'
GROUP BY 
    p.person_id, p.birth_date, p.gender, p.region,
    c.cohort_start_date, c.cohort_end_date;
```

#### Validation Rules

```sql
-- Rule 1: Observation dates must be valid
CHECK (observation_end_date >= observation_start_date)

-- Rule 2: Observation days must be positive
CHECK (total_observation_days > 0)

-- Rule 3: Eligibility flag must match observation days
CHECK (
    (meets_observation_requirement = TRUE AND total_observation_days >= 365) OR
    (meets_observation_requirement = FALSE AND total_observation_days < 365)
)
```

#### Missing Data Handling

Per Section II.A of the guide:

```sql
-- Missing gender coded as "Unknown"
COALESCE(p.gender, 'Unknown') AS gender

-- Missing age results in "Unknown" age_group
CASE 
    WHEN p.birth_date IS NULL THEN 'Unknown'
    WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) < 18 THEN '<18'
    -- ... other age groups ...
    ELSE 'Unknown'
END AS age_group
```

---

### 3.3 prevalence_cases

**Purpose:** Records all patients identified as prevalent cases, with detailed occurrence tracking.

#### Critical Columns

| Column                     | Type         | Purpose                       | Guide Reference                     |
| :------------------------- | :----------- | :---------------------------- | :---------------------------------- |
| `report_id`                | VARCHAR(50)  | Links to report (PK1)         | Foreign key                         |
| `person_id`                | INTEGER      | Patient identifier (PK2)      | Each patient counted once           |
| `first_occurrence_date`    | DATE         | First recorded occurrence     | Tracking for classification         |
| `last_occurrence_date`     | DATE         | Most recent occurrence        | Tracking for validation             |
| `total_occurrences`        | INTEGER      | Count of occurrences          | Audit trail                         |
| `age_group`                | VARCHAR(20)  | Stratification (denormalized) | Performance optimization            |
| `gender`                   | VARCHAR(20)  | Stratification (denormalized) | Performance optimization            |
| `region`                   | VARCHAR(100) | Stratification (denormalized) | Performance optimization            |
| `is_incident_in_period`    | BOOLEAN      | First-ever case in period?    | Section II.B: Incident vs Prevalent |
| `is_prevalent_from_prior`  | BOOLEAN      | Case existed before period?   | Section II.B: Incident vs Prevalent |
| `condition_occurrence_ids` | TEXT         | Links to source records       | Section III.1: Traceability         |

#### Population Logic

```sql
-- Step 1: Identify all patients with condition occurrence during reporting period
-- Step 2: Count each patient once (regardless of multiple occurrences)
-- Step 3: Classify as incident vs prevalent from prior
-- Step 4: Link to source CONDITION_OCCURRENCE records

INSERT INTO prevalence_cases (
    report_id,
    person_id,
    first_occurrence_date,
    last_occurrence_date,
    total_occurrences,
    age_group,
    gender,
    region,
    is_incident_in_period,
    is_prevalent_from_prior,
    condition_occurrence_ids
)
SELECT 
    'PREV_DIABETES_2024' AS report_id,
    co.person_id,
    MIN(co.condition_start_date) AS first_occurrence_date,
    MAX(co.condition_start_date) AS last_occurrence_date,
    COUNT(*) AS total_occurrences,
    -- Stratification from denominator table
    d.age_group,
    d.gender,
    d.region,
    -- Classification logic
    MIN(co.condition_start_date) >= '2024-01-01' AS is_incident_in_period,
    MIN(co.condition_start_date) < '2024-01-01' AS is_prevalent_from_prior,
    -- Source record linkage
    STRING_AGG(co.condition_occurrence_id::TEXT, ',' ORDER BY co.condition_start_date) AS condition_occurrence_ids
FROM condition_occurrence co
JOIN prevalence_denominator d 
    ON co.person_id = d.person_id 
    AND d.report_id = 'PREV_DIABETES_2024'
WHERE 
    -- Condition matches report
    co.condition_concept_id = 201826  -- Type 2 Diabetes
    -- Occurrence during reporting period OR patient has history
    AND (
        (co.condition_start_date BETWEEN '2024-01-01' AND '2024-12-31')
        OR 
        (co.condition_start_date < '2024-01-01' 
         AND co.condition_end_date >= '2024-01-01')
    )
GROUP BY 
    co.person_id, d.age_group, d.gender, d.region;
```

#### Key Concept: One Patient, One Record

**Important:** Regardless of how many times a patient has the condition recorded, they appear **exactly once** in this table. This implements the guide requirement: "Number of patients with ≥1 event in the time window" (Section II.B).

```sql
-- CORRECT: Counts each patient once
SELECT COUNT(DISTINCT person_id) FROM prevalence_cases;

-- INCORRECT: Would count multiple occurrences per patient
SELECT COUNT(*) FROM condition_occurrence;
```

#### Validation Rules

```sql
-- Rule 1: Occurrence dates must be valid
CHECK (last_occurrence_date >= first_occurrence_date)

-- Rule 2: At least one occurrence
CHECK (total_occurrences > 0)

-- Rule 3: Must be either incident OR prevalent from prior (not both)
CHECK (
    (is_incident_in_period = TRUE AND is_prevalent_from_prior = FALSE) OR
    (is_incident_in_period = FALSE AND is_prevalent_from_prior = TRUE)
)
```

---

### 3.4 prevalence_aggregated

**Purpose:** Stores final calculated prevalence metrics by stratification dimensions. This is the primary table for report generation.

#### Critical Columns

| Column                     | Type          | Purpose                          | Guide Reference                   |
| :------------------------- | :------------ | :------------------------------- | :-------------------------------- |
| `report_id`                | VARCHAR(50)   | Links to report (PK1)            | Foreign key                       |
| `stratification_level`     | VARCHAR(50)   | Dimension being stratified (PK2) | e.g., 'age_group', 'gender'       |
| `stratum_value`            | VARCHAR(100)  | Specific value of stratum (PK3)  | e.g., '18-34', 'Female'           |
| `denominator`              | INTEGER       | Eligible patient count           | Section II.B: Denominator         |
| `prevalent_cases`          | INTEGER       | Case count                       | Section II.B: Cases               |
| `prevalence_rate_raw`      | DECIMAL(10,6) | Unrounded calculation            | Intermediate calculation          |
| `prevalence_rate_display`  | DECIMAL(5,1)  | Rounded to 1 decimal             | Section II.B: Rounding            |
| `incident_cases_in_period` | INTEGER       | Subset: new cases                | Section II.B: Case classification |
| `prevalent_from_prior`     | INTEGER       | Subset: pre-existing cases       | Section II.B: Case classification |
| `prevalence_ci_lower_95`   | DECIMAL(5,1)  | 95% CI lower bound               | Optional metric                   |
| `prevalence_ci_upper_95`   | DECIMAL(5,1)  | 95% CI upper bound               | Optional metric                   |

#### Population Logic

```sql
-- Step 1: Aggregate denominator by stratification
-- Step 2: Aggregate cases by stratification
-- Step 3: Calculate prevalence rate
-- Step 4: Round for display (1 decimal place per guide)

INSERT INTO prevalence_aggregated (
    report_id,
    stratification_level,
    stratum_value,
    denominator,
    prevalent_cases,
    prevalence_rate_raw,
    prevalence_rate_display,
    incident_cases_in_period,
    prevalent_from_prior
)
-- Age Group Stratification
SELECT 
    'PREV_DIABETES_2024' AS report_id,
    'age_group' AS stratification_level,
    d.age_group AS stratum_value,
    COUNT(DISTINCT d.person_id) AS denominator,
    COUNT(DISTINCT c.person_id) AS prevalent_cases,
    -- Raw calculation (full precision)
    (COUNT(DISTINCT c.person_id)::DECIMAL / 
     COUNT(DISTINCT d.person_id)::DECIMAL * 100) AS prevalence_rate_raw,
    -- Display calculation (1 decimal per guide Section II.B)
    ROUND(
        (COUNT(DISTINCT c.person_id)::DECIMAL / 
         COUNT(DISTINCT d.person_id)::DECIMAL * 100),
        1
    ) AS prevalence_rate_display,
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END) AS incident_cases_in_period,
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END) AS prevalent_from_prior
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c 
    ON d.report_id = c.report_id 
    AND d.person_id = c.person_id
WHERE 
    d.report_id = 'PREV_DIABETES_2024'
    AND d.meets_observation_requirement = TRUE
GROUP BY d.age_group

UNION ALL

-- Gender Stratification
SELECT 
    'PREV_DIABETES_2024' AS report_id,
    'gender' AS stratification_level,
    d.gender AS stratum_value,
    COUNT(DISTINCT d.person_id) AS denominator,
    COUNT(DISTINCT c.person_id) AS prevalent_cases,
    (COUNT(DISTINCT c.person_id)::DECIMAL / 
     COUNT(DISTINCT d.person_id)::DECIMAL * 100) AS prevalence_rate_raw,
    ROUND(
        (COUNT(DISTINCT c.person_id)::DECIMAL / 
         COUNT(DISTINCT d.person_id)::DECIMAL * 100),
        1
    ) AS prevalence_rate_display,
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END) AS incident_cases_in_period,
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END) AS prevalent_from_prior
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c 
    ON d.report_id = c.report_id 
    AND d.person_id = c.person_id
WHERE 
    d.report_id = 'PREV_DIABETES_2024'
    AND d.meets_observation_requirement = TRUE
GROUP BY d.gender

UNION ALL

-- Overall (All patients)
SELECT 
    'PREV_DIABETES_2024' AS report_id,
    'overall' AS stratification_level,
    'All' AS stratum_value,
    COUNT(DISTINCT d.person_id) AS denominator,
    COUNT(DISTINCT c.person_id) AS prevalent_cases,
    (COUNT(DISTINCT c.person_id)::DECIMAL / 
     COUNT(DISTINCT d.person_id)::DECIMAL * 100) AS prevalence_rate_raw,
    ROUND(
        (COUNT(DISTINCT c.person_id)::DECIMAL / 
         COUNT(DISTINCT d.person_id)::DECIMAL * 100),
        1
    ) AS prevalence_rate_display,
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END) AS incident_cases_in_period,
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END) AS prevalent_from_prior
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c 
    ON d.report_id = c.report_id 
    AND d.person_id = c.person_id
WHERE 
    d.report_id = 'PREV_DIABETES_2024'
    AND d.meets_observation_requirement = TRUE;
```

#### Validation Rules

```sql
-- Rule 1: Denominator must be positive
CHECK (denominator > 0)

-- Rule 2: Cases cannot exceed denominator
CHECK (prevalent_cases <= denominator)

-- Rule 3: Prevalence must be between 0 and 100
CHECK (prevalence_rate_display >= 0 AND prevalence_rate_display <= 100)

-- Rule 4: Case breakdown must sum correctly
CHECK (
    prevalent_cases = COALESCE(incident_cases_in_period, 0) + 
                      COALESCE(prevalent_from_prior, 0)
    OR (incident_cases_in_period IS NULL AND prevalent_from_prior IS NULL)
)
```

#### Stratification Ordering

For proper display, use this ordering logic (per Section III.3):

```sql
ORDER BY 
    stratification_level,
    CASE 
        WHEN stratum_value = 'All' THEN 0       -- Overall first
        WHEN stratum_value = 'Unknown' THEN 999 -- Unknown last
        ELSE 1                                   -- Others alphabetically
    END,
    stratum_value;
```

---

### 3.5 prevalence_quality_checks

**Purpose:** Documents validation results for each report, implementing the guide's quality assurance checklist (Section IV).

#### Critical Columns

| Column              | Type         | Purpose                       | Guide Reference   |
| :------------------ | :----------- | :---------------------------- | :---------------- |
| `report_id`         | VARCHAR(50)  | Links to report (PK1)         | Foreign key       |
| `check_name`        | VARCHAR(100) | Unique check identifier (PK2) | Checklist item    |
| `check_category`    | VARCHAR(50)  | Type of check                 | Organization      |
| `check_status`      | VARCHAR(20)  | PASS/FAIL/WARNING             | Validation result |
| `check_description` | TEXT         | What is being checked         | Documentation     |
| `check_result`      | TEXT         | Details of result             | Audit trail       |
| `expected_value`    | TEXT         | What should happen            | Validation spec   |
| `actual_value`      | TEXT         | What actually happened        | Comparison        |

#### Standard Quality Checks

```sql
-- Check 1: All cases in denominator
INSERT INTO prevalence_quality_checks VALUES (
    'PREV_DIABETES_2024',
    'cases_in_denominator',
    'denominator',
    'PASS',
    'Verify all prevalent cases are in the eligible denominator',
    'All 7,432 cases found in denominator of 56,478 patients',
    '0 cases outside denominator',
    '0 cases outside denominator'
);

-- Check 2: Minimum observation requirement
INSERT INTO prevalence_quality_checks VALUES (
    'PREV_DIABETES_2024',
    'minimum_observation',
    'denominator',
    'PASS',
    'Verify all eligible patients have ≥365 days observation',
    'All 56,478 eligible patients meet minimum observation',
    '≥365 days for all',
    '100% compliance'
);

-- Check 3: Prevalence calculation accuracy
INSERT INTO prevalence_quality_checks VALUES (
    'PREV_DIABETES_2024',
    'prevalence_calculation',
    'calculation',
    'PASS',
    'Verify prevalence = (cases/denominator) × 100 rounded to 1 decimal',
    'All strata calculations verified. Max deviation: 0.0%',
    'Match formula with 1 decimal rounding',
    'All match exactly'
);

-- Check 4: Missing data handling
INSERT INTO prevalence_quality_checks VALUES (
    'PREV_DIABETES_2024',
    'missing_data_handling',
    'formatting',
    'PASS',
    'Verify missing demographics coded as "Unknown"',
    '234 patients with missing age coded as Unknown age_group',
    'All missing coded as "Unknown"',
    'All missing coded as "Unknown"'
);

-- Check 5: Rounding consistency
INSERT INTO prevalence_quality_checks VALUES (
    'PREV_DIABETES_2024',
    'rounding_consistency',
    'formatting',
    'PASS',
    'Verify prevalence rounded to 1 decimal place',
    'All 15 strata display values rounded to 1 decimal',
    '1 decimal place',
    '1 decimal place'
);
```

---

### 3.6 prevalence_report_footnotes

**Purpose:** Stores required documentation for complete table captions (Section III.1).

#### Standard Footnotes

```sql
-- Footnote 1: Source tables
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    1,
    'source',
    'Source: PERSON, COHORT, OBSERVATION_PERIOD, CONDITION_OCCURRENCE tables.'
);

-- Footnote 2: Calculation formula
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    2,
    'calculation',
    'Prevalence calculated as (prevalent_cases / denominator) × 100.'
);

-- Footnote 3: Denominator definition
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    3,
    'denominator',
    'Denominator includes all patients with ≥365 days of observation during 2024 (January 1 - December 31, 2024).'
);

-- Footnote 4: Case definition
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    4,
    'cases',
    'Prevalent cases include all patients with at least one Type 2 Diabetes diagnosis during 2024, regardless of onset date.'
);

-- Footnote 5: Rounding
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    5,
    'rounding',
    'Prevalence rounded to 1 decimal place.'
);

-- Footnote 6: Missing data
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    6,
    'missing_data',
    'Missing age or gender coded as "Unknown".'
);

-- Footnote 7: Traceability
INSERT INTO prevalence_report_footnotes VALUES (
    'PREV_DIABETES_2024',
    7,
    'query',
    'Query: diabetes_prevalence_2024.sql'
);
```

---

## 4. Data Flow and Population

### 4.1 Step-by-Step Population Sequence

```
Step 1: Create Report Metadata
    ↓
Step 2: Populate Denominator
    ├── Extract all patients from PERSON
    ├── Join with OBSERVATION_PERIOD
    ├── Calculate total observation days
    ├── Apply ≥365 day filter
    ├── Link to COHORT
    └── Assign stratification dimensions
    ↓
Step 3: Identify Prevalent Cases
    ├── Query CONDITION_OCCURRENCE
    ├── Filter to reporting period
    ├── Join with denominator
    ├── Count each patient once
    ├── Classify incident vs prevalent
    └── Link to source records
    ↓
Step 4: Calculate Aggregated Metrics
    ├── Group by stratification dimensions
    ├── Count denominator and cases
    ├── Calculate prevalence rate
    ├── Round to 1 decimal for display
    └── Calculate optional CI
    ↓
Step 5: Run Quality Checks
    ├── Execute validation function
    ├── Store results in quality_checks table
    └── Review for PASS/FAIL
    ↓
Step 6: Generate Footnotes
    ├── Create standard footnotes
    └── Add report-specific caveats
    ↓
Step 7: Generate Final Report
    └── Use v_prevalence_report_output view
```

### 4.2 Complete Population Script Template

```sql
-- ============================================================
-- PREVALENCE REPORT POPULATION SCRIPT
-- ============================================================
-- Report: Diabetes Prevalence 2024
-- Condition: Type 2 Diabetes (concept_id: 201826)
-- Period: Calendar Year 2024
-- ============================================================

BEGIN;

-- Step 1: Create report metadata
INSERT INTO prevalence_report_metadata (
    report_id,
    report_title,
    condition_concept_id,
    condition_name,
    reporting_period_start_date,
    reporting_period_end_date,
    minimum_observation_days,
    cohort_definition_id,
    source_query_path,
    generation_timestamp,
    generated_by,
    denominator_definition,
    case_definition
) VALUES (
    'PREV_DIABETES_2024',
    'Type 2 Diabetes Prevalence by Age Group and Gender (Calendar Year 2024)',
    201826,
    'Type 2 Diabetes Mellitus',
    '2024-01-01',
    '2024-12-31',
    365,
    1001,
    '/queries/prevalence/diabetes_2024.sql',
    CURRENT_TIMESTAMP,
    'analytics_pipeline',
    'Patients with ≥365 days observation during or prior to 2024',
    'Patients with at least one T2DM diagnosis during 2024'
);

-- Step 2: Populate denominator
INSERT INTO prevalence_denominator (
    report_id, person_id, age_group, gender, region,
    total_observation_days, observation_start_date, observation_end_date,
    meets_observation_requirement, cohort_start_date, cohort_end_date
)
SELECT 
    'PREV_DIABETES_2024',
    p.person_id,
    CASE 
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) BETWEEN 18 AND 34 THEN '18-34'
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) BETWEEN 35 AND 49 THEN '35-49'
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) BETWEEN 50 AND 64 THEN '50-64'
        WHEN EXTRACT(YEAR FROM AGE('2024-12-31', p.birth_date)) >= 65 THEN '65+'
        ELSE 'Unknown'
    END,
    COALESCE(p.gender, 'Unknown'),
    COALESCE(p.region, 'Unknown'),
    SUM(LEAST(op.observation_period_end_date, '2024-12-31') - 
        GREATEST(op.observation_period_start_date, '2024-01-01') + 1),
    MIN(op.observation_period_start_date),
    MAX(op.observation_period_end_date),
    SUM(op.observation_period_end_date - op.observation_period_start_date + 1) >= 365,
    c.cohort_start_date,
    c.cohort_end_date
FROM person p
JOIN observation_period op ON p.person_id = op.person_id
LEFT JOIN cohort c ON p.person_id = c.person_id 
    AND c.cohort_definition_id = 1001
WHERE 
    op.observation_period_start_date <= '2024-12-31'
    AND op.observation_period_end_date >= '2024-01-01'
GROUP BY p.person_id, p.birth_date, p.gender, p.region,
         c.cohort_start_date, c.cohort_end_date;

-- Step 3: Identify prevalent cases
INSERT INTO prevalence_cases (
    report_id, person_id,
    first_occurrence_date, last_occurrence_date, total_occurrences,
    age_group, gender, region,
    is_incident_in_period, is_prevalent_from_prior,
    condition_occurrence_ids
)
SELECT 
    'PREV_DIABETES_2024',
    co.person_id,
    MIN(co.condition_start_date),
    MAX(co.condition_start_date),
    COUNT(*),
    d.age_group,
    d.gender,
    d.region,
    MIN(co.condition_start_date) >= '2024-01-01',
    MIN(co.condition_start_date) < '2024-01-01',
    STRING_AGG(co.condition_occurrence_id::TEXT, ',' ORDER BY co.condition_start_date)
FROM condition_occurrence co
JOIN prevalence_denominator d 
    ON co.person_id = d.person_id 
    AND d.report_id = 'PREV_DIABETES_2024'
    AND d.meets_observation_requirement = TRUE
WHERE 
    co.condition_concept_id IN (
        SELECT descendant_concept_id 
        FROM concept_ancestor 
        WHERE ancestor_concept_id = 201826
    )
    AND (
        (co.condition_start_date BETWEEN '2024-01-01' AND '2024-12-31')
        OR 
        (co.condition_start_date < '2024-01-01' 
         AND COALESCE(co.condition_end_date, '9999-12-31') >= '2024-01-01')
    )
GROUP BY co.person_id, d.age_group, d.gender, d.region;

-- Step 4: Calculate aggregated metrics
INSERT INTO prevalence_aggregated (
    report_id, stratification_level, stratum_value,
    denominator, prevalent_cases,
    prevalence_rate_raw, prevalence_rate_display,
    incident_cases_in_period, prevalent_from_prior
)
-- Age Group
SELECT 
    'PREV_DIABETES_2024', 'age_group', d.age_group,
    COUNT(DISTINCT d.person_id),
    COUNT(DISTINCT c.person_id),
    (COUNT(DISTINCT c.person_id)::DECIMAL / COUNT(DISTINCT d.person_id)::DECIMAL * 100),
    ROUND((COUNT(DISTINCT c.person_id)::DECIMAL / COUNT(DISTINCT d.person_id)::DECIMAL * 100), 1),
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END),
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END)
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c ON d.report_id = c.report_id AND d.person_id = c.person_id
WHERE d.report_id = 'PREV_DIABETES_2024' AND d.meets_observation_requirement = TRUE
GROUP BY d.age_group
UNION ALL
-- Gender
SELECT 
    'PREV_DIABETES_2024', 'gender', d.gender,
    COUNT(DISTINCT d.person_id),
    COUNT(DISTINCT c.person_id),
    (COUNT(DISTINCT c.person_id)::DECIMAL / COUNT(DISTINCT d.person_id)::DECIMAL * 100),
    ROUND((COUNT(DISTINCT c.person_id)::DECIMAL / COUNT(DISTINCT d.person_id)::DECIMAL * 100), 1),
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END),
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END)
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c ON d.report_id = c.report_id AND d.person_id = c.person_id
WHERE d.report_id = 'PREV_DIABETES_2024' AND d.meets_observation_requirement = TRUE
GROUP BY d.gender
UNION ALL
-- Overall
SELECT 
    'PREV_DIABETES_2024', 'overall', 'All',
    COUNT(DISTINCT d.person_id),
    COUNT(DISTINCT c.person_id),
    (COUNT(DISTINCT c.person_id)::DECIMAL / COUNT(DISTINCT d.person_id)::DECIMAL * 100),
    ROUND((COUNT(DISTINCT c.person_id)::DECIMAL / COUNT(DISTINCT d.person_id)::DECIMAL * 100), 1),
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END),
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END)
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c ON d.report_id = c.report_id AND d.person_id = c.person_id
WHERE d.report_id = 'PREV_DIABETES_2024' AND d.meets_observation_requirement = TRUE;

-- Step 5: Run quality checks
INSERT INTO prevalence_quality_checks (report_id, check_name, check_category, check_status, check_description, check_result)
SELECT * FROM validate_prevalence_calculation('PREV_DIABETES_2024');

-- Step 6: Generate footnotes
INSERT INTO prevalence_report_footnotes (report_id, footnote_order, footnote_type, footnote_text)
VALUES
    ('PREV_DIABETES_2024', 1, 'source', 
     'Source: PERSON, COHORT, OBSERVATION_PERIOD, CONDITION_OCCURRENCE tables.'),
    ('PREV_DIABETES_2024', 2, 'calculation', 
     'Prevalence calculated as (prevalent_cases / denominator) × 100.'),
    ('PREV_DIABETES_2024', 3, 'denominator', 
     'Denominator includes all patients with ≥365 days of observation during 2024.'),
    ('PREV_DIABETES_2024', 4, 'cases', 
     'Prevalent cases include all patients with at least one T2DM diagnosis during 2024.'),
    ('PREV_DIABETES_2024', 5, 'rounding', 
     'Prevalence rounded to 1 decimal place.'),
    ('PREV_DIABETES_2024', 6, 'missing_data', 
     'Missing age or gender coded as "Unknown".'),
    ('PREV_DIABETES_2024', 7, 'query', 
     'Query: /queries/prevalence/diabetes_2024.sql');

COMMIT;

-- Step 7: Verify results
SELECT * FROM v_prevalence_report_output 
WHERE report_id = 'PREV_DIABETES_2024'
ORDER BY stratification_level, stratum_value;
```

---

## 5. Calculation Logic

### 5.1 Core Formula

**Prevalence (%) = (Prevalent Cases / Denominator) × 100**

#### Component Definitions

**Denominator:**
```sql
-- Count of UNIQUE patients meeting eligibility criteria
SELECT COUNT(DISTINCT person_id)
FROM prevalence_denominator
WHERE report_id = 'PREV_DIABETES_2024'
  AND meets_observation_requirement = TRUE;
```

**Prevalent Cases:**
```sql
-- Count of UNIQUE patients with condition
SELECT COUNT(DISTINCT person_id)
FROM prevalence_cases
WHERE report_id = 'PREV_DIABETES_2024';
```

**Prevalence Rate:**
```sql
-- Final calculation with rounding
SELECT 
    ROUND(
        (COUNT(DISTINCT c.person_id)::DECIMAL / 
         COUNT(DISTINCT d.person_id)::DECIMAL * 100),
        1  -- Round to 1 decimal place per guide
    ) AS prevalence_percentage
FROM prevalence_denominator d
LEFT JOIN prevalence_cases c 
    ON d.person_id = c.person_id 
    AND d.report_id = c.report_id
WHERE d.report_id = 'PREV_DIABETES_2024'
  AND d.meets_observation_requirement = TRUE;
```

### 5.2 Worked Example

**Scenario:** Calculate diabetes prevalence for age group 50-64

**Step 1: Count denominator**
```sql
SELECT COUNT(DISTINCT person_id)
FROM prevalence_denominator
WHERE report_id = 'PREV_DIABETES_2024'
  AND age_group = '50-64'
  AND meets_observation_requirement = TRUE;
-- Result: 18,234 patients
```

**Step 2: Count cases**
```sql
SELECT COUNT(DISTINCT person_id)
FROM prevalence_cases
WHERE report_id = 'PREV_DIABETES_2024'
  AND age_group = '50-64';
-- Result: 3,287 patients
```

**Step 3: Calculate prevalence**
```sql
SELECT ROUND((3287::DECIMAL / 18234::DECIMAL * 100), 1);
-- Result: 18.0%
```

**Step 4: Verify stored value**
```sql
SELECT prevalence_rate_display
FROM prevalence_aggregated
WHERE report_id = 'PREV_DIABETES_2024'
  AND stratification_level = 'age_group'
  AND stratum_value = '50-64';
-- Expected: 18.0
```

### 5.3 Rounding Logic

Per Section II.B of the guide: **Round to 1 decimal place for display**

**Critical Rule:** Round only at final display, not in intermediate calculations.

```sql
-- CORRECT: Store both raw and display values
prevalence_rate_raw    = 18.032447  -- Full precision
prevalence_rate_display = 18.0       -- Rounded to 1 decimal

-- INCORRECT: Rounding too early causes error accumulation
-- Don't do this:
intermediate_value = ROUND(numerator / denominator, 1)  -- Wrong!
final_value = intermediate_value * 100                   -- Compounds error
```

### 5.4 Confidence Intervals (Optional)

For 95% confidence intervals using Wilson score method:

```sql
WITH calc AS (
    SELECT 
        denominator AS n,
        prevalent_cases AS x,
        prevalent_cases::DECIMAL / denominator::DECIMAL AS p
    FROM prevalence_aggregated
    WHERE report_id = 'PREV_DIABETES_2024'
)
SELECT 
    ROUND(
        ((p + 1.96^2/(2*n) - 1.96 * SQRT(p*(1-p)/n + 1.96^2/(4*n^2))) / 
         (1 + 1.96^2/n)) * 100,
        1
    ) AS ci_lower_95,
    ROUND(
        ((p + 1.96^2/(2*n) + 1.96 * SQRT(p*(1-p)/n + 1.96^2/(4*n^2))) / 
         (1 + 1.96^2/n)) * 100,
        1
    ) AS ci_upper_95
FROM calc;
```

---

## 6. Quality Assurance

### 6.1 Automated Validation Function

The schema includes `validate_prevalence_calculation()` function that performs comprehensive checks:

```sql
-- Execute validation
SELECT * FROM validate_prevalence_calculation('PREV_DIABETES_2024');

-- Expected output:
┌──────────────────────────┬──────────────┬─────────────────────────────────┐
│ check_name               │ check_status │ message                         │
├──────────────────────────┼──────────────┼─────────────────────────────────┤
│ cases_in_denominator     │ PASS         │ All cases are in denominator    │
│ prevalence_calculation   │ PASS         │ Max deviation: 0.0              │
│ minimum_observation      │ PASS         │ All eligible patients meet req  │
└──────────────────────────┴──────────────┴─────────────────────────────────┘
```

### 6.2 Manual Validation Checklist

Implement the guide's Section IV checklist:

**☐ Checkpoint 1: Title**
```sql
SELECT report_title 
FROM prevalence_report_metadata 
WHERE report_id = 'PREV_DIABETES_2024';
-- Verify: Descriptive, includes condition, period, stratification
```

**☐ Checkpoint 2: Metrics**
```sql
-- Verify column names in aggregated table include units
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'prevalence_aggregated';
-- Look for: prevalence_rate_display (implies %)
```

**☐ Checkpoint 3: Denominator Definition**
```sql
SELECT denominator_definition 
FROM prevalence_report_metadata 
WHERE report_id = 'PREV_DIABETES_2024';
-- Verify: Mentions ≥365 days observation requirement
```

**☐ Checkpoint 4: Case Definition**
```sql
SELECT case_definition 
FROM prevalence_report_metadata 
WHERE report_id = 'PREV_DIABETES_2024';
-- Verify: Clear description of what constitutes a case
```

**☐ Checkpoint 5: Calculation Accuracy**
```sql
SELECT 
    stratification_level,
    stratum_value,
    denominator,
    prevalent_cases,
    prevalence_rate_display AS stored_value,
    ROUND((prevalent_cases::DECIMAL / denominator::DECIMAL * 100), 1) AS calculated_value,
    ABS(prevalence_rate_display - ROUND((prevalent_cases::DECIMAL / denominator::DECIMAL * 100), 1)) AS deviation
FROM prevalence_aggregated
WHERE report_id = 'PREV_DIABETES_2024';
-- Verify: deviation = 0.0 for all rows
```

**☐ Checkpoint 6: Missing Data Handling**
```sql
SELECT DISTINCT age_group 
FROM prevalence_aggregated 
WHERE report_id = 'PREV_DIABETES_2024' 
  AND stratification_level = 'age_group';
-- Verify: "Unknown" category present if applicable
```

**☐ Checkpoint 7: Footnotes Complete**
```sql
SELECT COUNT(*) AS footnote_count
FROM prevalence_report_footnotes
WHERE report_id = 'PREV_DIABETES_2024';
-- Verify: At least 7 standard footnotes (source, calculation, denominator, cases, rounding, missing data, query)
```

**☐ Checkpoint 8: No Duplicate Patients**
```sql
SELECT person_id, COUNT(*) 
FROM prevalence_cases 
WHERE report_id = 'PREV_DIABETES_2024'
GROUP BY person_id 
HAVING COUNT(*) > 1;
-- Verify: No results (each patient appears once)
```

### 6.3 Data Quality Metrics

Monitor these metrics for each report:

```sql
WITH metrics AS (
    SELECT 
        d.report_id,
        COUNT(DISTINCT d.person_id) AS total_in_denominator,
        SUM(CASE WHEN d.meets_observation_requirement THEN 1 ELSE 0 END) AS eligible_patients,
        COUNT(DISTINCT c.person_id) AS prevalent_cases,
        ROUND(AVG(d.total_observation_days), 0) AS avg_observation_days,
        SUM(CASE WHEN d.age_group = 'Unknown' THEN 1 ELSE 0 END) AS missing_age,
        SUM(CASE WHEN d.gender = 'Unknown' THEN 1 ELSE 0 END) AS missing_gender
    FROM prevalence_denominator d
    LEFT JOIN prevalence_cases c ON d.report_id = c.report_id AND d.person_id = c.person_id
    WHERE d.report_id = 'PREV_DIABETES_2024'
    GROUP BY d.report_id
)
SELECT 
    *,
    ROUND((prevalent_cases::DECIMAL / eligible_patients::DECIMAL * 100), 1) AS overall_prevalence,
    ROUND((missing_age::DECIMAL / total_in_denominator::DECIMAL * 100), 1) AS pct_missing_age,
    ROUND((missing_gender::DECIMAL / total_in_denominator::DECIMAL * 100), 1) AS pct_missing_gender
FROM metrics;
```

---

## 7. Usage Examples

### 7.1 Generate Complete Report

```sql
-- Use the built-in view for final output
SELECT 
    report_title,
    condition_name,
    TO_CHAR(reporting_period_start_date, 'YYYY-MM-DD') || ' to ' || 
    TO_CHAR(reporting_period_end_date, 'YYYY-MM-DD') AS reporting_period,
    stratification_level,
    stratum_value,
    eligible_patients AS denominator,
    prevalent_cases AS cases,
    prevalence_percentage || '%' AS prevalence
FROM v_prevalence_report_output
WHERE report_id = 'PREV_DIABETES_2024'
ORDER BY 
    stratification_level,
    CASE 
        WHEN stratum_value = 'All' THEN 0
        WHEN stratum_value = 'Unknown' THEN 999
        ELSE 1
    END,
    stratum_value;
```

**Output:**
```
┌───────────────────────────┬──────────┬─────┬────────────┐
│ Stratification │ Stratum  │ Denom │ Cases │ Prevalence │
├────────────────┼──────────┼───────┼───────┼────────────┤
│ age_group      │ 18-34    │12,456 │   423 │ 3.4%       │
│ age_group      │ 35-49    │15,678 │ 1,254 │ 8.0%       │
│ age_group      │ 50-64    │18,234 │ 3,287 │ 18.0%      │
│ age_group      │ 65+      │ 9,876 │ 2,456 │ 24.9%      │
│ age_group      │ Unknown  │   234 │    12 │ 5.1%       │
│ gender         │ Female   │28,567 │ 3,892 │ 13.6%      │
│ gender         │ Male     │27,789 │ 3,528 │ 12.7%      │
│ gender         │ Unknown  │   122 │    12 │ 9.8%       │
│ overall        │ All      │56,478 │ 7,432 │ 13.2%      │
└────────────────┴──────────┴───────┴───────┴────────────┘
```

### 7.2 Generate Caption with Footnotes

```sql
SELECT 
    m.report_title,
    STRING_AGG(f.footnote_text, ' ' ORDER BY f.footnote_order) AS caption
FROM prevalence_report_metadata m
JOIN prevalence_report_footnotes f ON m.report_id = f.report_id
WHERE m.report_id = 'PREV_DIABETES_2024'
GROUP BY m.report_title;
```

### 7.3 Compare Across Time Periods

```sql
SELECT 
    EXTRACT(YEAR FROM m.reporting_period_start_date) AS year,
    a.stratum_value AS age_group,
    a.prevalent_cases,
    a.denominator,
    a.prevalence_rate_display
FROM prevalence_aggregated a
JOIN prevalence_report_metadata m ON a.report_id = m.report_id
WHERE m.condition_concept_id = 201826  -- Diabetes
  AND a.stratification_level = 'age_group'
  AND EXTRACT(YEAR FROM m.reporting_period_start_date) IN (2022, 2023, 2024)
ORDER BY year, age_group;
```

### 7.4 Drill Down to Patient Level

```sql
-- Find all patients in a specific stratum
SELECT 
    c.person_id,
    c.first_occurrence_date,
    c.total_occurrences,
    c.is_incident_in_period,
    d.total_observation_days
FROM prevalence_cases c
JOIN prevalence_denominator d ON c.report_id = d.report_id AND c.person_id = d.person_id
WHERE c.report_id = 'PREV_DIABETES_2024'
  AND c.age_group = '50-64'
  AND c.gender = 'Female'
ORDER BY c.first_occurrence_date;
```

### 7.5 Export for Publication

```sql
-- Generate publication-ready table with proper formatting
SELECT 
    stratum_value AS "Age Group",
    TO_CHAR(denominator, 'FM999,999') AS "Eligible Patients",
    TO_CHAR(prevalent_cases, 'FM999,999') AS "Prevalent Cases",
    TO_CHAR(prevalence_rate_display, 'FM990.0') || '%' AS "Prevalence (%)"
FROM prevalence_aggregated
WHERE report_id = 'PREV_DIABETES_2024'
  AND stratification_level = 'age_group'
ORDER BY 
    CASE 
        WHEN stratum_value = 'All' THEN 0
        WHEN stratum_value = 'Unknown' THEN 999
        ELSE 1
    END,
    stratum_value;
```

---

## 8. Validation Procedures

### 8.1 Pre-Publication Validation Script

Run this complete validation before publishing any report:

```sql
-- ====================================
-- PREVALENCE REPORT VALIDATION SCRIPT
-- ====================================

\echo '==========================================';
\echo 'PREVALENCE REPORT VALIDATION';
\echo 'Report ID: PREV_DIABETES_2024';
\echo '==========================================';

-- Test 1: Metadata exists
\echo '\nTest 1: Metadata Completeness';
SELECT 
    CASE 
        WHEN COUNT(*) = 1 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    'Metadata record exists' AS test
FROM prevalence_report_metadata
WHERE report_id = 'PREV_DIABETES_2024';

-- Test 2: Denominator populated
\echo '\nTest 2: Denominator Population';
SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    'Denominator has ' || COUNT(*) || ' patients' AS test
FROM prevalence_denominator
WHERE report_id = 'PREV_DIABETES_2024';

-- Test 3: All eligible patients meet requirement
\echo '\nTest 3: Eligibility Criteria';
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' patients fail requirement'
    END AS status,
    'All eligible patients have ≥365 days observation' AS test
FROM prevalence_denominator
WHERE report_id = 'PREV_DIABETES_2024'
  AND meets_observation_requirement = TRUE
  AND total_observation_days < 365;

-- Test 4: All cases in denominator
\echo '\nTest 4: Case-Denominator Integrity';
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' cases not in denominator'
    END AS status,
    'All cases are in eligible denominator' AS test
FROM prevalence_cases c
LEFT JOIN prevalence_denominator d 
    ON c.report_id = d.report_id 
    AND c.person_id = d.person_id
    AND d.meets_observation_requirement = TRUE
WHERE c.report_id = 'PREV_DIABETES_2024'
  AND d.person_id IS NULL;

-- Test 5: No duplicate patients in cases
\echo '\nTest 5: Patient Uniqueness';
SELECT 
    CASE 
        WHEN MAX(cnt) = 1 THEN 'PASS'
        ELSE 'FAIL - Duplicate patients found'
    END AS status,
    'Each patient appears once in cases' AS test
FROM (
    SELECT person_id, COUNT(*) AS cnt
    FROM prevalence_cases
    WHERE report_id = 'PREV_DIABETES_2024'
    GROUP BY person_id
) subq;

-- Test 6: Prevalence calculation accuracy
\echo '\nTest 6: Calculation Accuracy';
SELECT 
    CASE 
        WHEN MAX(deviation) < 0.01 THEN 'PASS'
        ELSE 'FAIL - Max deviation: ' || MAX(deviation)
    END AS status,
    'Prevalence calculations match formula' AS test
FROM (
    SELECT 
        ABS(prevalence_rate_display - 
            ROUND((prevalent_cases::DECIMAL / denominator::DECIMAL * 100), 1)) AS deviation
    FROM prevalence_aggregated
    WHERE report_id = 'PREV_DIABETES_2024'
) subq;

-- Test 7: Aggregated sums match detail
\echo '\nTest 7: Aggregation Consistency';
WITH overall_agg AS (
    SELECT denominator, prevalent_cases
    FROM prevalence_aggregated
    WHERE report_id = 'PREV_DIABETES_2024'
      AND stratification_level = 'overall'
),
detail_sum AS (
    SELECT 
        COUNT(DISTINCT d.person_id) AS denom_count,
        COUNT(DISTINCT c.person_id) AS case_count
    FROM prevalence_denominator d
    LEFT JOIN prevalence_cases c ON d.report_id = c.report_id AND d.person_id = c.person_id
    WHERE d.report_id = 'PREV_DIABETES_2024'
      AND d.meets_observation_requirement = TRUE
)
SELECT 
    CASE 
        WHEN o.denominator = d.denom_count AND o.prevalent_cases = d.case_count THEN 'PASS'
        ELSE 'FAIL'
    END AS status,
    'Overall totals match detail records' AS test
FROM overall_agg o, detail_sum d;

-- Test 8: Footnotes complete
\echo '\nTest 8: Documentation Completeness';
SELECT 
    CASE 
        WHEN COUNT(*) >= 7 THEN 'PASS'
        ELSE 'FAIL - Only ' || COUNT(*) || ' footnotes'
    END AS status,
    'Minimum 7 footnotes present' AS test
FROM prevalence_report_footnotes
WHERE report_id = 'PREV_DIABETES_2024';

-- Test 9: Quality checks run
\echo '\nTest 9: Quality Assurance';
SELECT 
    CASE 
        WHEN COUNT(*) > 0 AND SUM(CASE WHEN check_status = 'FAIL' THEN 1 ELSE 0 END) = 0 THEN 'PASS'
        WHEN COUNT(*) = 0 THEN 'FAIL - No quality checks run'
        ELSE 'FAIL - ' || SUM(CASE WHEN check_status = 'FAIL' THEN 1 ELSE 0 END) || ' checks failed'
    END AS status,
    'Quality checks executed and passed' AS test
FROM prevalence_quality_checks
WHERE report_id = 'PREV_DIABETES_2024';

-- Test 10: Rounding consistency
\echo '\nTest 10: Rounding Compliance';
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'FAIL - ' || COUNT(*) || ' values not rounded to 1 decimal'
    END AS status,
    'All prevalence values rounded to 1 decimal' AS test
FROM (
    SELECT prevalence_rate_display
    FROM prevalence_aggregated
    WHERE report_id = 'PREV_DIABETES_2024'
      AND prevalence_rate_display != ROUND(prevalence_rate_display, 1)
) subq;

\echo '\n==========================================';
\echo 'VALIDATION COMPLETE';
\echo '==========================================';
```

### 8.2 Reconciliation with Source Data

Verify the aggregated results trace back to source tables:

```sql
-- Reconciliation Report
WITH source_counts AS (
    -- Count from raw source tables
    SELECT 
        COUNT(DISTINCT p.person_id) AS total_patients,
        COUNT(DISTINCT CASE 
            WHEN SUM(op.observation_period_end_date - op.observation_period_start_date + 1) >= 365 
            THEN p.person_id 
        END) AS eligible_patients,
        COUNT(DISTINCT co.person_id) AS patients_with_condition
    FROM person p
    LEFT JOIN observation_period op ON p.person_id = op.person_id
        AND op.observation_period_start_date <= '2024-12-31'
        AND op.observation_period_end_date >= '2024-01-01'
    LEFT JOIN condition_occurrence co ON p.person_id = co.person_id
        AND co.condition_concept_id IN (
            SELECT descendant_concept_id 
            FROM concept_ancestor 
            WHERE ancestor_concept_id = 201826
        )
        AND co.condition_start_date BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY p.person_id
),
schema_counts AS (
    -- Count from schema tables
    SELECT 
        COUNT(DISTINCT d.person_id) AS denominator_count,
        SUM(CASE WHEN d.meets_observation_requirement THEN 1 ELSE 0 END) AS eligible_count,
        COUNT(DISTINCT c.person_id) AS case_count
    FROM prevalence_denominator d
    LEFT JOIN prevalence_cases c ON d.report_id = c.report_id AND d.person_id = c.person_id
    WHERE d.report_id = 'PREV_DIABETES_2024'
)
SELECT 
    'Source Data' AS data_source,
    s.eligible_patients AS eligible,
    s.patients_with_condition AS cases
FROM source_counts s
UNION ALL
SELECT 
    'Schema Tables' AS data_source,
    sc.eligible_count AS eligible,
    sc.case_count AS cases
FROM schema_counts sc;
```

### 8.3 Temporal Consistency Checks

For reports spanning multiple time periods, verify consistency:

```sql
-- Check for unexpected prevalence changes
WITH period_comparison AS (
    SELECT 
        EXTRACT(YEAR FROM m.reporting_period_start_date) AS year,
        a.stratum_value,
        a.prevalence_rate_display,
        LAG(a.prevalence_rate_display) OVER (
            PARTITION BY a.stratum_value 
            ORDER BY m.reporting_period_start_date
        ) AS prev_year_prevalence,
        a.prevalence_rate_display - LAG(a.prevalence_rate_display) OVER (
            PARTITION BY a.stratum_value 
            ORDER BY m.reporting_period_start_date
        ) AS year_over_year_change
    FROM prevalence_aggregated a
    JOIN prevalence_report_metadata m ON a.report_id = m.report_id
    WHERE m.condition_concept_id = 201826
      AND a.stratification_level = 'age_group'
)
SELECT 
    year,
    stratum_value,
    prevalence_rate_display,
    year_over_year_change,
    CASE 
        WHEN ABS(year_over_year_change) > 5.0 THEN 'REVIEW - Large change'
        WHEN year_over_year_change IS NULL THEN 'First period'
        ELSE 'OK'
    END AS flag
FROM period_comparison
ORDER BY stratum_value, year;
```

---

## 9. Maintenance and Troubleshooting

### 9.1 Common Issues and Solutions

#### Issue 1: Cases Not Appearing in Denominator

**Symptom:** Quality check "cases_in_denominator" fails

**Diagnosis:**
```sql
SELECT 
    c.person_id,
    c.first_occurrence_date,
    d.person_id AS in_denominator,
    d.meets_observation_requirement,
    d.total_observation_days
FROM prevalence_cases c
LEFT JOIN prevalence_denominator d 
    ON c.report_id = d.report_id 
    AND c.person_id = d.person_id
WHERE c.report_id = 'PREV_DIABETES_2024'
  AND d.person_id IS NULL;
```

**Solution:**
- Verify patient has records in OBSERVATION_PERIOD
- Check if patient meets ≥365 day requirement
- Verify observation period overlaps with reporting period
- Re-populate denominator table if needed

#### Issue 2: Prevalence Calculation Mismatch

**Symptom:** Calculated prevalence doesn't match stored value

**Diagnosis:**
```sql
SELECT 
    stratification_level,
    stratum_value,
    denominator,
    prevalent_cases,
    prevalence_rate_display AS stored,
    ROUND((prevalent_cases::DECIMAL / denominator::DECIMAL * 100), 1) AS calculated,
    ABS(prevalence_rate_display - 
        ROUND((prevalent_cases::DECIMAL / denominator::DECIMAL * 100), 1)) AS deviation
FROM prevalence_aggregated
WHERE report_id = 'PREV_DIABETES_2024'
  AND ABS(prevalence_rate_display - 
      ROUND((prevalent_cases::DECIMAL / denominator::DECIMAL * 100), 1)) > 0.01;
```

**Solution:**
- Re-run aggregation step
- Verify no manual edits to prevalence_rate_display
- Check for concurrent updates during calculation
- Verify rounding function uses correct precision

#### Issue 3: Missing Stratification Values

**Symptom:** Expected strata (e.g., age groups) not appearing in results

**Diagnosis:**
```sql
-- Check which strata are present
SELECT DISTINCT age_group, COUNT(*) AS patient_count
FROM prevalence_denominator
WHERE report_id = 'PREV_DIABETES_2024'
  AND meets_observation_requirement = TRUE
GROUP BY age_group
ORDER BY age_group;
```

**Solution:**
- Verify age calculation logic in denominator population
- Check for NULL birth_dates (should map to "Unknown")
- Verify stratification grouping logic
- Consider if zero-count strata should be included

#### Issue 4: Duplicate Patient Records

**Symptom:** Patient appears multiple times in cases or denominator

**Diagnosis:**
```sql
-- Find duplicates in cases
SELECT person_id, COUNT(*) AS occurrence_count
FROM prevalence_cases
WHERE report_id = 'PREV_DIABETES_2024'
GROUP BY person_id
HAVING COUNT(*) > 1;

-- Find duplicates in denominator
SELECT person_id, COUNT(*) AS occurrence_count
FROM prevalence_denominator
WHERE report_id = 'PREV_DIABETES_2024'
GROUP BY person_id
HAVING COUNT(*) > 1;
```

**Solution:**
- Check PRIMARY KEY constraints are enforced
- Verify population queries use DISTINCT properly
- Re-populate affected table with corrected query
- Add additional validation checks

#### Issue 5: Performance Issues

**Symptom:** Report generation takes too long

**Diagnosis:**
```sql
-- Check table sizes
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_live_tup AS row_count
FROM pg_stat_user_tables
WHERE tablename LIKE 'prevalence%'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched
FROM pg_stat_user_indexes
WHERE tablename LIKE 'prevalence%'
ORDER BY idx_scan DESC;
```

**Solution:**
- Add indexes on frequently queried columns (already included in schema)
- Use EXPLAIN ANALYZE to identify slow queries
- Consider partitioning denominator/cases tables by report_id for large datasets
- Materialize views for frequently accessed aggregations
- Increase statistics target for heavily filtered columns

### 9.2 Data Refresh Procedures

#### Full Refresh (Complete Reprocessing)

```sql
-- Full refresh procedure
CREATE OR REPLACE PROCEDURE refresh_prevalence_report(
    p_report_id VARCHAR(50)
)
LANGUAGE plpgsql
AS $
BEGIN
    -- Step 1: Delete existing data (in reverse order of dependencies)
    DELETE FROM prevalence_report_footnotes WHERE report_id = p_report_id;
    DELETE FROM prevalence_quality_checks WHERE report_id = p_report_id;
    DELETE FROM prevalence_aggregated WHERE report_id = p_report_id;
    DELETE FROM prevalence_cases WHERE report_id = p_report_id;
    DELETE FROM prevalence_denominator WHERE report_id = p_report_id;
    -- Note: Keep metadata for traceability
    
    RAISE NOTICE 'Step 1: Deleted existing data for report %', p_report_id;
    
    -- Step 2: Re-populate (call existing population scripts)
    -- This would call the population logic from Section 4.2
    RAISE NOTICE 'Step 2: Re-populate tables (execute population script)';
    
    -- Step 3: Run validation
    INSERT INTO prevalence_quality_checks (report_id, check_name, check_category, check_status, check_description, check_result)
    SELECT * FROM validate_prevalence_calculation(p_report_id);
    
    RAISE NOTICE 'Step 3: Validation complete';
    
    -- Step 4: Update metadata timestamp
    UPDATE prevalence_report_metadata
    SET generation_timestamp = CURRENT_TIMESTAMP
    WHERE report_id = p_report_id;
    
    RAISE NOTICE 'Refresh complete for report %', p_report_id;
END;
$;

-- Execute refresh
CALL refresh_prevalence_report('PREV_DIABETES_2024');
```

#### Incremental Update (New Patients Only)

For ongoing reports, add new patients without reprocessing existing:

```sql
-- Incremental update procedure
CREATE OR REPLACE PROCEDURE update_prevalence_report_incremental(
    p_report_id VARCHAR(50),
    p_last_update_date DATE
)
LANGUAGE plpgsql
AS $
BEGIN
    -- Add new patients to denominator
    INSERT INTO prevalence_denominator (...)
    SELECT ...
    FROM person p
    WHERE p.created_date > p_last_update_date
    AND NOT EXISTS (
        SELECT 1 FROM prevalence_denominator d 
        WHERE d.report_id = p_report_id 
        AND d.person_id = p.person_id
    );
    
    -- Add new cases
    INSERT INTO prevalence_cases (...)
    SELECT ...
    FROM condition_occurrence co
    WHERE co.created_date > p_last_update_date
    AND NOT EXISTS (
        SELECT 1 FROM prevalence_cases c 
        WHERE c.report_id = p_report_id 
        AND c.person_id = co.person_id
    );
    
    -- Re-aggregate affected strata
    DELETE FROM prevalence_aggregated WHERE report_id = p_report_id;
    INSERT INTO prevalence_aggregated (...) 
    SELECT ... -- Full aggregation query
    
    -- Re-run validation
    DELETE FROM prevalence_quality_checks WHERE report_id = p_report_id;
    INSERT INTO prevalence_quality_checks (...)
    SELECT * FROM validate_prevalence_calculation(p_report_id);
    
    RAISE NOTICE 'Incremental update complete';
END;
$;
```

### 9.3 Archiving and Retention

```sql
-- Archive old reports
CREATE TABLE prevalence_report_archive (
    LIKE prevalence_report_metadata INCLUDING ALL
);

CREATE TABLE prevalence_aggregated_archive (
    LIKE prevalence_aggregated INCLUDING ALL
);

-- Archive procedure
CREATE OR REPLACE PROCEDURE archive_old_prevalence_reports(
    p_cutoff_date DATE
)
LANGUAGE plpgsql
AS $
BEGIN
    -- Archive metadata and aggregated results (keep for historical analysis)
    INSERT INTO prevalence_report_archive
    SELECT * FROM prevalence_report_metadata
    WHERE reporting_period_end_date < p_cutoff_date;
    
    INSERT INTO prevalence_aggregated_archive
    SELECT * FROM prevalence_aggregated
    WHERE report_id IN (
        SELECT report_id FROM prevalence_report_metadata
        WHERE reporting_period_end_date < p_cutoff_date
    );
    
    -- Delete patient-level details (PII considerations)
    DELETE FROM prevalence_denominator
    WHERE report_id IN (
        SELECT report_id FROM prevalence_report_metadata
        WHERE reporting_period_end_date < p_cutoff_date
    );
    
    DELETE FROM prevalence_cases
    WHERE report_id IN (
        SELECT report_id FROM prevalence_report_metadata
        WHERE reporting_period_end_date < p_cutoff_date
    );
    
    RAISE NOTICE 'Archived reports older than %', p_cutoff_date;
END;
$;

-- Execute: Archive reports older than 2 years
CALL archive_old_prevalence_reports(CURRENT_DATE - INTERVAL '2 years');
```

### 9.4 Monitoring and Alerts

Set up monitoring for data quality:

```sql
-- Create monitoring view
CREATE OR REPLACE VIEW v_prevalence_report_monitoring AS
SELECT 
    m.report_id,
    m.report_title,
    m.reporting_period_start_date,
    m.reporting_period_end_date,
    m.generation_timestamp,
    -- Data completeness metrics
    (SELECT COUNT(*) FROM prevalence_denominator d WHERE d.report_id = m.report_id) AS denominator_records,
    (SELECT COUNT(*) FROM prevalence_cases c WHERE c.report_id = m.report_id) AS case_records,
    (SELECT COUNT(*) FROM prevalence_aggregated a WHERE a.report_id = m.report_id) AS aggregated_strata,
    -- Quality check summary
    (SELECT COUNT(*) FROM prevalence_quality_checks q WHERE q.report_id = m.report_id AND q.check_status = 'PASS') AS checks_passed,
    (SELECT COUNT(*) FROM prevalence_quality_checks q WHERE q.report_id = m.report_id AND q.check_status = 'FAIL') AS checks_failed,
    (SELECT COUNT(*) FROM prevalence_quality_checks q WHERE q.report_id = m.report_id AND q.check_status = 'WARNING') AS checks_warning,
    -- Documentation completeness
    (SELECT COUNT(*) FROM prevalence_report_footnotes f WHERE f.report_id = m.report_id) AS footnote_count,
    -- Overall status
    CASE 
        WHEN (SELECT COUNT(*) FROM prevalence_quality_checks q WHERE q.report_id = m.report_id AND q.check_status = 'FAIL') > 0 THEN 'FAIL'
        WHEN (SELECT COUNT(*) FROM prevalence_quality_checks q WHERE q.report_id = m.report_id AND q.check_status = 'WARNING') > 0 THEN 'WARNING'
        WHEN (SELECT COUNT(*) FROM prevalence_quality_checks q WHERE q.report_id = m.report_id AND q.check_status = 'PASS') > 0 THEN 'PASS'
        ELSE 'NOT VALIDATED'
    END AS overall_status
FROM prevalence_report_metadata m;

-- Query for reports needing attention
SELECT * 
FROM v_prevalence_report_monitoring
WHERE overall_status IN ('FAIL', 'WARNING', 'NOT VALIDATED')
ORDER BY generation_timestamp DESC;
```

---

## 10. Advanced Topics

### 10.1 Multi-Condition Reporting

Generate prevalence for multiple conditions in one report:

```sql
-- Create a multi-condition variant
CREATE TABLE prevalence_multi_condition_aggregated (
    report_id VARCHAR(50),
    condition_concept_id INTEGER,
    condition_name VARCHAR(255),
    stratification_level VARCHAR(50),
    stratum_value VARCHAR(100),
    denominator INTEGER,
    prevalent_cases INTEGER,
    prevalence_rate_display DECIMAL(5,1),
    PRIMARY KEY (report_id, condition_concept_id, stratification_level, stratum_value)
);

-- Population query for multiple conditions
INSERT INTO prevalence_multi_condition_aggregated
SELECT 
    'PREV_CHRONIC_2024' AS report_id,
    concept_id AS condition_concept_id,
    concept_name,
    'age_group' AS stratification_level,
    d.age_group AS stratum_value,
    COUNT(DISTINCT d.person_id) AS denominator,
    COUNT(DISTINCT CASE WHEN co.condition_concept_id IS NOT NULL THEN d.person_id END) AS prevalent_cases,
    ROUND(
        (COUNT(DISTINCT CASE WHEN co.condition_concept_id IS NOT NULL THEN d.person_id END)::DECIMAL / 
         COUNT(DISTINCT d.person_id)::DECIMAL * 100),
        1
    ) AS prevalence_rate_display
FROM prevalence_denominator d
CROSS JOIN (
    SELECT concept_id, concept_name 
    FROM concept 
    WHERE concept_id IN (201826, 316866, 313217)  -- Diabetes, HTN, Asthma
) conditions
LEFT JOIN condition_occurrence co 
    ON d.person_id = co.person_id
    AND co.condition_concept_id = conditions.concept_id
    AND co.condition_start_date BETWEEN '2024-01-01' AND '2024-12-31'
WHERE d.report_id = 'PREV_DIABETES_2024'
  AND d.meets_observation_requirement = TRUE
GROUP BY concept_id, concept_name, d.age_group;
```

### 10.2 Comorbidity Analysis

Calculate prevalence of condition combinations:

```sql
-- Comorbidity prevalence
WITH patient_conditions AS (
    SELECT DISTINCT
        pc1.person_id,
        pc1.age_group,
        pc1.gender,
        c1.concept_name AS condition1,
        c2.concept_name AS condition2
    FROM prevalence_cases pc1
    JOIN prevalence_cases pc2 ON pc1.person_id = pc2.person_id
    JOIN concept c1 ON c1.concept_id = 201826  -- Diabetes
    JOIN concept c2 ON c2.concept_id = 316866  -- Hypertension
    WHERE pc1.report_id = 'PREV_DIABETES_2024'
      AND pc2.report_id = 'PREV_HTN_2024'
)
SELECT 
    age_group,
    COUNT(DISTINCT person_id) AS comorbid_patients,
    ROUND(
        (COUNT(DISTINCT person_id)::DECIMAL / 
         (SELECT COUNT(DISTINCT person_id) FROM prevalence_denominator 
          WHERE report_id = 'PREV_DIABETES_2024' 
          AND meets_observation_requirement = TRUE)::DECIMAL * 100),
        1
    ) AS comorbidity_prevalence
FROM patient_conditions
GROUP BY age_group;
```

### 10.3 Trend Analysis

Automated trend detection across reporting periods:

```sql
-- Detect significant trends
WITH trend_data AS (
    SELECT 
        EXTRACT(YEAR FROM m.reporting_period_start_date) AS year,
        a.stratum_value,
        a.prevalence_rate_display
    FROM prevalence_aggregated a
    JOIN prevalence_report_metadata m ON a.report_id = m.report_id
    WHERE m.condition_concept_id = 201826
      AND a.stratification_level = 'age_group'
      AND EXTRACT(YEAR FROM m.reporting_period_start_date) >= 2020
),
trend_calc AS (
    SELECT 
        stratum_value,
        REGR_SLOPE(prevalence_rate_display, year) AS slope,
        REGR_R2(prevalence_rate_display, year) AS r_squared,
        COUNT(*) AS n_years
    FROM trend_data
    GROUP BY stratum_value
)
SELECT 
    stratum_value,
    ROUND(slope, 2) AS annual_change_percentage_points,
    ROUND(r_squared, 3) AS r_squared,
    CASE 
        WHEN slope > 1.0 AND r_squared > 0.8 THEN 'Strong increasing trend'
        WHEN slope > 0.5 AND r_squared > 0.6 THEN 'Moderate increasing trend'
        WHEN slope < -1.0 AND r_squared > 0.8 THEN 'Strong decreasing trend'
        WHEN slope < -0.5 AND r_squared > 0.6 THEN 'Moderate decreasing trend'
        ELSE 'Stable or unclear trend'
    END AS trend_interpretation
FROM trend_calc
WHERE n_years >= 3
ORDER BY ABS(slope) DESC;
```

---

## 11. Integration with External Systems

### 11.1 Export to BI Tools

Generate CSV for Tableau/Power BI:

```sql
-- Export query with proper formatting
COPY (
    SELECT 
        m.report_title AS "Report Title",
        m.condition_name AS "Condition",
        TO_CHAR(m.reporting_period_start_date, 'YYYY-MM-DD') AS "Period Start",
        TO_CHAR(m.reporting_period_end_date, 'YYYY-MM-DD') AS "Period End",
        a.stratification_level AS "Stratification",
        a.stratum_value AS "Stratum",
        a.denominator AS "Denominator",
        a.prevalent_cases AS "Cases",
        a.prevalence_rate_display AS "Prevalence %"
    FROM prevalence_aggregated a
    JOIN prevalence_report_metadata m ON a.report_id = m.report_id
    WHERE m.report_id = 'PREV_DIABETES_2024'
    ORDER BY a.stratification_level, a.stratum_value
) TO '/export/prevalence_diabetes_2024.csv' WITH CSV HEADER;
```

### 11.2 REST API Integration

Sample API endpoint structure for prevalence data:

```sql
-- Function to support API queries
CREATE OR REPLACE FUNCTION get_prevalence_report_json(
    p_report_id VARCHAR(50)
)
RETURNS JSON
LANGUAGE plpgsql
AS $
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'report_id', m.report_id,
        'title', m.report_title,
        'condition', m.condition_name,
        'period', json_build_object(
            'start', m.reporting_period_start_date,
            'end', m.reporting_period_end_date
        ),
        'metadata', json_build_object(
            'generated', m.generation_timestamp,
            'generator', m.generated_by,
            'source_query', m.source_query_path
        ),
        'results', (
            SELECT json_agg(
                json_build_object(
                    'stratification', a.stratification_level,
                    'stratum', a.stratum_value,
                    'denominator', a.denominator,
                    'cases', a.prevalent_cases,
                    'prevalence', a.prevalence_rate_display,
                    'incident_cases', a.incident_cases_in_period,
                    'prevalent_from_prior', a.prevalent_from_prior
                )
            )
            FROM prevalence_aggregated a
            WHERE a.report_id = m.report_id
        ),
        'footnotes', (
            SELECT json_agg(
                json_build_object(
                    'order', f.footnote_order,
                    'type', f.footnote_type,
                    'text', f.footnote_text
                )
            )
            FROM prevalence_report_footnotes f
            WHERE f.report_id = m.report_id
            ORDER BY f.footnote_order
        ),
        'quality_status', (
            SELECT json_build_object(
                'overall', CASE 
                    WHEN SUM(CASE WHEN q.check_status = 'FAIL' THEN 1 ELSE 0 END) > 0 THEN 'FAIL'
                    WHEN SUM(CASE WHEN q.check_status = 'WARNING' THEN 1 ELSE 0 END) > 0 THEN 'WARNING'
                    ELSE 'PASS'
                END,
                'checks', json_agg(
                    json_build_object(
                        'name', q.check_name,
                        'status', q.check_status,
                        'description', q.check_description
                    )
                )
            )
            FROM prevalence_quality_checks q
            WHERE q.report_id = m.report_id
        )
    ) INTO result
    FROM prevalence_report_metadata m
    WHERE m.report_id = p_report_id;
    
    RETURN result;
END;
$;

-- Usage: SELECT get_prevalence_report_json('PREV_DIABETES_2024');
```

---

## 12. Appendices

### Appendix A: Quick Reference Card

```
┌────────────────────────────────────────────────────────────┐
│         PREVALENCE REPORTING QUICK REFERENCE               │
├────────────────────────────────────────────────────────────┤
│ FORMULA                                                    │
│   Prevalence (%) = (Cases / Denominator) × 100            │
│                                                            │
│ KEY REQUIREMENTS                                           │
│   ✓ Denominator: ≥365 days observation                    │
│   ✓ Cases: Each patient counted once                      │
│   ✓ Rounding: 1 decimal place for display                 │
│   ✓ Missing data: Code as "Unknown"                       │
│                                                            │
│ TABLE POPULATION ORDER                                     │
│   1. prevalence_report_metadata                           │
│   2. prevalence_denominator                               │
│   3. prevalence_cases                                     │
│   4. prevalence_aggregated                                │
│   5. prevalence_quality_checks                            │
│   6. prevalence_report_footnotes                          │
│                                                            │
│ VALIDATION CHECKLIST                                       │
│   □ All cases in denominator                              │
│   □ Calculations match formula                            │
│   □ No duplicate patients                                 │
│   □ ≥7 footnotes present                                  │
│   □ All quality checks PASS                               │
│                                                            │
│ FINAL OUTPUT VIEW                                          │
│   SELECT * FROM v_prevalence_report_output               │
│   WHERE report_id = 'YOUR_REPORT_ID';                    │
└────────────────────────────────────────────────────────────┘
```

### Appendix B: Glossary

| Term                   | Definition                                                                                                                  |
| :--------------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| **Denominator**        | Number of eligible patients with ≥365 days observation during reporting period                                              |
| **Eligible Patient**   | Patient meeting minimum observation requirement (≥365 days)                                                                 |
| **Prevalent Case**     | Patient with at least one occurrence of the condition during the reporting period (includes both incident and pre-existing) |
| **Incident Case**      | First-ever occurrence of a condition (subset of prevalent cases)                                                            |
| **Reporting Period**   | Time window for aggregation (typically calendar year)                                                                       |
| **Stratification**     | Grouping by demographic or clinical dimensions (age, gender, region)                                                        |
| **Observation Period** | Span of time when clinical events are expected to be recorded for a patient                                                 |
| **Cohort**             | Defined group of patients meeting specific criteria                                                                         |
| **Missing Data**       | Demographic values coded as "Unknown" when not available                                                                    |

### Appendix C: Schema Change Log

| Version | Date       | Changes                | Impact             |
| :------ | :--------- | :--------------------- | :----------------- |
| 1.0     | 2025-11-23 | Initial schema release | New implementation |

### Appendix D: Contact and Support

**Schema Maintainer:** Analytics Team  
**Documentation:** This document  
**Related Guides:** Comprehensive Guide for Designing Auditable Clinical Aggregated Statistics Tables (v2.0)

---

**End of Documentation**

*This documentation implements requirements from the Comprehensive Guide for Designing Auditable Clinical Aggregated Statistics Tables (Version 2.0) and ensures statistical accuracy, data architecture integrity, and complete auditability for prevalence reporting.*