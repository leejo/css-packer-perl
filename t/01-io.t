#!perl -T

# =========================================================================== #
#
# All these tests are stolen from CSS::Minifier
#
# =========================================================================== #

use Test::More;

my $not = 6;

SKIP: {
	eval( 'use CSS::Packer' );
	
	skip( 'CSS::Packer not installed!', $not ) if ( $@ );
	
	plan tests => $not;
	
	minTest( 's1', 'pretty' );
	minTest( 's2', 'pretty' );
	minTest( 's3', 'minify' );
	minTest( 's4', 'minify' );
	
	my $var = "foo {\na : b;\n}";
	CSS::Packer::minify( \$var, { 'compress' => 'minify' } );
	is( $var, 'foo{a:b;}', 'string literal input and ouput (minify)' );
	$var = "foo {\na : b;\n}";
	CSS::Packer::minify( \$var, { 'compress' => 'pretty' } );
	is( $var, "foo{\na:b;\n}\n", 'string literal input and ouput (pretty)' );
}

sub filesMatch {
	my $file1 = shift;
	my $file2 = shift;
	my $a;
	my $b;
	
	while (1) {
		$a = getc($file1);
		$b = getc($file2);
		
		if (!defined($a) && !defined($b)) { # both files end at same place
			return 1;
		}
		elsif (
			!defined($b) || # file2 ends first
			!defined($a) || # file1 ends first
			$a ne $b
		) {     # a and b not the same
			return 0;
		}
	}
}

sub minTest {
	my $filename = shift;
	my $compress = shift || 'pretty';
	
	open(INFILE, 't/stylesheets/' . $filename . '.css') or die("couldn't open file");
	open(GOTFILE, '>t/stylesheets/' . $filename . '-got.css') or die("couldn't open file");
	
	my $css = join( '', <INFILE> );
	CSS::Packer::minify( \$css, { 'compress' => $compress } );
	print GOTFILE $css;
	close(INFILE);
	close(GOTFILE);
	
	open(EXPECTEDFILE, 't/stylesheets/' . $filename . '-expected.css') or die("couldn't open file");
	open(GOTFILE, 't/stylesheets/' . $filename . '-got.css') or die("couldn't open file");
	ok(filesMatch(GOTFILE, EXPECTEDFILE));
	close(EXPECTEDFILE);
	close(GOTFILE);
}

