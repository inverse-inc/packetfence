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
    %connection_type
    $UNKNOWN
    $management_network
    %ConfigRealm
    $HTTPS
    $HTTP
);
use pf::constants::config qw($DEFAULT_SMTP_PORT $DEFAULT_SMTP_PORT_SSL $DEFAULT_SMTP_PORT_TLS %ALERTING_PORTS);
use IO::Socket::SSL qw(SSL_VERIFY_NONE);
use pf::constants::config qw($TIME_MODIFIER_RE);
use pf::constants::realm;
use File::Basename;
use Net::MAC::Vendor;
use Net::SMTP;
use MIME::Lite;
use MIME::Lite::TT;
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
    get_translatable_time trappable_mac
    portal_hosts
    filter_authentication_sources
    get_realm_authentication_source
    get_captive_portal_uri
    get_send_email_config
    send_mime_lite
    is_inline_configured
    strip_username_if_needed
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
    my (%data) = @_;
    my $to = $Config{'alerting'}{'emailaddr'};
    my $host_prefix = $cluster_enabled ? " ($host_id)" : '';
    my $date = POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );
    my $subject = $Config{'alerting'}{'subjectprefix'} . $host_prefix . " " . $data{'subject'} . " ($date)";
    my $msg = MIME::Lite->new(
        To      => $to,
        Subject => $subject,
        Data    => $data{message} . "\n",
    );
    return send_mime_lite($msg);
}

=head2 send_email - Send an email using a template

=cut

