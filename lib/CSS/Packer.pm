package CSS::Packer;

use 5.008;
use warnings;
use strict;
use Carp;

use vars qw/$VERSION $RULE $DECLARATION $COMMENT $CHARSET $MEDIA $IMPORT $PLACEHOLDER/;

$VERSION = '0.2';

$RULE = qr/([^{}~;]+)\{([^{}]*)\}/;

$IMPORT = qr/\@import\s+("[^"]+"|'[^']+'|url\(\s*"[^"]+"\s*\)|url\(\s*'[^']+'\s*\)|url\(\s*[^'"]+?\s*\))(.*?);/;

$MEDIA = qr/\@media([^{}]+){((\s*$IMPORT|$RULE)+)\s*}/;

$DECLARATION = qr/((?>[^;:]+)):(?<=:)((?>[^;]*));/;

$COMMENT = qr/(\/\*[^*]*\*+([^\/][^*]*\*+)*\/)/;

$CHARSET = qr/^(\@charset)\s+("[^"]*";|'[^']*';)/;

$PLACEHOLDER = qr/(?>[^~]*)(~(iec_start|iec_end|charset|import_\d+|media_\d+|rule_\d+)~)(?>[^~]*)/;

# -----------------------------------------------------------------------------

sub minify {
	my ( $scalarref, $opts ) = @_;
	
	if ( ref( $scalarref ) ne 'SCALAR' ) {
		carp( 'First argument must be a scalarref!' );
		return '';
	}
	
	return '' if ( ${$scalarref} eq '' );
	
	if ( ref( $opts ) ne 'HASH' ) {
		carp( 'Second argument must be a hashref of options! Using defaults!' ) if ( $opts );
		$opts = { 'compress' => 'pretty' };
	}
	else {
		$opts->{'compress'} = grep( $opts->{'compress'}, ( 'minify', 'pretty' ) ) ? $opts->{'compress'} : 'pretty';
	}
	
	$opts = { 'compress' => 'pretty' } if ( ref( $opts ) ne 'HASH' or $opts->{'compress'} ne 'minify' );
	
	${$scalarref} =~ s/~iec_start~/ /gsm;
	${$scalarref} =~ s/~iec_end~/ /gsm;
	
	${$scalarref} =~ s/~charset~/ /gsm;
	${$scalarref} =~ s/~import_\d+~/ /gsm;
	${$scalarref} =~ s/~media_\d+~/ /gsm;
	${$scalarref} =~ s/~rule_\d+~/ /gsm;
 	${$scalarref} =~ s/\r//gsm;
	
	my $charset	= '';
	my $import	= [];
	my $media	= [];
	my $rule	= [];
	
	my $_do_declaration = sub {
		my ( $key, $value ) = @_;
		
		$key	=~ s/^\s*|\s*$//gs;
		$value	=~ s/^\s*|\s*$//gs;
		
		if ( $key eq 'content' ) {
			my @strings;
			my $_do_content = sub {
				my $string = shift;
				
				my $ret = '~string_' . scalar( @strings ) . '~';
				
				push( @strings, $string );
				
				return $ret;
			};
			
			$value =~ s/"(\\.|[^"\\])*"/&$_do_content( $& )/egs;
			
			$value =~ s/(?>\s+)(~string_\d+~)/$1/gsm;
			$value =~ s/(~string_\d+~)(?>\s+)/$1/gsm;
			
			$value =~ s/~string_(\d+)~/$strings[$1]/egsm;
		}
		else {
			$value =~ s/\s*,\s*/,/gsm;
			$value =~ s/\s+/ /gsm;
		}
		
		return '' if ( not $key or ( not $value and $value ne '0' ) );
		
		return $key . ':' . $value . ';' . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' );
	};
	
	my $_do_rule = sub {
		my ( $selector, $declaration ) = @_;
		
		$selector =~ s/^\s*|\s*$//gs;
		$selector =~ s/\s*,\s*/,/gsm;
		$selector =~ s/\s+/ /gsm;
		
		$declaration =~ s/^\s*|\s*$//gs;
		
		$declaration =~ s/$DECLARATION/&$_do_declaration( $1, $2 )/egsm;
		
		my $ret = '~rule_' . scalar( @{$rule} ) . '~';
		
		my $store = $selector . '{' . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' ) . $declaration . '}' . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' );
		
		$store = '' unless ( $selector or $declaration );
		
		push( @{$rule}, $store );
		
		return $ret;
	};
	
	my $_do_import = sub {
		my ( $file, $mediatype ) = @_;
		
		if ( $file =~ /^("|')(?>\s*)(.*?)(?>\s*)\1$/ ) {
			$file = $1 . $2 . $1;
		}
		elsif ( $file =~ /^url\(\s*("|')(?>\s*)(.*?)(?>\s*)\1\s*\)$/ ) {
			$file = 'url(' . $1 . $2 . $1 . ')';
		}
		elsif ( $file =~ /^url\((?>\s*)(.*?)(?>\s*)\)$/ ) {
			$file = 'url(' . $1 . ')';
		}
		else {
			$file = '';
		}
		
		my $store = '@import ' . $file;
		
		if ( $mediatype ) {
			$mediatype =~ s/^\s*|\s*$//gs;
			$mediatype =~ s/\s*,\s*/,/gsm;
			
			$store .= $mediatype;
		}
		
		$store .= ';' . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' );
		
		my $ret = '~import_' . scalar( @{$import} ) . '~';
		
		push( @{$import}, $store );
		
		return $ret;
	};
	
	my $iec_isopen = 0;
	
	my $_do_comment = sub {
		my $comment = shift;
		
		if ( $comment =~ /\\\*\/$/ and not $iec_isopen ) {
			$iec_isopen = 1;
			return '~iec_start~';
		}
		elsif ( $comment !~ /\\\*\/$/ and $iec_isopen ) {
			$iec_isopen = 0;
			return '~iec_end~';
		}
		
		return ' ';
	};
	
	my $_do_charset = sub {
		my ( $selector, $declaration ) = @_;
		
		$charset = $selector . " " . $declaration . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' );
		
		return '~charset~';
	};
	
	my $_do_media = sub {
		my ( $mediatype, $mediarules ) = @_;
		
		$mediatype =~ s/^\s*|\s*$//gs;
		$mediatype =~ s/\s*,\s*/,/gsm;
		
		$mediarules =~ s/$IMPORT/&$_do_import( $1, $2 )/egsm;
		$mediarules =~ s/$RULE/&$_do_rule( $1, $2 )/egsm;
		
		$mediarules =~ s/$PLACEHOLDER/$1/gsm;
		
		my $ret = '~media_' . scalar( @{$media} ) . '~';
		
		my $store = '@media ' . $mediatype . '{' . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' ) .
			$mediarules . '}' . ( $opts->{'compress'} eq 'pretty' ? "\n" : '' );
		
		push( @{$media}, $store );
		
		return $ret;
	};
	
	${$scalarref} =~ s/$CHARSET/&$_do_charset( $1, $2 )/emos;
	
	${$scalarref} =~ s/$COMMENT/&$_do_comment( $& )/egsm;
	
	${$scalarref} =~ s/$MEDIA/&$_do_media( $1, $2 )/egsm;
	
	${$scalarref} =~ s/$IMPORT/&$_do_import( $1, $2 )/egsm;
	
	${$scalarref} =~ s/$RULE/&$_do_rule( $1, $2 )/egsm;
	
	${$scalarref} =~ s/$PLACEHOLDER/$1/gsm;
	
	${$scalarref} =~ s/~media_(\d+)~/$media->[$1]/egsm;
	${$scalarref} =~ s/~rule_(\d+)~/$rule->[$1]/egsm;
	${$scalarref} =~ s/~import_(\d+)~/$import->[$1]/egsm;
	${$scalarref} =~ s/~charset~/$charset/gsm;
	
	${$scalarref} =~ s/~iec_start~/sprintf( '\/*\\*\/%s', $opts->{'compress'} eq 'pretty' ? "\n" : '' )/egsm;
	${$scalarref} =~ s/~iec_end~/sprintf( '\/**\/%s', $opts->{'compress'} eq 'pretty' ? "\n" : '' )/egsm;
	
	${$scalarref} =~ s/\n$//s unless ( $opts->{'compress'} eq 'pretty' );
}

1;

__END__

=head1 NAME

CSS::Packer - Another CSS minifier

=head1 VERSION

Version 0.2

=head1 SYNOPSIS

    use CSS::Packer;

    CSS::Packer::minify( $scalarref, $opts );

=head1 DESCRIPTION

A fast pure Perl CSS minifier.

=head1 FUNCTIONS

=head2 CSS::Packer::minify( $scalarref, $opts );

First argument must be a scalarref of CSS-Code.
Second argument must be a hashref of options. The only option is

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

=back

=head1 AUTHOR

Merten Falk, C<< <nevesenin at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-css-packer at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CSS-Packer>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc CSS::Packer

=head1 COPYRIGHT & LICENSE

Copyright 2008 Merten Falk, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<CSS::Minifier>,
L<CSS::Minifier::XS>

=cut
