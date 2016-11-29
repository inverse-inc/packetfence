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
use File::Slurp;
use pf::file_paths qw($domains_ntlm_cache_users_dir);
use File::Spec::Functions;

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
        File::Slurp::write_file($file, join("\n", @$users));
        my $msg = "Successfully created valid users file ($file) with ".scalar(@$users)." entries.";
        $logger->info($msg);
        return ($TRUE, $msg);
    }
    else {
        return ($users, $msg);
    }
}

1;
