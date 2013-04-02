package CSS::Packer;

use 5.008009;
use warnings;
use strict;
use Carp;
use Regexp::RegGrp;

our $VERSION = '1.003_001';

our @COMPRESSION_LEVELS = ( 'minify', 'pretty' );
our $DEFAULT_COMPRESSION_LEVEL = 'pretty';

our $ARGUMENTS = [ 'compression_level', 'no_compress_comment', 'no_copyright_comment', 'copyright_comment_text' ];

our $COPYRIGHT_COMMENT = '\/\*((?>[^*]|\*[^/])*copyright(?>[^*]|\*[^/])*)\*\/';

our $DICTIONARY = {
    'STRING1' => qr~"(?>(?:(?>[^"\\]+)|\\.|\\"|\\\s)*)"~,
    'STRING2' => qr~'(?>(?:(?>[^'\\]+)|\\.|\\'|\\\s)*)'~
};

our $WHITESPACES        = '\s+';
our $RULE               = '([^{};]+)\{([^{}]*)\}';
our $URL                = 'url\(\s*(' . $DICTIONARY->{STRING1} . '|' . $DICTIONARY->{STRING2} . '|[^\'"\s]+?)\s*\)';
our $IMPORT             = '\@import\s+(' . $DICTIONARY->{STRING1} . '|' . $DICTIONARY->{STRING2} . '|' . $URL . ')([^;]*);';
our $MEDIA              = '\@media([^{}]+)\{((?:' . $IMPORT . '|' . $RULE . '|' . $WHITESPACES . ')+)\}';
our $DECLARATION        = '((?>[^;:]+)):(?<=:)((?>[^;]*))(?:;|\s*$)';
our $COMMENT            = '(\/\*[^*]*\*+([^/][^*]*\*+)*\/)';
our $PACKER_COMMENT     = '\/\*\s*CSS::Packer\s*(\w+)\s*\*\/';
our $CHARSET            = '^(\@charset)\s+(' . $DICTIONARY->{STRING1} . '|' . $DICTIONARY->{STRING2} . ');';
our $CONTENT_VALUE_ATTR = qr~([\w-]+)\(\s*([\w-]+)\s*\)~;
our @REGGRPS            = ( 'whitespaces', 'url', 'import', 'declaration', 'rule', 'content_value', 'mediarules', 'global' );

our $REGGRPS_SCHEMA = {
    url           => ['url'],
    declaration   => ['declaration'],
    rule          => ['rule'],
    content_value => ['content_value'],
    mediarules    => [ 'import', 'rule', 'whitespaces' ],
    global        => [ 'charset', 'media', 'import', 'rule', 'whitespaces' ]
};

our $REGGRPS = {
    content_value => [
        { regexp => $DICTIONARY->{STRING1} },
        { regexp => $DICTIONARY->{STRING2} },
        {
            regexp      => $CONTENT_VALUE_ATTR,
            replacement => sub {
                return $_[0]->{submatches}->[0] . '(' . $_[0]->{submatches}->[1] . ')';
                }
        },
        {
            regexp      => $WHITESPACES,
            replacement => ''
        }
    ],
    whitespaces => [
        {
            regexp      => $WHITESPACES,
            replacement => ''
        }
    ],
    url => [
        {
            regexp      => $URL,
            replacement => sub {
                my $url = $_[0]->{submatches}->[0];

                return 'url(' . $url . ')';
                }
        }
    ],
    import => [
        {
            regexp      => $IMPORT,
            replacement => sub {
                my $submatches = $_[0]->{submatches};
                my $url        = $submatches->[0];
                my $mediatype  = $submatches->[2];

                my $compression_level = $_[0]->{opts}->{packer}->get_compression_level();

                $_[0]->{opts}->{packer}->_get_reggrp( 'url' )->exec( \$url );

                $mediatype =~ s/^\s*|\s*$//gs;
                $mediatype =~ s/\s*,\s*/,/gsm;

                return '@import ' . $url . ( $mediatype ? ( ' ' . $mediatype ) : '' ) . ';' . ( $compression_level eq 'pretty' ? "\n" : '' );
                }
        }
    ],
    declaration => [
        {
            regexp      => $DECLARATION,
            replacement => sub {
                my $submatches = $_[0]->{submatches};
                my $key        = $submatches->[0];
                my $value      = $submatches->[1];

                my $compression_level = $_[0]->{opts}->{packer}->get_compression_level();

                $key   =~ s/^\s*|\s*$//gs;
                $value =~ s/^\s*|\s*$//gs;

                if ( $key eq 'content' ) {
                    $_[0]->{opts}->{packer}->_get_reggrp( 'content_value' )->exec( \$value );
                }
                else {
                    $value =~ s/\s*,\s*/,/gsm;
                    $value =~ s/\s+/ /gsm;
                }

                return '' if ( not $key or $value eq '' );

                return $key . ':' . $value . ';' . ( $compression_level eq 'pretty' ? "\n" : '' );
                }
        }
    ],
    rule => [
        {
            regexp      => $RULE,
            replacement => sub {
                my $submatches  = $_[0]->{submatches};
                my $selector    = $submatches->[0];
                my $declaration = $submatches->[1];

                my $compression_level = $_[0]->{opts}->{packer}->get_compression_level();

                $selector =~ s/^\s*|\s*$//gs;
                $selector =~ s/\s*,\s*/,/gsm;
                $selector =~ s/\s+/ /gsm;

                $declaration =~ s/^\s*|\s*$//gs;

                $_[0]->{opts}->{packer}->_get_reggrp( 'declaration' )->exec( \$declaration );

                my $store = $selector . '{' . ( $compression_level eq 'pretty' ? "\n" : '' ) . $declaration . '}' . ( $compression_level eq 'pretty' ? "\n" : '' );

                $store = '' unless ( $selector or $declaration );

                return $store;
                }
        }
    ],
    charset => [
        {
            regexp      => $CHARSET,
            replacement => sub {
                my $submatches = $_[0]->{submatches};

                my $compression_level = $_[0]->{opts}->{packer}->get_compression_level();

                return $submatches->[0] . " " . $submatches->[1] . ( $compression_level eq 'pretty' ? "\n" : '' );
                }
        }
    ],
    media => [
        {
            regexp      => $MEDIA,
            replacement => sub {
                my $submatches = $_[0]->{submatches};
                my $mediatype  = $submatches->[0];
                my $mediarules = $submatches->[1];

                my $compression_level = $_[0]->{opts}->{packer}->get_compression_level();

                $mediatype =~ s/^\s*|\s*$//gs;
                $mediatype =~ s/\s*,\s*/,/gsm;

                $_[0]->{opts}->{packer}->_get_reggrp( 'mediarules' )->exec( \$mediarules );

                return '@media ' . $mediatype . '{' . ( $compression_level eq 'pretty' ? "\n" : '' ) . $mediarules . '}' . ( $compression_level eq 'pretty' ? "\n" : '' );
                }
        }
    ]
};

