package pf::util;

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

use English qw( -no_match_vars );
use File::Basename;
use FileHandle;
use Log::Log4perl;
use Net::MAC::Vendor;
use Net::SMTP;
use POSIX();
use File::Spec::Functions;

our ( %local_mac );

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        valid_date valid_ip reverse_ip clean_ip
        clean_mac valid_mac mac2nb macoui2nb whitelisted_mac trappable_mac format_mac_for_acct format_mac_as_cisco
        ip2interface ip2device ip2int int2ip
        isenabled isdisabled isempty
        getlocalmac
        get_all_internal_ips get_internal_nets get_routed_isolation_nets get_routed_registration_nets get_inline_nets
        get_internal_devs get_internal_devs_phy get_external_devs get_internal_macs
        get_internal_info createpid readpid deletepid
        parse_template mysql_date oui_to_vendor mac2oid oid2mac
        str_to_connection_type connection_type_to_str
        get_total_system_memory
        parse_mac_from_trap
        get_vlan_from_int
        get_abbr_time get_translatable_time
        pretty_bandwidth
        unpretty_bandwidth
        pf_run pfmailer
        generate_id load_oui download_oui
        trim_path format_bytes log_of ordinal_suffix
        untaint_chain
    );
}

# TODO pf::util shouldn't rely on pf::config as this prevent pf::config from
#      being able to use pf::util
use pf::config;

=head1 SUBROUTINES

TODO: This list is incomplete.

=over

=cut

sub valid_date {
    my ($date) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');

    # kludgy but short
    if ( $date
        !~ /^\d{4}\-((0[1-9])|(1[0-2]))\-((0[1-9])|([12][0-9])|(3[0-1]))\s+(([01][0-9])|(2[0-3]))(:[0-5][0-9]){2}$/
        )
    {
        $logger->error("invalid date $date");
        return (0);
    } else {
        return (1);
    }
}

sub valid_ip {
    my ($ip) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    if ( !$ip || $ip !~ /^(?:\d{1,3}\.){3}\d{1,3}$/ || $ip =~ /^0\.0\.0\.0$/ )
    {
        my $caller = ( caller(1) )[3] || basename($0);
        $caller =~ s/^(pf::\w+|main):://;
        $logger->error("invalid IP: $ip from $caller");
        return (0);
    } else {
        return (1);
    }
}

=item reverse_ip

Returns the IP in reverse notation. ex: 1.2.3.4 will return 4.3.2.1

Used for DNS configuration templates.

=cut

sub reverse_ip {
    my ($ip) = @_;

    if ( $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ ) {
        return "$4.$3.$2.$1";
    } else {
        return;
    }
}

=item clean_ip

Properly format an IPv4 address. Has the nice side-effect of untainting it also.

=cut

sub clean_ip {
    my ($ip) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    if ($ip =~ /^((?:\d{1,3}\.){3}\d{1,3})$/) {
        return $1;
    }
    return;
}


=item clean_mac

Clean a MAC address accepting xxxxxxxxxxxx, xx-xx-xx-xx-xx-xx, xx:xx:xx:xx:xx:xx, xxxx-xxxx-xxxx and xxxx.xxxx.xxxx.

Returns an untainted string with MAC in format: xx:xx:xx:xx:xx:xx

=cut

sub clean_mac {
    my ($mac) = @_;
    return (0) if ( !$mac );

    # trim garbage
    $mac =~ s/[\s\-\.:]//g;
    # lowercase
    $mac = lc($mac);
    # inject :
    $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g if ( $mac =~ /^[a-f0-9]{12}$/i );
    # Untaint MAC (see perldoc perlsec if you don't know what Taint mode is)
    if ($mac =~ /^([0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2}:[0-9a-zA-Z]{2})$/) {
        return $1;
    }

    return;
}

=item format_mac_for_acct

Put the mac address in the accounting format, accepting xx:xx:xx:xx:xx:xx

Returning format XXXXXXXXXXXX

=cut

