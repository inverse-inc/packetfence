package pfconfig::namespaces::resource::Profile_Filters;

=head1 NAME

pfconfig::namespaces::resource::Profile_Filters

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::Profile_Filters

=cut

use strict;
use warnings;

use pf::profile::filter;
use pf::factory::profile::filter;
use pf::constants::Portal::Profile;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self) = @_;
    $self->{profiles_config} = $self->{cache}->get_cache('config::Profiles');
}

sub build {
    my ($self) = @_;

    # CHANGE ME !!!! THIS IS FOR normalize_time
    # Waiting for pf::util / pf::config circular dependency remediation
    my $config_module = pfconfig::namespaces::config->new;

    my %Profiles_Config = %{$self->{profiles_config}};

    #Clearing the Profile filters
    my @Profile_Filters = ();
    my $default_description = $Profiles_Config{'default'}{'description'};
    foreach my $profile_id (keys %Profiles_Config) {
        my $profile = $Profiles_Config{$profile_id};
        $profile->{'description'} = '' if $profile_id ne 'default' && $profile->{'description'} eq $default_description;
        foreach my $field (qw(locale mandatory_fields sources filter provisioners) ) {
            $profile->{$field} = [split(/\s*,\s*/, $profile->{$field} || '')];
        }
        $profile->{block_interval} = $config_module->normalize_time($profile->{block_interval}
              || $pf::constants::Portal::Profile::BLOCK_INTERVAL_DEFAULT_VALUE);
        my $filters = $profile->{'filter'};
        if($profile_id ne 'default' && @$filters) {
            my @filterObjects;
            foreach my $filter (@{$profile->{'filter'}}) {
                push @filterObjects, pf::factory::profile::filter->instantiate($profile_id,$filter);
            }
            if(defined ($profile->{filter_match_style}) && $profile->{filter_match_style} eq 'all') {
                push @Profile_Filters, pf::profile::filter::all->new(profile => $profile_id, value => \@filterObjects);
            } else {
                push @Profile_Filters,@filterObjects;
            }
        }
    }
    #Add the default filter so it always matches if no other filter matches
    push @Profile_Filters, pf::profile::filter->new( { profile => 'default', value => 1 } );

    return \@Profile_Filters;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

