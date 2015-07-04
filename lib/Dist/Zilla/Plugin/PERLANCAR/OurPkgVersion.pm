package Dist::Zilla::Plugin::PERLANCAR::OurPkgVersion;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

use Moose;
with (
    'Dist::Zilla::Role::FileMunger',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [ ':InstallModules', ':ExecFiles' ],
    },
);

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

    my $content = $file->content;

    my $end_pos = $content =~ /^(__DATA__|__END__)$/m ? $-[0] : undef;
    $self->log_debug(["end_pos: %s", $end_pos]);

    my $munged_version = 0;
    $content =~ s/
                     ^
                     (\s*)           # capture all whitespace before comment

                     (?:our [ ] \$VERSION [ ] = [ ] 'v?[0-9_.]+'; [ ] )?  # previously produced output
                     (
                         \#\s*VERSION  # capture # VERSION
                         \b            # and ensure it ends on a word boundary
                         [             # conditionally
                             [:print:]   # all printable characters after VERSION
                             \s          # any whitespace including newlines see GH #5
                         ]*            # as many of the above as there are
                 )
                 $               # until the EOL}xm
                 /

                     !defined($end_pos) || $-[0] < $end_pos ?

                     "${1}our \$VERSION = '$version'; $2"

                     :

                     $&

                     /emx and $munged_version++;

    if ( $munged_version ) {
        $self->log_debug([ 'adding $VERSION assignment to %s', $file->name ]);
        $file->content($content);
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

=for Pod::Coverage .+

=head1 SYNOPSIS

in dist.ini

	[PERLANCAR::OurPkgVersion]

in your modules

	# VERSION

or

	our $VERSION = '0.123'; # VERSION


=head1 DESCRIPTION

This module is like L<Dist::Zilla::Plugin::OurPkgVersion> but can replace the
previously generated C<our $VERSION = '0.123'; > bit. If the author of
OurPkgVersion thinks this is a good idea, then perhaps this module will be
merged with OurPkgVersion.

Comment/directive below C<__DATA__> or C<__END__> will not be replaced.


=head1 SEE ALSO

L<Dist::Zill::Plugin::OurPkgVersion>

Another approach: L<Dist::Zill::Plugin::RewriteVersion> and L<Dist::Zill::Plugin:::BumpVersionAfterRelease>
