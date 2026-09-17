-- The four inequality operators (<, <=, >, >=), for both postcode and
-- dps, had no RESTRICT/JOIN selectivity estimator registered at all
-- (confirmed live: pg_operator.oprrest/oprjoin both '-' for all four on
-- each type -- only = and <> had eqsel/neqsel/eqjoinsel/neqjoinsel).
-- Without one, the planner cannot use ANALYZE's own column
-- statistics/histogram for a `<`/`<=`/`>`/`>=`/`BETWEEN` predicate at
-- all -- it falls back to a fixed default guess regardless of how
-- accurate or fresh the table's real statistics are. This is a distinct
-- root cause from the range_lower()/range_upper() rendering bug 1.3.3
-- fixed: confirmed live against a real fleet table
-- ("@OS".add_gb_builtaddress, 34.8M rows, freshly ANALYZEd, a plain
-- btree(postcode) index already present) that `postcode BETWEEN
-- range_lower('SW1A') AND range_upper('SW1A')` still chose a sequential
-- scan even with accurate statistics and a matching index available --
-- exactly what missing selectivity estimation predicts, not something
-- another ANALYZE could ever have fixed.
--
-- pg_catalog.scalarltsel/scalarlesel/scalargtsel/scalargesel (and their
-- join counterparts) are PostgreSQL's own standard, built-in estimators
-- for any type with ordinary scalar/ordered comparison semantics and a
-- histogram ANALYZE can collect for it -- both types already qualify
-- (LIKE = pg_catalog.int4 for postcode; a fixed single-byte
-- PASSEDBYVALUE type for dps), so this is registering existing
-- PostgreSQL machinery, not writing new estimation logic. No new
-- function, no C code -- ALTER OPERATOR ... SET is enough.

ALTER OPERATOR < (postcode, postcode) SET (RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
ALTER OPERATOR <= (postcode, postcode) SET (RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
ALTER OPERATOR > (postcode, postcode) SET (RESTRICT = scalargtsel, JOIN = scalargtjoinsel);
ALTER OPERATOR >= (postcode, postcode) SET (RESTRICT = scalargesel, JOIN = scalargejoinsel);

ALTER OPERATOR < (dps, dps) SET (RESTRICT = scalarltsel, JOIN = scalarltjoinsel);
ALTER OPERATOR <= (dps, dps) SET (RESTRICT = scalarlesel, JOIN = scalarlejoinsel);
ALTER OPERATOR > (dps, dps) SET (RESTRICT = scalargtsel, JOIN = scalargtjoinsel);
ALTER OPERATOR >= (dps, dps) SET (RESTRICT = scalargesel, JOIN = scalargejoinsel);
