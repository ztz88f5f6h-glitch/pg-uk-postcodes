#include <postgres.h>
#include <varatt.h>
#include <utils/builtins.h>
#include <libpq/pqformat.h>

#ifdef PG_MODULE_MAGIC
PG_MODULE_MAGIC;
#endif

#include "postcode.h"
#include "binfmt.h"

#define PG_RETURN_POSTCODE(p) return UInt32GetDatum(p)
#define PG_GETARG_POSTCODE(n) DatumGetUInt32(PG_GETARG_DATUM(n))

#define PG_RETURN_DPS(p)      return UInt8GetDatum(p)
#define PG_GETARG_DPS(n)      DatumGetUInt8(PG_GETARG_DATUM(n))

Datum postcode_in             (PG_FUNCTION_ARGS);
Datum postcode_out            (PG_FUNCTION_ARGS);
Datum postcode_recv           (PG_FUNCTION_ARGS);
Datum postcode_send           (PG_FUNCTION_ARGS);
Datum postcode_validate       (PG_FUNCTION_ARGS);
Datum postcode_cmp            (PG_FUNCTION_ARGS);
Datum postcode_eq             (PG_FUNCTION_ARGS);
Datum postcode_ne             (PG_FUNCTION_ARGS);
Datum postcode_lt             (PG_FUNCTION_ARGS);
Datum postcode_gt             (PG_FUNCTION_ARGS);
Datum postcode_lte            (PG_FUNCTION_ARGS);
Datum postcode_gte            (PG_FUNCTION_ARGS);
Datum postcode_cmp_partial    (PG_FUNCTION_ARGS);
Datum postcode_eq_partial     (PG_FUNCTION_ARGS);
Datum postcode_ne_partial     (PG_FUNCTION_ARGS);
Datum postcode_range_lower    (PG_FUNCTION_ARGS);
Datum postcode_range_upper    (PG_FUNCTION_ARGS);

Datum dps_in                  (PG_FUNCTION_ARGS);
Datum dps_out                 (PG_FUNCTION_ARGS);
Datum dps_recv                (PG_FUNCTION_ARGS);
Datum dps_send                (PG_FUNCTION_ARGS);
Datum dps_validate            (PG_FUNCTION_ARGS);
Datum dps_cmp                 (PG_FUNCTION_ARGS);
Datum dps_eq                  (PG_FUNCTION_ARGS);
Datum dps_ne                  (PG_FUNCTION_ARGS);
Datum dps_lt                  (PG_FUNCTION_ARGS);
Datum dps_gt                  (PG_FUNCTION_ARGS);
Datum dps_lte                 (PG_FUNCTION_ARGS);
Datum dps_gte                 (PG_FUNCTION_ARGS);

__attribute__((warn_unused_result))
static inline postcode postcode_mask (postcode a, postcode b) {
   if (! GET_AREA(b))      return 0;
   if (! GET_DISTRICT1(b)) return MASK_DISTRICT(a);
   if (! GET_SECTOR(b))    return MASK_SECTOR(a);
   if (! GET_WALK1(b))     return MASK_WALK(a);
   return a;
}

// Number of low-order bits NOT pinned by a parsed partial fragment b --
// mirrors postcode_mask()'s own branch structure exactly (same ordering,
// same fields), just returning a bit count instead of directly clearing
// them. Used by range_lower()/range_upper() below. Returns -1 for an
// empty/invalid fragment (no area given at all).
__attribute__((warn_unused_result))
static inline int postcode_free_bits (postcode b) {
   if (! GET_AREA(b))      return -1;
   if (! GET_DISTRICT1(b)) return 24;
   if (! GET_SECTOR(b))    return 14;
   if (! GET_WALK1(b))     return 10;
   return 0;
}


PG_FUNCTION_INFO_V1(postcode_in);

Datum postcode_in (PG_FUNCTION_ARGS) {
   postcode p = postcode_parse(PG_GETARG_CSTRING(0), false);

   if (p == 0)
      ereport(ERROR, (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                      errmsg (_("cannot parse input for type postcode"))));

   PG_RETURN_POSTCODE(p);
}


PG_FUNCTION_INFO_V1(postcode_out);

