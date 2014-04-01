package Dist::Zilla::Plugin::SHARYANTO::OurPkgVersion;

use 5.008;
use strict;
use warnings;

# VERSION

use Moose;
with (
	'Dist::Zilla::Role::FileMunger',
	'Dist::Zilla::Role::FileFinderUser' => {
		default_finders => [ ':InstallModules', ':ExecFiles' ],
	},
);

use PPI;
use MooseX::Types::Perl qw( LaxVersionStr );
use namespace::autoclean;

sub munge_files {
	my $self = shift;

	$self->munge_file($_) for @{ $self->found_files };
	return;
}

sub munge_file {
	my ( $self, $file ) = @_;

	if ( $file->name =~ m/\.pod$/ixms ) {
		$self->log_debug( 'Skipping: "' . $file->name . '" is pod only');
		return;
	}

	my $version = $self->zilla->version;

	confess 'invalid characters in version'
		unless LaxVersionStr->check( $version );

	my $content = $file->content;

	my $doc = PPI::Document->new(\$content)
		or $self->log( 'Skipping: "'
			. $file->name
			.  '" error with PPI: '
			. PPI::Document->errstr
			)
			;

	return unless defined $doc;

	my $comments = $doc->find('PPI::Token::Comment');

	my $version_regex
		= q{
                  ^
                  (\s*)           # capture all whitespace before comment

                  (
                    (?:our \s \$VERSION \s = \s 'v?[0-9_.]+'; )?  # previously produced output
                    \#\s*VERSION  # capture # VERSION
                    \b            # and ensure it ends on a word boundary
                    [             # conditionally
                      [:print:]   # all printable characters after VERSION
                      \s          # any whitespace including newlines see GH #5
                    ]*            # as many of the above as there are
                  )
                  $               # until the EOL}
		;

	my $munged_version = 0;
	if ( ref($comments) eq 'ARRAY' ) {
		foreach ( @{ $comments } ) {
			if ( /$version_regex/xms ) {
				my ( $ws, $comment ) =  ( $1, $2 );
				$comment =~ s/(?=\bVERSION\b)/TRIAL /x if $self->zilla->is_trial;
				my $code
						= "$ws"
						. q{our $VERSION = '}
						. $version
						. qq{'; $comment}
						;
				$_->set_content("$code");
				$file->content( $doc->serialize );
				$munged_version++;
			}
		}
	}

	if ( $munged_version ) {
		$self->log_debug([ 'adding $VERSION assignment to %s', $file->name ]);
	}
	else {
		$self->log( 'Skipping: "'
			. $file->name
			. '" has no "# VERSION" comment'
			);
	}
	return;
}
__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: no line insertion and does Package version with our

=head1 SYNOPSIS

in dist.ini

	[SHARYANTO::OurPkgVersion]

in your modules

	# VERSION

or

	our $VERSION = '0.123'; # VERSION


=head1 DESCRIPTION

This module is like L<Dist::Zilla::Plugin::OurPkgVersion> but can replace the
previously generated C<our $VERSION = '0.123'; > bit. If the author of
OurPkgVersion thinks this is a good idea, then perhaps this module will be
merged with OurPkgVersion.