sub format_mac_for_acct {
    my ($mac) = @_;
    return (0) if ( !$mac );
    # trim garbage
    $mac =~ s/[\s\-\.:]//g;
    # uppercase
    $mac = uc($mac);
    return ($mac);
}

=item format_mac_as_cisco

Put the mac address in the cisco format, accepting xx:xx:xx:xx:xx:xx

Returning format aabb.ccdd.eeff

=cut

sub format_mac_as_cisco {
    my ($mac) = @_;

    if (defined($mac) &&
        $mac =~ /^([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2})$/
        ) {
            return "$1$2.$3$4.$5$6";
    }

    # couldn't process, return undef
    return;
}

=item valid_mac

Validates MAC addresses. Returns 1 or 0 (true or false)

Accepting xx-xx-xx-xx-xx-xx, xx:xx:xx:xx:xx:xx, xxxx-xxxx-xxxx and xxxx.xxxx.xxxx

=cut

sub valid_mac {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    if (! ($mac =~ /^[0-9a-f:\.-]+$/i)) {
        $logger->error("invalid MAC: $mac");
        return (0);
    }
    $mac = clean_mac($mac);
    if (   $mac =~ /^ff:ff:ff:ff:ff:ff$/
        || $mac =~ /^00:00:00:00:00:00$/
        || $mac !~ /^([0-9a-f]{2}(:|$)){6}$/i )
    {
        $logger->error("invalid MAC: $mac");
        return (0);
    } else {
        return (1);
    }
}

=item  macoui2nb

Extract the OUI (Organizational Unique Identifier) from a MAC address then
converts it into a decimal value. To be used to generate vendormac violations.

in: MAC address (of xx:xx:xx:xx:xx format)

Returns a number.

=cut

sub macoui2nb {
    my ($mac) = @_;

    my $oui = substr($mac, 0, 8);
    $oui =~ s/://g;
    return hex($oui);
}

=item  mac2nb

Converts a MAC address into a decimal value. To be used to generate mac violations.

in: MAC address (of xx:xx:xx:xx:xx format)

Returns a number.

=cut

sub mac2nb {
    my ($mac) = @_;
    my $nb;

    $mac =~ s/://g;
    # disabling warnings in this scope because a MAC address (48bit) is larger than an int on 32bit systems
    # and perl warns about it but gives the right value.
    {
        no warnings;
        $nb = hex($mac);
    }

    return $nb;
}

sub whitelisted_mac {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    return (0) if ( !valid_mac($mac) );
    $mac = clean_mac($mac);
    foreach
        my $whitelist ( split( /\s*,\s*/, $Config{'trapping'}{'whitelist'} ) )
    {
        if ( $mac eq clean_mac($whitelist) ) {
            $logger->info("$mac is whitelisted, skipping");
            return (1);
        }
    }
    return (0);
}

