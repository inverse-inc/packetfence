package pf::domain::ntlm_cache;

use strict;
use warnings;

use pf::constants;
use pf::authentication;
use pf::config qw(%ConfigDomain);
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );
use Data::Dumper;
use pf::log;
use File::Slurp qw(write_file read_file);
use pf::file_paths qw($domains_ntlm_cache_users_dir);
use File::Spec::Functions;
use pf::domain;
use pf::util;
use File::Temp;
use pf::Redis;
use pf::constants::domain qw($NTLM_REDIS_CACHE_HOST $NTLM_REDIS_CACHE_PORT);

sub fetch_valid_users {
    my ($domain) = @_;
    my $logger = get_logger;
    my $config = $ConfigDomain{$domain};
    my $ldap_source = getAuthenticationSource($config->{ntlm_cache_source});

    return ($FALSE, "Invalid LDAP source $config->{ntlm_cache_source}") unless(defined($ldap_source));

    my $filter = $config->{ntlm_cache_filter};

    my ($connection, $LDAPServer, $LDAPServerPort ) = $ldap_source->_connect();

    if (!defined($connection)) {
        return ($FALSE, "Error communicating with the LDAP server");
    }

    my $page = Net::LDAP::Control::Paged->new(size => 1000) or die $!;
    my @users;
    my $cookie;
    while(1) {
        my $msg = $connection->search(
            base => $ldap_source->{basedn}, 
            filter => $filter, 
            control => [$page], 
            attrs => [$ldap_source->{usernameattribute}],
            scope => $ldap_source->{scope},
        );

        return ($FALSE, "Error contacting LDAP : ".$msg->error) if($msg->code);
        
        foreach my $entry($msg->entries) {
            my $username = lc($entry->get_value($ldap_source->{usernameattribute}));
            $logger->info("Account '$username' isn't locked or disabled. Will be included in the NTLM cache.");
            push @users, $username;
        }
        # Get cookie from paged control
        my($resp)  = $msg->control( LDAP_CONTROL_PAGED )  or last;
        $cookie    = $resp->cookie or last;
     
        # Set cookie in paged control
        $page->cookie($cookie);
    }
    return \@users;
}

sub generate_valid_users_file {
    my ($domain) = @_;
    my $logger = get_logger;
    my ($users, $msg) = fetch_valid_users($domain);
    if($users) {
        my $file = catfile($domains_ntlm_cache_users_dir, "$domain.valid-users.txt");
        write_file($file, join("\n", @$users));
        my $msg = "Successfully created valid users file ($file) with ".scalar(@$users)." entries.";
        $logger->info($msg);
        return ($file, $msg);
    }
    else {
        return ($FALSE, $msg);
    }
}

sub fetch_all_valid_hashes {
    my ($domain) = @_;
    my $logger = get_logger;
    my ($valid_users_file, $err) = generate_valid_users_file($domain);
    unless($valid_users_file) {
        my $msg = "Cannot generate valid users file ($err)";
        $logger->error($msg);
        return ($FALSE, $msg);
    }
    my $config = $ConfigDomain{$domain};
    my $source = getAuthenticationSource($config->{ntlm_cache_source});
    return ($FALSE, "Invalid LDAP source $config->{ntlm_cache_source}") unless(defined($source));
    
    my ($connection, $LDAPServer, $LDAPServerPort ) = $source->_connect();

    if (!defined($connection)) {
        return ($FALSE, "Error communicating with the LDAP server");
    }

    # We need to fetch the sAMAccountName of the DN in the AD source
    my $result = $connection->search(
        base => $source->{binddn}, 
        filter => '(sAMAccountName=*)', 
        attrs => ['sAMAccountName'],
    );

    return ($FALSE, "Cannot find sAMAccountName of user ".$source->{binddn}) unless($result->count > 0);

    my $tmpfile = File::Temp->new()->filename;
    my $ntds_file = $tmpfile.".ntds";

    my $sAMAccountName = $result->entry(0)->get_value('sAMAccountName');

    eval {
        $result = pf_run("/usr/local/pf/addons/secretsdump.py '".pf::domain::escape_bind_user_string($sAMAccountName)."':'".pf::domain::escape_bind_user_string($source->{password})."'@".$source->{host}." -just-dc-ntlm -output $tmpfile -usersfile $valid_users_file", accepted_exit_status => [ 0 ]);
    };
    if (!defined($result) || $@) {
        return ($FALSE, "Can't generate hash list via secretsdump.py. Check logs for details.");
    }
    return ($ntds_file);
}

sub populate_ntlm_redis_cache {
    my ($domain) = @_;
    my $logger = get_logger;
    my $config = $ConfigDomain{$domain};

    my ($ntds_file, $err) = fetch_all_valid_hashes($domain);

    unless($ntds_file) {
        $logger->error($err);
        return ($FALSE, $err);
    }

    my $content = read_file($ntds_file);
    my $redis = pf::Redis->new(server => "$NTLM_REDIS_CACHE_HOST:$NTLM_REDIS_CACHE_PORT", reconnect => 5);

    foreach my $line (split(/\n/, $content)) {
        my $data = [ split(':', $line) ];
        my $user = $data->[0];
        my $nthash = $data->[3];
        $user = [split(/\\/, $user)]->[-1];
        $user = lc($user);
        my $key = "NTHASH:$domain:$user";
        $logger->info("Inserting '$key' => '$nthash'");
        $redis->set($key, $nthash, 'EX', $config->{ntlm_cache_expiry});
    }
}

1;
