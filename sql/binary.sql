CREATE TABLE bintest (p postcode, d dps);
\copy bintest FROM '/tmp/postcode_binary_test/data/binary.data' WITH BINARY;
SELECT * FROM bintest;
