### //////////////////////////////////////////////////////////////////////////
#
#	TOP
#

=head1 NAME

SML::Parser - SIMPLIFIED MARKUP LANGUAGE

=cut

#------------------------------------------------------
# 2004/03/28 0:51 - $Date: 2004/05/19 14:46:10 $
# (C) Daniel Peder & Infoset s.r.o., all rights reserved
# http://www.infoset.com, Daniel.Peder@infoset.com
#------------------------------------------------------

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: package
#

	package SML::Parser;


### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: version
#

	use vars qw( $VERSION $VERSION_LABEL $REVISION $REVISION_DATETIME $REVISION_LABEL $PROG_LABEL );

	$VERSION           = '0.11';
	
	$REVISION          = (qw$Revision: 1.7 $)[1];
	$REVISION_DATETIME = join(' ',(qw$Date: 2004/05/19 14:46:10 $)[1,2]);
	$REVISION_LABEL    = '$Id: Parser.pm_rev 1.7 2004/05/19 14:46:10 root Exp root $';
	$VERSION_LABEL     = "$VERSION (rev. $REVISION $REVISION_DATETIME)";
	$PROG_LABEL        = __PACKAGE__." - ver. $VERSION_LABEL";

=pod

 $Revision: 1.7 $
 $Date: 2004/05/19 14:46:10 $

=cut


#### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: debug
#

	use vars qw( $DEBUG ); $DEBUG=0;
	

## //////////////////////////////////////////////////////////////////////////
#
#	SECTION: constants
#

	# use constant	name		=> 'value';
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: modules use
#

	require 5.005_62;

	use strict                  ;
	use warnings                ;
	

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: methods
#

=head1 METHODS

=over 4

=cut



=item	new

 $sml = SML::Parser->new();
 
=cut

### --------------------------------------------------------------------------
sub		new
### --------------------------------------------------------------------------
{
	my( $proto ) = @_;
	bless {}, ref( $proto ) || $proto;
}

### ##########################################################################

=item	parse ( $str )

Parse HTML|XML like string source. No other rules, no checks.

Creates simple stream of 3 types of parsed items:

 - comment data:
 [ 'C', $comment_body ]
 
 - text data
 [ 'T', $text_body ]
 
 - element tag data
 [ 'E', $pi, $tag_name, $tag_body ]
 
Data are returned as ref to ARRAY of items described above.

=cut

### --------------------------------------------------------------------------
sub		parse
### --------------------------------------------------------------------------
{
	my( $self, $text_source )=@_;

	my	$re_TagMark	= 		# matches the begin/opening of tag or comment
	qr{
		(?:
			<				#    - open bracket
			(!--)			# $1 - comment
		)
		|					# or
		(?:
			<				#    - open bracket
			([/!\?]*)		# $2 - processing instruction: '/', '!', '?', [ closing tag | special tags ]; note that special tags can't be paired with closing tag
			([\w\-\.\:]+)	# $3 - tagname, much more tolerant that the HTML/XML, for example, ':::' is valid tag name here
		)
	}xs;

	my	$re_TagBody	=		# matches the rest of tag body as continuation of previous $re_TagMark match
	qr{
		(.*?)>				# simply get end of tag
	}xs;

	my	$re_CommentBody	=	# matches the rest of comment body as continuation of previous $re_TagMark match
	qr{
		(.*?)-->			# simply get end of comment
	}xs;
	
	my	@data;
	my	$prev_pos	= 0;
	my	$curr_pos	= 0;

	while( $text_source =~ /$re_TagMark/csgo )
	{
			$curr_pos	= pos( $text_source );
		my	$text	= substr( $text_source, $prev_pos, $curr_pos - length( $& ) - $prev_pos );
			$prev_pos	= $curr_pos;
		my	$cmnt	= $1;
		my	$pi		= $2; #$pi	= '' unless defined $pi;
		my	$tag	= $3; #$tag	= '' unless defined $tag;
		my	$body	= '';
		
		if( $DEBUG ){ ( my	$tmp_val	= $& ) =~ s{\s+}{ }gos; print "match: $tmp_val\n"; }
		
		if( $cmnt && scalar($text_source =~ /$re_CommentBody/csgo) ) # BUG:TODO:unclosed comments are treated as tags with pi & tagname undef!
		{
			# special 'comment' case
			$body = $1;
			push @data, [ 'T', $text ] if length( $text );
			push @data, [ 'C', $body ]; # [C]omment
			$DEBUG && print " = comment ($text) '$body' \n\n";
		}
		elsif( $text_source =~ /$re_TagBody/cgo )
		{
			$body = $1;
			push @data, [ 'T', $text ] if length( $text );
			push @data, [ 'E', $pi, $tag, $body ]; # [E]lement tag; note that body is the unparsed attributes part
			$DEBUG && print " = element ($text) '$pi' '$tag' '$body' \n\n";
		}
		else
		{
			push @data, [ 'T', $text . $& ];
			$DEBUG && print " = text\n\n";
		}
		$prev_pos		= pos( $text_source );
	}
	my	$text = substr( $text_source, $prev_pos );
		push @data, [ 'T', $text ] if length( $text );

	\@data
}


