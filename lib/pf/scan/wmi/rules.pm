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
use Config::IniFiles;
use pf::api::jsonrpcclient;

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
    my ($self, $rules) = @_;
    my $logger = $self->logger;

    my @rules = split("\n",$rules->{'_wmi_rules'});
    my $success = 0;
    foreach my $rule  ( @rules ) {
        my $rule_config = $pf::config::ConfigWmi{$rule};
        my ($rc, $result) = $self->runWmi($rules,$rule_config);
        if(!$rc) {
            $logger->error("Error rule wmi rule '$rule': $result");
            return $rc;
        }
        $success = $rc;
        my $action = $rule_config->{'action'};
        my %cfg;
        tie %cfg, 'Config::IniFiles', ( -file => \$action );
        foreach my $test  ( sort keys %cfg ) {
            if ($test =~ /^\w+:(.*)$/) {
                my $condition = $1;
                $condition =~ s/(\w+)/$self->parse($cfg{$1},$result)/gee;
                $condition =~ s/\|/ \|\| /g;
                $condition =~ s/\&/ \&\& /g;
                if (eval $condition) {
                    $logger->info("Match WMI ".$rule." rule: ".$test." for ". $rules->{'_scanMac'});
                    if ( defined($cfg{$test}->{'action'}) && $cfg{$test}->{'action'} ne '' ) {
                        last if ($cfg{$test}->{'action'} =~ /allow/i);
                        $self->dispatchAction($cfg{$test},$rules,shift @$result);
                    }
                }
            }
        }
    }
    return $success;
}

=item runWMI

execute WMI command on the remote device

=cut

sub runWmi {
    my ($self, $rules, $rule) = @_;
    my $ret_string = wmitest($rules->{'_domain'}, $rules->{'_username'},$rules->{'_password'}, $rules->{'_scanIp'}, $rule->{'namespace'}, $rule->{'request'});
    return ($TRUE, $self->parseResult($ret_string));
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

    my $header = shift(@{$string});
    if (!defined ($header)) {
        $logger->error("No WMI header given in string '$string'");
        return [];
    }
    my @result;
    foreach my $answer (@{$string}) {
        my %response;
        @response{@{$header}} = @{$answer};
        push @result, \%response;
    }
    return \@result;
}

=item parse

Parse all result and try to match

=cut

sub parse {
    my ($self, $cfg, $result) = @_;
    foreach my $value (@{$result}) {
        return $TRUE if ($self->_match_rule_against_value($cfg,$value->{$cfg->{'attribute'}}));
    }
    return $FALSE;
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
    return $FALSE;
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

use Inline (Python => Config => directory => '/usr/local/pf/var',
                                untaint => 1,
                                no_untaint_warn => 1,
           );

use Inline Python  => <<'END_OF_PYTHON_CODE';

from impacket import version, ntlm
from impacket.dcerpc.v5 import transport, dcomrt
from impacket.dcerpc.v5.dtypes import NULL
from impacket.dcerpc.v5.dcom import wmi
from impacket.dcerpc.v5.dcomrt import DCOMConnection
import sys
import os

s = []

def wmitest(domain, username, password, address, namespace, sql):
    import cmd

    class WMIQUERY(cmd.Cmd):
        def __init__(self, iWbemServices):
            cmd.Cmd.__init__(self)
            self.iWbemServices = iWbemServices

        def do_shell(self, s):
            os.system(s)

        def printReply(self, iEnum):
            global s
            printHeader = True
            while True:
                try:
                    pEnum = iEnum.Next(0xffffffff,1)[0]
                    record = pEnum.getProperties()
                    if printHeader is True:
                        element = []
                        for col in record:
                            element.append(col)
                        s.append(element)
                    printHeader = False
                    elem = [] 
                    for key in record:
                        elem.append(record[key]['value'])
                    s.append(elem)
                except Exception, e:
                    #import traceback
                    #print traceback.print_exc()
                    if str(e).find('S_FALSE') < 0:
                        raise
                    else:
                        break
            iEnum.RemRelease()

        def default(self, line):
            line = line.strip('\n')
            if line[-1:] == ';':
                line = line[:-1]
            try:
                iEnumWbemClassObject = self.iWbemServices.ExecQuery(line.strip('\n'))
                self.printReply(iEnumWbemClassObject)
                iEnumWbemClassObject.RemRelease()
            except Exception, e:
                print str(e)
         
        def emptyline(self):
            pass

        def do_exit(self, line):
            return True


    lmhash = ''
    nthash = ''
    if namespace == '':
        namespace = '//>/root/cimv2'

    dcom = DCOMConnection(address, username, password, domain, lmhash, nthash, oxidResolver = True)

    iInterface = dcom.CoCreateInstanceEx(wmi.CLSID_WbemLevel1Login,wmi.IID_IWbemLevel1Login)
    iWbemLevel1Login = wmi.IWbemLevel1Login(iInterface)
    iWbemServices= iWbemLevel1Login.NTLMLogin(namespace, NULL, NULL)
    iWbemLevel1Login.RemRelease()

    shell = WMIQUERY(iWbemServices)
    shell.onecmd(sql)

    iWbemServices.RemRelease()
    dcom.disconnect()
    return s


END_OF_PYTHON_CODE

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
