package fingerbank::IniFiles;

=head1 NAME

fingerbank::IniFiles add documentation

=cut

=head1 DESCRIPTION

fingerbank::IniFiles

Additional functionality for Config::IniFiles

=cut

use strict;
use warnings;

use Config::IniFiles;
use base qw(Config::IniFiles);
use Template;
*errors = \@Config::IniFiles::errors;

our $PrettyName;
our $tt = Template->new({ABSOLUTE => 1, CACHE_SIZE => 0});
$tt->context->define_vmethod('hash', 'env_or_default', sub {
    # Apache variables that aren't undefined will appear as ${NAME_OF_VARIABLE} so we check that the key exists and doesn't equal to that value
    exists($_[0]{$_[1]}) && $_[0]{$_[1]} ne '${'.$_[1].'}' && $_[0]{$_[1]} ne '' ? $_[0]{$_[1]} : $_[2]; 
});


=head2 new

=cut

sub new {
    my ($proto, %args) = @_;
    my $class = ref($proto) || $proto;
    if(exists($args{-envsubst}) && $args{-envsubst}) {
        my $processed_file;
        $ENV{BRL} = "[%";
        $ENV{BRR} = "%]";
        $tt->process($args{-file}, {ENV => \%ENV}, \$processed_file) || die "Can't process TT for $args{-file}: ".$tt->error;
        $args{-file} = \$processed_file;
    }
    delete($args{-envsubst});

    return $class->SUPER::new(%args);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;