Datum postcode_out (PG_FUNCTION_ARGS) {
   // postcode_render() writes up to 8 visible characters (2-letter area +
   // 2-char district + space + sector + 2-char walk, e.g. "SW1A 1AA") plus
   // a null terminator -- 9 bytes, not 8. This under-allocation has been a
   // one-byte heap overflow for every postcode with a 2-letter area and a
   // 2-char district since this function was written.
   char *str = palloc(9);

   if (postcode_render(PG_GETARG_POSTCODE(0), str) == 0)
      ereport(ERROR, (errcode(ERRCODE_DATA_CORRUPTED),
                      errmsg (_("cannot render corrupted binary data to text"))));

   PG_RETURN_CSTRING(str);
}


PG_FUNCTION_INFO_V1(postcode_recv);

Datum postcode_recv (PG_FUNCTION_ARGS) {
   postcode p = pq_getmsgint((StringInfo) PG_GETARG_POINTER(0), sizeof(postcode));

   if (! postcode_binchk(p))
      ereport(ERROR, (errcode(ERRCODE_INVALID_BINARY_REPRESENTATION),
                      errmsg (_("received binary data is invalid for type postcode")),
                      errhint(_("server binary format version is %s"), STR(EXTVERSION))));

   PG_RETURN_POSTCODE(p);
}


PG_FUNCTION_INFO_V1(postcode_send);

Datum postcode_send (PG_FUNCTION_ARGS) {
   StringInfoData b;
   pq_begintypsend(&b);
   pq_sendint(&b, PG_GETARG_POSTCODE(0), sizeof(postcode));
   PG_RETURN_BYTEA_P(pq_endtypsend(&b));
}


PG_FUNCTION_INFO_V1(postcode_validate);

Datum postcode_validate (PG_FUNCTION_ARGS) {
   postcode p = postcode_parse(text_to_cstring(PG_GETARG_TEXT_P(0)), false);
   PG_RETURN_BOOL(p ? TRUE : FALSE);
}


PG_FUNCTION_INFO_V1(postcode_cmp);

Datum postcode_cmp (PG_FUNCTION_ARGS) {
   postcode a = PG_GETARG_POSTCODE(0),
            b = PG_GETARG_POSTCODE(1);

   if (a == b) PG_RETURN_INT32( 0);
   if (a >  b) PG_RETURN_INT32( 1);
   else        PG_RETURN_INT32(-1);
}


PG_FUNCTION_INFO_V1(postcode_eq);

Datum postcode_eq (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_POSTCODE(0) == PG_GETARG_POSTCODE(1));
}


PG_FUNCTION_INFO_V1(postcode_ne);

Datum postcode_ne (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_POSTCODE(0) != PG_GETARG_POSTCODE(1));
}


PG_FUNCTION_INFO_V1(postcode_lt);

Datum postcode_lt (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_POSTCODE(0) < PG_GETARG_POSTCODE(1));
}


PG_FUNCTION_INFO_V1(postcode_gt);

Datum postcode_gt (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_POSTCODE(0) > PG_GETARG_POSTCODE(1));
}


PG_FUNCTION_INFO_V1(postcode_lte);

Datum postcode_lte (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_POSTCODE(0) <= PG_GETARG_POSTCODE(1));
}


PG_FUNCTION_INFO_V1(postcode_gte);

Datum postcode_gte (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_POSTCODE(0) >= PG_GETARG_POSTCODE(1));
}


PG_FUNCTION_INFO_V1(postcode_cmp_partial);

Datum postcode_cmp_partial (PG_FUNCTION_ARGS) {
   postcode b = postcode_parse(text_to_cstring(PG_GETARG_TEXT_P(1)), true);
   postcode a = postcode_mask(PG_GETARG_POSTCODE(0), b);

   if (b == 0) PG_RETURN_INT32(-1); // invalid postcode fragment
   if (a == b) PG_RETURN_INT32( 0);
   if (a >  b) PG_RETURN_INT32( 1);
   else        PG_RETURN_INT32(-1);
}


PG_FUNCTION_INFO_V1(postcode_eq_partial);

