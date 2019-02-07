
=head1 NAME

ldap-auth

=cut

=head1 DESCRIPTION

ldap-auth

=cut

#!/usr/bin/perl
package SHM;
use IPC::SysV qw(IPC_PRIVATE S_IRUSR S_IWUSR);
use IPC::SharedMem;

our $SHM = IPC::SharedMem->new(IPC_PRIVATE, 8, S_IRWXU);

$SHM->write(pack("S", 0), 0, 2);

sub getCount {
    my $count_packed = $SHM->read(0, 2);
    return unpack("S",$count_packed);
}

sub incCount {
    my $count = getCount();
    $count++;
    $SHM->write(pack("S", $count),0, 2);
}


package TestLdapServer;

use strict;
use warnings;
use Net::LDAP::Constant qw(LDAP_SUCCESS);
use Net::LDAP::Server;
use base 'Net::LDAP::Server';
use fields qw();

use constant RESULT_OK => {
    'matchedDN'    => '',
    'errorMessage' => '',
    'resultCode'   => LDAP_SUCCESS
};

# constructor
sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    return $self;
}

# the bind operation
sub bind {
    my $self    = shift;
    my $reqData = shift;
    return RESULT_OK;
}

# the search operation
sub search {
    my $self    = shift;
    my $reqData = shift;
    my $base = $reqData->{'baseObject'};
    my @entries;
    if ($reqData->{'scope'}) {
        SHM::incCount();

        my $entry1 = Net::LDAP::Entry->new;
        $entry1->dn("cn=bob,$base");
        $entry1->add(
            cn          => 'bob',
            memberOf => ['CN=IS_Assurance,DC=ldap,DC=inverse,DC=ca'],
        );
        push @entries, $entry1;
    }
    else {
        # base
        my $entry = Net::LDAP::Entry->new;
        $entry->dn($base);
        $entry->add(
            dn => $base,
            sn => 'value1',
            cn => [qw(value1 value2)]
        );
        push @entries, $entry;
    }
    return RESULT_OK, @entries;
}

package Listener;
use Net::Daemon;
use base 'Net::Daemon';

sub Run {
    my $self = shift;

    my $handler = TestLdapServer->new($self->{socket});
    while (1) {
        my $finished = $handler->handle;
        if ($finished) {

            # we have finished with the socket
            $self->{socket}->close;
            return;
        }
    }
}

package main;
use strict;
use warnings;

use IO::Handle;

pipe(my $reader, my $writer);
my $pid = fork();

exit 1 unless defined $pid;

unless ($pid) {
    close($reader);
    $writer->autoflush(1);
    my $listener = Listener->new(
        {   localport => 33389,
            logfile   => 'STDERR',
            pidfile   => '/tmp/pf-ldap.pid',
            mode      => 'single'
        }
    );
    close($reader);
    $writer->write("done\n");
    close($writer);
    $listener->Bind;
    exit 0;
}


close($writer);
my $line = <$reader>;
close($reader);
sleep(1);

BEGIN {
    use lib qw(/usr/local/pf/lib);
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 6;    # last test to print

use Test::NoWarnings;
use pf::authentication;
use pf::Authentication::constants;

my $source = getAuthenticationSource('LDAP0');

$source->cache->clear;

#my $ldap = Net::LDAP->new( 'localhost', port => 33389 ) or die "$@";

isa_ok($source,'pf::Authentication::Source::LDAPSource');

my $params = { username => 'bob'};

is(0,SHM::getCount(),"No search was done");

my @action = pf::authentication::match([$source], $params, $Actions::SET_ROLE);

is(SHM::getCount(),1,"The search was done the first time");

@action = pf::authentication::match([$source], $params, $Actions::SET_ROLE);

is(SHM::getCount(),1,"The search was done only once");

$source->cache_match(0);

@action = pf::authentication::match([$source], $params, $Actions::SET_ROLE);

is(SHM::getCount(),2,"The search was done a second time");

END {
    local $?;
    `kill \$(cat /tmp/pf-ldap.pid)`
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

