#!perl -T

use Test::More;

my $not = 18;

SKIP: {
    eval { use CSS::Packer; };

    skip( 'CSS::Packer not installed!', $not ) if ( $@ );

    plan tests => $not;

    my $packer = CSS::Packer->init();

    ok( ! $packer->get_no_compress_comment(), 'Default value for no_compress_comment' );
    ok( ! $packer->get_no_copyright_comment(), 'Default value for remove_copyright' );
    is( $packer->get_compression_level(), 'pretty', 'Default value for compression_level' );
    is( $packer->_get_copyright_comment(), '', 'Default value for copyright' );

    $packer->set_no_compress_comment( 1 );
    ok( $packer->get_no_compress_comment(), 'Set no_compress_comment.' );
    $packer->set_no_compress_comment( 0 );
    ok( ! $packer->get_no_compress_comment(), 'Unset no_compress_comment.' );

    $packer->set_no_copyright_comment( 1 );
    ok( $packer->get_no_copyright_comment(), 'Set no_copyright_comment.' );
    $packer->set_no_copyright_comment( 0 );
    ok( ! $packer->get_no_copyright_comment(), 'Unset no_copyright_comment.' );

    $packer->set_compression_level( 'minify' );
    is( $packer->get_compression_level(), 'minify', 'Set compression_level to "minify".' );
    $packer->set_compression_level( 'foo' );
    is( $packer->get_compression_level(), 'minify', 'Set compression_level to "foo" failed.' );
    $packer->set_compression_level( 'pretty' );
    is( $packer->get_compression_level(), 'pretty', 'Setting compression_level back to "pretty".' );

    $packer->set_copyright_comment_text( 'Ich war\'s!' );
    is( $packer->_get_copyright_comment(), "/* Ich war's! */\n", 'Set copyright' );
    $packer->set_copyright_comment_text( 'Ich war\'s' . "\n" . 'nochmal!' );
    is( $packer->_get_copyright_comment(), "/* Ich war's\nnochmal! */\n", 'Set copyright' );
    $packer->set_copyright_comment_text( '' );
    is( $packer->_get_copyright_comment(), '', 'Reset copyright' );

    my $str = '';

    $packer->minify( \$str, {} );

    ok( ! $packer->get_no_compress_comment(), 'Default value for no_compress_comment is still set.' );
    is( $packer->get_compression_level(), 'pretty', 'Default value for compression_level is still set.' );

    $packer->minify(
        \$str,
        {
            compression_level            => 'minify',
            no_compress_comment => 1,
        }
    );

    ok( $packer->get_no_compress_comment(), 'Set no_compress_comment again.' );
    is( $packer->get_compression_level(), 'minify', 'Set compression_level to "minify" again.' );
}