sub send_email {
    my ($template, $email, $subject, $data, $tmpoptions) = @_;
    my $logger = get_logger();

    try {
        require MIME::Lite::TT;
    }
    catch {
        $logger->error(
                "Could not send email because I couldn't load a module. "
              . "Are you sure you have MIME::Lite::TT installed?" );
        return $FALSE;
    };

    require pf::web;

    my %TmplOptions = (
        INCLUDE_PATH => "$html_dir/captive-portal/templates/emails/",
        ENCODING     => 'utf8',
        %{$tmpoptions // {}},
    );
    my %vars = (
        %$data,
        i18n        => \&pf::web::i18n,
        i18n_format => \&pf::web::i18n_format
    );
    utf8::decode($subject);
    my $msg = MIME::Lite::TT->new(
        To          => $email,
        Bcc         => $data->{'bcc'} || '',
        Subject     => $subject,
        Encoding    => 'base64',
        Template    => "emails-$template.html",
        TmplOptions => \%TmplOptions,
        TmplParams  => \%vars,
        ( $data->{'from'} ? ( From => $data->{'from'} ) : () ),
    );
    $msg->attr( "Content-Type" => "text/html; charset=UTF-8" );
    return send_mime_lite($msg);
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

=head2 is_inline_configured

return the number of inline networks

=cut

sub is_inline_configured {
    return scalar @inline_nets;
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

Find sources for a specific realm

=cut

sub get_realm_authentication_source {
    my ( $username, $realm, $sources ) = @_;
    return [grep { $_->realmIsAllowed($realm) } @{$sources}];
}

=head2 filter_authentication_sources

Filter a given list of authentication sources based on a username / realm

=cut

sub filter_authentication_sources {
    my ( $sources, $username, $realm ) = @_;

    return $sources unless ( defined($username) || defined($realm) );

    my $realm_authentication_source = get_realm_authentication_source($username, $realm, $sources);

    return $sources unless ( ref($realm_authentication_source) eq 'ARRAY');

    $realm = "null" unless ( defined($realm) );

    get_logger->info("Found authentication source(s) : '", join(',', (map {$_->id} @{$realm_authentication_source})) . "' for realm '$realm'");

    return $realm_authentication_source;
}

=head2 get_captive_portal_uri

Returns the complete captive-portal URI

=cut

sub get_captive_portal_uri {
    my $captive_portal_uri = isenabled($Config{'captive_portal'}{'secure_redirect'}) ? $HTTPS : $HTTP;
    $captive_portal_uri .= "://" . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};

    return $captive_portal_uri;
}

=head2 get_send_email_config

get the configuration for sending email

=cut

sub get_send_email_config {
    my ($config) = @_;
    my %args;
    my $encryption = $config->{smtp_encryption} // 'none';
    $encryption = 'none' if !exists $ALERTING_PORTS{$encryption};
    if ($encryption eq 'ssl') {
        $args{SSL} = 1;
    } elsif ($encryption eq 'starttls') {
        $args{StartTLS} = 1;
    }
    $args{From} = $config->{fromaddr} || 'root@' . $fqdn;
    if (isdisabled($config->{smtp_verifyssl})) {
        $args{SSL_verify_mode} = SSL_VERIFY_NONE;
    }
    my $username = $config->{smtp_username};
    my $password = $config->{smtp_password};
    if (defined $username && length($username) &&
        defined $password && length($password)) {
        $args{AuthUser} = $username;
        $args{AuthPass} = $password;
    }
    $args{Hostname} = $config->{smtpserver};
    $args{Hello} = $fqdn;
    $args{Timeout} = $config->{smtp_timeout};
    $args{Port} = $config->{smtp_port} || $ALERTING_PORTS{$encryption};
    return \%args;
}

=head2 send_mime_lite

Submit a mime lite object using the current alerting settings

=cut

sub send_mime_lite {
    my ($mime, @args) = @_;
    my $result = eval {
        do_send_mime_lite($mime, @args);
    };
    if ($@) {
        my $to = $mime->{_extracted_to};
        my $msg = "Can't send email to '$to' :'$@'";
        $msg =~ s/\n//g;
        get_logger->error($msg);
    }

    return $result ? $TRUE : $FALSE;
}

=head2 do_send_mime_lite

do_send_mime_lite

=cut

sub do_send_mime_lite {
    my ($mime, @args) = @_;
    $mime->send(
        'sub',
        \&send_using_smtp_callback,
        @args
    );
    return $mime->last_send_successful();
}

=head2 send_using_smtp_callback

Handles the logic of sending an email of a MIME::Lite object
Using the configuration of from pf.conf

=cut

sub send_using_smtp_callback {
    my ($self, %args) = @_;
    my $alerting_config = merge_with_alert_config(\%args);
    my $config = get_send_email_config($alerting_config);
    %args = (%$config, %args);

    # We may need the "From:" and "To:" headers to pass to the
    # SMTP mailer also.
    $self->{last_send_successful} = 0;

    my @hdr_to = MIME::Lite::extract_only_addrs( scalar $self->get('To') );
    if ($MIME::Lite::AUTO_CC) {
        foreach my $field (qw(Cc Bcc)) {
            push @hdr_to, MIME::Lite::extract_only_addrs($_)
              for $self->get($field);
        }
    }
    my $hostname = $args{Hostname};
    Carp::croak "send_using_smtp_callback: nobody to send to for host '$hostname'?!\n"
      unless @hdr_to;

    $args{To} ||= \@hdr_to;
    $args{From} ||=
      MIME::Lite::extract_only_addrs( scalar $self->get('Return-Path') );
    $args{From} ||= MIME::Lite::extract_only_addrs( scalar $self->get('From') );
    $self->{_extracted_to} = join(",", @{$args{To}});

    if (!(scalar $self->get('From')) && $args{From}) {
        $self->add(From => $args{From} );
    }

    # Create SMTP client.
    # MIME::Lite::SMTP is just a wrapper giving a print method
    # to the SMTP object.

    my %opts = %args;
    my $smtp = MIME::Lite::SMTP->new( $hostname, %opts )
      or Carp::croak "SMTP Failed to connect to mail server: $!\n";

    if ($args{StartTLS}) {
        $smtp->starttls;
    }

    # Possibly authenticate
    if (    defined $args{AuthUser}
        and defined $args{AuthPass}
        and !$args{NoAuth} )
    {
        if ( $smtp->supports( 'AUTH', 500, ["Command unknown: 'AUTH'"] ) ) {
            $smtp->auth( $args{AuthUser}, $args{AuthPass} )
              or die "SMTP auth() command failed: $!\n" . $smtp->message . "\n";
        }
        else {
            die "SMTP auth() command not supported on $hostname\n";
        }
    }

    # Send the mail command
    %opts = MIME::Lite::__opts( \%args, @MIME::Lite::_mail_opts );
    $smtp->mail( $args{From}, %opts ? \%opts : () )
      or die "SMTP mail() command failed: $!\n" . $smtp->message . "\n";

    # Send the recipients command
    %opts = MIME::Lite::__opts( \%args, @MIME::Lite::_recip_opts );
    $smtp->recipient( @{ $args{To} }, %opts ? \%opts : () )
      or die "SMTP recipient() command failed: $!\n" . $smtp->message . "\n";

    # Send the data
    $smtp->data()
      or die "SMTP data() command failed: $!\n" . $smtp->message . "\n";
    $self->print_for_smtp($smtp);
    $smtp->datasend("\n");

    # Finish the mail
    $smtp->dataend()
      or Carp::croak "Net::CMD (Net::SMTP) DATAEND command failed.\n"
      . "Last server message was:"
      . $smtp->message
      . "This probably represents a problem with newline encoding ";

    # terminate the session
    $smtp->quit;

    return $self->{last_send_successful} = 1;
}

=head2 merge_with_alert_config

merge_with_alert_config

=cut

sub merge_with_alert_config {
    my ($config) = @_;
    my %alerting_config = %{$Config{alerting}};
    for my $k (keys %alerting_config ) {
        next unless exists $config->{$k};
        if (defined (my $val = delete $config->{$k})) {
            $alerting_config{$k} = $val;
        }
    }

    return \%alerting_config;
}

=head2 strip_username_if_needed

Strips a username if configured in the realm configuration

Valid context are "portal" and "admin", basically any prefix to "_strip_username" that is configured for the realm

=cut

sub strip_username_if_needed {
    my ($username, $context) = @_;
    return $username unless(defined($username));
    
    my $logger = get_logger;

    my ($stripped, $realm) = strip_username($username);
    $realm = $realm ? lc($realm) : undef;
    
    my $realm_config = defined($realm) && exists($ConfigRealm{$realm}) ? $ConfigRealm{$realm} : $ConfigRealm{lc($pf::constants::realm::DEFAULT)};

    my $param = $context . "_strip_username";

    if(isenabled($realm_config->{$param})) {
        $logger->debug("Stripping username is enabled in this context ($context). Will return a split username and realm.");
        return ($stripped, $realm);
    }
    else {
        $logger->debug("Stripping username is disabled in this context ($context). Will return the username as is with the realm.");
        return ($username, undef);
    }
}

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