### ##########################################################################

=item	parse_attributes ( $attr_string )

Parse body of the element same way as the HTML attributes.

=cut

### --------------------------------------------------------------------------
sub		parse_attributes
### --------------------------------------------------------------------------
{
	my( $self, $attr_string )=@_;
	
	my	%attrs;
	
	# 1. extract quoted areas
	while( 1 )
	{
		my( $mixed, $quoted, $last );
		if( $attr_string =~ m{(.*?)(['"])(.*?)\2}cgos )
		{
			# $mixed =
			#	(1) single tokens 'some_attr, 
			#	(2) assigned tokens 'SomeAttr=notQuotedValue', 
			#	(3) any other garbage ' abc ===', ...
			#
			# $quoted = the value withing single or double quotes, eg: 
			#	" value within 'double quotes' " or 
			#	' double quote " within single quotes '
			#
			
			( $mixed, $quoted )	= ($1,$3);
		}
		else
		{
			
			if( my $pos = pos( $attr_string ))
			{
				$mixed	= substr( $attr_string, $pos );
			}
			else
			{
				$mixed = $attr_string;
			}
			$last = 1;
		}
		
		my(	$key, $val );
		foreach ( split '\s+', $mixed )
		{
			( $key, $val ) = ('*','');
			#debug# print "data: '$_'\n";
			
			next unless /\S/;
			if( /^([\w\.\-]+)(=(\S*))?$/ )
			{
				if( $2 )
				{
					( $key, $val ) = ($1,$3);
				}
				else
				{
					$key	= $_;
					$val	= "\x00";
				}
				
			}
			else
			{
				$key	= '*';
				$val	= $_;
			}
			#debug# print "values: ( $key, $val )\n";
			push @{$attrs{$key}}, $val;
			push @{$attrs{'='}}, [$key, $#{$attrs{$key}}];
		}
		if( $quoted )
		{
			if( !$val )
			{
				if( @{$attrs{$key}} )
				{
					pop @{$attrs{$key}} ;
					pop @{$attrs{'='}}	;
				}
				push @{$attrs{$key}}, $quoted;
				push @{$attrs{'='}}, [$key, $#{$attrs{$key}}];
			}
			else
			{
				push @{$attrs{'*'}}, $quoted;
				push @{$attrs{'='}}, ['*', $#{$attrs{'*'}}];
			}
			#debug# print "( $key, $quoted )\n";
		}
		
		last if $last;
	}
	return \%attrs
}






=back

=cut


1;

__DATA__

__END__

### //////////////////////////////////////////////////////////////////////////
#
#	SECTION: TODO
#

=head1 TODO	

- rewrite some parts of code into methods and subclasses

=cut
