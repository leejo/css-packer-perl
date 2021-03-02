#!perl -T

use Test::More;

my $not = 18;

SKIP: {
    eval { use CSS::Packer; };

    skip( 'CSS::Packer not installed!', $not ) if ( $@ );

    plan tests => $not;

    my $packer = CSS::Packer->init();

    ok( ! $packer->no_compress_comment(), 'Default value for no_compress_comment' );
    ok( ! $packer->remove_copyright(), 'Default value for remove_copyright' );
    is( $packer->compress(), 'pretty', 'Default value for compress' );
    is( $packer->copyright(), '', 'Default value for copyright' );

    $packer->no_compress_comment( 1 );
    ok( $packer->no_compress_comment(), 'Set no_compress_comment.' );
    $packer->no_compress_comment( 0 );
    ok( ! $packer->no_compress_comment(), 'Unset no_compress_comment.' );

    $packer->remove_copyright( 1 );
    ok( $packer->remove_copyright(), 'Set remove_copyright.' );
    $packer->remove_copyright( 0 );
    ok( ! $packer->remove_copyright(), 'Unset remove_copyright.' );

    $packer->compress( 'minify' );
    is( $packer->compress(), 'minify', 'Set compress to "minify".' );
    $packer->compress( 'foo' );
    is( $packer->compress(), 'minify', 'Set compress to "foo" failed.' );
    $packer->compress( 'pretty' );
    is( $packer->compress(), 'pretty', 'Setting compress back to "pretty".' );

    $packer->copyright( 'Ich war\'s!' );
    is( $packer->copyright(), "/* Ich war's! */\n", 'Set copyright' );
    $packer->copyright( 'Ich war\'s' . "\n" . 'nochmal!' );
    is( $packer->copyright(), "/* Ich war's\nnochmal! */\n", 'Set copyright' );
    $packer->copyright( '' );
    is( $packer->copyright(), '', 'Reset copyright' );

    my $str = '';

    $packer->minify( \$str, {} );

    ok( ! $packer->no_compress_comment(), 'Default value for no_compress_comment is still set.' );
    is( $packer->compress(), 'pretty', 'Default value for compress is still set.' );

    $packer->minify(
        \$str,
        {
            compress            => 'minify',
            no_compress_comment => 1,
        }
    );

    ok( $packer->no_compress_comment(), 'Set no_compress_comment again.' );
    is( $packer->compress(), 'minify', 'Set compress to "minify" again.' );
}
