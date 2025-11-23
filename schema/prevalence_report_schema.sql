-- ============================================================================
-- PREVALENCE REPORT SCHEMA
-- ============================================================================
-- Purpose: Define the structure for auditable prevalence reporting tables
-- Based on: Comprehensive Guide for Designing Auditable Clinical Aggregated 
--           Statistics Tables (Version 2.0)
-- 
-- Key Principle: Prevalence = (prevalent_cases / denominator) × 100
-- Where:
--   - Denominator = eligible patient count with ≥365 days observation
--   - Prevalent Cases = unique patients with ≥1 occurrence during reporting period
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PREVALENCE_REPORT_METADATA
-- ----------------------------------------------------------------------------
-- Stores metadata about each prevalence report for traceability and auditability
-- ----------------------------------------------------------------------------

CREATE TABLE prevalence_report_metadata (
    report_id                       VARCHAR(50) PRIMARY KEY,
    report_title                    VARCHAR(500) NOT NULL,
    condition_concept_id            INTEGER NOT NULL,
    condition_name                  VARCHAR(255) NOT NULL,
    reporting_period_start_date     DATE NOT NULL,
    reporting_period_end_date       DATE NOT NULL,
    minimum_observation_days        INTEGER NOT NULL DEFAULT 365,
    cohort_definition_id            INTEGER,
    source_query_path               VARCHAR(500),
    generation_timestamp            TIMESTAMP NOT NULL,
    generated_by                    VARCHAR(100),
    
    -- Documentation fields
    denominator_definition          TEXT NOT NULL DEFAULT 'Patients with ≥365 days observation during reporting period',
    case_definition                 TEXT NOT NULL DEFAULT 'Patients with at least one occurrence of condition during reporting period',
    
    -- Constraints
    CONSTRAINT chk_valid_period CHECK (reporting_period_end_date >= reporting_period_start_date),
    CONSTRAINT chk_min_obs CHECK (minimum_observation_days > 0),
    
    -- Foreign keys
    CONSTRAINT fk_condition_concept FOREIGN KEY (condition_concept_id) 
        REFERENCES concept(concept_id),
    CONSTRAINT fk_cohort_def FOREIGN KEY (cohort_definition_id) 
        REFERENCES cohort_definition(cohort_definition_id)
);

COMMENT ON TABLE prevalence_report_metadata IS 
'Metadata for prevalence reports ensuring traceability and reproducibility. Each report documents the exact parameters and definitions used.';

-- ----------------------------------------------------------------------------
-- 2. PREVALENCE_DENOMINATOR
-- ----------------------------------------------------------------------------
-- Stores the eligible population (denominator) for prevalence calculations
-- Tracks which patients meet the minimum observation requirement
-- ----------------------------------------------------------------------------

CREATE TABLE prevalence_denominator (
    report_id                       VARCHAR(50) NOT NULL,
    person_id                       INTEGER NOT NULL,
    
    -- Stratification dimensions
    age_group                       VARCHAR(20),
    gender                          VARCHAR(20),
    region                          VARCHAR(100),
    
    -- Observation tracking
    total_observation_days          INTEGER NOT NULL,
    observation_start_date          DATE NOT NULL,
    observation_end_date            DATE NOT NULL,
    
    -- Eligibility flag
    meets_observation_requirement   BOOLEAN NOT NULL,
    
    -- Cohort linkage
    cohort_start_date               DATE,
    cohort_end_date                 DATE,
    
    -- Audit fields
    created_timestamp               TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (report_id, person_id),
    
    -- Foreign keys
    CONSTRAINT fk_denom_report FOREIGN KEY (report_id) 
        REFERENCES prevalence_report_metadata(report_id),
    CONSTRAINT fk_denom_person FOREIGN KEY (person_id) 
        REFERENCES person(person_id),
    
    -- Data quality constraints
    CONSTRAINT chk_observation_dates CHECK (observation_end_date >= observation_start_date),
    CONSTRAINT chk_observation_days CHECK (total_observation_days > 0),
    CONSTRAINT chk_eligibility CHECK (
        (meets_observation_requirement = TRUE AND total_observation_days >= 365) OR
        (meets_observation_requirement = FALSE AND total_observation_days < 365)
    )
);

COMMENT ON TABLE prevalence_denominator IS 
'Eligible population for prevalence calculations. Includes all patients with ≥365 days observation during or prior to reporting period.';

