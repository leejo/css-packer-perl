use strict;
use warnings;

use inc::Module::Install;

all_from        'lib/CSS/Packer.pm';
test_requires   'Test::More'        => 0;
requires        'Regexp::RegGrp'    => '0.001_002';

repository 'http://github.com/nevesenin/css-packer-perl';

auto_install();
WriteAll();