sub trappable_mac {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
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

=item  oid2mac - convert a MAC in oid format to a MAC in usual format

in: 6 dot-separated digits (ex: 0.18.240.19.50.186)

out: comma-separated MAC address (ex: 00:12:f0:13:32:ba)

=cut

sub oid2mac {
    my ($oid) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    if ($oid =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
        return lc(sprintf( "%02X:%02X:%02X:%02X:%02X:%02X", $1, $2, $3, $4, $5, $6));
    } else {
        $logger->warn("$oid is not a MAC in oid format");
        return;
    }
}

=item  mac2oid - convert a MAC in usual pf format into a MAC in oid format

in: comma-separated MAC address (ex: 00:12:f0:13:32:ba). Use clean_mac() if you need.

out: 6 dot-separated digits (ex: 0.18.240.19.50.186)

=cut

sub mac2oid {
    my ($mac) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    if ($mac =~ /^([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2})$/i) {
        return hex($1).".".hex($2).".".hex($3).".".hex($4).".".hex($5).".".hex($6);
    } else {
        $logger->warn("$mac is not a valid MAC");
        return;
    }
}

sub pfmailer {
    my (%data)     = @_;
    my $logger     = Log::Log4perl::get_logger('pf::util');
    my $smtpserver = $Config{'alerting'}{'smtpserver'};
    my @to = split( /\s*,\s*/, $Config{'alerting'}{'emailaddr'} );
    my $from = $Config{'alerting'}{'fromaddr'} || 'root@' . $fqdn;
    my $subject
        = $Config{'alerting'}{'subjectprefix'} . " " . $data{'subject'};
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

=item  isenabled

Is the given configuration parameter considered enabled? y, yes, true, enable
and enabled are all positive values for PacketFence.

=cut

sub isenabled {
    my ($enabled) = @_;
    if ( $enabled && $enabled =~ /^\s*(y|yes|true|enable|enabled)\s*$/i ) {
        return (1);
    } else {
        return (0);
    }
}

=item  isdisabled

Is the given configuration parameter considered disabled? n, no, false,
disable and disabled are all negative values for PacketFence.

=cut

sub isdisabled {
    my ($disabled) = @_;
    if ( $disabled =~ /^\s*(n|no|false|disable|disabled)\s*$/i ) {
        return (1);
    } else {
        return (0);
    }
}

=item  isempty

Is the given configuration parameter considered empty? Whitespace is
considered empty.

=cut

sub isempty {
    my ($parameter) = @_;

    return $TRUE if ( $parameter =~ /^\s*$/ );
    # otherwise
    return $FALSE;
}

# TODO port to IO::Interface::Simple?
sub getlocalmac {
    my ($dev) = @_;
    return (-1) if ( !$dev );
    return ( $local_mac{$dev} ) if ( defined $local_mac{$dev} );
    foreach (`LC_ALL=C /sbin/ifconfig -a`) {
        if (/^$dev.+HWaddr\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/i) {
            # cache the value
            $local_mac{$dev} = clean_mac($1);
            return $local_mac{$dev};
        }
    }
    return (0);
}

sub ip2int {
    return ( unpack( "N", pack( "C4", split( /\./, shift ) ) ) );
}

sub int2ip {
    return ( join( ".", unpack( "C4", pack( "N", shift ) ) ) );
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

sub get_external_devs {
    my @devs;
    foreach my $interface (@external_nets) {
        push @devs, $interface->tag("int");
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

sub createpid {
    my ($pname) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    $pname = basename($0) if ( !$pname );
    my $pid     = $$;
    my $pidfile = $var_dir . "/run/$pname.pid";
    $logger->info("$pname starting and writing $pid to $pidfile");
    my $outfile = new FileHandle ">$pidfile";
    if ( defined($outfile) ) {
        print $outfile $pid;
        $outfile->close;
        return ($pid);
    } else {
        $logger->error("$pname: unable to open $pidfile for writing: $!");
        return (-1);
    }
}

sub readpid {
    my ($pname) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    $pname = basename($0) if ( !$pname );
    my $pidfile = $var_dir . "/run/$pname.pid";
    my $file    = new FileHandle "$pidfile";
    if ( defined($file) ) {
        my $pid = $file->getline();
        chomp($pid);
        $file->close;
        return ($pid);
    } else {
        $logger->error("$pname: unable to open $pidfile for reading: $!");
        return (-1);
    }
}

sub deletepid {
    my ($pname) = @_;
    $pname = basename($0) if ( !$pname );
    my $pidfile = $var_dir . "/run/$pname.pid";
    unlink($pidfile) || return (-1);
    return (1);
}

sub parse_template {
    my ( $tags, $template, $destination, $comment_char ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    my (@parsed);
    my $template_fh;
    open( $template_fh, '<', $template ) || $logger->logcroak("Unable to open template $template: $!");
    while (<$template_fh>) {
        study $_;
        foreach my $tag ( keys %{$tags} ) {
            $_ =~ s/%%$tag%%/$tags->{$tag}/ig;
        }
        push @parsed, $_;
    }

    # add generated file header (inserting in front of array)
    $comment_char = "#" if (!defined($comment_char));
    unshift @parsed,
        "$comment_char This file is generated from a template at $template\n"
        ."$comment_char Any changes made to this file will be lost on restart\n\n";

    if ($destination) {
        my $destination_fh;
        open( $destination_fh, ">", $destination )
            || $logger->logcroak( "Unable to open template destination $destination: $!");

        foreach my $line (@parsed) {
            print {$destination_fh} $line;
        }
        pf_chown($destination);
    } else {
        return (@parsed);
    }
    return 1;
}

sub mysql_date {
    return ( POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime ) );
}

sub oui_to_vendor {
    my ($mac) = @_;
    load_oui();
    my $oui_info = Net::MAC::Vendor::fetch_oui_from_cache($mac);

    return $$oui_info[0] || '';
}

sub load_oui {
    my ($force) = @_;
    if ( !%$Net::MAC::Vendor::Cached || $force  ) {
        my $logger = Log::Log4perl::get_logger('pf::util');
        $logger->info("loading Net::MAC::Vendor cache from $oui_file");
        Net::MAC::Vendor::load_cache("file://$oui_file");
    }
}

sub download_oui {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    require LWP::UserAgent;
    my $browser = LWP::UserAgent->new;
    my $response = $browser->get($oui_url);
    my ($status,$msg) = $response->code;
    if ( !$response->is_success ) {
        $msg = "Unable to update OUI prefixes: " . $response->status_line;
    } else {
        my ($oui_fh);
        open( $oui_fh, '>', "$oui_file" )
            || $logger->info("Unable to open $oui_file: $!");
        print $oui_fh $response->content;
        close($oui_fh);
        $msg = "OUI prefixes updated via $oui_url";
    }
    return ($status,$msg);
}

=item connection_type_to_str

In the database we store the connection type as a string but we use a constant binary value internally.
This converts from the constant binary value to the string.

return connection_type string (as defined in pf::config) or an empty string if connection type not found

=cut

sub connection_type_to_str {
    my ($conn_type) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');

    # convert connection_type constant into a string for database
    if (defined($conn_type) && $conn_type ne '' && defined($connection_type_to_str{$conn_type})) {

        return $connection_type_to_str{$conn_type};
    } else {
        my ($package, undef, undef, $routine) = caller(1);
        $logger->warn("unable to convert connection_type to string. called from $package $routine");
        return '';
    }
}

=item str_to_connection_type

In the database we store the connection type as a string but we use a constant binary value internally.
This parses the string from the database into the the constant binary value.

return connection_type constant (as defined in pf::config) or undef if connection type not found

=cut

sub str_to_connection_type {
    my ($conn_type_str) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');

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

=item get_total_system_memory

Returns the total amount of memory in kilobytes. Undef if something went wrong or it can't determined.

=cut

sub get_total_system_memory {
    my $logger = Log::Log4perl::get_logger('pf::util');


    my $result = open(my $meminfo_fh , '<', '/proc/meminfo');
    if (!defined($result)) {
        $logger->warn("Unable to open /proc/meminfo: $!");
        return;
    }

    my $total_mem; # in kilobytes
    while (<$meminfo_fh>) {

        if (m/^MemTotal:\s+(\d+) kB/) {
            $total_mem = $1;
            last;
        }
    }

    return $total_mem;
}

=item parse_mac_from_trap

snmptrapd sometimes converts an Hex-STRING into STRING if all of the values are valid "printable" ascii.

This method handles both technique and return the MAC address in a format PacketFence expects.

Must be combined with new regular expression that handles both formats: $SNMP::MAC_ADDRESS_FORMAT

=cut

sub parse_mac_from_trap {
    my ($to_parse) = @_;

    my $mac;
    if ($to_parse =~ /Hex-STRING:\ ([0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2}\ [0-9A-Z]{2})/) {
        $mac = lc($1);
        $mac =~ s/ /:/g;

    } elsif ($to_parse =~ /STRING:\ "(.+)"/s) {
        $mac = $1;
        $mac =~ s/\\"/"/g; # replaces \" with "
        $mac =~ s/\\\\/\\/g; # replaces \\ with \
        $mac = unpack("H*", $mac);
        $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g; # builds groups of two separ ated by :
    }

    return $mac;
}

=item get_abbr_time

Return the abbreviated time representation given a number of seconds.

ex:
  7200 will return '2h'
  70 will return '70s'

See pf::config::normalize_time

=cut

sub get_abbr_time {
    my $time = int shift;

    if ($time < 60) {
        return $time . 's';
    } elsif ($time < 3600 || $time % 3600 > 0) {
        return int($time/60) . 'm';
    } elsif ($time < 86400 || $time % 86400 > 0) {
        return int($time/3600) . 'h';
    } elsif ($time < 604800 || $time % 604800 > 0) {
        return int($time/86400) . 'D';
    } elsif ($time < 2592000 || $time % 2592000 > 0) { # 30 days
        return int($time/604800) . 'W';
    } elsif ($time < 31536000 || $time % 31536000 > 0) { # 365 days
        return int($time/2592000) . 'M';
    } else {
        return int($time/31536000) . 'Y';
    }
}

=item get_translatable_time

Returns a triplet with singular and plural english string representation plus integer of a time string
as defined in pf.conf.

ex: 7D will return ("day", "days", 7)

Returns undef on failure

=cut

sub get_translatable_time {
   my ($time) = @_;

   # grab time unit
   my ( $value, $unit ) = $time =~ /^(\d+)($TIME_MODIFIER_RE)$/i;

   unless ($unit) {
       $time = get_abbr_time($time);
       ( $value, $unit ) = $time =~ /^(\d+)($TIME_MODIFIER_RE)$/i;
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

=item get_vlan_from_int

Returns the VLAN id for a given interface

=cut

sub get_vlan_from_int {
    my ($eth) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');

    my $result = open(my $vlaninfo_fh , '<', "/proc/net/vlan/$eth");
    if (!defined($result)) {
        $logger->warn("Unable to open VLAN proc description for $eth: $!");
        return;
    }

    while (<$vlaninfo_fh>) {

        if (m/^$eth\s+VID:\s+(\d+)\s+/) {
            return $1;
        }
    }

    return;
}


sub log_of {
    my ($n,$base) = @_;
    return log($n)/log($base);
}

sub format_bytes {
    my ($n,@args) = @_;
    my @DEFAULT_UNITS = ("","KB", "MB", "GB", "TB", "PB");
    my $unit = 1024;
    my $i = 0;
    my $format = "%.2f";
    if($n >= $unit) {
        $i = int(log_of($n,$unit));
        $i = $#DEFAULT_UNITS if $i >= @DEFAULT_UNITS;
        $n /= $unit ** $i;
        $n = sprintf($format,$n);
    }
    return "$n $DEFAULT_UNITS[$i]";
}

=item pretty_bandwidth

Returns the proper bandwidth calculation along with the unit

=cut

sub pretty_bandwidth {
    my ($bytes) = @_;
    my @units = ("Bytes", "KB", "MB", "GB", "TB", "PB");
    my $x;

    for ($x=0; $bytes>=800 && $x<scalar(@units); $x++ ) {
        $bytes /= 1024;
    }
    my $rounded = sprintf("%.2f",$bytes);
    return "$rounded $units[$x]"
}

=item unpretty_bandwidth

Returns the bandwidth in bytes depending of the incombing unit

=cut

sub unpretty_bandwidth {
    my ($bw,$unit) = @_;

    # Check what units we have, and multiple by 1024 exponent something
    if ($unit eq 'PB') {
        return $bw * 1024**5;
    } elsif ($unit eq 'TB') {
        return $bw * 1024**4;
    } elsif ($unit eq 'GB') {
        return $bw * 1024**3;
    } elsif ($unit eq 'MB') {
        return $bw * 1024**2;
    } elsif ($unit eq 'KB') {
        return $bw * 1024;
    }

    # Not matching, We assume we have bytes then
    return $bw;
}

=item pf_run ( COMMAND, %OPTIONS )

Execute a system command but check the return status and log anything not normal.

Returns output in list or string based on context (like backticks does ``)
but returns undef on a failure. Non-zero exit codes are considered failures.

Does not enforce any security. Callers should take care of string sanitization.

Takes an optional hash that offers additional options. For now,
accepted_exit_status => arrayref allows the command to succeed and a proper
value being returned if the exit status is mentionned in the arrayref. For
example: accepted_exit_status => [ 1, 2, 3] will allow the process to exit
with code 1, 2 or 3 without reporting it as an error.

=cut

sub pf_run {
    my ($command, %options) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');

    local $OS_ERROR;
    # Using perl trickery to figure out what the caller expects so I can return him just that
    # this is to perfectly emulate the backtick operator behavior
    my (@result, $result);
    if (not defined wantarray) {
        # void context
        `$command`;
        return if ($CHILD_ERROR == 0);

    } elsif (wantarray) {
        # list context
        @result = `$command`;
        return @result if ($CHILD_ERROR == 0);

    } else {
        # scalar context
        $result = `$command`;
        return $result if ($CHILD_ERROR == 0);
    }
    # copying as soon as possible
    my $exception = $OS_ERROR;

    # slightly modified version of "perldoc -f system" error handling strategy
    my $caller = ( caller(1) )[3] || basename($0);
    $caller =~ s/^(pf::\w+|main):://;

    # died with an OS problem
    if ($CHILD_ERROR == -1) {
        $logger->warn("Problem trying to run command: $command called from $caller. OS Error: $exception");

    # died with a signal
    } elsif ($CHILD_ERROR & 127) {
        my $signal = ($CHILD_ERROR & 127);
        my $with_core = ($CHILD_ERROR & 128) ? 'with' : 'without';
        $logger->warn(
            "Problem trying to run command: $command called from $caller. "
            . "Child died with signal $signal $with_core coredump."
        );
    # Non-zero exit code received
    } else {
        my $exit_status = $CHILD_ERROR >> 8;
        # user specified that this error code is ok
        if (grep { $_ == $exit_status } @{$options{'accepted_exit_status'}}) {
            # we accept the result
            return if (not defined wantarray); # void context
            return @result if (wantarray); # list context
            return $result; # scalar context
        }
        $logger->warn(
            "Problem trying to run command: $command called from $caller. "
            . "Child exited with non-zero value $exit_status"
        );
    }
    return;
}

=item generate_id

This will generate and return a new id.
The id will be as follow: epochtime + 2 random numbers + last four characters of the mac address
The epoch will be used in database entries so we use the same to make sure it is the same.

=cut

sub generate_id {
    my ( $epoch, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("Generating a new ID with epoch $epoch and mac $mac");

    # Generate 2 random numbers
    # the number 100 is to permit a 2 digits random number
    my $random = int(rand(100));

    # Get the four last characters of the mac address
    $mac =~ s/\://g;
    $mac = substr($mac, -4);

    my $id = $epoch . $random . $mac;

    $logger->info("New ID generated: $id");

    return $id;
}

=item ordinal_suffix

=cut

sub ordinal_suffix {
    my ($num) = @_;
    if( 4 <= $num && $num <= 20 ) {
        return "${num}th";
    }
    my $last_digit = $num % 10;
    if ($last_digit == 1) {
        return "${num}st";
    }
    elsif ($last_digit == 2) {
        return "${num}nd";
    }
    elsif ($last_digit == 3) {
        return "${num}rd";
    }
    return "${num}th";
}

=item trim_path

=cut

sub trim_path {
    my ($path) = @_;
    my @parts = ();
    foreach my $part (File::Spec->splitdir($path)) {
        if ($part eq '..') {
            # Note that if there are no directory parts, this will effectively
            #         # swallow any excess ".." components.
             pop(@parts);
        }
        elsif ($part ne '.') {
            push(@parts, $part);
        }
    }
   return ((@parts == 0) ? '' : catdir(@parts));
}

=item pf_chown

=cut

sub pf_chown {
    my ($file) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam('pf')
        or die "pf not in passwd file";
    chown $uid, $gid, $file;
}

=item untaint_chain

=cut

sub untaint_chain {
    my ($chain) = @_;
    if ($chain =~ /^(.+)$/) {
        return $1;
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