CREATE INDEX idx_denom_eligible ON prevalence_denominator(report_id, meets_observation_requirement);
CREATE INDEX idx_denom_strata ON prevalence_denominator(report_id, age_group, gender, region);

-- ----------------------------------------------------------------------------
-- 3. PREVALENCE_CASES
-- ----------------------------------------------------------------------------
-- Stores patients identified as prevalent cases
-- Each patient counted once regardless of multiple occurrences
-- ----------------------------------------------------------------------------

CREATE TABLE prevalence_cases (
    report_id                       VARCHAR(50) NOT NULL,
    person_id                       INTEGER NOT NULL,
    
    -- Case identification
    first_occurrence_date           DATE NOT NULL,
    last_occurrence_date            DATE NOT NULL,
    total_occurrences               INTEGER NOT NULL DEFAULT 1,
    
    -- Stratification dimensions (denormalized for performance)
    age_group                       VARCHAR(20),
    gender                          VARCHAR(20),
    region                          VARCHAR(100),
    
    -- Case classification
    is_incident_in_period           BOOLEAN,  -- TRUE if first-ever occurrence in reporting period
    is_prevalent_from_prior         BOOLEAN,  -- TRUE if occurred before reporting period
    
    -- Source event linkage
    condition_occurrence_ids        TEXT,  -- Comma-separated list of source records
    
    -- Audit fields
    created_timestamp               TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (report_id, person_id),
    
    -- Foreign keys
    CONSTRAINT fk_cases_report FOREIGN KEY (report_id) 
        REFERENCES prevalence_report_metadata(report_id),
    CONSTRAINT fk_cases_person FOREIGN KEY (person_id) 
        REFERENCES person(person_id),
    
    -- Data quality constraints
    CONSTRAINT chk_occurrence_dates CHECK (last_occurrence_date >= first_occurrence_date),
    CONSTRAINT chk_occurrence_count CHECK (total_occurrences > 0),
    CONSTRAINT chk_case_classification CHECK (
        (is_incident_in_period = TRUE AND is_prevalent_from_prior = FALSE) OR
        (is_incident_in_period = FALSE AND is_prevalent_from_prior = TRUE) OR
        (is_incident_in_period = TRUE AND is_prevalent_from_prior = FALSE)
    )
);

COMMENT ON TABLE prevalence_cases IS 
'Prevalent cases: patients with at least one occurrence of the condition during the reporting period. Includes both incident and pre-existing cases.';

CREATE INDEX idx_cases_strata ON prevalence_cases(report_id, age_group, gender, region);
CREATE INDEX idx_cases_incident ON prevalence_cases(report_id, is_incident_in_period);

-- ----------------------------------------------------------------------------
-- 4. PREVALENCE_AGGREGATED
-- ----------------------------------------------------------------------------
-- Final aggregated prevalence statistics by stratification dimensions
-- This is the primary output table for reporting
-- ----------------------------------------------------------------------------

CREATE TABLE prevalence_aggregated (
    report_id                       VARCHAR(50) NOT NULL,
    
    -- Stratification dimensions
    stratification_level            VARCHAR(50) NOT NULL,  -- e.g., 'age_group', 'gender', 'overall'
    stratum_value                   VARCHAR(100) NOT NULL, -- e.g., '18-34', 'Female', 'All'
    
    -- Core metrics (unrounded for calculations)
    denominator                     INTEGER NOT NULL,
    prevalent_cases                 INTEGER NOT NULL,
    prevalence_rate_raw             DECIMAL(10, 6),  -- Unrounded for intermediate calculations
    
    -- Display metrics (rounded per guide specifications)
    prevalence_rate_display         DECIMAL(5, 1),   -- Rounded to 1 decimal place
    
    -- Additional metrics
    incident_cases_in_period        INTEGER,         -- Cases that are also incident
    prevalent_from_prior            INTEGER,         -- Cases from before period
    
    -- Confidence intervals (optional)
    prevalence_ci_lower_95          DECIMAL(5, 1),
    prevalence_ci_upper_95          DECIMAL(5, 1),
    
    -- Audit fields
    created_timestamp               TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (report_id, stratification_level, stratum_value),
    
    -- Foreign keys
    CONSTRAINT fk_agg_report FOREIGN KEY (report_id) 
        REFERENCES prevalence_report_metadata(report_id),
    
    -- Data quality constraints
    CONSTRAINT chk_denominator_positive CHECK (denominator > 0),
    CONSTRAINT chk_cases_le_denominator CHECK (prevalent_cases <= denominator),
    CONSTRAINT chk_prevalence_range CHECK (
        prevalence_rate_display >= 0 AND prevalence_rate_display <= 100
    ),
    CONSTRAINT chk_case_breakdown CHECK (
        prevalent_cases = COALESCE(incident_cases_in_period, 0) + COALESCE(prevalent_from_prior, 0)
        OR (incident_cases_in_period IS NULL AND prevalent_from_prior IS NULL)
    )
);

