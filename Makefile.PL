use strict;
use warnings;

use inc::Module::Install;

all_from        'lib/CSS/Packer.pm';
test_requires   'Test::More'        => 0;
requires        'Regexp::RegGrp'    => "1.000";

repository 'http://github.com/nevesenin/css-packer-perl';

clean_files 't/stylesheets/s?-got.css';

auto_install();
WriteAll();