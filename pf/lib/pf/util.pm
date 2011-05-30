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
use File::Basename;
use FileHandle;
use POSIX();
use Net::SMTP;
use Net::MAC::Vendor;
use Log::Log4perl;
# TODO these look like they are not required.. get rid of them?
use threads;
use threads::shared;

our ( %trappable_ip, %reggable_ip, %is_internal, %local_mac );

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        valid_date valid_ip clean_mac acct_mac valid_mac get_decimal_oui_from_mac whitelisted_mac trappable_mac 
        trappable_ip reggable_ip
        inrange_ip ip2gateway ip2interface ip2device isinternal pfmailer isenabled
        isdisabled getlocalmac ip2int int2ip 
        get_all_internal_ips get_internal_nets get_routed_isolation_nets get_routed_registration_nets get_internal_ips
        get_internal_devs get_internal_devs_phy get_external_devs get_managed_devs get_internal_macs
        get_internal_info get_gateways get_dhcp_devs createpid readpid deletepid
        pfmon_preload parse_template mysql_date oui_to_vendor mac2oid oid2mac 
        str_to_connection_type connection_type_to_str
        get_total_system_memory
    );
}

use pf::config;

=head1 SUBROUTINES

TODO: This list is incomplete.

=over

=cut

sub pfmon_preload {
    # we don't preload (cache) except in arp mode. 
    # This is a hack for bug #861 because on large networks (like 10.0.0.0/8) pfmon runs out of memory preloading
    # TODO: it should be implemented more efficiently (b-tree?) or simplify removed if pfmon doesn't need it that much
    if (basename($0) eq "pfmon" && isenabled($Config{'general'}{'caching'}) && $Config{'network'}{'mode'} =~ /^arp$/i) {
        %trappable_ip = preload_trappable_ip();
        %reggable_ip  = preload_reggable_ip();
        %is_internal  = preload_is_internal();
        %local_mac    = preload_getlocalmac();
    }
}

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

=item clean_mac 

Clean a MAC address accepting xx-xx-xx-xx-xx-xx, xx:xx:xx:xx:xx:xx, xxxx-xxxx-xxxx and xxxx.xxxx.xxxx.

Returns a string with MAC in format: xx:xx:xx:xx:xx:xx

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
    return ($mac);
}

=item acct_mac

Put the mac address in the accounting format, accepting xx:xx:xx:xx:xx

Returning format xx-xx-xx-xx-xx-xx

=cut
sub acct_mac {
    my ($mac) = @_;
    return (0) if ( !$mac );
    # trim garbage
    $mac =~ s/[\s\-\.:]//g;
    # lowercase
    $mac = lc($mac);
    # inject :
    $mac =~ s/([a-f0-9]{2})(?!$)/$1-/g if ( $mac =~ /^[a-f0-9]{12}$/i );
    return ($mac);
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

=item * get_decimal_oui_from_mac

Extract the OUI (Organizational Unique Identifier) from a MAC address then
converts it into a decimal value. To be used to generate mac address violations.

in: mac address (xx:xx:xx:xx:xx)

out: an int

=cut

sub get_decimal_oui_from_mac {
    my ($mac) = @_;

    return (0) if ( !valid_mac($mac) );
    $mac = clean_mac($mac);

    my $oui = substr($mac, 0, 8);
    $oui =~ s/://g;
    return hex($oui);
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

    if (  !valid_mac($mac)
        || grep( { $_ eq $mac } get_internal_macs() )
        || $mac eq $blackholemac )
    {
        $logger->info("$mac is not trappable, skipping");
        return (0);
    } else {
        return (1);
    }
}

sub trappable_ip {
    my ($ip) = @_;
    return (0) if ( !$ip || !valid_ip($ip) );
    return ( $trappable_ip{$ip} ) if ( defined( $trappable_ip{$ip} ) );
    return inrange_ip( $ip, $Config{'trapping'}{'range'} );
}

sub reggable_ip {
    my ($ip) = @_;
    return (0) if ( !$ip || !valid_ip($ip) );
    return (1)
        if ( !defined $Config{'registration'}{'range'}
        || !$Config{'registration'}{'range'} );
    return ( $reggable_ip{$ip} ) if ( defined( $reggable_ip{$ip} ) );
    return inrange_ip( $ip, $Config{'registration'}{'range'} );
}

sub inrange_ip {
    my ( $ip, $network_range ) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');

    if ( grep( { $_ eq $ip } get_gateways() ) ) {
        $logger->info("$ip is a gateway, skipping");
        return (0);
    }
    if ( grep( { $_ eq $ip } get_internal_ips() ) ) {
        $logger->info("$ip is a local int, skipping");
        return (0);
    }

    foreach my $range ( split( /\s*,\s*/, $network_range ) ) {
        if ( $range =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) {
            my $block = new Net::Netmask($range);
            if ( $block->size() > 2 ) {
                return (1)
                    if ( $block->match($ip)
                    && $block->nth(0)  ne $ip
                    && $block->nth(-1) ne $ip );
            } else {
                return (1) if ( $block->match($ip) );
            }

#return(1) if ($block->match($ip) && $block->nth(0) ne $ip && $block->nth(-1) ne $ip);
        } elsif ( $range
            =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})-(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
            )
        {

            my $int_ip = ip2int($ip);
            my $start  = $1;
            my $end    = $2;

            if ( !valid_ip($start) || !valid_ip($end) ) {
                $logger->error("$range not valid range!");
            } else {
                my $int_start = ip2int($start);
                my $int_end   = ip2int($end);
                return (1)
                    if ( $int_ip >= $int_start && $int_ip <= $int_end );
            }
        } elsif (
            $range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})-(\d{1,3})$/ )
        {

            my $int_ip = ip2int($ip);
            my $net    = $1;
            my $start  = $2;
            my $end    = $3;

            if (   !valid_ip( $net . "." . $start )
                || $end < $start
                || $end > 255 )
            {
                $logger->error("$range not valid range!");
            } else {
                my $int_start = ip2int( $net . "." . $start );
                my $int_end   = ip2int( $net . "." . $end );
                return (1)
                    if ( $int_ip >= $int_start && $int_ip <= $int_end );
            }
        } elsif ( $range =~ /^(?:\d{1,3}\.){3}\d{1,3}$/ ) {
            return (1) if ( $range =~ /^$ip$/ );
        } else {
            $logger->error("$range not valid!");
            next;
        }
    }
    $logger->debug("$ip is not in $network_range, skipping");
    return (0);
}