# --------------------------------------------------------------------------- #

sub set_compression_level {
    my ( $self, $value ) = @_;

    $value ||= $DEFAULT_COMPRESSION_LEVEL;

    if ( grep( $value eq $_, @COMPRESSION_LEVELS ) ) {
        $self->{_compression_level} = $value;
    }
    else {
        carp( 'Unknown value for compression_level!' );
    }
}

sub get_compression_level {
    my ( $self ) = @_;

    return $self->{_compression_level};
}

sub set_no_compress_comment {
    my ( $self, $no_compress_comment ) = @_;

    $self->{_no_compress_comment} = $no_compress_comment ? 1 : 0;
}

sub get_no_compress_comment {
    my ( $self ) = @_;

    return $self->{_no_compress_comment};
}

sub set_no_copyright_comment {
    my ( $self, $no_copyright_comment ) = @_;

    $self->{_no_copyright_comment} = $no_copyright_comment ? 1 : 0;
}

sub get_no_copyright_comment {
    my ( $self ) = @_;

    return $self->{_no_copyright_comment};
}

sub set_copyright_comment_text {
    my ( $self, $value ) = @_;

    $value ||= '';

    $value =~ s/^\s*|\s*$//gs;

    $self->{_copyright_comment_text} = $value;
}

sub _set_existing_copyright_comment_text {
    my ( $self, $value ) = @_;

    $value =~ s/^\s*|\s*$//gs;

    $self->{_existing_copyright_comment_text} = $value;
}

sub _get_copyright_comment {
    my ( $self ) = @_;

    my $copyright_text = $self->{_copyright_comment_text} || $self->{_existing_copyright_comment_text};

    return '' unless ( $copyright_text );

    return '/* ' . $copyright_text . ' */' . "\n";
}

sub _args_are_valid {
    my ( $self, $args ) = @_;

    if ( ref( $args ) ne 'HASH' ) {
        carp( 'Argument must be a hashref!' );
        return 0;
    }

    foreach my $key ( keys( %$args ) ) {
        unless ( $key ~~ $ARGUMENTS ) {
            carp( 'Unknown key "' . $key . '"!' );
            return 0;
        }
        if ( ref( $args->{$key} ) ) {
            carp( 'Value for key "' . $key . '" must be a scalar!' );
            return 0;
        }
    }

    return 1;
}

sub new {
    my ( $class, $args ) = @_;
    my $self  = {};

    $args ||= {};

    bless( $self, $class );

    return unless ( $self->_args_are_valid( $args ) );

    foreach my $arg ( @$ARGUMENTS ) {
        my $method = 'set_' . $arg;
        $self->$method( $args->{$arg} );
    }

    $self->_create_reggrps();

    return $self;
}

