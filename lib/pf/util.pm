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
use POSIX::2008;
use Net::MAC::Vendor;
use File::Path qw(make_path remove_tree);
use POSIX qw(setuid setgid);
use File::Spec::Functions;
use File::Slurp qw(read_dir);
use List::MoreUtils qw(all any);
use Try::Tiny;
use pf::file_paths qw(
    $conf_dir
    $oui_file
    $oui_url
    $var_dir
    $html_dir
);
use NetAddr::IP;
use File::Temp;
use Encode qw(encode);
use MIME::Lite::TT;
use Digest::MD5;
use Time::HiRes qw(stat time);
use Fcntl qw(:DEFAULT);
use Net::Ping;
use Crypt::OpenSSL::X509;
use Date::Parse;
use pf::CHI;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        valid_date valid_ip valid_ips reverse_ip clean_ip
        clean_mac valid_mac mac2nb macoui2nb format_mac_for_acct format_mac_as_cisco
        ip2int int2ip sort_ip
        isenabled isdisabled isempty
        getlocalmac
        parse_template mysql_date oui_to_vendor mac2oid oid2mac
        get_total_system_memory
        parse_mac_from_trap
        get_vlan_from_int
        get_abbr_time
        pretty_bandwidth
        unpretty_bandwidth
        pf_run
        generate_id load_oui download_oui
        trim_path format_bytes log_of ordinal_suffix
        untaint_chain read_dir_recursive all_defined
        valid_mac_or_ip listify
        normalize_time
        search_hash
        is_prod_interface
        valid_ip_range
        cert_is_self_signed
        safe_file_update
        fix_file_permissions
        strip_username
        generate_session_id
        calc_page_count
        whowasi
        validate_argv
        touch_file
        pf_make_dir
        empty_dir
        is_in_list
        validate_date
        clean_locale 
        parse_api_action_spec
        pf_chown
        user_chown
        ping
        run_as_pf
        find_outgoing_interface
        strip_filename_from_exceptions
        expand_csv
        validate_unregdate
    );
}

# TODO pf::util shouldn't rely on pf::config as this prevent pf::config from
#      being able to use pf::util
use pf::constants;
use pf::constants::config;
use pf::constants::user;
#use pf::config;
use pf::log;
use Time::Piece;

=head1 SUBROUTINES

TODO: This list is incomplete.

=over

=cut

