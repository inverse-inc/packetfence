package pf::vlan::filter;

=head1 NAME

pf::vlan::filter - handle the authorization rules on the vlan attribution

=cut

=head1 DESCRIPTION

pf::vlan::filter deny, rewrite role based on rules. 

=cut

use strict;
use warnings;

use Log::Log4perl;
use Time::Period;
use pf::config qw(%connection_type_to_str %ConfigVlanFilters);

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = Log::Log4perl::get_logger("pf::vlan::filter");
   $logger->debug("instantiating new pf::vlan::filter");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $scope, $switch,$ifIndex,$mac,$node_info,$connection_type,$user_name,$ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    foreach my $rule  ( sort keys %ConfigVlanFilters ) {
        if ( defined($ConfigVlanFilters{$rule}->{'scope'}) && $ConfigVlanFilters{$rule}->{'scope'} eq $scope) {
            if ($rule =~ /^\d+:(.*)$/) {
                my $test = $1;
                $test =~ s/([0-9]+)/$self->dispatch_rule($ConfigVlanFilters{$1},$switch,$ifIndex,$mac,$node_info,$connection_type,$user_name,$ssid)/gee;
                $test =~ s/\|/ \|\| /g;
                $test =~ s/\&/ \&\& /g;
                if (eval $test) {
                    $logger->info("Match Vlan rule: ".$rule);
                    my $role = $ConfigVlanFilters{$rule}->{'action'};
                    my $vlan = $switch->getVlanByName($role);
                    return ($vlan, $role);
                }
            }
        }
    }
}

=item dispatch_rules

Return the reference to the function that parse the rule.

=cut

sub dispatch_rule {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    my $key = {
        node_info => \&node_info_parser,
        switch  => \&switch_parser,
        ifIndex  => \&ifindex_parser,
        mac  => \&mac_parser,
        connection_type  => \&connection_type_parser,
        username  => \&username_parser,
        ssid  => \&ssid_parser,
        time => \&time_parser,
    };
    return $key->{$rule->{'filter'}}->($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid);
}

=item dispatch_action

Return the reference to the function that do the action.

=cut

sub action {
    my ($self, $rule) = @_;

    if ($rule->{'action'}) {
        return $rule->{'action'};
    } else {
        return 1;
    }
}

=item node_info_parser

Parse the node_info attribute and compare to the rule. If it match then take the action

=cut

sub node_info_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if ($rule->{'operator'} eq 'is') {
        if ($node_info->{$rule->{'attribute'}} =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($node_info->{$rule->{'attribute'}} !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item switch_parser

Parse the switch attribute and compare to the rule. If it match then take the action

=cut

sub switch_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if ($rule->{'operator'} eq 'is') {
        if ($switch->{$rule->{'attribute'}} =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($switch->{$rule->{'attribute'}} !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item ifindex_parser

Parse the ifindex value and compare to the rule. If it match then take the action

=cut

sub ifindex_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if ($rule->{'operator'} eq 'is') {
        if ($ifIndex =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($ifIndex !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item mac_parser

Parse the mac value and compare to the rule. If it match then take the action

=cut

sub mac_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if ($rule->{'operator'} eq 'is') {
        if ($mac =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($mac !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item connection_type_parser

Parse the connection_type value and compare to the rule. If it match then take the action

=cut

sub connection_type_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;
 
    if ($rule->{'operator'} eq 'is') {
        if ($connection_type_to_str{$connection_type} =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($connection_type_to_str{$connection_type} !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item username_parser

Parse the ursername value and compare to the rule. If it match then take the action

=cut

sub username_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if ($rule->{'operator'} eq 'is') {
        if ($user_name =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($user_name !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item ssid_parser

Parse the ssid valus and compare to the rule. If it match then take the action

=cut

sub ssid_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    if ($rule->{'operator'} eq 'is') {
        if ($ssid =~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if ($ssid !~ /$rule->{'regexp'}/) {
            return 1;
        } else {
            return 0;
        }
    }
}

=item time_parser

Check the current time and compare to the period

=cut

sub time_parser {
    my ($self, $rule, $switch, $ifIndex, $mac, $node_info, $connection_type, $user_name, $ssid) = @_;

    my $time = time();
    if ($rule->{'operator'} eq 'is') {
        if (inPeriod($time,$rule->{'regexp'})) {
            return 1;
        } else {
            return 0;
        }
    } else {
        if (!inPeriod($time,$rule->{'regexp'})) {
            return 1;
        } else {
            return 0;
        }
    }
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