Datum postcode_eq_partial (PG_FUNCTION_ARGS) {
   postcode b = postcode_parse(text_to_cstring(PG_GETARG_TEXT_P(1)), true);
   postcode a = postcode_mask(PG_GETARG_POSTCODE(0), b);

   if (b == 0) PG_RETURN_BOOL(false); // invalid postcode fragment
   PG_RETURN_BOOL(a == b);
}


PG_FUNCTION_INFO_V1(postcode_ne_partial);

Datum postcode_ne_partial (PG_FUNCTION_ARGS) {
   postcode b = postcode_parse(text_to_cstring(PG_GETARG_TEXT_P(1)), true);
   postcode a = postcode_mask(PG_GETARG_POSTCODE(0), b);

   if (b == 0) PG_RETURN_BOOL(true); // invalid postcode fragment
   PG_RETURN_BOOL(a != b);
}


// range_lower()/range_upper() -- the sound, index-friendly replacement
// for indexed prefix matching. % was formerly registered under btree
// strategy 3 (the "equality" slot) to get an index-assisted plan, but
// PostgreSQL requires that strategy's operator to be a genuine
// equivalence relation for the planner's equivalence-class reasoning to
// stay sound, and % isn't one (two different postcodes can both match
// the same fragment without being equal to each other). Fixed by
// dropping that opfamily registration; these two functions express a
// fragment as a genuine half-open range instead, usable with the
// ordinary (and ordinarily correct) </>= strategies:
//
//    WHERE code >= range_lower('SW1') AND code < range_upper('SW1')
//
// range_lower() is just the fragment's own parsed value -- postcode_parse
// already leaves every unspecified trailing field zeroed. range_upper()
// is the smallest value strictly greater than every value matching the
// fragment: add one at the bit position immediately above whichever
// field postcode_free_bits() says is the first absent one, mirroring
// postcode_mask()'s own field-by-field logic exactly so this can't drift
// out of sync with how % itself decides what "matches this fragment"
// means. Both raise an error for a malformed fragment rather than
// silently returning a value, unlike %/!% -- these are meant to be
// called with a literal, known-good fragment when constructing a query.
//
// IMPORTANT: the returned values are comparison bounds, not necessarily
// valid/renderable postcodes in their own right, for any fragment
// shorter than a full 7-character code -- eg range_lower('BA') has no
// district set at all, which correctly fails postcode_binchk (it isn't
// a real postcode, it's "the smallest packed value with area=BA"). Only
// a full code's lower bound is guaranteed renderable, since that's
// exactly the parsed input value with nothing masked out. Confirmed
// live: range_upper() on a full code ending in a walk letter of 'Z' can
// even render as a non-alphabetic character (Z's raw value + 1) if
// forced through ::text -- harmless for its actual purpose (comparison
// bounds don't need to look like real postcodes, only sort correctly
// relative to them, which this does), but a reminder these functions
// are for `>=`/`<` expressions, not for display.

PG_FUNCTION_INFO_V1(postcode_range_lower);

Datum postcode_range_lower (PG_FUNCTION_ARGS) {
   postcode b = postcode_parse(text_to_cstring(PG_GETARG_TEXT_P(0)), true);
   int free_bits = postcode_free_bits(b);

   if (free_bits < 0)
      ereport(ERROR, (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                      errmsg (_("invalid postcode prefix"))));

   PG_RETURN_POSTCODE(b);
}


PG_FUNCTION_INFO_V1(postcode_range_upper);

Datum postcode_range_upper (PG_FUNCTION_ARGS) {
   postcode b = postcode_parse(text_to_cstring(PG_GETARG_TEXT_P(0)), true);
   int free_bits = postcode_free_bits(b);

   if (free_bits < 0)
      ereport(ERROR, (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                      errmsg (_("invalid postcode prefix"))));

   PG_RETURN_POSTCODE(b + (1u << free_bits));
}


PG_FUNCTION_INFO_V1(postcode_to_char);

