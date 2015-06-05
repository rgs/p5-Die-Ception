use 5.14.2;
use warnings;
use Test::More tests => 4;
use Die::Ception ':all';

my @warn;
local $SIG{__WARN__} = sub { push @warn, $_[0] };
END {
    for my $warn (@warn) {
      print "# $warn";
    }
}

our $where_to_die;
our $where_died;

sub alarmer {
    die_until_package($where_to_die, "alarm!\n");
}

package main1;
sub foo {
    eval { main2::foo(); 1 } or $::where_died = __PACKAGE__;
}
package main2;
sub foo {
    eval { main3::foo(); 1 } or $::where_died = __PACKAGE__;
}
package main3;
sub foo {
    eval { main4::foo(); 1 } or $::where_died = __PACKAGE__;
}
package main4;
sub foo {
    ::alarmer();
}

package main;
$where_to_die = 'main1'; main1::foo();
is($where_died, $where_to_die, "died in $where_to_die");
undef $where_died;
$where_to_die = 'main2'; main1::foo();
is($where_died, $where_to_die, "died in $where_to_die");
undef $where_died;
$where_to_die = 'main3'; main1::foo();
is($where_died, $where_to_die, "died in $where_to_die");
undef $where_died;
pass("finished peacefully");
