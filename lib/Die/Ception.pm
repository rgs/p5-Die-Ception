package Die::Ception;

use 5.14.2;
use warnings;

our $VERSION = '0.01';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = (
    all => [
        our @EXPORT_OK = qw(
            die_until_package
        )
    ]
);

1;
