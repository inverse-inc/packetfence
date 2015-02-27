package pf::scan::wmi::rules;

=head1 NAME

pf::scan::wmi::rules - Test wmi rules

=cut

=head1 DESCRIPTION

pf::scan::wmi::rules deny or allow based on rules. 

=cut

use strict;
use warnings;

use Log::Log4perl;
use Net::WMIClient qw(wmiclient);
use Config::IniFiles;
use pf::api::jsonrpcclient;
use pf::ConfigStore::WMI();

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
   my $logger = Log::Log4perl::get_logger("pf::scan::wmi::rules");
   $logger->debug("instantiating new pf::scan::wmi::rules");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}

=item test

Test all the rules

=cut

sub test {
    my ($self, $rules) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    my $wmics = pf::ConfigStore::WMI->new();

    foreach my $rule  ( @{$rules->{'_rules'}} ) {
        $logger->warn($rule);
        my $rule_config = $wmics->read($rule);
        my ($rc, $result) = $self->runWmi($rules,$rule_config);
        return $rc if (!$rc);
        my $action = join("\n", @{$rule_config->{'action'}});
        my %cfg;
        tie %cfg, 'Config::IniFiles', ( -file => \$action );
        foreach my $test  ( sort keys %cfg ) {
            if ($test =~ /^\w+:(.*)$/) {
                my $condition = $1;
                $condition =~ s/(\w+)/$self->parse($cfg{$1},$result)/gee;
                $condition =~ s/\|/ \|\| /g;
                $condition =~ s/\&/ \&\& /g;
                $logger->warn($condition);
                if (eval $condition) {
                    $logger->info("Match WMI ".$rule." rule: ".$test." for ". $rules->{'_scanMac'});
                    if ( defined($cfg{$test}->{'action'}) && $cfg{$test}->{'action'} ne '' ) {
                        last if ($cfg{$test}->{'action'} =~ /allow/i);
                        $self->dispatchAction($cfg{$test},$rules,shift $result);
                    }
                }
            }
        }
    }
    return 0;
}

=item runWMI

execute WMI command on the remote device

=cut

sub runWmi {
    my ($self, $rules, $rule) = @_;

    my $request = {};
    $request->{'Username'} = $rules->{'_domain'} .'/'. $rules->{'_username'} .'%'. $rules->{'_password'};
    $request->{'Host'} = $rules->{'_scanIp'};
    $request->{'Query'} = $rule->{'request'};
    my ($rc, $ret_string) = wmiclient($request);
    return ($rc,$self->parseResult($ret_string));

}

=item parseResult

Parse the result of the wmicli

=cut

sub parseResult {
    my ($self, $string) = @_;
    $string =~ s/\r\n/\n/g;

    my @ans = split('\n', $string);
    my $i = 0;
    my $line;
    my @result;

    my $resultat = {};

    shift @ans;
    my @entries = split(/\|/,shift @ans);


    foreach $line (@ans) {
        my @values = split(/\|/,$line);
        my $j = 0;
        foreach my $elements (@entries) {
            $resultat->{"$elements"} = $values[$j];
            $j++;
        }
        $result[$i] = $resultat;
        undef $resultat;
        $i++;
    }
return \@result;
}

=item parse

Parse all result and try to match

=cut

sub parse {
    my ($self, $cfg, $result) = @_;
    foreach my $value (@{$result}) {
        return 1 if ($self->_match_rule_against_value($cfg,$value->{$cfg->{'attribute'}}));
    }
    return 0;
}

=item _match_rule_against_value

Matches the rule against a value

=cut

sub _match_rule_against_value {
    my ($self, $rule, $value) = @_;

    if (defined($value)) {
        my $op = $rule->{'operator'};
        if ($op && exists $RULE_OPS{$op}) {
            return $RULE_OPS{$op}->($value, $rule->{'value'});
        }
    }
    return 0;
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

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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
