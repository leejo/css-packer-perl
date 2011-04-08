#!perl -T

use Test::More;

my $not = 11;

SKIP: {
    eval { use CSS::Packer; };

    skip( 'CSS::Packer not installed!', $not ) if ( $@ );

    plan tests => $not;

    my $packer = CSS::Packer->init();

    is( $packer->compress(), 'pretty', 'Default value for compress' );
    ok( ! $packer->no_compress_comment(), 'Default value for no_compress_comment' );

    $packer->no_compress_comment( 1 );
    ok( $packer->no_compress_comment(), 'Set no_compress_comment.' );
    $packer->no_compress_comment( 0 );
    ok( ! $packer->no_compress_comment(), 'Unset no_compress_comment.' );

    $packer->compress( 'minify' );
    is( $packer->compress(), 'minify', 'Set compress to "minify".' );
    $packer->compress( 'foo' );
    is( $packer->compress(), 'minify', 'Set compress to "foo" failed.' );
    $packer->compress( 'pretty' );
    is( $packer->compress(), 'pretty', 'Setting compress back to "pretty".' );

    my $str = '';

    $packer->minify( \$str, {} );

    ok( ! $packer->no_compress_comment(), 'Default value for remove_comments is still set.' );
    is( $packer->compress(), 'pretty', 'Default value for remove_newlines is still set.' );

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