sub valid_date {
    my ($date) = @_;
    my $logger = get_logger();

    # kludgy but short
    if ( !defined $date || $date
        !~ /^\d{4}\-((0[1-9])|(1[0-2]))\-((0[1-9])|([12][0-9])|(3[0-1]))\s+(([01][0-9])|(2[0-3]))(:[0-5][0-9]){2}$/
        )
    {
        $logger->warn("invalid date " . ($date // "'undef'"));
        return (0);
    } else {
        return (1);
    }
}

our $VALID_IP_REGEX = qr/^(?:\d{1,3}\.){3}\d{1,3}$/;
our $VALID_IPS_REGEX = qr/^((?:\d{1,3}\.){3}\d{1,3},*)+?$/;
our $NON_VALID_IP_REGEX = qr/^(?:0\.){3}0$/;

sub valid_ip {
    my ($ip) = @_;
    my $logger = get_logger();
    if ( !$ip || $ip !~ $VALID_IP_REGEX || $ip =~ $NON_VALID_IP_REGEX) {
        my $caller = ( caller(1) )[3] || basename($0);
        $caller =~ s/^(pf::\w+|main):://;
        $logger->debug("invalid IP: $ip from $caller");
        return (0);
    } else {
        return (1);
    }
}

sub valid_ips {
    my ($ip) = @_;
    my $logger = get_logger();
    if ( !$ip || $ip !~ $VALID_IPS_REGEX) {
        my $caller = ( caller(1) )[3] || basename($0);
        $caller =~ s/^(pf::\w+|main):://;
        $logger->debug("invalid IPs: $ip from $caller");
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
    my $logger = get_logger();
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
    return "0" unless defined $mac;

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

    return "0";
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

our $VALID_MAC_REGEX = qr/^[0-9a-f:\.-]+$/i;
our $NON_VALID_MAC_REGEX = qr/^(00|ff)(:\g1){5}$/;
our $VALID_PF_MAC_REGEX = qr/^[0-9a-f]{2}(:[0-9a-f]{2}){5}$/;

sub valid_mac {
    my ($mac) = @_;
    return (0) unless defined $mac;
    my $logger = get_logger();
    if ( !defined($mac) ) {
        return(0);
    }
    if ( $mac !~ $VALID_MAC_REGEX) {
        $logger->debug("invalid MAC: $mac");
        return (0);
    }
    $mac = clean_mac($mac);
    if( !$mac || $mac =~ $NON_VALID_MAC_REGEX || $mac !~ $VALID_PF_MAC_REGEX) {
        $logger->debug("invalid MAC: " . ($mac?$mac:"empty"));
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




=item  oid2mac - convert a MAC in oid format to a MAC in usual format

in: 6 dot-separated digits (ex: 0.18.240.19.50.186)

out: comma-separated MAC address (ex: 00:12:f0:13:32:ba)

=cut

sub oid2mac {
    my ($oid) = @_;
    my $logger = get_logger();
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
    my $logger = get_logger();
    if ($mac =~ /^([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2}):([0-9a-f]{2})$/i) {
        return hex($1).".".hex($2).".".hex($3).".".hex($4).".".hex($5).".".hex($6);
    } else {
        $logger->warn("$mac is not a valid MAC");
        return;
    }
}

=item  isenabled

Is the given configuration parameter considered enabled? y, yes, true, enable
and enabled are all positive values for PacketFence.

=cut

sub isenabled {
    my ($enabled) = @_;
    if ( $enabled && $enabled =~ /^\s*(y|yes|true|enable|enabled|1)\s*$/i ) {
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
    if ( !defined ($disabled) || $disabled =~ /^\s*(n|no|false|disable|disabled|0)\s*$/i ) {
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

sub getlocalmac {
    my ($dev) = @_;
    return (-1) if ( !$dev );
    my $chi = pf::CHI->new(namespace => 'local_mac');
    my $mac = $chi->compute($dev, sub {
        foreach (`LC_ALL=C /sbin/ifconfig -a $dev`) {
            if (/ether\s+(\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)/i) {
                # cache the value
                return clean_mac($1);
            }
        }
        return (0);
    });
    return $mac;
}

sub ip2int {
    return ( unpack( "N", pack( "C4", split( /\./, shift ) ) ) );
}

sub int2ip {
    return ( join( ".", unpack( "C4", pack( "N", shift ) ) ) );
}

=item sort_ip

Sorts an array of IP addresses

=cut

sub sort_ip {
    return
        map { $_->[0] }
        sort { $a->[1] <=> $b->[1] }
        map { [$_,ip2int($_)] } @_;
}

=item safe_file_update($file, $content)

This safely modifies the contents of a file using a rename

=cut

sub safe_file_update {
    my ($file, $contents) = @_;
    my ($volume, $dir, $filename) = File::Spec->splitpath($file);
    $dir = '.' if $dir eq '';
    # Creates a new file in the same directory to ensure it is on the same filesystem
    pf_make_dir($dir);
    my $temp = File::Temp->new(DIR => $dir) or die "cannot create temp file in $dir";
    syswrite $temp, $contents;
    $temp->flush;
    close $temp;
    unless( rename ($temp->filename, $file) ) {
        my $logger = pf::log::get_logger();
        $logger->error("cannot save contents to $file '$!'");
        die "cannot save contents to $file";
    }
    $temp->unlink_on_destroy(0);
    fix_file_permissions($file);
}

=item empty_dir

Empty the contents of a directory

=cut

sub empty_dir {
    my ($dir) = @_;
    remove_tree( $dir, {keep_root => 1, result => \my $list} );
    return $list;
}

=item fix_file_permissions(@files)

fix the file permissions of the files

=cut

sub fix_file_permissions {
    my ($file) = @_;
    pf_run('sudo /usr/local/pf/bin/pfcmd fixpermissions file "' . $file . '"');
}

=item fix_files_permissions

Fix the files permissions

=cut

sub fix_files_permissions {
    pf_run('sudo /usr/local/pf/bin/pfcmd fixpermissions');
}

sub parse_template {
    my ( $tags, $template, $destination, $comment_char ) = @_;
    my $logger = get_logger();
    my (@parsed);
    my $template_fh;
    open( $template_fh, '<', $template ) || $logger->logcroak("Unable to open template $template: $!");
    while (<$template_fh>) {
        study $_;
        foreach my $tag ( keys %{$tags} ) {
#            use Data::Dumper;
#            print Dumper($tag, $tags->{$tag});
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
        if ($destination =~ /(.*)\/\w+/) {
            mkdir $1 unless -d $1;
            pf_chown($1);
        }
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
        my $logger = get_logger();
        $logger->info("loading Net::MAC::Vendor cache from $oui_file");
        Net::MAC::Vendor::load_cache("file://$oui_file");
    }
}

sub download_oui {
    my $logger = get_logger();
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

=item get_total_system_memory

Returns the total amount of memory in kilobytes. Undef if something went wrong or it can't determined.

=cut

sub get_total_system_memory {
    my $logger = get_logger();


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

=item get_vlan_from_int

Returns the VLAN id for a given interface

=cut

sub get_vlan_from_int {
    my ($eth) = @_;
    my $logger = get_logger();

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
    my ($n, $base) = @_;
    return log($n)/log($base);
}

sub format_bytes {
    my ($n, @args) = @_;
    my @DEFAULT_UNITS = ("bytes","KB", "MB", "GB", "TB", "PB");
    my $unit = 1024;
    my $i = 0;
    my $format = "%.2f";
    return undef unless ($n);
    if ($n >= $unit) {
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

    for ($x=0; $bytes>=800 && $x < scalar(@units); $x++ ) {
        $bytes /= 1024;
    }
    my $rounded = sprintf("%.2f",$bytes);
    return "$rounded $units[$x]"
}

=item unpretty_bandwidth

Returns the bandwidth in bytes depending of the incombing unit

=cut


sub unpretty_bandwidth {
    my (@bw) = @_;
    return undef if (!defined($bw[0]));
    my ($bw,$unit);

    if (!defined($bw[1])) {
        if ($bw[0] =~ /(\d+)(\w+)/) {
            $bw = $1;
            $unit = $2;
        }
    } else {
        $bw = $bw[0];
        $unit = $bw[1];
    }
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
    my $logger = get_logger();

    # Prefixing command using LANG=C to avoid system locale messing up with return
    $command = 'LANG=C ' . $command;

    local $!;
    # Using perl trickery to figure out what the caller expects so I can return him just that
    # this is to perfectly emulate the backtick operator behavior
    my (@result, $result);
    $command = untaint_chain($command);
    if (not defined wantarray) {
        # void context
        `$command`;
        return if ($? == 0);

    } elsif (wantarray) {
        # list context
        @result = `$command`;
        return @result if ($? == 0);

    } else {
        # scalar context
        $result = `$command`;
        return $result if ($? == 0);
    }
    # copying as soon as possible
    my $exception = $!;

    # slightly modified version of "perldoc -f system" error handling strategy
    my $caller = ( caller(1) )[3] || basename($0);
    $caller =~ s/^(pf::\w+|main):://;

    my $loggable_command = $command;
    if(defined($options{log_strip})){
        $loggable_command =~ s/$options{log_strip}/*obfuscated-information*/g;
    }
    # died with an OS problem
    if ($? == -1) {
        $logger->warn("Problem trying to run command: $loggable_command called from $caller. OS Error: $exception");

    # died with a signal
    } elsif ($? & 127) {
        my $signal = ($? & 127);
        my $with_core = ($? & 128) ? 'with' : 'without';
        $logger->warn(
            "Problem trying to run command: $loggable_command called from $caller. "
            . "Child died with signal $signal $with_core coredump."
        );
    # Non-zero exit code received
    } else {
        my $exit_status = $? >> 8;
        # user specified that this error code is ok
        if (grep { $_ == $exit_status } @{$options{'accepted_exit_status'}}) {
            # we accept the result
            return if (not defined wantarray); # void context
            return @result if (wantarray); # list context
            return $result; # scalar context
        }
        $logger->warn(
            "Problem trying to run command: $loggable_command called from $caller. "
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
    my $logger = get_logger();

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


=item expand_csv

Expands a comma seperated string or an array of comma seperated strings into an array

=cut

sub expand_csv {
    my ($list) = @_;
    $list //= [];
    my @expanded;
    if (ref $list eq 'ARRAY') {
        @expanded = @$list;
    } else {
        @expanded = $list;
    }
    return map {split(/\s*,\s*/, $_)} @expanded;
}


=item pf_chown

=cut

sub pf_chown {
    my ($file) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam('pf')
        or die "pf not in passwd file";
    chown $uid, $gid, $file;
}

=item user_chown

=cut

sub user_chown {
    my ($user, $file) = @_;
    my ($login,$pass,$uid,$gid) = getpwnam($user)
        or die "$user not in passwd file";
    chown $uid, $gid, $file;
}

=item untaint_chain

=cut

sub untaint_chain {
    my ($chain) = @_;
    if (defined $chain && $chain =~ /^(.+)$/) {
        return $1;
    }
    return undef;
}

sub valid_mac_or_ip {
    my ($mac_or_ip) = @_;
    return 1 if($mac_or_ip =~ $VALID_IP_REGEX && $mac_or_ip !~ $NON_VALID_IP_REGEX) ;
    if ($mac_or_ip !~ $NON_VALID_IP_REGEX && $mac_or_ip =~ $VALID_MAC_REGEX) {
        my ($mac) = clean_mac($mac_or_ip);
        return 1 if($mac && $mac !~ $NON_VALID_MAC_REGEX && $mac =~ $VALID_PF_MAC_REGEX);
    }
    get_logger()->debug("invalid MAC or IP: $mac_or_ip");
    return 0;
}

=item valid_ip_range

Test if it's an ip and it's range of ip address

=cut

sub valid_ip_range {
    my ($ip) =@_;
    return 1 if (defined(NetAddr::IP->new($ip)));
}

=item read_dir_recursive

 Reads all the files in a directory recusivley

=cut

sub read_dir_recursive {
    my ($root_path) = @_;
    my @files;
    foreach my $entry (read_dir($root_path)) {
        my $full_path = catfile($root_path, $entry);
        if (-d $full_path) {
            push @files, map {catfile($entry, $_) } _readDirRecursive($full_path);
        }
        elsif ($entry !~ m/^\./) {
            push @files, $entry;
        }
    }
    return @files;
}

sub all_defined {
    all { defined $_ } @_;
}

=item listify

Will change a scalar to an array ref if it is not one already

=cut

sub listify {
    ref($_[0]) eq 'ARRAY' ? $_[0] : [$_[0]]
}

=item normalize_time - formats date

Returns the number of seconds represented by the time period.

Months and years are approximate. Do not use for anything serious about time.

=cut

sub normalize_time {
    my ($date) = @_;
    return undef if (!defined($date));
    if ( $date =~ /^\d+$/ ) {
        return ($date);

    } else {
        my ( $num, $modifier ) = $date =~ /^(\d+)($pf::constants::config::TIME_MODIFIER_RE)/ or return (0);

        if ( $modifier eq "s" ) { return ($num * 1);
        } elsif ( $modifier eq "m" ) { return ( $num * 60 );
        } elsif ( $modifier eq "h" ) { return ( $num * 60 * 60 );
        } elsif ( $modifier eq "D" ) { return ( $num * 24 * 60 * 60 );
        } elsif ( $modifier eq "W" ) { return ( $num * 7 * 24 * 60 * 60 );
        } elsif ( $modifier eq "M" ) { return ( $num * 30 * 24 * 60 * 60 );
        } elsif ( $modifier eq "Y" ) { return ( $num * 365 * 24 * 60 * 60 );
        }
    }
}

=item search_hash

Used to search for an element in a hash that has a specific value in one of it's field

Ex :
my %h = {
  'test' => {'result' => '2'},
  'test2' => {'result' => 'success'}
}

Searching for field result with value 'success' would return the value of test2

{'result' => 'success'} == search_hash(\%h, 'result', 'success');

=cut

sub search_hash {
    my ($h, $field, $value) = @_;
    return grep { exists $_->{$field} && defined $_->{$field} && $_->{$field} eq $value  } values %{$h};
}

=item is_prod_interface

return true if the interface is a management interface

=cut

sub is_prod_interface {
    my ($int) = @_;
    if ($int =~ /management|^dhcp-?listener$|managed/i) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=item cert_is_self_signed

Check if a certicate is self-signed

=cut

sub cert_is_self_signed {
    my ($path) = @_;
    my $cert = Crypt::OpenSSL::X509->new_from_file($path);
    my $self_signed = $cert->is_selfsigned;
    return $self_signed;
}

=item cert_expires_in

Returns either true or false if the given certificate is about to expire in a given delay

Use current time if no delay is given

=cut

sub cert_expires_in {
    my ($path, $delay) = @_;
    return undef if !defined $path;
    my $cert = Crypt::OpenSSL::X509->new_from_file($path);
    my $expiration = str2time($cert->notAfter);

    $delay = normalize_time($delay) if $delay;
    $delay = ( $delay ) ? $delay + time : time;

    return $delay > $expiration;
}

=item strip_username

Will strip a username matching pattern user@realm or \\realm\user

Returns ($user,$realm) if found or ($user) if not matching any realm pattern

=cut

sub strip_username {
    my ($username) = @_;
    return $username unless(defined($username));

    # user@domain
    if($username =~ /(.*)\@(.*)/){
        return ($1,$2);
    }
    # user%domain
    elsif($username =~ /(.*)\%(.*)/){
        return ($1,$2);
    }
    # \\domain\user
    elsif($username =~ /\\\\(.*)\\(.*)/) {
        return ($2,$1);
    }
    # domain\\user
    elsif($username =~ /(.*)\\\\(.*)/) {
        return ($2,$1);
    }
    # domain\user
    elsif($username =~ /(.*)\\(.*)/) {
        return ($2,$1);
    }
    return $username;
}

sub generate_session_id {
    my ($length) = @_;
    $length //= 32;
    return substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0, $length);
}

=item $pageCount = calc_page_count($count, $perPage)

Calculates the number of pages

=cut

sub calc_page_count {
    my ($count, $perPage) = @_;
    $count //= 0;
    $perPage //= 25;
    return int( ($count + $perPage  - 1) / $perPage );
}

=item whowasi

Return the parent function name

=cut

sub whowasi { ( caller(2) )[3] }

=item validate_argv

Test if the required arguments are provided

=cut

sub validate_argv {
    my ($require, $found) = @_;
    my $logger = pf::log::get_logger();

    if (!(@{$require} == @{$found})) {
        my %diff;
        @diff{ @{$require} } = @{$require};
        delete @diff{ @{$found} };
        $logger->error("Missing argument ". join(',',keys %diff) ." for the function ".whowasi());
        return 0;
    }
    return 1;
}

=item touch_file

Change the timestamp of a file based off the current from Time::HiRes

=cut

sub touch_file {
    my ( $filename) = @_;

    if (sysopen(my $fh,$filename,O_RDWR | O_CREAT)) {
        my ($seconds, $microseconds) = Time::HiRes::gettimeofday();
        POSIX::2008::futimens(fileno $fh, $seconds, $microseconds * 1000,$seconds, $microseconds * 1000);
        chown( $pf::constants::user::PF_UID, $pf::constants::user::PF_GID, $fh );
        close($fh);
    }
    else {
        get_logger->error("Can't create/open $filename\nPlease run 'pfcmd fixpermissions'");
    }
}

=item pf_make_dir

Make a directory with the proper permissions

=cut

sub pf_make_dir {
    my ($dir_path) = @_;
    umask 0;
    return make_path(
        $dir_path,
        {
            user => $pf::constants::user::PF_UID,
            group => $pf::constants::user::PF_GID,
            mode => 02775,
        }
    );
}

=item is_in_list

Searches for an item in a comma separated list of elements (like we do in our configuration files).

Returns true or false values based on if item was found or not.

=cut

sub is_in_list {
    my ($item, $list) = @_;
    my @list = (ref($list) eq 'ARRAY') ? @$list : split( /\s*,\s*/, $list );
    return $TRUE if any { $_ eq $item } @list;
    return $FALSE;
}

=item validate_date

Check if a date is between 1970-01-01 and 2038-01-18

=cut

sub validate_date {
    my ($date) = @_;
    my $valid = $FALSE;

    eval {
        my $t = Time::Piece->strptime($date, "%Y-%m-%d");
        if (
            $t->year > 2038
            || $t->year == 2038 && $t->mon > 1
            || $t->year == 2038 && $t->mon == 1 && $t->mday > 18
            || $t->year < 1970
           ) {
            $valid = $FALSE;
        }
        else {
            $valid = $TRUE;
        }
    };
    if ($@) {
        $valid = $FALSE;
    }

    return $valid;
}

=item validate_unregdate

Check if a date is between 1970-01-01 and 2038-01-18 or 0000-MM-DD

=cut

sub validate_unregdate {
    my ($date) = @_;
    my $valid = $FALSE;
    if ($date !~ /^0-(\d\d-\d\d)/) {
        return validate_date($date);
    }

    if (eval { Time::Piece->strptime($1, "%m-%d") } ) {
        $valid =  $TRUE;
    }

    return $valid;
}


=item clean_locale

Clean the format of the locale stored

=cut

sub clean_locale {
    my ($locale) = @_;
    if( $locale =~ /^([A-Za-z_]+)\./ ) {
        $locale = $1;
    }
    return $locale;
}

=item parse_api_action_spec

Parse an api action spec

=cut

sub parse_api_action_spec {
    my ($spec) = @_;
    unless ($spec =~ /^\s*(?<api_method>[a-zA-Z0-9_]+)\s*:\s*(?<api_parameters>.*)$/) {
        return undef;
    }
    #return a copy of the named captures hash
    return {%+};
}

sub ping {
    my ($host) = @_;
    my $p = Net::Ping->new("icmp");
    return $p->ping($host);
}

=head2 run_as_pf

Sets the UID and GID of the currently running process to pf

=cut

sub run_as_pf {
    my (undef, undef,$uid,$gid) = getpwnam('pf');
    
    # Early return if we're already running as pf
    return $TRUE if($uid == $<);

    unless(setgid($gid)) {
        my $msg = "Cannot switch process user to pf. setgid to $gid has failed";
        print STDERR $msg . "\n";
        get_logger->error($msg);
        return $FALSE;
    }
    
    unless(setuid($uid)) {
        my $msg = "Cannot switch process user to pf. setuid to $uid has failed";
        print STDERR $msg . "\n";
        get_logger->error($msg);
        return $FALSE;
    }

    return $TRUE;
}

=head2 find_outgoing_interface

Find the outgoing interface from a specific incoming interface

=cut

sub find_outgoing_interface {
    my ($gateway, $dev) = @_;
    my @interface_src;

    if (defined $dev) {
        @interface_src = split(" ", pf_run("sudo ip route get 8.8.8.8 from $gateway iif $dev"));
    } else {
        @interface_src = split(" ", pf_run("sudo ip route get 8.8.8.8 from $gateway"));
    }

    if ($interface_src[3] eq 'via') {
        return $interface_src[6];
    } else {
        return $interface_src[2];
    }
}

=head2 strip_filename_from_exceptions

Strip out filename from exception messages

=cut

sub strip_filename_from_exceptions {
    my ($exception) = @_;
    if (defined $exception) {
        $exception =~ s/^(.*) at .*?$/$1/;
    }
    return $exception;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
