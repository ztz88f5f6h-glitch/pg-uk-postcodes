-- Upgrade path for databases that already have 1.3.0 installed.
--
-- 1.3.0 registered % (partial match) at btree strategy 3, which is
-- reserved for true equality -- btree relies on strategy-3 matches
-- being reflexive/interchangeable (skip-scan, dedup), which a partial
-- match isn't. That's the root cause of upstream issue #3 ("Use of
-- indexes with % operator produces incorrect results"): queries using
-- % return wrong results whenever a btree index exists on the postcode
-- column. Dropping it here -- % still works correctly as a plain
-- function call (postcode_eq_partial), just without index support,
-- i.e. a sequential scan instead of a fast-but-wrong one.
ALTER OPERATOR FAMILY postcode_ops USING btree DROP
   OPERATOR 3 (postcode, text),
   FUNCTION 1 (postcode, text);
