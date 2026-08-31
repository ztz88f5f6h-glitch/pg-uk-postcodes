-- 1.3.1 fixed the correctness bug (dropped %'s unsound btree strategy-3
-- registration -- see the comment in postcode--1.3.1.sql / upstream
-- issue #3) but didn't replace the index-assisted plan it removed with
-- anything. range_lower()/range_upper() are that replacement: a
-- fragment expressed as a genuine half-open range, usable with the
-- already-correct </>= strategies for full index support with no
-- opfamily trickery:
--
--    WHERE postcode >= range_lower('LS24') AND postcode < range_upper('LS24')

CREATE FUNCTION range_lower(text)
   RETURNS postcode
   AS 'MODULE_PATHNAME', 'postcode_range_lower'
   LANGUAGE C IMMUTABLE STRICT;

CREATE FUNCTION range_upper(text)
   RETURNS postcode
   AS 'MODULE_PATHNAME', 'postcode_range_upper'
   LANGUAGE C IMMUTABLE STRICT;
