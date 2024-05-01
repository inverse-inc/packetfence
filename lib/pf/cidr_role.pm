package pf::cidr_role;

=head1 NAME

pf::cidr_role - Calculate the network CIDR associated to a role in a switch

=cut

=head1 DESCRIPTION

pf::cidr_role allow to calculate the cidr network of a role associated to a switch. 

=cut

use strict;
use warnings;

use pf::log;
use pf::config;
use pf::util();
use pf::locationlog();
use pf::SwitchFactory();
use NetAddr::IP;
use Digest::MD5 qw(md5_base64);
use pf::ConfigStore::Switch();

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::cidr_role");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}


sub update {
    my ($self, %postdata) = @_;
    my @require = qw(mac ip mask lease_length);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);
    if (defined $postdata{'mask'}) {
        $self->update_switch_role_with_mask(%postdata);
    } else {
        $self->update_switch_role_with_ip(%postdata);
    }
}


sub update_switch_role_with_mask {
    my ($self, %postdata) = @_;
    my @require = qw(mac ip mask lease_length);

    my $locationlog = pf::locationlog::locationlog_view_open_mac($postdata{'mac'});
    if ( !defined($locationlog) || $locationlog eq "0" ) {
        return undef;
    }

    my $current_network = NetAddr::IP->new( $postdata{'ip'}, $postdata{'mask'} );

    my $switch = pf::SwitchFactory->instantiate({ switch_mac => $locationlog->{'switch_mac'}, switch_ip => $locationlog->{'switch_ip'}, switch_id => $locationlog->{'switch'}});

    return undef unless (pf::util::isenabled($switch->{'_NetworkMap'}));

    my $networks = $switch->cache_distributed->get($locationlog->{'switch'}.".".$locationlog->{'role'});

    my $processed_mac = $switch->cache_distributed->get($locationlog->{'switch'}.".".$locationlog->{'role'}.".". md5_base64($postdata{'mac'}.".".$current_network->network()));

    $switch->cache_distributed->set($locationlog->{'switch'}.".".$locationlog->{'role'}.".". md5_base64($postdata{'mac'}.".".$current_network->network()),1,{ expires_in => $postdata{'lease_length'} } );

    if (defined $processed_mac) {
        # If the mac has already been processed in the same network then do nothing
        return undef;
    }

    # Do we already got some requests for this network ?
    if (exists $networks->{$current_network->network()}) {
        $networks->{$current_network->network()} = $networks->{$current_network->network()} + 1;
        # Try to see if other networks exist for this role in this switch
        my $max = 0;
        foreach my $network (keys %{$networks}) {
            next if ($network eq $current_network->network());
            if ($networks->{$network} >= $max) {
                $max = $networks->{$network};
            }
        }
        # If the current network count is greater than another one and if the number of devices in this network is greater than 10 (TODO Config variable)
        if ( ( $networks->{$current_network->network()} >= $max ) && ( $networks->{$current_network->network()} >= "10" ) ) {
            # If the current network doesn't match with the current one we update the configuration
            if ($switch->{"_".$locationlog->{'role'}."Network"} ne $current_network->network()) {
                my $cs = pf::ConfigStore::Switch->new;
                $cs->update($locationlog->{'switch'}, { $locationlog->{'role'}."Network" => $current_network->network()});
                $cs->commit();
            }
        }
    } else {
        # First time we see a device in this network
        $networks->{$current_network->network()} = 1;
    }
    # Cleanup loop (we can't increment the counter forever)
    if (exists $networks->{$switch->{"_".$locationlog->{'role'}."Network"}} && $networks->{$switch->{"_".$locationlog->{'role'}."Network"}} >= 200) {
        foreach my $network (keys %{$networks}) {
            if ($network eq $switch->{"_".$locationlog->{'role'}."Network"} ) {
                # Default
                $networks->{$network} = 10;
            }
            $networks->{$network} = 0;
        }
    }
    $switch->cache_distributed->set($locationlog->{'switch'}.".".$locationlog->{'role'},$networks, {expires_in => '24h'} );
}

sub update_switch_role_with_ip {
    my ($self, %postdata) = @_;
    my @require = qw(mac ip mask lease_length);
    my @found = grep {exists $postdata{$_}} @require;
    return unless pf::util::validate_argv(\@require,  \@found);

    my $locationlog = pf::locationlog::locationlog_view_open_mac($postdata{'mac'});
    if ( !defined($locationlog) || $locationlog eq "0" ) {
        return undef;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
