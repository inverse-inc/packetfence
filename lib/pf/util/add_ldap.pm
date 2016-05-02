package pf::util::add_ldap;

=head1 NAME

pf::util::ldap -

=cut

=head1 DESCRIPTION

pf::util::ldap

=cut

=head2 create_entry

Create a new lday entry

=cut

use strict;
use warnings;
use Net::LDAP;
use Net::LDAPS;
use Encode;
use List::MoreUtils qw(any);
use Net::LDAP::Util qw(escape_filter_value);
use DateTime;
use pf::log;
use pf::config qw(%Config $fqdn);
use pf::config::util qw(send_email);
use Text::Password::Pronounceable;
use pf::custom::ldap_add_config qw(%LdapAddConfig);
use pf::sms_carrier qw(sms_carrier_view_all);


our %MAP_REQUEST_ATTRIBUTES = (
    phone => 'mobile',
    email => 'mail',
    firstname => 'givenName',
    lastname => 'sn',
);

#BIGEPOCH (01/01/1970) is 11644524000 "seconds intervals since 01/01/1601"

use constant BIGEPOCH => '11644524000';
my $logger = get_logger;

sub unix_epoch_to_ad_epoch {
    use integer;
    my ($unix_epoch) = @_;
    return ($unix_epoch + BIGEPOCH) * 10000000;
}

=head1 FUNCTIONS

=cut

sub add_new_user {
    my ($userinfo) = @_;
    _add_user_to_ldap(\%LdapAddConfig, $userinfo);
    if ($userinfo->{by_email}) {
        send_email_to_user($userinfo);
    }
    elsif ($userinfo->{by_sms}) {
        send_sms_to_user($userinfo);
    }
}


=head2 _add_user_to_ldap

=cut

use Data::Dumper;

sub _add_user_to_ldap {
    my ($config, $userinfo) = @_;
    my $ldap = connect_to_ldap($config);
    unless ($ldap) {
        $logger->error("Cannot connect to ldap server");
        goto ERROR;
    }

    my @errors;
    my $cn = generate_random_value($config->{username_generation});
    my $dn = "cn=$cn,$config->{user_ou}";
    $userinfo->{username} = $cn;
    my $attrs = _make_attributes($config, $userinfo);
    my $msg = $ldap->add($dn, attrs => $attrs);
    if ($msg->is_error()) {
        @errors = ($msg);
        goto ERROR_ADD;
    }

    my @groups_added;
    add_to_groups($ldap, $dn, $config->{user_groups} // [], \@groups_added, \@errors);
    if (@errors) {
        goto ERROR_GROUP;
    }

    my $new_password = generate_random_value($config->{password_generation});
    my $additional_attributes = _post_create_attributes($config);
    $userinfo->{password} = $new_password;
    $msg = update_ad_password($ldap, $dn, $new_password, $additional_attributes);
    if ($msg->is_error()) {
        @errors = ($msg);
        goto ERROR_GROUP;
    }

    return 1;

#Error handling

ERROR_GROUP:
#Removing groups added
    foreach my $group (@groups_added) {
        my $msg = $ldap->modify($group, delete => {
            member => [$dn],
        });
        push @errors, $msg if $msg->is_error;
    }

#Remove user added
    $msg = $ldap->delete($dn);

ERROR_ADD:
#Log error
    $logger->error(join ("\n", map { $_->error } @errors));

ERROR:
    die "Problem creating user account\n";
}

=head2 _post_create_attributes

=cut

sub _post_create_attributes {
    my ($config) = @_;
    my $datetime = DateTime->now->add(days => 1)->truncate(to => 'hour');
    return {
        userAccountControl => 512,
        pwdLastSet         => 0,
        accountExpires     => unix_epoch_to_ad_epoch($datetime->epoch)
      };
}

=head2 generate_random_value

Generate random value

=cut

sub generate_random_value {
    my ($generate_config) = @_;
    return Text::Password::Pronounceable->generate($generate_config->{min}, $generate_config->{max});
}

=head2 _make_attributes

=cut

sub _make_attributes {
    my ($config, $userinfo) = @_;
    my $cn = $userinfo->{username};
    my @attributes = (
        objectClass => $config->{objectClass},
        (map {$_ => $cn} qw(cn sAMAccountName)),
    );
    while (my ($param, $ad_attrib) = each %MAP_REQUEST_ATTRIBUTES) {
        my $value = $userinfo->{$param};
        next unless defined $value;
        push @attributes, $ad_attrib, $value;
    }
    return \@attributes;
}

=head2 update_ad_password

Update the AD password

=cut

sub update_ad_password {
    my ($ldap, $dn, $password, $update_ad_password) = @_;
    $ldap->modify(
        $dn,
        replace => {
            %$update_ad_password, unicodePwd => encode('utf16le', '"' . decode('utf8', $password) . '"'),
        });
}

sub add_to_groups {
    my ($ldap, $dn, $groups, $added, $errors) = @_;
    my @msgs;
    foreach my $group (@$groups) {
        my $msg = $ldap->modify($group, add => {member => [$dn]});
        if ($msg->is_error()) {
            push @$errors, $ldap->modify($group, add => {member => [$dn]});
        }
        else {
            push @$added, $group;
        }
    }
}

sub connect_to_ldap {
    my ($config) = @_;
    my $encryption = $config->{encryption};
    my $connection =
      $encryption eq 'ssl'
      ? Net::LDAPS->new($config->{host}, port => $config->{port}, timeout => $config->{'connection_timeout'})
      : Net::LDAP->new($config->{host}, port => $config->{port}, timeout => $config->{'connection_timeout'});
    return $connection unless defined $connection;

    # try TLS if required, return undef if it fails
    if ($encryption eq 'tls') {
        my $mesg = $connection->start_tls();
    }
    my $result = $connection->bind($config->{'binddn'}, password => $config->{'password'});
    return $connection;
}

=head2 send_email_to_user

Send email to user

=cut

sub send_email_to_user {
    my ($user_info) = @_;
    send_email(
        "guest-library",
        $user_info->{email},
        "Access to the Library",
        {
            firstname => $user_info->{firstname},
            lastname => $user_info->{lastname},
            username  => $user_info->{username},
            password  => $user_info->{password},
        });
}

=head2 send_sms_to_user

Send sms to user

=cut

sub send_sms_to_user {
    my ($user_info) = @_;
    my $sms_carrier = sms_carrier_view_all({sms_carriers => [$user_info->{mobileprovider}]});

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    my $from = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;

    my $email = sprintf($sms_carrier->[0]{'email_pattern'}, $user_info->{'phone'});
    my $msg = MIME::Lite->new(
        From    => $from,
        To      => $email,
        Subject => "Network Activation",
        Data    => "\nUser name: $user_info->{username}\nPassword: $user_info->{password}"
    );

    my $result = 0;
    eval {
        $msg->send('smtp', $smtpserver, Timeout => 20);
        $result = $msg->last_send_successful();
        $logger->info("Email sent to $email (Network Activation)");
    };
    if ($@) {
        my $msg = "Can't send email to $email: $@";
        $msg =~ s/\n//g;
        $logger->error($msg);
    }

    return $result;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

