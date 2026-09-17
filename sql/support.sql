-- postcode_eq_partial_support(): rewrites `code % 'fragment'` into the
-- equivalent range_lower()/range_upper() bounds at plan time, for a
-- plan-time-constant fragment, so % gets an index-assisted plan without
-- repeating 1.3.0's soundness bug (registering % itself under btree
-- strategy 3 -- see the comment above CREATE OPERATOR FAMILY
-- postcode_ops). This is the same core soundness property range.sql
-- already tests for range_lower()/range_upper() directly -- here
-- testing that % itself, unindexed vs via the support-function rewrite,
-- agrees exactly, since the whole point is that % keeps meaning what it
-- always meant.

CREATE TEMP TABLE support_sample (code postcode);
INSERT INTO support_sample VALUES
   ('BA1 1AA'), ('BA1 1AZ'), ('BA1 9ZZ'), ('BA10 1AA'), ('BA11 1AA'),
   ('BA2 1AA'), ('AB1 1AA'), ('LS24 9JT'), ('SW1A 1AA'), ('SW1A 2AA');

CREATE INDEX ON support_sample USING btree (code);
ANALYZE support_sample;

-- Soundness: with a constant fragment (support function active), % must
-- return exactly the same rows as the always-correct, unindexed range
-- form -- same property range.sql checks for range_lower()/
-- range_upper() directly, here checking % agrees with itself with and
-- without the optimization in play.
SELECT count(*) AS disagreements FROM support_sample
WHERE (code % 'BA1')
  IS DISTINCT FROM (code >= range_lower('BA1') AND code < range_upper('BA1'));

SELECT count(*) AS disagreements FROM support_sample
WHERE (code % 'BA')
  IS DISTINCT FROM (code >= range_lower('BA') AND code < range_upper('BA'));

SELECT count(*) AS disagreements FROM support_sample
WHERE (code % 'SW1A 1')
  IS DISTINCT FROM (code >= range_lower('SW1A 1') AND code < range_upper('SW1A 1'));

-- Actually returns the right rows
SELECT code::text FROM support_sample WHERE code % 'BA1' ORDER BY code;

-- Plan-time rewrite only applies to a genuine constant -- a
-- column/parameter fragment must still work correctly (just unindexed,
-- exactly as before this version), not be mishandled by the support
-- function declining
CREATE TEMP TABLE fragment_holder (frag text);
INSERT INTO fragment_holder VALUES ('BA1');
SELECT s.code::text FROM support_sample s, fragment_holder f WHERE s.code % f.frag ORDER BY s.code;

-- An invalid fragment: % has always returned false rather than raising
-- (postcode_eq_partial's own long-standing behaviour) -- the support
-- function must decline (not attempt to raise, not attempt to "fix"
-- this) and let the plain function run as it always has
SELECT code::text FROM support_sample WHERE code % '' ORDER BY code; -- no rows
SELECT code::text FROM support_sample WHERE code % 'ZZ-not-real' ORDER BY code; -- no rows

-- NULL fragment: same long-standing behaviour (NULL, not an error, not
-- a match)
SELECT code % NULL FROM support_sample LIMIT 1;

-- The actual point of this whole exercise -- a constant fragment now
-- gets a genuine index-assisted plan instead of the sequential scan %
-- has always been limited to before this version -- is deliberately
-- *not* asserted here: plan cost/text isn't stable pg_regress output,
-- same reasoning range.sql already gives for its own range form.
-- Confirmed live via EXPLAIN separately (see postcode--1.3.2--1.3.3.sql's
-- own commit message / README).
