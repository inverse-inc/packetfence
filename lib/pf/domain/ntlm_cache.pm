package pf::domain::ntlm_cache;

=head1 NAME

pf::domain::ntlm_cache

=head1 DESCRIPTION

Controls the caching of the NT hashes for domains

=cut

use strict;
use warnings;

use pf::constants;
use pf::authentication;
use pf::config qw(%ConfigDomain $OS);
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );
use pf::log;
use File::Slurp qw(write_file read_file);
use pf::file_paths qw($domains_ntlm_cache_users_dir);
use File::Spec::Functions;
use pf::domain;
use pf::util;
use File::Temp;
use pf::Redis;
use pf::constants::domain qw($NTLM_REDIS_CACHE_HOST $NTLM_REDIS_CACHE_PORT);
use Socket;
use pf::CHI;
our $SECRETSDUMP_BIN;
if ($OS eq 'rhel') {
    $SECRETSDUMP_BIN = '/usr/bin/secretsdump.py';
} elsif ($OS eq 'debian') {
    $SECRETSDUMP_BIN = '/usr/bin/impacket-secretsdump';
}

my $CHI_CACHE = pf::CHI->new( namespace => 'ntlm_cache_username_lookup' );

=head2 get_sync_samaccountname

Get the sAMAccountName for use in the sync based on the auth source
In source, bind DN could be a DN or a sAMAccountname 

=cut

sub get_sync_samaccountname {
    my ($domain, $source) = @_;
    my $logger = get_logger;
    my $config = $ConfigDomain{$domain};

    my $sAMAccountName;

    # to catch a LDAP DN in the form of CN=user,OU=Users,dc=domain,dc=com
    if ($source->{binddn} =~ /(.*)=(.*)/) {
        my ($connection, $LDAPServer, $LDAPServerPort ) = $source->_connect();

        if (!defined($connection)) {
            return ($FALSE, "Error communicating with the LDAP server");
        }

        # We need to fetch the sAMAccountName of the DN in the AD source
        # base search is the DN itself to return only one result
        my $result = $connection->search(
            base => $source->{binddn},
            filter => '(sAMAccountName=*)',
            attrs => ['sAMAccountName'],
        );

        return ($FALSE, "Cannot find sAMAccountName of user ".$source->{binddn}) unless($result->count > 0);

        $sAMAccountName = $result->entry(0)->get_value('sAMAccountName');

    } else {
        ($sAMAccountName) = strip_username($source->{binddn});
    }
    return $sAMAccountName;
}

=head2 secretsdump

Call the secretsdump binary and return the NTDS filename

=cut

sub secretsdump {
    my ($domain, $source, @opts) = @_;
    my $logger = get_logger;
    my $config = $ConfigDomain{$domain};

    my $tmpfile = File::Temp->new()->filename;
    my $ntds_file = $tmpfile.".ntds";

    my ($sAMAccountName, $msg) = get_sync_samaccountname($domain, $source);
    return ($FALSE, $msg) unless($sAMAccountName);

    my $result;
    my $success = $FALSE;

    foreach my $server (@{$source->{host} // []}) {
        eval {
            $result = safe_pf_run(
                $SECRETSDUMP_BIN,
                pf::domain::escape_bind_user_string($sAMAccountName) . ':' . pf::domain::escape_bind_user_string($source->{password}) . '@' . inet_ntoa(inet_aton($server)),
                '-just-dc-ntlm',
                '-output',
                $tmpfile,
                @opts,
                {accepted_exit_status => [ 0 ], working_directory => "/tmp"}
            );
        };
        if (!defined($result) || $@) {
            $result = "Can't generate hash list via secretsdump.py. Check logs for details.";
        }
        elsif($result =~ /Something wen't wrong/) {
            $result = "Cannot synchronize users hashes. Command output: $result";
        }
        else {
            $success = $TRUE;
            last;
        }
    }

    return $success ? $ntds_file : ($FALSE, $result);
}

=head2 cache_user

Populate the NTLM cache for a single user

=cut

sub cache_user {
    my ($domain, $username) = @_;
    my $logger = get_logger;
    my $config = $ConfigDomain{$domain};
    my $source = getAuthenticationSource($config->{ntlm_cache_source});
    return ($FALSE, "Invalid LDAP source $config->{ntlm_cache_source}") unless(defined($source));
    my $cache_key = "$domain.$username";
    my $user = get_from_cache($cache_key);
    unless($user){
        if($username =~ /^host\//) {
            ($username, my $msg) = $source->findAtttributeFrom("servicePrincipalName", $username, "sAMAccountName");
            return ($FALSE, $msg) unless($username);
        }
        elsif (lc($source->{'usernameattribute'}) ne lc('sAMAccountName')) {
            ($username, my $msg) = $source->findAtttributeFrom($source->{'usernameattribute'}, $username, "sAMAccountName");
            return ($FALSE, $msg) unless($username);
        }
        set_to_cache($cache_key, $username);

    }
    if (defined($user)) {
        $username = $user;
    }
    my ($ntds_file, $msg) = secretsdump($domain, $source, '-just-dc-user', $username);
    return ($FALSE, $msg) unless($ntds_file);

    my $info = extract_info_from_dump_line(read_ntds_file($ntds_file));
    if($info->{username} && $info->{nthash}) {
        insert_user_in_redis_cache($domain, $info->{username}, $info->{nthash});
        get_logger->info("Cached user $username for domain $domain");
        return $TRUE;
    }
    else {
        return ($FALSE, "Couldn't extract informations out of the dump output");
    }
}

=head2 populate_ntlm_redis_cache

Populate the redis NTLM cache for a domain

=cut

sub populate_ntlm_redis_cache {
    my ($domain) = @_;
    my $logger = get_logger;
    my $config = $ConfigDomain{$domain};

    my ($ntds_file, $err) = fetch_all_valid_hashes($domain);

    unless($ntds_file) {
        $logger->error($err);
        return ($FALSE, $err);
    }

    my $content = read_ntds_file($ntds_file);

    foreach my $line (split(/\n/, $content)) {
        my $info = extract_info_from_dump_line($line);
        insert_user_in_redis_cache($domain, $info->{username}, $info->{nthash});
    }
    return ($TRUE);
}

=head2 read_ntds_file

Returns the content of an NTDS file and deletes it at the same time

=cut

sub read_ntds_file {
    my ($ntds_file) = @_;
    my $content = read_file($ntds_file);
    # file isn't needed anymore
    unlink($ntds_file);
    return $content;
}

=head2 extract_info_from_dump_line

Extract the username and NT hash from a dump line

=cut

sub extract_info_from_dump_line {
    my ($line) = @_;
    my $data = [ split(':', $line) ];
    my $user = $data->[0];
    my $nthash = $data->[3];
    $user = [split(/\\/, $user)]->[-1];
    $user = lc($user);
    return {username => $user, nthash => $nthash};
}

=head2 insert_user_in_redis_cache

Insert a user/NT hash combination inside redis for a given domain

=cut

sub insert_user_in_redis_cache {
    my ($domain, $user, $nthash) = @_;
    my $logger = get_logger;
    my $client = pf::api::queue_cluster->new(queue => "general");
    $client->notify_all("insert_user_in_redis_cache", $domain, $user, $nthash);
}

=head2 get_from_cache

Get the value from the key

=cut

sub get_from_cache {
    my ($key) = @_;

    return $CHI_CACHE->get($key);
}

=head2 set_to_cache

Set the value associated to the key

=cut

sub set_to_cache {
    my ($key, $value) = @_;

    $CHI_CACHE->set($key,$value);
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

