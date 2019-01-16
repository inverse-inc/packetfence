package pf::scan::wmi::rules;

=head1 NAME

pf::scan::wmi::rules - Test wmi rules

=cut

=head1 DESCRIPTION

pf::scan::wmi::rules deny or allow based on rules.

=cut

use strict;
use warnings;

use pf::constants;
use pf::log;
use Net::WMIClient qw(wmiclient);
use Config::IniFiles;
use pf::api::jsonrpcclient;
use List::Util qw(first);

our %RULE_OPS = (
    is => sub { $_[0] eq $_[1] ? 1 : 0  },
    is_not => sub { $_[0] ne $_[1] ? 1 : 0  },
    match => sub { $_[0] =~ $_[1] ? 1 : 0  },
    match_not => sub { $_[0] !~ $_[1] ? 1 : 0  },
);

=head1 SUBROUTINES

=over

=item new

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::scan::wmi::rules");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $scan) = @_;
    my $logger = $self->logger;

    my @rules = split("\n", $scan->{'_wmi_rules'});
    my $success = 0;
    foreach my $rule (@rules) {
        my $rule_config = $pf::config::ConfigWmi{$rule};
        if (!defined $rule_config) {
            $logger->warn("Invalid rule '$rule' given");
            next;
        }

        my ($rc, $result) = $self->runWmi($scan, $rule_config);
        if(!$rc) {
            $logger->error("Error rule wmi rule '$rule': $result");
            return $rc;
        }

        $success = $rc;
        $self->filterResponse($scan, $rule_config, $result);
    }

    return $success;
}

=item filterResponse

filterResponse

=cut

sub filterResponse {
    my ($self, $scan, $rule_config, $result) = @_;
    foreach my $filter (@{$rule_config->{filters} // []}) {
        my $r = first { $filter->match($_) } @$result;
        if ($r) {
            my $answer = $filter->answer;
            if ( defined($answer->{'action'}) && $answer->{'action'} ne '' ) {
                last if ($answer->{'action'} =~ /allow/i);
                $self->dispatchAction($answer, $scan, $r);
            }
        }
    }
    return ;
}

=item runWMI

execute WMI command on the remote device

=cut

sub runWmi {
    my ($self, $scan, $rule) = @_;

    my $request = {};
    $request->{'Username'} = $scan->{'_domain'} .'/'. $scan->{'_username'} .'%'. $scan->{'_password'};
    $request->{'Host'} = $scan->{'_scanIp'};
    $request->{'Query'} = $rule->{'request'};
    $request->{'Namespace'} = $rule->{'namespace'};
    $request->{'NameSpace'} = $rule->{'namespace'}; #this is to fix an issue in the lib WMIClient
    my ($rc, $ret_string) = wmiclient($request);
    if ($rc) {
        return ($rc, $self->parseResult($ret_string));
    }
    return ($rc, $ret_string);
}

=item parseResult

Parse the result of the wmicli

=cut

sub parseResult {
    my ($self, $string) = @_;
    my $logger = $self->logger;
    if (!defined ($string)) {
        $logger->warn("uninitialized response given");
        return [];
    }
    $logger->trace( sub { "The WMI string to parse '$string' " });
    $string =~ s/\r\n/\n/g;

    my ($class, $header, @answers) = split('\n', $string);
    if (!defined ($header)) {
        $logger->error("No WMI header given in string '$string'");
        return [];
    }
    my @entries = split(/\|/, $header);
    my @result;
    foreach my $answer (@answers) {
        my %response;
        @response{@entries} = map { s/^"//;s/"$//;$_ } split(/\|/,$answer);
        push @result, \%response;
    }
    return \@result;
}

=item dispatchAction

Return the reference to the function that call the api.

=cut

sub dispatchAction {
    my ($self, $rule, $attributes, $result) = @_;
    my $param = $self->evalParam($rule->{'action_param'}, $attributes->{_scanMac}, $result, $attributes->{'_domain'});
    my $apiclient = pf::api::jsonrpcclient->new;
    $apiclient->notify($rule->{'action'},%{$$param});
}

=item evalParam

evaluate action parameters

=cut

sub evalParam {
    my ($self, $action_param, $mac, $result, $realm) = @_;
    $action_param =~ s/\s//g;
    my @params = split(',', $action_param);
    my $return = {};

    foreach my $param (@params) {
        $param =~ s/(\$.*)/$1/gee;
        #We remove the realm from the return value
        $param =~ s/$realm\\//g;
        my @param_unit = split('=',$param);
        $return = { %$return, @param_unit };
    }
    return \$return;
}

=item logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
