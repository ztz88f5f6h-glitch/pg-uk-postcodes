-- range_lower()/range_upper() are comparison bounds, not necessarily
-- valid/renderable postcodes in their own right, for anything shorter
-- than a full 7-character code -- eg range_lower('BA') has no district
-- set at all (it's not a real postcode, it's "the smallest possible
-- packed value with area=BA"). Such values are valid comparison bounds,
-- but are not valid postcodes for the type output function. The named
-- postcode_to_text() helper deliberately returns SQL NULL for them.

-- basic bounds: area only -- every real BA postcode must fall in
-- [range_lower('BA'), range_upper('BA'))
SELECT 'BA1 1AZ'::postcode >= range_lower('BA') AND 'BA1 1AZ'::postcode < range_upper('BA');
SELECT 'AB1 1AA'::postcode >= range_lower('BA') AND 'AB1 1AA'::postcode < range_upper('BA'); -- different area: false

-- basic bounds: area+district (no space -> district gets both digits,
-- per the same disambiguation % itself uses)
SELECT 'BA1 1AZ'::postcode >= range_lower('BA1') AND 'BA1 1AZ'::postcode < range_upper('BA1');
SELECT 'BA10 1AA'::postcode >= range_lower('BA1') AND 'BA10 1AA'::postcode < range_upper('BA1'); -- district 10, not 1: false

-- area+district+sector (explicit space forces the district/sector split)
SELECT 'BA1 1AZ'::postcode >= range_lower('BA1 1') AND 'BA1 1AZ'::postcode < range_upper('BA1 1');
SELECT 'BA1 9ZZ'::postcode >= range_lower('BA1 1') AND 'BA1 9ZZ'::postcode < range_upper('BA1 1'); -- sector 9, not 1: false

-- full code: range of exactly one value. The lower bound is always
-- exactly the input value, and always safely renderable -- that's the
-- one case with nothing masked out.
SELECT range_lower('BA1 1AZ')::text;
SELECT range_lower('BA1 1AZ') = 'BA1 1AZ'::postcode;
SELECT range_upper('BA1 1AZ') > 'BA1 1AZ'::postcode;   -- correct ordering
SELECT range_upper('BA1 1AZ') > range_lower('BA1 1AZ');

-- invalid fragments raise, unlike %/!% which just never/always match --
-- unchanged by 1.3.3: this is range_lower()/range_upper() rejecting a
-- malformed *fragment* (the text argument), a completely different
-- thing from rendering an already-successfully-parsed partial *result*
-- to text, which is what changed
SELECT range_lower('');
SELECT range_lower('BA-');

-- Partial results are not valid for the type output function, but the
-- named helper returns SQL NULL rather than raising.
SELECT range_lower('BA')::text;
SELECT postcode_to_text(range_lower('BA')) IS NULL;
SELECT postcode_to_text(range_upper('BA')) IS NULL;
SELECT to_char(range_lower('BA'), 'AD');
SELECT postcode_to_text(range_lower('BA1')) IS NULL;   -- district set, sector/walk not
SELECT postcode_to_text(range_lower('BA1 1')) IS NULL; -- district+sector set, walk not

-- a normal, fully-valid one-digit-district postcode is completely
-- unaffected -- district2's *absence* was always valid and is still
-- correctly omitted, not rendered as '?'
SELECT 'SW1 1AA'::postcode::text;

-- the core soundness property: for every fragment and every real row,
-- the range form and the %% boolean form must agree exactly
CREATE TEMP TABLE range_sample (code postcode);
INSERT INTO range_sample VALUES
   ('BA1 1AA'), ('BA1 1AZ'), ('BA1 9ZZ'), ('BA10 1AA'), ('BA11 1AA'),
   ('BA2 1AA'), ('AB1 1AA'), ('LS24 9JT');

SELECT count(*) AS disagreements FROM range_sample
WHERE (code % 'BA1')
  IS DISTINCT FROM (code >= range_lower('BA1') AND code < range_upper('BA1'));

SELECT count(*) AS disagreements FROM range_sample
WHERE (code % 'BA')
  IS DISTINCT FROM (code >= range_lower('BA') AND code < range_upper('BA'));

SELECT count(*) AS disagreements FROM range_sample
WHERE (code % 'BA1 1')
  IS DISTINCT FROM (code >= range_lower('BA1 1') AND code < range_upper('BA1 1'));

-- range form actually returns the right rows
SELECT code::text FROM range_sample
WHERE code >= range_lower('BA1') AND code < range_upper('BA1')
ORDER BY code;

CREATE INDEX ON range_sample USING btree (code);
ANALYZE range_sample;

-- range form drives a genuine index scan (ordinary </>= strategies, no
-- opfamily trickery) -- confirmed live via EXPLAIN separately, not
-- asserted here since plan cost/text isn't stable output for pg_regress
SELECT code::text FROM range_sample
WHERE code >= range_lower('BA1') AND code < range_upper('BA1')
ORDER BY code;