Datum postcode_to_char (PG_FUNCTION_ARGS) {
   postcode p = PG_GETARG_POSTCODE(0);
   text  *txt = PG_GETARG_TEXT_P(1);
   char  *str = VARDATA(txt);
   size_t len = VARSIZE(txt) - VARHDRSZ;

   if (! postcode_binchk(p))
      ereport(ERROR, (errcode(ERRCODE_DATA_CORRUPTED),
                      errmsg (_("cannot render corrupted binary data to text"))));

   // each template pattern expands to a maximum of two characters
   if (len >= SIZE_MAX/2)
      ereport(ERROR, (errcode(ERRCODE_PROGRAM_LIMIT_EXCEEDED),
                      errmsg (_("template argument too long"))));

   char *buf = palloc(len*2 + 1);
   char *b = buf;

   for (size_t i = 0; i != len; i++) {
      switch (str[i]) {
         case 'A': WRITE_AREA(b, p);     break;
         case 'D': WRITE_DISTRICT(b, p); break;
         case 'S': WRITE_SECTOR(b, p);   break;
         case 'W': WRITE_WALK(b, p);     break;

        default: *(b++) = str[i];
      }
   }
   *b = '\0';

   PG_RETURN_TEXT_P(cstring_to_text(buf));
}


PG_FUNCTION_INFO_V1(dps_in);

Datum dps_in (PG_FUNCTION_ARGS) {
   dps d = postcode_dps_parse(PG_GETARG_CSTRING(0));

   if (d == 0)
      ereport(ERROR, (errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
                      errmsg (_("cannot parse input for type dps"))));

   PG_RETURN_DPS(d);
}


PG_FUNCTION_INFO_V1(dps_out);

Datum dps_out (PG_FUNCTION_ARGS) {
   char *str = palloc(3);
   postcode_dps_render(PG_GETARG_DPS(0), str);
   PG_RETURN_CSTRING(str);
}


PG_FUNCTION_INFO_V1(dps_recv);

Datum dps_recv (PG_FUNCTION_ARGS) {
   dps d = pq_getmsgint((StringInfo) PG_GETARG_POINTER(0), sizeof(dps));

   if (! postcode_dps_binchk(d))
      ereport(ERROR, (errcode(ERRCODE_INVALID_BINARY_REPRESENTATION),
                      errmsg (_("received binary data is invalid for type dps")),
                      errhint(_("server binary format version is %s"), STR(EXTVERSION))));

   PG_RETURN_DPS(d);
}


PG_FUNCTION_INFO_V1(dps_send);

Datum dps_send (PG_FUNCTION_ARGS) {
   StringInfoData b;
   pq_begintypsend(&b);
   pq_sendint(&b, PG_GETARG_DPS(0), sizeof(dps));
   PG_RETURN_BYTEA_P(pq_endtypsend(&b));
}


PG_FUNCTION_INFO_V1(dps_validate);

Datum dps_validate (PG_FUNCTION_ARGS) {
   dps d = postcode_dps_parse(text_to_cstring(PG_GETARG_TEXT_P(0)));
   PG_RETURN_BOOL(d ? TRUE : FALSE);
}


PG_FUNCTION_INFO_V1(dps_cmp);

Datum dps_cmp (PG_FUNCTION_ARGS) {
   dps a = PG_GETARG_DPS(0),
       b = PG_GETARG_DPS(1);

   if (a == b) PG_RETURN_INT32( 0);
   if (a >  b) PG_RETURN_INT32( 1);
   else        PG_RETURN_INT32(-1);
}


PG_FUNCTION_INFO_V1(dps_eq);

Datum dps_eq (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_DPS(0) == PG_GETARG_DPS(1));
}


PG_FUNCTION_INFO_V1(dps_ne);

Datum dps_ne (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_DPS(0) != PG_GETARG_DPS(1));
}


PG_FUNCTION_INFO_V1(dps_lt);

Datum dps_lt (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_DPS(0) < PG_GETARG_DPS(1));
}


PG_FUNCTION_INFO_V1(dps_gt);

Datum dps_gt (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_DPS(0) > PG_GETARG_DPS(1));
}


PG_FUNCTION_INFO_V1(dps_lte);

Datum dps_lte (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_DPS(0) <= PG_GETARG_DPS(1));
}


PG_FUNCTION_INFO_V1(dps_gte);

Datum dps_gte (PG_FUNCTION_ARGS) {
   PG_RETURN_BOOL(PG_GETARG_DPS(0) >= PG_GETARG_DPS(1));
}
