package pf::config::util;


=head1 NAME

pf::util - module for generic functions and utilities used by all the
modules.

=cut

=head1 DESCRIPTION

pf::util contains many functions and utilities used by the other different
modules.

=cut

use strict;
use warnings;

use pf::cluster;
use pf::constants;
use pf::config qw(
    %Config
    @internal_nets
    $fqdn
    @routed_isolation_nets
    @routed_registration_nets
    @inline_nets
    %connection_type_to_str
    %connection_type
    $UNKNOWN
    $management_network
    %ConfigRealm
    $HTTPS
    $HTTP
);
use pf::constants::config qw($TIME_MODIFIER_RE);
use File::Basename;
use Net::MAC::Vendor;
use Net::SMTP;
use POSIX();
use File::Spec::Functions;
use File::Slurp qw(read_dir);
use List::MoreUtils qw(all any);
use Try::Tiny;
use pf::file_paths qw(
    $html_dir
);
use pf::util;
use pf::log;
use pf::authentication;

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    whitelisted_mac ip2interface ip2device
    pfmailer send_email get_all_internal_ips
    get_internal_nets get_routed_isolation_nets
    get_routed_registration_nets get_inline_nets
    get_internal_devs get_internal_devs_phy
    get_internal_macs get_internal_info
    connection_type_to_str str_to_connection_type
    get_translatable_time trappable_mac
    portal_hosts
    filter_authentication_sources
    get_realm_authentication_source
    get_captive_portal_uri
  );
}

=head1 METHODS

=cut

sub trappable_mac {
    my ($mac) = @_;
    my $logger = get_logger();
    return (0) if ( !$mac );
    $mac = clean_mac($mac);

    if ( !valid_mac($mac)
        || grep( { $_ eq $mac } get_internal_macs() ) )
    {
        $logger->info("$mac is not trappable, skipping");
        return (0);
    } else {
        return (1);
    }
}

sub whitelisted_mac {
    my ($mac) = @_;
    my $logger = get_logger();
    return (0) if ( !valid_mac($mac) );
    $mac = clean_mac($mac);
    foreach
        my $whitelist ( split( /\s*,\s*/, $Config{'fencing'}{'whitelist'} ) )
    {
        if ( $mac eq clean_mac($whitelist) ) {
            $logger->info("$mac is whitelisted, skipping");
            return (1);
        }
    }
    return (0);
}

sub ip2interface {
    my ($ip) = @_;
    return (0) if ( !valid_ip($ip) );
    foreach my $interface (@internal_nets) {
        if ( $interface->match($ip) ) {
            return ( $interface->tag("ip") );
        }
    }
    return (0);
}


sub ip2device {
    my ($ip) = @_;
    return (0) if ( !valid_ip($ip) );
    foreach my $interface (@internal_nets) {
        if ( $interface->match($ip) ) {
            return ( $interface->tag("int") );
        }
    }
    return (0);
}

=head2 pfmailer - send an email

=cut

sub pfmailer {
    my (%data)     = @_;
    my $logger     = get_logger();
    my $smtpserver = untaint_chain($Config{'alerting'}{'smtpserver'});
    my @to = split( /\s*,\s*/, $Config{'alerting'}{'emailaddr'} );
    my $from = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;
    my $host_prefix = $cluster_enabled ? " ($host_id)" : '';
    my $subject
        = $Config{'alerting'}{'subjectprefix'} . $host_prefix . " " . $data{'subject'};
    my $date = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );
    my $smtp = Net::SMTP->new( $smtpserver, Hello => $fqdn );

    if ( defined $smtp ) {
        $smtp->mail($from);
        $smtp->to(@to);
        $smtp->data();
        $smtp->datasend("From: $from\n");
        $smtp->datasend( "To: " . join( ",", @to ) . "\n" );
        $smtp->datasend("Subject: $subject ($date)\n");
        $smtp->datasend("\n");
        $smtp->datasend( $data{'message'} );
        $smtp->dataend();
        $smtp->quit;
        $logger->info(
            "email regarding '$subject' sent to " . join( ",", @to ) );
    } else {
        $logger->error("can not connect to SMTP server $smtpserver!");
    }
    return 1;
}

=head2 send_email - Send an email using a template

=cut