COMMENT ON TABLE prevalence_aggregated IS 
'Final aggregated prevalence statistics. Prevalence = (prevalent_cases / denominator) × 100, rounded to 1 decimal place for display.';

CREATE INDEX idx_agg_strata ON prevalence_aggregated(report_id, stratification_level);

-- ----------------------------------------------------------------------------
-- 5. PREVALENCE_QUALITY_CHECKS
-- ----------------------------------------------------------------------------
-- Stores quality assurance check results for each report
-- Ensures data integrity and adherence to guide specifications
-- ----------------------------------------------------------------------------

CREATE TABLE prevalence_quality_checks (
    report_id                       VARCHAR(50) NOT NULL,
    check_name                      VARCHAR(100) NOT NULL,
    check_category                  VARCHAR(50) NOT NULL,  -- 'denominator', 'cases', 'calculation', 'formatting'
    check_status                    VARCHAR(20) NOT NULL,  -- 'PASS', 'FAIL', 'WARNING'
    check_description               TEXT NOT NULL,
    check_result                    TEXT,
    expected_value                  TEXT,
    actual_value                    TEXT,
    check_timestamp                 TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    PRIMARY KEY (report_id, check_name),
    
    CONSTRAINT fk_qc_report FOREIGN KEY (report_id) 
        REFERENCES prevalence_report_metadata(report_id),
    CONSTRAINT chk_status VALUES CHECK (check_status IN ('PASS', 'FAIL', 'WARNING'))
);

COMMENT ON TABLE prevalence_quality_checks IS 
'Quality assurance checks for prevalence reports. Documents validation results per guide checklist.';

-- ----------------------------------------------------------------------------
-- 6. PREVALENCE_REPORT_FOOTNOTES
-- ----------------------------------------------------------------------------
-- Stores footnotes and documentation required by the guide
-- Ensures complete caption and traceability information
-- ----------------------------------------------------------------------------

CREATE TABLE prevalence_report_footnotes (
    report_id                       VARCHAR(50) NOT NULL,
    footnote_order                  INTEGER NOT NULL,
    footnote_type                   VARCHAR(50) NOT NULL,  -- 'source', 'rounding', 'denominator', 'caveat', 'missing_data'
    footnote_text                   TEXT NOT NULL,
    
    PRIMARY KEY (report_id, footnote_order),
    
    CONSTRAINT fk_footnote_report FOREIGN KEY (report_id) 
        REFERENCES prevalence_report_metadata(report_id)
);

COMMENT ON TABLE prevalence_report_footnotes IS 
'Documentation and footnotes for prevalence reports. Required for complete table captions per guide Section III.1.';

-- ----------------------------------------------------------------------------
-- 7. Views for Reporting
-- ----------------------------------------------------------------------------

-- View: Complete denominator with eligibility
CREATE VIEW v_prevalence_denominator_summary AS
SELECT 
    d.report_id,
    d.age_group,
    d.gender,
    d.region,
    COUNT(DISTINCT d.person_id) AS total_patients,
    COUNT(DISTINCT CASE WHEN d.meets_observation_requirement THEN d.person_id END) AS eligible_patients,
    ROUND(AVG(d.total_observation_days), 0) AS avg_observation_days,
    MIN(d.observation_start_date) AS earliest_observation,
    MAX(d.observation_end_date) AS latest_observation
FROM prevalence_denominator d
GROUP BY d.report_id, d.age_group, d.gender, d.region;

COMMENT ON VIEW v_prevalence_denominator_summary IS 
'Summary of denominator by stratification dimensions. Shows eligible vs total patients.';

-- View: Case summary with classification
CREATE VIEW v_prevalence_cases_summary AS
SELECT 
    c.report_id,
    c.age_group,
    c.gender,
    c.region,
    COUNT(DISTINCT c.person_id) AS total_cases,
    COUNT(DISTINCT CASE WHEN c.is_incident_in_period THEN c.person_id END) AS incident_cases,
    COUNT(DISTINCT CASE WHEN c.is_prevalent_from_prior THEN c.person_id END) AS prevalent_from_prior,
    ROUND(AVG(c.total_occurrences), 1) AS avg_occurrences_per_patient,
    MIN(c.first_occurrence_date) AS earliest_case,
    MAX(c.last_occurrence_date) AS latest_case
