#ifndef POSTCODE_BINFMT_H__
#define POSTCODE_BINFMT_H__

#include <stdint.h>
#include <stdbool.h>

typedef uint32_t postcode;
typedef uint8_t  dps;

const char * postcode_version (void);

__attribute__((nonnull (1)))
__attribute__((warn_unused_result))
postcode postcode_parse (const char *str, bool partial);

__attribute__((nonnull (2)))
// buf must be at least 9 bytes: up to 8 visible characters (e.g.
// "SW1A 1AA") plus a null terminator. Never fails -- a field that isn't
// a valid, renderable value (out of range, or simply unset, other than
// district2 which is legitimately optional) renders as '?' rather than
// aborting; return value is always > 0.
int postcode_render (postcode p, char buf[9]);

__attribute__((warn_unused_result))
bool postcode_binchk (postcode p);

// Per-field validity used by postcode_binchk()/postcode_render() (see
// their comments in binfmt.c) and by postcode_to_char()'s template
// expansion in postcode.c, so a template like 'AD' can render '?' for
// an individual invalid/absent field the same way ::text now does,
// rather than requiring a full postcode_binchk() pass up front.
__attribute__((warn_unused_result)) bool valid_area      (postcode p);
__attribute__((warn_unused_result)) bool valid_district1 (postcode p);
__attribute__((warn_unused_result)) bool valid_district2 (postcode p);
__attribute__((warn_unused_result)) bool valid_sector    (postcode p);
__attribute__((warn_unused_result)) bool valid_walk1     (postcode p);
__attribute__((warn_unused_result)) bool valid_walk2     (postcode p);

__attribute__((nonnull (1)))
__attribute__((warn_unused_result))
dps postcode_dps_parse (const char *str);

__attribute__((nonnull (2)))
int postcode_dps_render (dps d, char buf[3]);

__attribute__((warn_unused_result))
bool postcode_dps_binchk (dps d);

#endif