sub send_email {
    my ($template, $email, $subject, $data) = @_;
    my $logger = get_logger();

    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    $data->{'from'} = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn unless ($data->{'from'});

    try {
        require MIME::Lite::TT;
    } catch {
        $logger->error("Could not send email because I couldn't load a module. ".
                       "Are you sure you have MIME::Lite::TT installed?");
        return $FALSE;
    };

    require pf::web;

    my %TmplOptions = (
        INCLUDE_PATH    => "$html_dir/captive-portal/templates/emails/",
        ENCODING        => 'utf8',
    );
    my %vars = (%$data, i18n => \&pf::web::i18n, i18n_format => \&pf::web::i18n_format);
    utf8::decode($subject);
    my $msg = MIME::Lite::TT->new(
        From        =>  $data->{'from'},
        To          =>  $email,
        Cc          =>  $data->{'cc'} || '',
        Subject     =>  $subject,
        Template    =>  "emails-$template.html",
        TmplOptions =>  \%TmplOptions,
        TmplParams  =>  \%vars,
        TmplUpgrade =>  1,
    );
    $msg->attr("Content-Type" => "text/html; charset=UTF-8;");

    my $result = 0;
    try {
      $msg->send('smtp', $smtpserver, Timeout => 20);
      $result = $msg->last_send_successful();
      $logger->info("Email sent to $email ($subject)");
    } catch {
      $logger->error("Can't send email to $email: $@");
    };

    return $result;
}


sub get_all_internal_ips {
    my @ips;
    foreach my $interface (@internal_nets) {
        my @tmpips = $interface->enumerate();
        pop @tmpips;
        push @ips, @tmpips;
    }
    return (@ips);
}

sub get_internal_nets {
    my @nets;
    foreach my $interface (@internal_nets) {
        push @nets, $interface->desc();
    }
    return (@nets);
}

sub get_routed_isolation_nets {
    my @nets;
    foreach my $interface (@routed_isolation_nets) {
        push @nets, $interface->desc();
    }
    return (@nets);
}

sub get_routed_registration_nets {
    my @nets;
    foreach my $interface (@routed_registration_nets) {
        push @nets, $interface->desc();
    }
    return (@nets);
}

sub get_inline_nets {
    my @nets;
    foreach my $interface (@inline_nets) {
        push @nets, $interface->desc();
    }
    return (@nets);
}

sub get_internal_devs {
    my @devs;
    foreach my $internal (@internal_nets) {
        push @devs, $internal->tag("int");
    }
    return (@devs);
}

sub get_internal_devs_phy {
    my @devs;
    foreach my $internal (@internal_nets) {
        my $dev = $internal->tag("int");
        push( @devs, $dev ) if ( $dev !~ /:\d+$/ );
    }
    return (@devs);
}

sub get_internal_macs {
    my @macs;
    my %seen;
    foreach my $internal (@internal_nets) {
        my $mac = getlocalmac( $internal->tag("int") );
        push @macs, $mac if ( $mac && !defined( $seen{$mac} ) );
        $seen{$mac} = 1;
    }
    return (@macs);
}

sub get_internal_info {
    my ($device) = @_;
    foreach my $interface (@internal_nets) {
        return ($interface) if ( $interface->tag("int") eq $device );
    }
    return;
}

=head2 connection_type_to_str

In the database we store the connection type as a string but we use a constant binary value internally.
This converts from the constant binary value to the string.

return connection_type string (as defined in pf::config) or an empty string if connection type not found

=cut

sub connection_type_to_str {
    my ($conn_type) = @_;
    my $logger = get_logger();

    # convert connection_type constant into a string for database
    if (defined($conn_type) && $conn_type ne '' && defined($connection_type_to_str{$conn_type})) {

        return $connection_type_to_str{$conn_type};
    } else {
        my ($package, undef, undef, $routine) = caller(1);
        $logger->warn("unable to convert connection_type to string. called from $package $routine");
        return '';
    }
}


=head2 str_to_connection_type

In the database we store the connection type as a string but we use a constant binary value internally.
This parses the string from the database into the the constant binary value.

return connection_type constant (as defined in pf::config) or undef if connection type not found

=cut