FROM prevalence_cases c
GROUP BY c.report_id, c.age_group, c.gender, c.region;

COMMENT ON VIEW v_prevalence_cases_summary IS 
'Summary of prevalent cases by stratification dimensions. Breaks down incident vs pre-existing cases.';

-- View: Complete report output
CREATE VIEW v_prevalence_report_output AS
SELECT 
    m.report_id,
    m.report_title,
    m.condition_name,
    m.reporting_period_start_date,
    m.reporting_period_end_date,
    a.stratification_level,
    a.stratum_value,
    a.denominator AS eligible_patients,
    a.prevalent_cases,
    a.prevalence_rate_display AS prevalence_percentage,
    a.incident_cases_in_period,
    a.prevalent_from_prior,
    a.prevalence_ci_lower_95,
    a.prevalence_ci_upper_95
FROM prevalence_report_metadata m
JOIN prevalence_aggregated a ON m.report_id = a.report_id
ORDER BY 
    m.report_id, 
    a.stratification_level,
    CASE 
        WHEN a.stratum_value = 'All' THEN 0
        WHEN a.stratum_value = 'Unknown' THEN 999
        ELSE 1 
    END,
    a.stratum_value;

COMMENT ON VIEW v_prevalence_report_output IS 
'Complete prevalence report output with all metrics formatted for presentation. Use this view for final table generation.';

-- ----------------------------------------------------------------------------
-- 8. Helper Functions
-- ----------------------------------------------------------------------------

-- Function to validate prevalence calculation
CREATE OR REPLACE FUNCTION validate_prevalence_calculation(
    p_report_id VARCHAR(50)
)
RETURNS TABLE (
    check_name VARCHAR(100),
    check_status VARCHAR(20),
    message TEXT
) AS $$
BEGIN
    -- Check 1: All cases are in denominator
    RETURN QUERY
    SELECT 
        'cases_in_denominator'::VARCHAR(100),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'::VARCHAR(20)
            ELSE 'FAIL'::VARCHAR(20)
        END,
        CASE 
            WHEN COUNT(*) = 0 THEN 'All cases are in denominator'
            ELSE 'Found ' || COUNT(*) || ' cases not in denominator'
        END::TEXT
    FROM prevalence_cases c
    LEFT JOIN prevalence_denominator d 
        ON c.report_id = d.report_id 
        AND c.person_id = d.person_id
    WHERE c.report_id = p_report_id
        AND d.person_id IS NULL;
    
    -- Check 2: Prevalence rate matches calculation
    RETURN QUERY
    SELECT 
        'prevalence_calculation'::VARCHAR(100),
        CASE 
            WHEN MAX(ABS(
                a.prevalence_rate_display - 
                ROUND((a.prevalent_cases::DECIMAL / a.denominator * 100), 1)
            )) < 0.1 THEN 'PASS'::VARCHAR(20)
            ELSE 'FAIL'::VARCHAR(20)
        END,
        'Max deviation: ' || COALESCE(MAX(ABS(
            a.prevalence_rate_display - 
            ROUND((a.prevalent_cases::DECIMAL / a.denominator * 100), 1)
        ))::TEXT, '0')::TEXT
    FROM prevalence_aggregated a
    WHERE a.report_id = p_report_id;
    
    -- Check 3: Denominator has minimum observation
    RETURN QUERY
    SELECT 
        'minimum_observation'::VARCHAR(100),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'::VARCHAR(20)
            ELSE 'FAIL'::VARCHAR(20)
        END,
        CASE 
            WHEN COUNT(*) = 0 THEN 'All eligible patients meet minimum observation'
            ELSE 'Found ' || COUNT(*) || ' eligible patients with <365 days observation'
        END::TEXT
    FROM prevalence_denominator d
    WHERE d.report_id = p_report_id
        AND d.meets_observation_requirement = TRUE
        AND d.total_observation_days < 365;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_prevalence_calculation IS 
'Validates prevalence report calculations against guide specifications. Returns PASS/FAIL for key quality checks.';

-- ----------------------------------------------------------------------------
-- End of Schema
-- ----------------------------------------------------------------------------