sub _set_reggrp {
    my ( $self, $reggrp_name, $reggrp ) = @_;

    $self->{_reggrps}->{$reggrp_name} = $reggrp;
}

sub _get_reggrp {
    my ( $self, $reggrp_name ) = @_;

    return $self->{_reggrps}->{$reggrp_name};
}

sub _create_reggrps {
    my ( $self ) = @_;

    foreach my $reggrp_schema_key ( keys( %$REGGRPS_SCHEMA ) ) {
        my $reggrp_data = [];
        foreach my $reggrp_data_key ( @{ $REGGRPS_SCHEMA->{$reggrp_schema_key} } ) {
            push( @$reggrp_data, @{ $REGGRPS->{$reggrp_data_key} } );
        }
        $self->_set_reggrp( $reggrp_schema_key, Regexp::RegGrp->new( { reggrp => $reggrp_data } ) );
    }
}

*init = \&new;

sub minify {
    my ( $self, $input, $opts );

    unless (ref( $_[0] )
        and ref( $_[0] ) eq __PACKAGE__ )
    {
        $self = __PACKAGE__->init();

        shift( @_ ) unless ( ref( $_[0] ) );

        ( $input, $opts ) = @_;
    }
    else {
        ( $self, $input, $opts ) = @_;
    }

    if ( ref( $input ) ne 'SCALAR' ) {
        carp( 'First argument must be a scalarref!' );
        return undef;
    }

    $opts ||= {};

    return unless ( $self->_args_are_valid( $opts ) );

    foreach my $key ( keys( %$opts ) ) {
        my $method = 'set_' . $key;

        $self->$method( $opts->{$key} );
    }

    my $css  = \'';
    my $cont = 'void';

    if ( defined( wantarray ) ) {
        my $tmp_input = ref( $input ) ? ${$input} : $input;

        $css  = \$tmp_input;
        $cont = 'scalar';
    }
    else {
        $css = ref( $input ) ? $input : \$input;
    }

    my $copyright_comment = '';

    if ( ${$css} =~ /$COPYRIGHT_COMMENT/ism ) {
        $copyright_comment = $1;
    }

    # Resets copyright_comment() if there is no copyright comment
    $self->_set_existing_copyright_comment_text( $copyright_comment );

    if ( ! $self->get_no_compress_comment() && ${$css} =~ /$PACKER_COMMENT/ ) {
        my $compress = $1;
        if ( $compress eq '_no_compress_' ) {
            return ( $cont eq 'scalar' ) ? ${$css} : undef;
        }

        $self->set_compression_level( $compress );
    }

    ${$css} =~ s/$COMMENT/ /gsm;

    $self->_get_reggrp( 'global' )->exec( $css, { packer => $self } );

    unless ( $self->get_no_copyright_comment() ) {
        ${$css} = $self->_get_copyright_comment() . ${$css};
    }

    return ${$css} if ( $cont eq 'scalar' );
}

1;

__END__

=head1 NAME

CSS::Packer - Another CSS minifier

=head1 VERSION

Version 1.003_001

=head1 DESCRIPTION

A fast pure Perl CSS minifier.

=head1 SYNOPSIS

    use CSS::Packer;

    my $packer = CSS::Packer->init();

    $packer->minify( $scalarref, $opts );

To return a scalar without changing the input simply use (e.g. example 2):

    my $ret = $packer->minify( $scalarref, $opts );

For backward compatibility it is still possible to call 'minify' as a function:

    CSS::Packer::minify( $scalarref, $opts );

First argument must be a scalarref of CSS-Code.
Second argument must be a hashref of options. Possible options are:

=over 4

=item compress

Defines compression level. Possible values are 'minify' and 'pretty'.
Default value is 'pretty'.

'pretty' converts

    a {
    color:          black
    ;}   div

    { width:100px;
    }

to

    a{
    color:black;
    }
    div{
    width:100px;
    }

'minify' converts the same rules to

    a{color:black;}div{width:100px;}

=item copyright

You can add a copyright notice at the top of the script.

=item no_copyright_comment

If there is a copyright notice in a comment it will only be removed if this
option is set to a true value. Otherwise the first comment that contains the
word "copyright" will be added at the top of the packed script. A copyright
comment will be overwritten by a copyright notice defined with the copyright
option.

=item no_compress_comment

If not set to a true value it is allowed to set a CSS comment that
prevents the input being packed or defines a compression level.

    /* CSS::Packer _no_compress_ */
    /* CSS::Packer pretty */

=back

=head1 AUTHOR

Merten Falk, C<< <nevesenin at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests through
the web interface at L<http://github.com/nevesenin/css-packer-perl/issues>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc CSS::Packer

=head1 COPYRIGHT & LICENSE

Copyright 2008 - 2011 Merten Falk, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<CSS::Minifier>,
L<CSS::Minifier::XS>

=cut