sub str_to_connection_type {
    my ($conn_type_str) = @_;
    my $logger = get_logger();

    # convert database string into connection_type constant
    if (defined($conn_type_str) && $conn_type_str ne '' && defined($connection_type{$conn_type_str})) {

        return $connection_type{$conn_type_str};
    } elsif (defined($conn_type_str) && $conn_type_str eq '') {

        $logger->debug("got an empty connection_type, this happens if we discovered the node but it never connected");
        return $UNKNOWN;

    } else {
        my ($package, undef, undef, $routine) = caller(1);
        $logger->warn("unable to parse string into a connection_type constant. called from $package $routine");
        return;
    }
}

=head2 get_translatable_time

Returns a triplet with singular and plural english string representation plus integer of a time string
as defined in pf.conf.

ex: 7D will return ("day", "days", 7)

Returns undef on failure

=cut

sub get_translatable_time {
   my ($time) = @_;

   # grab time unit
   my ($value, $unit) = $time =~ /^(\d+)($TIME_MODIFIER_RE)/;

   unless ($unit) {
       $time = get_abbr_time($time);
       ($value, $unit) = $time =~ /^(\d+)($TIME_MODIFIER_RE)$/i;
   }

   if ($unit eq "s") { return ("second", "seconds", $value);
   } elsif ($unit eq "m") { return ("minute", "minutes", $value);
   } elsif ($unit eq "h") { return ("hour", "hours", $value);
   } elsif ($unit eq "D") { return ("day", "days", $value);
   } elsif ($unit eq "W") { return ("week", "weeks", $value);
   } elsif ($unit eq "M") { return ("month", "months", $value);
   } elsif ($unit eq "Y") { return ("year", "years", $value);
   }
   return;
}

=head2 portal_hosts

Returns the list of host and IP on which the portal is configured to listen

=cut

sub portal_hosts {
    my @hosts;
    foreach my $net (@internal_nets) {
        push @hosts, $net->{Tip} if defined($net->{Tip});
        push @hosts, $net->{Tvip} if defined($net->{Tvip});
        push @hosts, $net->{Tipv6_address} if defined($net->{Tipv6_address});
    }
    push @hosts, $management_network->{Tip} if defined($management_network->{Tip});
    push @hosts, $management_network->{Tvip} if defined($management_network->{Tvip});
    push @hosts, $fqdn;
    return @hosts;
}

=head2 get_realm_authentication_source

Get a source for a specific username and realm
Will look it up in the realm configuration

=cut

sub get_realm_authentication_source {
    my ( $username, $realm ) = @_;

    $realm = "null" unless ( defined($realm) );
    $realm = lc $realm;

    my $realm_authentication_source;

    if ( exists $ConfigRealm{$realm} ) {
        if ( my $source = $ConfigRealm{$realm}{source} ) {
            get_logger->info("Found authentication source '$source' for realm '$realm'");
            $realm_authentication_source = pf::authentication::getAuthenticationSource($source);
        }
    }
    elsif ( exists $ConfigRealm{default} && $realm ne "null" ) {
        if ( my $source = $ConfigRealm{default}{source} ) {
            get_logger->info("Found authentication source '$source' for realm '$realm' through the default realm");
            $realm_authentication_source = pf::authentication::getAuthenticationSource($source);
        }
    }

    return $realm_authentication_source;

}

=head2 filter_authentication_sources

Filter a given list of authentication sources based on a username / realm

=cut

sub filter_authentication_sources {
    my ( $sources, $username, $realm ) = @_;

    return @$sources unless ( defined($username) || defined($realm) );

    my $realm_authentication_source = get_realm_authentication_source($username, $realm);

    return @$sources unless ( defined($realm_authentication_source) && defined($realm_authentication_source->{id}) && $realm_authentication_source->{id} ne "" );

    get_logger->info("Found authentication source '" . $realm_authentication_source->{id} . "' for realm '$realm'");
    
    if ( any { $_ eq $realm_authentication_source} @$sources ) {
        get_logger->info("Realm '$realm' authentication source '" . $realm_authentication_source->{id} . "' is part of the available connection profile authentication sources. Using it as the only authentication source.");
        return ($realm_authentication_source);
    }
    else {
        get_logger->info("Realm '$realm' authentication source '" . $realm_authentication_source->{id} . "' is not configured in the connection profile. Ignoring it and using the connection profile authentication sources");
    }

    return @$sources;
}

=head2 get_captive_portal_uri

Returns the complete captive-portal URI

=cut

sub get_captive_portal_uri {
    my $captive_portal_uri = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    $captive_portal_uri .= "://" . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};

    return $captive_portal_uri;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
