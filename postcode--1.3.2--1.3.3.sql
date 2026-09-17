-- Three independent additions:
--
-- 1. Real CREATE CAST entries to/from text, for both types. postcode::text
--    and 'SW1A 1AA'::postcode already worked without these -- Postgres
--    falls back to any type's own I/O functions for the :: syntax with
--    no cast registered at all -- but that implicit fallback isn't
--    honoured by internal machinery that needs a real pg_cast entry,
--    such as ALTER COLUMN TYPE's automatic dependent-index rewrite:
--    confirmed live, a functional index built on postcode::text (e.g.
--    split_part(postcode::text, ' ', 1), or to_char(postcode,'AD') once
--    the column is briefly widened to plain TEXT and back around a
--    bulk load) fails to auto-rebuild with "function ... does not
--    exist", because the rewrite path resolves function arguments via
--    real casts, not the :: fallback.
--
--    <type> AS text is registered AS IMPLICIT, not the more conservative
--    ASSIGNMENT initially tried here -- confirmed live (regression test
--    cast.sql's idx_survives case) that ASSIGNMENT doesn't actually fix
--    the ALTER COLUMN TYPE problem above: PostgreSQL only auto-applies
--    an ASSIGNMENT cast for INSERT/UPDATE target-column coercion, never
--    for ordinary function/operator argument resolution -- and the
--    dependent-index rewrite re-resolves the stored index expression
--    (e.g. split_part(code, ' ', 1), code now postcode-typed) through
--    exactly that same ordinary argument-resolution path, which only
--    ever considers IMPLICIT casts. So ASSIGNMENT alone left the
--    original bug completely unfixed despite the cast existing in
--    pg_cast -- this was caught by the test actually exercising the
--    ALTER, not by reasoning about it, which is exactly why that test
--    is in there. text AS <type> stays ASSIGNMENT, deliberately
--    asymmetric: nothing in this fleet's actual problem needs arbitrary
--    text values implicitly coercing *into* postcode/dps in general
--    expression contexts (that direction can still raise on invalid
--    input, which is a worse thing to have fire implicitly than a safe,
--    always-succeeds-on-a-valid-value render to text), and <type> AS
--    text is the direction every real failure this pass was chasing
--    actually needed. Behaviour is unchanged either direction beyond
--    that: postcode_to_text()/dps_to_text() are exactly what ::text
--    already did; text_to_postcode()/text_to_dps() are exactly what
--    ::postcode/::dps already did (same postcode_parse()/
--    postcode_dps_parse() call, same strict raise-on-invalid-input --
--    topostcode() remains the NULL-safe alternative for messy input,
--    unchanged).
--
-- 2. postcode_render()/postcode_to_char() no longer require a full
--    postcode_binchk() pass to produce any text at all -- an individual
--    field that isn't valid/renderable now renders as '?' instead of
--    the whole call raising ERRCODE_DATA_CORRUPTED. This is what makes
--    range_lower()/range_upper()'s deliberately-partial boundary values
--    (see their own comment) safely convertible via ::text/to_char() at
--    all -- previously both raised outright for anything shorter than a
--    full code. No CREATE FUNCTION needed here: postcode_out()/
--    postcode_to_char()'s C symbols are unchanged, only their bodies.
--
-- 3. A planner support function on %, rewriting `col % 'fragment'` (for
--    a plan-time-constant fragment) into the equivalent range_lower()/
--    range_upper() bounds at plan time, so % gets an index-assisted
--    plan without repeating 1.3.0's mistake (registering % itself under
--    btree strategy 3, which requires a true equivalence relation and
--    produced wrong results -- see the comment above CREATE OPERATOR
--    FAMILY postcode_ops in postcode--1.3.0.sql). See
--    postcode_eq_partial_support()'s own comment in postcode.c for the
--    full reasoning, including exactly what it declines to handle and
--    why (a non-constant fragment, a NULL, or an invalid fragment --
--    all fall back to the plain function, unindexed but always
--    correct, same as before this pass).

CREATE FUNCTION postcode_to_text(postcode)
   RETURNS text
   AS 'MODULE_PATHNAME'
   LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION text_to_postcode(text)
   RETURNS postcode
   AS 'MODULE_PATHNAME'
   LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (postcode AS text)
   WITH FUNCTION postcode_to_text(postcode)
   AS IMPLICIT;

CREATE CAST (text AS postcode)
   WITH FUNCTION text_to_postcode(text)
   AS ASSIGNMENT;

CREATE FUNCTION dps_to_text(dps)
   RETURNS text
   AS 'MODULE_PATHNAME'
   LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION text_to_dps(text)
   RETURNS dps
   AS 'MODULE_PATHNAME'
   LANGUAGE C IMMUTABLE STRICT;

CREATE CAST (dps AS text)
   WITH FUNCTION dps_to_text(dps)
   AS IMPLICIT;

CREATE CAST (text AS dps)
   WITH FUNCTION text_to_dps(text)
   AS ASSIGNMENT;

CREATE FUNCTION postcode_eq_partial_support(internal)
   RETURNS internal
   AS 'MODULE_PATHNAME'
   LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION postcode_eq_partial(postcode, text)
   RETURNS boolean
   AS 'MODULE_PATHNAME'
   LANGUAGE C IMMUTABLE STRICT
   SUPPORT postcode_eq_partial_support;
