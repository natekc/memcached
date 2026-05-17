#!/usr/bin/env perl

use strict;
use Test::More tests => 30;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;

my $server = new_memcached();
my $sock = $server->sock;

# Bug 21
print $sock "set bug21 0 0 19\r\n9223372036854775807\r\n";
is(scalar <$sock>, "STORED\r\n", "stored text");
print $sock "incr bug21 1\r\n";
is(scalar <$sock>, "9223372036854775808\r\n", "bug21 incr 1");
print $sock "incr bug21 1\r\n";
is(scalar <$sock>, "9223372036854775809\r\n", "bug21 incr 2");
print $sock "decr bug21 1\r\n";
is(scalar <$sock>, "9223372036854775808\r\n", "bug21 decr");

print $sock "set num 0 0 1\r\n1\r\n";
is(scalar <$sock>, "STORED\r\n", "stored num");
mem_get_is($sock, "num", 1, "stored 1");

print $sock "incr num 1\r\n";
is(scalar <$sock>, "2\r\n", "+ 1 = 2");
mem_get_is($sock, "num", 2);

print $sock "incr num 8\r\n";
is(scalar <$sock>, "10\r\n", "+ 8 = 10");
mem_get_is($sock, "num", 10);

print $sock "decr num 1\r\n";
is(scalar <$sock>, "9\r\n", "- 1 = 9");

print $sock "decr num 9\r\n";
is(scalar <$sock>, "0\r\n", "- 9 = 0");

print $sock "decr num 5\r\n";
is(scalar <$sock>, "0\r\n", "- 5 = 0");

printf $sock "set num 0 0 10\r\n4294967296\r\n";
is(scalar <$sock>, "STORED\r\n", "stored 2**32");

print $sock "incr num 1\r\n";
is(scalar <$sock>, "4294967297\r\n", "4294967296 + 1 = 4294967297");

printf $sock "set num 0 0 %d\r\n18446744073709551615\r\n", length("18446744073709551615");
is(scalar <$sock>, "STORED\r\n", "stored 2**64-1");

print $sock "incr num 1\r\n";
is(scalar <$sock>, "0\r\n", "(2**64 - 1) + 1 = 0");

print $sock "decr bogus 5\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "can't decr bogus key");

print $sock "decr incr 5\r\n";
is(scalar <$sock>, "NOT_FOUND\r\n", "can't incr bogus key");

print $sock "set bigincr 0 0 1\r\n0\r\n";
is(scalar <$sock>, "STORED\r\n", "stored bigincr");
print $sock "incr bigincr 18446744073709551610\r\n";
is(scalar <$sock>, "18446744073709551610\r\n");

print $sock "set text 0 0 2\r\nhi\r\n";
is(scalar <$sock>, "STORED\r\n", "stored hi");
print $sock "incr text 1\r\n";
is(scalar <$sock>,
   "CLIENT_ERROR cannot increment or decrement non-numeric value\r\n",
   "hi - 1 = 0");

# Regression: safe_strtoull must reject negative deltas and negative stored
# values, including ones whose two's-complement bit pattern happens to wrap
# back into a positive (long long) value.
print $sock "set negdelta 0 0 1\r\n5\r\n";
is(scalar <$sock>, "STORED\r\n", "stored negdelta");

# Plain negative delta.
print $sock "incr negdelta -1\r\n";
is(scalar <$sock>,
   "CLIENT_ERROR invalid numeric delta argument\r\n",
   "incr rejects -1 delta");

# Negative delta whose magnitude exceeds LLONG_MAX so the unsigned value
# wraps back into a positive signed value (the original bug in #1105).
print $sock "incr negdelta -9912337881327533328\r\n";
is(scalar <$sock>,
   "CLIENT_ERROR invalid numeric delta argument\r\n",
   "incr rejects large negative delta that wraps");

print $sock "decr negdelta -1\r\n";
is(scalar <$sock>,
   "CLIENT_ERROR invalid numeric delta argument\r\n",
   "decr rejects -1 delta");

# Stored value with a leading '-' must not be treated as numeric, even when
# its strtoull result wraps back into a positive signed value.
print $sock "set negval 0 0 20\r\n-9912337881327533328\r\n";
is(scalar <$sock>, "STORED\r\n", "stored negval");
print $sock "incr negval 10\r\n";
is(scalar <$sock>,
   "CLIENT_ERROR cannot increment or decrement non-numeric value\r\n",
   "incr rejects stored negative value");

# Sanity: confirm value is unchanged after the failed incr.
mem_get_is($sock, "negval", "-9912337881327533328");