sub ip2gateway {
    my ($ip) = @_;
    return (0) if ( !valid_ip($ip) );
    foreach my $interface (@internal_nets) {
        if ( $interface->match($ip) ) {
            return ( $interface->tag("gw") );
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

sub isinternal {
    my ($ip) = @_;
    return (0) if ( !valid_ip($ip) );
    return ( $is_internal{$ip} ) if ( defined( $is_internal{$ip} ) );
    foreach my $interface (@internal_nets) {
        if ( $interface->match($ip) ) {
            return (1);
        }
    }
    return (0);
}

=item * oid2mac - convert a MAC in oid format to a MAC in usual format 

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

=item * mac2oid - convert a MAC in usual pf format into a MAC in oid format

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

sub isenabled {
    my ($enabled) = @_;
    if ( $enabled =~ /^\s*(y|yes|true|enable|enabled)\s*$/i ) {
        return (1);
    } else {
        return (0);
    }
}

sub isdisabled {
    my ($disabled) = @_;
    if ( $disabled =~ /^\s*(n|no|false|disable|disabled)\s*$/i ) {
        return (1);
    } else {
        return (0);
    }
}

sub getlocalmac {
    my ($dev) = @_;
    return (-1) if ( !$dev );
    return ( $local_mac{$dev} ) if ( defined $local_mac{$dev} );
    foreach (`LC_ALL=C /sbin/ifconfig -a`) {
        return ( clean_mac($1) )
            if (/^$dev.+HWaddr\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/i);
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

sub get_internal_ips {
    my @ips;
    foreach my $internal (@internal_nets) {
        push @ips, $internal->tag("ip");
    }
    return (@ips);
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

sub get_managed_devs {
    my @devs;
    foreach my $interface (@managed_nets) {
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

sub get_gateways {
    my @gateways;
    foreach my $interface (@internal_nets) {
        push @gateways, $interface->tag("gw");
    }
    return (@gateways);
}

sub get_dhcp_devs {
    my %dhcp_devices;
    foreach my $dhcp ( tied(%Config)->GroupMembers("dhcp") ) {
        if ( defined( $Config{$dhcp}{'device'} ) ) {
            foreach my $dev ( split( /\s*,\s*/, $Config{$dhcp}{'device'} ) ) {
                $dhcp_devices{$dev}++;
            }
        }
    }
    return ( keys(%dhcp_devices) );
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

    #close(TEMPLATE);
    if ($destination) {
        my $destination_fh;
        open( $destination_fh, ">", $destination )
            || $logger->logcroak( "Unable to open template destination $destination: $!");

        foreach my $line (@parsed) {
            print {$destination_fh} $line;
        }

        #close(DESTINATION);
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
    my $logger = Log::Log4perl::get_logger('pf::util');
    if ( scalar( keys( %${Net::MAC::Vendor::Cached} ) ) == 0 ) {
        $logger->debug("loading Net::MAC::Vendor cache from $oui_file");
        Net::MAC::Vendor::load_cache("file://$oui_file");
    }
    my $oui_info = Net::MAC::Vendor::lookup($mac);
    return $$oui_info[0] || '';
}

sub preload_getlocalmac {
    my $logger = Log::Log4perl::get_logger('pf::util');
    $logger->info("preloading local mac addresses");
    my %hash;
    my @iflist = `LC_ALL=C /sbin/ifconfig -a`;
    foreach my $dev ( get_internal_devs() ) {
        my @line = grep(
            {/^$dev .+HWaddr\s+\w\w:\w\w:\w\w:\w\w:\w\w:\w\w/} @iflist );
        $line[0] =~ /^$dev .+HWaddr\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/;
        $hash{$dev} = clean_mac($1);
    }
    return (%hash);
}

sub preload_trappable_ip {
    my $logger = Log::Log4perl::get_logger('pf::util');
    $logger->info("preloading trappable_ip hash");
    return ( preload_network_range( $Config{'trapping'}{'range'} ) );
}

sub preload_reggable_ip {
    my $logger = Log::Log4perl::get_logger('pf::util');
    $logger->info("preloading reggable_ip hash");
    return ( preload_network_range( $Config{'registration'}{'range'} ) );
}

# Generic Preloading Network Range Function
#
sub preload_network_range {
    my ($network_range) = @_;
    my $logger = Log::Log4perl::get_logger('pf::util');
    my $caller = ( caller(1) )[3] || basename($0);
    $caller =~ s/^pf::\w+:://;

    #print "caller: network range = $network_range\n";
    my %cache_ip;

    foreach my $gateway ( get_gateways() ) {
        $cache_ip{$gateway} = 0;
    }
    foreach my $intip ( get_internal_ips() ) {
        $cache_ip{$intip} = 0;
    }
    foreach my $range ( split( /\s*,\s*/, $network_range ) ) {
        if ( $range =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2}$/ ) {
            my $block = new Net::Netmask($range);
            if ( $block->size() > 2 ) {
                $cache_ip{ $block->nth(0) }  = 0;
                $cache_ip{ $block->nth(-1) } = 0;
            }
            foreach my $ip ( $block->enumerate() ) {
                $cache_ip{$ip} = 1 if ( !defined( $cache_ip{$ip} ) );
            }
        } elsif ( $range
            =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})-(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
            )
        {
            my $start = $1;
            my $end   = $2;
            if ( !valid_ip($start) || !valid_ip($end) ) {
                $logger->error("$range not valid range!");
            } else {
                for ( my $i = ip2int($start); $i <= ip2int($end); $i++ ) {
                    $cache_ip{ int2ip($i) } = 1;
                }
            }
        } elsif (
            $range =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3})\.(\d{1,3})-(\d{1,3})$/ )
        {
            my $net   = $1;
            my $start = $2;
            my $end   = $3;
            if (   !valid_ip( $net . "." . $start )
                || $end < $start
                || $end > 255 )
            {
                $logger->error("$range not valid range!");
            } else {
                for ( my $i = $start; $i <= $end; $i++ ) {
                    my $ip = $net . "." . $i;
                    $cache_ip{$ip} = 1 if ( !defined( $cache_ip{$ip} ) );
                }
            }
        } elsif ( $range =~ /^(?:\d{1,3}\.){3}\d{1,3}$/ ) {
            $cache_ip{$range} = 1;
        } else {
            $logger->error("$range not valid!");
        }
    }
    $logger->info( scalar( keys(%cache_ip) ) . " cache_ip entries cached" );
    return (%cache_ip);
}

sub preload_is_internal {
    my $logger = Log::Log4perl::get_logger('pf::util');
    my %is_internal;
    $logger->info("preloading is_internal hash");
    foreach my $interface (@internal_nets) {
        foreach my $ip ( $interface->enumerate() ) {
            $is_internal{$ip} = 1;
        }
    }
    $logger->info(
        scalar( keys(%is_internal) ) . " is_internal entries cached" );
    return (%is_internal);
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
        return UNKNOWN;

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

=back

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2009-2011 Inverse inc.

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
