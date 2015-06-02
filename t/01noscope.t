use strict;
use warnings;
use Test::More tests => 7;

BEGIN { use_ok 'Die::Ception', ':all' }

my $eval_ok = eval { die_until_package("main","foo\n"); 1 };
my $err = $@;
ok(!$eval_ok, 'eval died');
is($err, "foo\n", "got error message");
undef $err;

sub this_dies {
    die_until_package("main", "bar\n");
}
$eval_ok = eval { this_dies(); 1 };
$err = $@;
ok(!$eval_ok, 'eval died');
is($err, "bar\n", "got error message");
undef $err;

package main2;
$eval_ok = eval { ::die_until_package("main2","foo\n"); 1 };
package main;
$err = $@;
ok(!$eval_ok, 'eval died');
is($err, "foo\n", "got error message");
undef $err;
