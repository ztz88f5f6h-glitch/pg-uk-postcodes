-- The four inequality operators now carry PostgreSQL's own standard
-- scalar-comparison selectivity estimators, same as int4/text/date use
-- for the same operators -- previously unset entirely (pg_operator's
-- oprrest/oprjoin both '-'), which meant the planner could never use
-- ANALYZE's own column statistics for a </<=/>/>=/BETWEEN predicate on
-- either type, regardless of how accurate or fresh those statistics
-- were. Catalog state is what's checked here (deterministic, portable
-- pg_regress output) -- actual plan choice for a given table/data
-- distribution isn't (same reasoning range.sql/support.sql already give
-- for not asserting EXPLAIN output directly); confirmed live separately
-- against a real fleet table instead -- see this version's own upgrade
-- script for that.

SELECT oprname, oprrest, oprjoin
FROM pg_operator
WHERE oprleft = 'postcode'::regtype AND oprright = 'postcode'::regtype
ORDER BY oprname;

SELECT oprname, oprrest, oprjoin
FROM pg_operator
WHERE oprleft = 'dps'::regtype AND oprright = 'dps'::regtype
ORDER BY oprname;

-- Sanity: the operators still work correctly -- registering a
-- selectivity estimator changes cost estimation only, never the actual
-- comparison result
SELECT 'BA1 1AA'::postcode < 'BA1 1AZ'::postcode;
SELECT 'BA1 1AA'::postcode <= 'BA1 1AA'::postcode;
SELECT 'BA1 1AZ'::postcode > 'BA1 1AA'::postcode;
SELECT 'BA1 1AA'::postcode >= 'BA1 1AA'::postcode;
SELECT '1A'::dps < '1B'::dps;
SELECT '9Z'::dps >= '9Z'::dps;

-- And range_lower()/range_upper() (which are exactly `code >= lower AND
-- code < upper` under the hood) still return correct, fully-agreeing
-- results with real statistics in play -- same soundness property
-- range.sql/support.sql already check, re-verified here now that these
-- comparisons have real selectivity estimates behind them
CREATE TEMP TABLE selectivity_sample (code postcode);
INSERT INTO selectivity_sample SELECT
   (CASE (i % 5)
      WHEN 0 THEN 'BA' || (i % 20 + 1) || ' ' || (i % 9 + 1) || 'A' || chr(65 + i % 26)
      WHEN 1 THEN 'SW1A ' || (i % 9 + 1) || 'A' || chr(65 + i % 26)
      WHEN 2 THEN 'LS' || (i % 25 + 1) || ' ' || (i % 9 + 1) || 'A' || chr(65 + i % 26)
      WHEN 3 THEN 'M' || (i % 9 + 1) || ' ' || (i % 9 + 1) || 'A' || chr(65 + i % 26)
      ELSE 'AB' || (i % 20 + 1) || ' ' || (i % 9 + 1) || 'A' || chr(65 + i % 26)
    END)::postcode
   FROM generate_series(1, 2000) i;
CREATE INDEX ON selectivity_sample USING btree (code);
ANALYZE selectivity_sample;

SELECT count(*) AS disagreements FROM selectivity_sample
WHERE (code >= range_lower('BA1') AND code < range_upper('BA1'))
  IS DISTINCT FROM (code % 'BA1');
