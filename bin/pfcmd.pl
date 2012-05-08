#!/usr/bin/perl -T

=head1 NAME

pfcmd - PacketFence command line interface

=head1 SYNOPSIS

pfcmd <command> [options]

 Command:
 checkup                     | perform a sanity checkup and report any problems
 class                       | view violation classes
 config                      | query, set, or get help on pf.conf configuration paramaters
 configfiles                 | push or pull configfiles into/from database
 floatingnetworkdeviceconfig | query/modify floating network devices configuration parameters
 fingerprint                 | view DHCP Fingerprints
 graph                       | trending graphs
 history                     | IP/MAC history
 ifoctetshistorymac          | accounting history
 ifoctetshistoryswitch       | accounting history
 ifoctetshistoryuser         | accounting history
 import                      | bulk import of information into the database
 interfaceconfig             | query/modify interface configuration parameters
 ipmachistory                | IP/MAC history
 locationhistorymac          | Switch/Port history
 locationhistoryswitch       | Switch/Port history
 lookup                      | node or pid lookup against local data store
 manage                      | manage node entries
 networkconfig               | query/modify network configuration parameters
 node                        | node manipulation
 nodeaccounting              | RADIUS Accounting Information
 nodecategory                | nodecategory manipulation
 nodeuseragent               | View User-Agent information associated to a node
 person                      | person manipulation
 reload                      | rebuild fingerprint or violations tables without restart
 report                      | current usage reports
 schedule                    | Nessus scan scheduling
 service                     | start/stop/restart and get PF daemon status
 switchconfig                | query/modify switches.conf configuration parameters
 switchlocation              | view switchport description and location
 traplog                     | update traplog RRD files and graphs or obtain
 switch IPs
 trigger                     | view and throw triggers
 ui                          | used by web UI to create menu hierarchies and dashboard
 update                      | download canonical fingerprint or OUI data
 useragent                   | view User-Agent fingerprint information
 version                     | output version information
 violation                   | violation manipulation
 violationconfig             | query/modify violations.conf configuration parameters

=cut

use strict;
use warnings;

# force UID/EUID to root to allow socket binds, etc
# required for non-root (and GUI) service restarts to work
$> = 0;
$< = 0;

use Data::Dumper;
use English qw( -no_match_vars ) ;  # Avoids regex performance penalty
use POSIX();
use Readonly;
use Date::Parse;
use File::Basename qw(basename);
use Log::Log4perl;
use Try::Tiny;

use constant INSTALL_DIR => '/usr/local/pf';

use lib INSTALL_DIR . "/lib";

use pf::config;
use pf::config::ui;
use pf::enforcement;
use pf::pfcmd;
use pf::util;

# Perl taint mode setup (see: perlsec)
delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} = "/bin:/sbin:/usr/bin:/usr/sbin";

# Uncomment the following line to enable tracing in the grammar
# Warning: doing so will break the web admin
# TODO: this parameter should be exposed to the CLI
#our $RD_TRACE = 1;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger( basename($0) );
Log::Log4perl::MDC->put( 'proc', basename($0) );
Log::Log4perl::MDC->put( 'tid',  $PROCESS_ID );

Readonly my $delimiter => '|';
use vars qw/%cmd $grammar/;
my $command;

my $count  = $ENV{PER_PAGE};
my $offset = $ENV{PAGE_NUM};

@ARGV = ( $ENV{ARGS} ) if ( $ENV{ARGS} );

if ( $offset && $offset > 0 ) {
    $offset = $offset - 1;
    $offset = $offset * $count;
}

my %defaults;
my %myconfig;
my %documentation;

if ( defined $ENV{GATEWAY_INTERFACE} ) {
    require CGI;
    import CGI qw(-no_debug :standard);
    my $q = new CGI;
    if ( $q->param('ARGS') ) {
        @ARGV = $q->param("ARGS");
        print $q->header;
    } elsif ( scalar(@ARGV) == 0 ) {
        print 'ERROR in parameters';
        return (0);
    }
}

# generate pre-compiled grammar
#Parse::RecDescent->Precompile($grammar, "pfcmd_pregrammar");
#exit 1;

# dynamic grammar parsing (slow)
#my $parser=Parse::RecDescent->new($grammar);

# FIXME: all of this is confusing duplication, we need to get rid of one of both method to call a sub
my %cmd_tmp = pf::pfcmd::parseCommandLine( join(' ', @ARGV) );
if (! exists($cmd_tmp{'grammar'})) {
    %cmd = %cmd_tmp;
    # TODO minor refactoring: call method using exit( method() ) instead of appending an exit(1)
    my %commands = (
        'checkup' => sub { 
            my $return = checkup(); 
            print "Nothing to report.\n" if ($return == $FALSE);
            exit(1);
        },
        'class' => sub { class(); exit(1); },
        'config' => sub { config(); exit(0); },
        'configfiles' => sub { configfiles(); exit(1); },
        'floatingnetworkdeviceconfig' => sub { floatingnetworkdeviceconfig(); exit(1); },
        'fingerprint' => sub { fingerprint(); exit(1); },
        'graph' => sub { graph(); exit(1); },
        'help' => sub { help(); exit(0); },
        'history' => sub { history(); exit(1); },
        'ifoctetshistorymac' => sub { ifoctetshistorymac(); exit(1); },
        'ifoctetshistoryswitch' => sub { ifoctetshistoryswitch(); exit(1); },
        'ifoctetshistoryuser' => sub { ifoctetshistoryuser(); exit(1); },
        'import' => sub { import_data(); exit(1); },
        'interfaceconfig' => sub { interfaceconfig(); exit(1); },
        'ipmachistory' => sub { ipmachistory(); exit(1); },
        'locationhistorymac' => sub { locationhistorymac(); exit(1); },
        'locationhistoryswitch' => sub { locationhistoryswitch(); exit(1); },
        'lookup' => sub { lookup(); exit(1); },
        'manage' => sub { exit(manage()); },
        'networkconfig' => sub { networkconfig(); exit(1); },
        'node' => sub {
            require pf::node; 
            import pf::node;
            command_param('node');
            exit(1);
        },
        'nodeaccounting' => sub { nodeaccounting(); exit(1) },
        'nodecategory' => sub { nodecategory(); exit(1); },
        'nodeuseragent' => sub { nodeuseragent(); exit(1); },
        'person' => sub { 
            require pf::person; 
            import pf::person;
            command_param('person');
            exit(1);
        },
        'reload' => sub { reload(); exit(1); },
        'report' => sub { report(); exit(1); },
        'schedule' => sub { schedule(); exit(1); },
        'service' => sub { exit service(); },
        'switchconfig' => sub { switchconfig(); exit(1); },
        'switchlocation' => sub { switchlocation(); exit(1); },
        'traplog' => sub { traplog(); exit(1); },
        'trigger' => sub { trigger(); exit(1); },
        'ui' => sub { ui(); exit(1); },
        'update' => sub { update(); exit(1); },
        'useragent' => sub { useragent(); exit(1); },
        'version' => sub { version(); exit(1); },
        'violation' => sub {
            require pf::violation; 
            import pf::violation;
            command_param('violation');
            exit(1);
        },
        'violationconfig' => sub { violationconfig(); exit(1); },
    );
    if ( $commands{ $cmd{'command'}[0] } ) {
        $commands{ $cmd{'command'}[0] }->();
    } else {
        die "unknown command";
    };

} else {
    if ($cmd_tmp{'grammar'} == 0) {

        # if argument list is not empty then it's a command not understood
        if (@ARGV) {
            # line number is a hack for web admin error output
            print STDERR "Command not understood. (pfcmd grammar test failed at line ".__LINE__.".)\n";
        }
        require pf::pfcmd::help;
        pf::pfcmd::help::usage();
        exit(1);
    }
    $command = $cmd{'command'}[0];
}

#if ($command =~ /^(version|class|help|history|ipmachistory|locationhistoryswitch|locationhistorymac|ifoctetshistorymac|ifoctetshistoryswitch|ifoctetshistoryuser|report|ui|graph|switchlocation|nodecategory|trigger)$/i) {
#  ($main::{$command} or sub { print "No such sub: $_\n" })->();
#  exit 1;
#}

if ( lc($command) eq 'person' ) {
    require pf::person;
    import pf::person;
    command_param($command);
} elsif ( lc($command) eq 'node' ) {
    require pf::node;
    import pf::node;
    command_param($command);
} elsif ( lc($command) eq 'violation' ) {
    require pf::violation;
    import pf::violation;
    command_param($command);
} else {
    # calling a function looked up dynamically: first test coderef existence
    if (!exists(&{$main::{$command}})) {
        print "No such sub: $command at line ".__LINE__.".\n";
    } else {
        # then execute main::$command sub
        $logger->debug("executing sub " . $command . "()");
        # TODO: wrapping this around a try / catch block wouldn't hurt
        &{$main::{$command}}();
    }
}

# END MAIN

sub help {
    my $service = ($cmd{command}[1] || '');
    require pf::pfcmd::help;
    my $functionName = "pf::pfcmd::help::help_$service";
    if ( !$service || !defined(&$functionName) ) {
        pf::pfcmd::help::usage($TRUE);
    } else {
        ( $pf::pfcmd::help::{ "help_" . $service } )->();
    }
}

# will be replaced in 1.6ish with SOAP
#
sub manage {
    my $option = $cmd{manage_options}[0];
    my $mac    = lc( $cmd{manage_options}[1] );
    my $id;
    $id = $cmd{manage_options}[2] if ( defined $cmd{manage_options}[2] );
    my $function = "manage_" . $option;
    if ( $option eq "register" ) {
        return 1 if ( !$id );
        my %params = format_assignment( @{ $cmd{assignment} } );
        require pf::node;
        pf::node::node_register( $mac, $id, %params );
    } elsif ( $option eq "deregister" ) {
        require pf::node;
        pf::node::node_deregister($mac);
    } elsif ( $option eq "vclose" ) {
        return 2 if ( !$id );
        require pf::violation;
        print pf::violation::violation_close( $mac, $id );
    } elsif ( $option eq "vopen" ) {
        return 3 if ( !$id );
        require pf::violation;
        print pf::violation::violation_add( $mac, $id );
    }
    pf::enforcement::reevaluate_access( $mac, $function );
    return 0;
}

sub locationhistoryswitch {
    require pf::locationlog;
    import pf::locationlog;
    my $switch  = $cmd{command}[1];
    my $ifIndex = $cmd{command}[2];
    my $date;
    $date = str2time( $cmd{command}[3] ) if ( defined $cmd{command}[1] );
    my %params;
    $params{'ifIndex'} = $ifIndex;

    if ($date) {
        $params{'date'} = $date;
    }
    exit(
        print_results( "locationlog_history_switchport", $switch, %params ) );
}

sub locationhistorymac {
    require pf::locationlog;
    import pf::locationlog;
    my $mac = $cmd{command}[1];
    my %params;
    $params{'mac'} = $mac;
    $params{'date'} = str2time( $cmd{command}[2] ) if ( defined $cmd{command}[2] );
    exit( print_results( "locationlog_history_mac", $mac, %params ) );
}

sub ifoctetshistoryswitch {
    require pf::ifoctetslog;
    import pf::ifoctetslog;
    my $switch  = $cmd{command}[1];
    my $ifIndex = $cmd{command}[2];
    my %params;
    $params{'ifIndex'} = $ifIndex;
    if (scalar(@{$cmd{command}}) == 5) {
        $params{'start_time'} = str2time( $cmd{command}[3] );
        $params{'end_time'}   = str2time( $cmd{command}[4] );
    }
    exit(
        print_results( "ifoctetslog_history_switchport", $switch, %params ) );
}

sub ifoctetshistorymac {
    require pf::ifoctetslog;
    import pf::ifoctetslog;
    my $mac = $cmd{command}[1];
    my %params;
    if (scalar(@{$cmd{command}}) == 4) {
        $params{'start_time'} = str2time( $cmd{command}[2] );
        $params{'end_time'}   = str2time( $cmd{command}[3] );
    }
    exit( print_results( "ifoctetslog_history_mac", $mac, %params ) );
}

sub ifoctetshistoryuser {
    require pf::ifoctetslog;
    import pf::ifoctetslog;
    my $user = $cmd{command}[1];
    my %params;
    if (scalar(@{$cmd{command}}) == 4) {
        $params{'start_time'} = str2time( $cmd{command}[2] );
        $params{'end_time'}   = str2time( $cmd{command}[3] );
    }
    exit( print_results( "ifoctetslog_history_user", $user, %params ) );
}

sub nodecategory {
    require pf::nodecategory;
    import pf::nodecategory;
    my $sub_cmd = $cmd{'nodecategory_options'}[0];
    my $id = $cmd{'nodecategory_options'}[1];

    if ($sub_cmd eq 'view') {

        if ($id eq 'all') {
            exit(print_results("nodecategory_view_all"));

        } else {
            exit(print_results("nodecategory_view", $id));
        }

    } elsif ($sub_cmd eq 'add') {

        my %params = format_assignment(@{$cmd{'nodecategory_assignment'}});
        try {
            nodecategory_add(%params);
        } catch {
            chomp($_);
            $logger->logcarp("$_");
        };
 
    } elsif ($sub_cmd eq 'edit') {

        my %params = format_assignment(@{$cmd{'nodecategory_assignment'}});
        try {
            nodecategory_modify($id, %params);
        } catch {
            chomp($_);
            $logger->logcarp("$_");
        };
 
    } elsif ($sub_cmd eq 'delete') {

        try {
            nodecategory_delete($id);
        } catch {
            chomp($_);
            $logger->logcarp("$_");
        };
    } 
    return 1;
}

sub nodeaccounting {
    my ( $function, $id );
    require pf::accounting;
    pf::accounting->import(qw(node_accounting_view node_accounting_view_all));
    $id = $cmd{command}[2];
    if ( $id && $id ne 'all' ) {
         $function = "node_accounting_view";
    } else {
         $function = "node_accounting_view_all";
    }
    exit( print_results( $function, $id ) );
}

sub nodeuseragent {
    my ( $function, $id );
    require pf::useragent;
    pf::useragent->import(qw(node_useragent_view node_useragent_view_all));
    $id = $cmd{command}[2];
    if ( $id && $id ne 'all' ) {
        $function = "node_useragent_view";
    } else {
        $function = "node_useragent_view_all";
    }
    exit( print_results( $function, $id ) );
}

sub switchlocation {
    require pf::switchlocation;
    import pf::switchlocation;
    my $switch = $cmd{command}[2];
    my %params;
    $params{'ifIndex'} = $cmd{command}[3];
    exit(
        print_results( "switchlocation_view_switchport", $switch, %params ) );
}

sub violationconfig {
    require Config::IniFiles;
    my %violations_conf;
    tie %violations_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/violations.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error( "Error reading violations.conf: "
                . join( "\n", @errors )
                . "\n" );
        return 0;
    }

    my $mode;
    if ( scalar( @{ $cmd{'command'} } ) == 1 ) {
        if ( exists( $cmd{'violationconfig_options'} ) ) {
            $mode = $cmd{'violationconfig_options'}[0];
        }
    } else {
        $mode = $cmd{'command'}[1];
    }

    if ( $mode eq 'get' ) {
        foreach my $section ( tied(%violations_conf)->Sections ) {
            foreach my $key ( keys %{ $violations_conf{$section} } ) {
                $violations_conf{$section}{$key} =~ s/\s+$//;
            }
        }

        my @fields = field_order();
        print join( $delimiter, @fields ) . "\n";

        # Now that we printed all the fields, we skip the key since it's not
        # under the config section but actually the section itself
        shift @fields;

        # Loop, filter and display
        foreach my $section ( keys %violations_conf ) {
            if ( $cmd{'command'}[2] eq 'all' || $cmd{'command'}[2] eq $section ) {

                my @values;
                foreach my $column (@fields) {
                    push @values,
                        ( $violations_conf{$section}{$column} || $violations_conf{'defaults'}{$column} || '' );
                }
                print $section . $delimiter . join( $delimiter, @values ) . "\n";
            }
        }
    } elsif ( $mode eq 'delete' ) {
        my $section = $cmd{'command'}[2];
        # TODO: this seems wrong. 1st: hardcoded violation id, 2nd: how does the web react to that print?
        if ( $section
            =~ /^(default|all|1100001|1100004|1100005|1100009|1100010|1200001|1200003)$/
            )
        {
            print "This violation can't be deleted (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        } else {
            if ( tied(%violations_conf)->SectionExists($section) ) {
                tied(%violations_conf)->DeleteSection($section);
                tied(%violations_conf)
                    ->WriteConfig( $conf_dir . "/violations.conf" )
                    or $logger->logdie("Unable to write config to $conf_dir/violations.conf. "
                        ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
                require pf::configfile;
                import pf::configfile;
                configfile_import( $conf_dir . "/violations.conf" );
            } else {
                print "Unknown violation $section! (Error at line ".__LINE__." in pfcmd)\n";
                exit;
            }
        }
    } elsif ( $mode eq 'edit' ) {
        my $section     = $cmd{'violationconfig_options'}[1];
        my @assignments = @{ $cmd{'violationconfig_assignment'} };
        if ( tied(%violations_conf)->SectionExists($section) ) {
            foreach my $assignment (@assignments) {
                my ( $param, $value ) = @$assignment;
                if ($section eq 'defaults') {
                    if ( defined( $violations_conf{$section}{$param} ) ) {
                        tied(%violations_conf)
                            ->setval( $section, $param, $value );
                    } else {
                        tied(%violations_conf)
                            ->newval( $section, $param, $value );
                    }
                } else {
                    if ( defined( $violations_conf{$section}{$param} ) ) {
                        if (   ( !exists( $violations_conf{'defaults'}{$param} ) )
                            || ( $violations_conf{'defaults'}{$param} ne $value )
                            )
                        {
                            tied(%violations_conf)
                                ->setval( $section, $param, $value );
                        } else {
                            tied(%violations_conf)->delval( $section, $param );
                        }
                    } else {
                        if (   ( !exists( $violations_conf{'defaults'}{$param} ) )
                            || ( $violations_conf{'defaults'}{$param} ne $value )
                            )
                        {
                            tied(%violations_conf)
                                ->newval( $section, $param, $value );
                        }
                    }
                }
            }
            tied(%violations_conf)
                ->WriteConfig( $conf_dir . "/violations.conf" )
                or $logger->logdie("Unable to write config to $conf_dir/violations.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/violations.conf" );
        } else {
            print "Unknown violation $section! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    } elsif ( $mode eq 'add' ) {
        my $section     = $cmd{'violationconfig_options'}[1];
        my @assignments = @{ $cmd{'violationconfig_assignment'} };
        if ( !( tied(%violations_conf)->SectionExists($section) ) ) {
            tied(%violations_conf)->AddSection($section);
            foreach my $assignment (@assignments) {
                my ( $param, $value ) = @$assignment;
                if (   ( !exists( $violations_conf{'defaults'}{$param} ) )
                    || ( $violations_conf{'defaults'}{$param} ne $value ) )
                {
                    tied(%violations_conf)
                        ->newval( $section, $param, $value );
                }
            }
            tied(%violations_conf)
                ->WriteConfig( $conf_dir . "/violations.conf" )
                or $logger->logdie("Unable to write config to $conf_dir/violations.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/violations.conf" );
        } else {
            print "Violation $section already exists! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    }
}

sub floatingnetworkdeviceconfig {
    require Config::IniFiles;
    my $configFile = $floating_devices_file;
    my %floatingnetworkdevice_conf;

    tie %floatingnetworkdevice_conf, 'Config::IniFiles', ( -file => $configFile, -allowempty => 1 );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error("Error reading $configFile: " . join( "\n", @errors ) . "\n" );
        return 0;
    }

    my $mode;
    if ( scalar( @{ $cmd{'command'} } ) == 1 ) {
        if ( exists( $cmd{'floatingnetworkdeviceconfig_options'} ) ) {
            $mode = $cmd{'floatingnetworkdeviceconfig_options'}[0];
        }
    } else {
        $mode = $cmd{'command'}[1];
    }

    if ( $mode eq 'get' ) {
        foreach my $section ( tied(%floatingnetworkdevice_conf)->Sections ) {
            foreach my $key ( keys %{ $floatingnetworkdevice_conf{$section} } ) {
                $floatingnetworkdevice_conf{$section}{$key} =~ s/\s+$//;
            }
        }

        my @sections_tmp = keys %floatingnetworkdevice_conf;
        my @sections = map substr( $_, 4 ) => sort map pack( 'C4' => /(\d+)\.(\d+)\.(\d+)\.(\d+)/ ) 
            . $_ => @sections_tmp;

        my @fields = field_order();
        print join( $delimiter, @fields ) . "\n";

        # Now that we printed all the fields, we skip the key since it's not
        # under the config section but actually the section itself
        shift @fields;

        # Loop, filter and display
        foreach my $section (@sections) {
            if ( $cmd{'command'}[2] eq 'all' || $cmd{'command'}[2] eq $section ) {
                my @values;
                foreach my $column (@fields) {
                    push @values, ( $floatingnetworkdevice_conf{$section}{$column} || '' );
                }
                print $section . $delimiter . join( $delimiter, @values ) . "\n";
            }
        }

    } elsif ( $mode eq 'delete' ) {
        my $section = $cmd{'command'}[2];
        if ( $section =~ /^(all|stub)$/ ) {
            print "This floating network device can't be deleted. (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        } else {
            if ( tied(%floatingnetworkdevice_conf)->SectionExists($section) ) {
                tied(%floatingnetworkdevice_conf)->DeleteSection($section);
                my $tied_floatingnetworkdevice = tied(%floatingnetworkdevice_conf);
                $tied_floatingnetworkdevice->WriteConfig($configFile)
                    or $logger->logdie("Unable to write config to $configFile. "
                                  ."You might want to check the file's permissions. (see pfcmd)"); # web ui hack
                require pf::configfile;
                import pf::configfile;
                configfile_import($configFile);
            } else {
                print "Unknown floating network device $section! (Error at line ".__LINE__." in pfcmd)\n";
                exit;
            }
        }
    } elsif ( $mode eq 'edit' ) {
        my $section     = $cmd{'floatingnetworkdeviceconfig_options'}[1];
        my @assignments = @{ $cmd{'floatingnetworkdeviceconfig_assignment'} };
        if ( tied(%floatingnetworkdevice_conf)->SectionExists($section) ) {
            foreach my $assignment (@assignments) {
                my ( $param, $value ) = @$assignment;
                if ( defined( $floatingnetworkdevice_conf{$section}{$param} ) ) {
                    tied(%floatingnetworkdevice_conf)->setval( $section, $param, $value );
                } else {
                    tied(%floatingnetworkdevice_conf)->newval( $section, $param, $value );
                }
            }
            my $tied_floatingnetworkdevice = tied(%floatingnetworkdevice_conf);
            $tied_floatingnetworkdevice->WriteConfig($configFile)
                or $logger->logdie("Unable to write config to $configFile. "
                                  ."You might want to check the file's permissions. (see pfcmd)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import($configFile);
        } else {
            print "Unknown floating network device $section! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    } elsif ( $mode eq 'add' ) {
        my $section     = $cmd{'floatingnetworkdeviceconfig_options'}[1];
        my @assignments = @{ $cmd{'floatingnetworkdeviceconfig_assignment'} };
        if ( !( tied(%floatingnetworkdevice_conf)->SectionExists($section) ) ) {
            foreach my $assignment (@assignments) {
                tied(%floatingnetworkdevice_conf)->AddSection($section);
                my ( $param, $value ) = @$assignment;
                tied(%floatingnetworkdevice_conf)->newval( $section, $param, $value );
            }
            my $tied_floatingnetworkdevice = tied(%floatingnetworkdevice_conf);
            $tied_floatingnetworkdevice->WriteConfig($configFile)
                or $logger->logdie("Unable to write config to $configFile. "
                                  ."You might want to check the file's permissions. (see pfcmd)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import($configFile);
        } else {
            print "Floating network device $section already exists! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    }
}

sub networkconfig {

    my $mode;
    if ( scalar( @{ $cmd{'command'} } ) == 1 ) {
        if ( exists( $cmd{'networkconfig_options'} ) ) {
            $mode = $cmd{'networkconfig_options'}[0];
        }
    } else {
        $mode = $cmd{'command'}[1];
    }

    if ( $mode eq 'get' ) {

        my @networks_tmp = keys %ConfigNetworks;
        my @networks = map substr( $_, 4 ) => sort map pack( 'C4' => /(\d+)\.(\d+)\.(\d+)\.(\d+)/ ) 
            . $_ => @networks_tmp;

        my @fields = field_order();
        print join( $delimiter, @fields ) . "\n";

        # Now that we printed all the fields, we skip the key since it's not
        # under the config section but actually the section itself
        shift @fields;

        # Loop, filter and display
        foreach my $network (@networks) {
            if ( $cmd{'command'}[2] eq 'all' || $cmd{'command'}[2] eq $network )
            {
                my @values;
                foreach my $column (@fields) {
                    # pf_gateway to next_hop translation
                    # TODO remove code once pf_gateway is deprecated (somewhere in 2012)
                    if ($column eq 'next_hop' 
                        && !defined($ConfigNetworks{$network}{$column}) 
                        && defined($ConfigNetworks{$network}{'pf_gateway'})) {
                            $ConfigNetworks{$network}{$column} = $ConfigNetworks{$network}{'pf_gateway'};
                    }
                    push @values, ( $ConfigNetworks{$network}{$column} || '' );
                }
                print $network . $delimiter . join( $delimiter, @values ) . "\n";
            }
        }
    } elsif ( $mode eq 'delete' ) {
        my $network = $cmd{'command'}[2];
        if ( $network eq 'all' ) {
            print "This network can't be deleted (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        } else {
            if ( tied(%ConfigNetworks)->SectionExists($network) ) {
                tied(%ConfigNetworks)->DeleteSection($network);
                my $tied_network = tied(%ConfigNetworks);
                $tied_network->WriteConfig($network_config_file)
                    or $logger->logdie("Unable to write config to $network_config_file. "
                                      ."You might want to check the file's permissions. (see pfcmd)"); # web ui hack
                require pf::configfile;
                import pf::configfile;
                configfile_import( $network_config_file );
            } else {
                print "Unknown network $network! (Error at line ".__LINE__." in pfcmd)\n";
                exit;
            }
        }
    } elsif ( $mode eq 'edit' ) {
        my $network     = $cmd{'networkconfig_options'}[1];
        my @assignments = @{ $cmd{'networkconfig_assignment'} };
        if ( tied(%ConfigNetworks)->SectionExists($network) ) {
            foreach my $assignment (@assignments) {
                my ( $param, $value ) = @$assignment;
                if ( defined( $ConfigNetworks{$network}{$param} ) ) {
                    tied(%ConfigNetworks)->setval( $network, $param, $value );
                } else {
                    tied(%ConfigNetworks)->newval( $network, $param, $value );
                }
            }
            my $tied_network = tied(%ConfigNetworks);
            $tied_network->WriteConfig($network_config_file)
                or $logger->logdie("Unable to write config to $network_config_file. "
                                  ."You might want to check the file's permissions. (see pfcmd)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $network_config_file );
        } else {
            print "Unknown network $network! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    } elsif ( $mode eq 'add' ) {
        my $network     = $cmd{'networkconfig_options'}[1];
        my @assignments = @{ $cmd{'networkconfig_assignment'} };
        if ( !( tied(%ConfigNetworks)->SectionExists($network) ) ) {
            foreach my $assignment (@assignments) {
                tied(%ConfigNetworks)->AddSection($network);
                my ( $param, $value ) = @$assignment;
                tied(%ConfigNetworks)->newval( $network, $param, $value );
            }
            my $tied_network = tied(%ConfigNetworks);
            $tied_network->WriteConfig( $network_config_file )
                or $logger->logdie("Unable to write config to $network_config_file. "
                                  ."You might want to check the file's permissions. (see pfcmd)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $network_config_file );
        } else {
            print "Network $network already exists! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    }
}

sub import_data {
    require pf::import;
    import pf::import;
    my $type = $cmd{command}[1];
    my $file = $cmd{command}[2];
    $logger->info("Import requested. Type: $type, file to import: $file");

    if (lc($type) eq 'nodes') {
        pf::import::nodes($file);
    }
    print "Import process complete\n";
}

sub interfaceconfig {
    require Config::IniFiles;
    my %pf_conf;
    tie %pf_conf, 'Config::IniFiles', ( -file => "$conf_dir/pf.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error(
            "Error reading pf.conf: " . join( "\n", @errors ) . "\n" );
        return 0;
    }

    my $mode;
    if ( scalar( @{ $cmd{'command'} } ) == 1 ) {
        if ( exists( $cmd{'interfaceconfig_options'} ) ) {
            $mode = $cmd{'interfaceconfig_options'}[0];
        }
    } else {
        $mode = $cmd{'command'}[1];
    }

    if ( $mode eq 'get' ) {
        foreach my $section ( tied(%pf_conf)->Sections ) {
            foreach my $key ( keys %{ $pf_conf{$section} } ) {
                $pf_conf{$section}{$key} =~ s/\s+$//;
            }
        }

        my @fields = field_order();
        print join( $delimiter, @fields ) . "\n";

        # Now that we printed all the fields, we skip the key since it's not
        # under the config section but actually the section itself
        shift @fields;

        # Loop, filter and display
        foreach my $section ( keys %pf_conf ) {
            if ( $section =~ /^interface (.+)$/ ) {
                my $interface_name = $1;
                if ( $cmd{'command'}[2] eq 'all' || $cmd{'command'}[2] eq $interface_name ) {
                    my @values;
                    foreach my $column (@fields) {
                        push @values, ( $pf_conf{$section}{$column} || '' );
                    }
                    print $interface_name . $delimiter . join( $delimiter, @values ) . "\n";
                }
            }
        }
    } elsif ( $mode eq 'delete' ) {
        my $section      = $cmd{'command'}[2];
        my $section_name = "interface $section";
        if ( $section eq 'all' ) {
            print "This interface can't be deleted (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        } else {
            if ( tied(%pf_conf)->SectionExists($section_name) ) {
                tied(%pf_conf)->DeleteSection($section_name);
                tied(%pf_conf)->WriteConfig( $conf_dir . "/pf.conf" )
                    or $logger->logdie("Unable to write config to $conf_dir/pf.conf. "
                        ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
                require pf::configfile;
                import pf::configfile;
                configfile_import( $conf_dir . "/pf.conf" );
            } else {
                print "Unknown interface $section! (Error at line ".__LINE__." in pfcmd)\n";
                exit;
            }
        }
    } elsif ( $mode eq 'edit' ) {
        my $section      = $cmd{'interfaceconfig_options'}[1];
        my $section_name = "interface $section";
        my @assignments  = @{ $cmd{'interfaceconfig_assignment'} };
        if ( tied(%pf_conf)->SectionExists($section_name) ) {
            foreach my $assignment (@assignments) {
                my ( $param, $value ) = @$assignment;
                if ( defined( $pf_conf{$section_name}{$param} ) ) {
                    tied(%pf_conf)->setval( $section_name, $param, $value );
                } else {
                    tied(%pf_conf)->newval( $section_name, $param, $value );
                }
            }
            tied(%pf_conf)->WriteConfig( $conf_dir . "/pf.conf" )
                or $logger->logdie("Unable to write config to $conf_dir/pf.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/pf.conf" );
        } else {
            print "Unknown interface $section! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    } elsif ( $mode eq 'add' ) {
        my $section      = $cmd{'interfaceconfig_options'}[1];
        my $section_name = "interface $section";
        my @assignments  = @{ $cmd{'interfaceconfig_assignment'} };
        if ( !( tied(%pf_conf)->SectionExists($section_name) ) ) {
            foreach my $assignment (@assignments) {
                tied(%pf_conf)->AddSection($section_name);
                my ( $param, $value ) = @$assignment;
                tied(%pf_conf)->newval( $section_name, $param, $value );
            }
            tied(%pf_conf)->WriteConfig( $conf_dir . "/pf.conf" )
                or $logger->logdie("Unable to write config to $conf_dir/pf.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/pf.conf" );
        } else {
            print "Interface $section already exists! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    }
}

sub switchconfig {
    require Config::IniFiles;
    my %switches_conf;
    tie %switches_conf, 'Config::IniFiles',
        ( -file => "$conf_dir/switches.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error(
            "Error reading switches.conf: " . join( "\n", @errors ) . "\n" );
        return 0;
    }

    my $mode;
    if ( scalar( @{ $cmd{'command'} } ) == 1 ) {
        if ( exists( $cmd{'switchconfig_options'} ) ) {
            $mode = $cmd{'switchconfig_options'}[0];
        }
    } else {
        $mode = $cmd{'command'}[1];
    }

    if ( $mode eq 'get' ) {
        foreach my $section ( tied(%switches_conf)->Sections ) {
            foreach my $key ( keys %{ $switches_conf{$section} } ) {
                $switches_conf{$section}{$key} =~ s/\s+$//;
            }
        }

        #sort the switches (http://www.sysarch.com/Perl/sort_paper.html)
        my %switches_conf_tmp = %switches_conf;
        delete $switches_conf_tmp{'default'};
        my @sections_tmp = keys(%switches_conf_tmp);
        my @sections
            = map substr( $_, 4 ) => sort
            map pack( 'C4' => /(\d+)\.(\d+)\.(\d+)\.(\d+)/ )
            . $_ => @sections_tmp;
        unshift( @sections, 'default' );

        my @fields = field_order();
        print join( $delimiter, @fields ) . "\n";

        # Now that we printed all the fields, we skip the key since it's not
        # under the config section but actually the section itself
        shift @fields;

        # Loop, filter and display
        foreach my $section (@sections) {
            if ( $cmd{'command'}[2] eq 'all' || $cmd{'command'}[2] eq $section ) {
                my @values;
                foreach my $column (@fields) {
                    push @values,
                        ( $switches_conf{$section}{$column} || $switches_conf{'default'}{$column} || '' );
                }
                print $section . $delimiter . join( $delimiter, @values ) . "\n";
            }
        }
    } elsif ( $mode eq 'delete' ) {
        my $section = $cmd{'command'}[2];
        if ( $section =~ /^(default|all|127.0.0.1)$/ ) {
            print "This switch can't be deleted (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        } else {
            if ( tied(%switches_conf)->SectionExists($section) ) {
                tied(%switches_conf)->DeleteSection($section);
                my $tied_switch = tied(%switches_conf);
                $tied_switch->WriteConfig($conf_dir . "/switches.conf")
                    or $logger->logdie("Unable to write config to $conf_dir/switches.conf. "
                        ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # hack
                require pf::configfile;
                import pf::configfile;
                configfile_import( $conf_dir . "/switches.conf" );
            } else {
                print "Unknown switch $section! (Error at line ".__LINE__." in pfcmd)\n";
                exit;
            }
        }
    } elsif ( $mode eq 'edit' ) {
        my $section     = $cmd{'switchconfig_options'}[1];
        my @assignments = @{ $cmd{'switchconfig_assignment'} };
        if ( tied(%switches_conf)->SectionExists($section) ) {
            foreach my $assignment (@assignments) {
                my ( $param, $value ) = @$assignment;
                if ($section eq 'default') {
                    if ( defined( $switches_conf{$section}{$param} ) ) {
                        tied(%switches_conf)
                            ->setval( $section, $param, $value );
                    } else {
                        tied(%switches_conf)
                            ->newval( $section, $param, $value );
                    }
                } else {
                    if ( defined( $switches_conf{$section}{$param} ) ) {
                        if (   ( !exists( $switches_conf{'default'}{$param} ) )
                            || ( $switches_conf{'default'}{$param} ne $value ) )
                        {
                            tied(%switches_conf)
                                ->setval( $section, $param, $value );
                        } else {
                            tied(%switches_conf)->delval( $section, $param );
                        }
                    } else {
                        if (   ( !exists( $switches_conf{'default'}{$param} ) )
                            || ( $switches_conf{'default'}{$param} ne $value ) )
                        {
                            tied(%switches_conf)
                                ->newval( $section, $param, $value );
                        }
                    }
                }
            }
            my $tied_switch = tied(%switches_conf);
            $tied_switch->WriteConfig($conf_dir . "/switches.conf")
                or $logger->logdie("Unable to write config to $conf_dir/switches.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/switches.conf" );
        } else {
            print "Unknown switch $section! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    } elsif ( $mode eq 'add' ) {
        my $section     = $cmd{'switchconfig_options'}[1];
        my @assignments = @{ $cmd{'switchconfig_assignment'} };
        if ( !( tied(%switches_conf)->SectionExists($section) ) ) {
            foreach my $assignment (@assignments) {
                tied(%switches_conf)->AddSection($section);
                my ( $param, $value ) = @$assignment;
                if (   ( !exists( $switches_conf{'default'}{$param} ) )
                    || ( $switches_conf{'default'}{$param} ne $value ) )
                {
                    tied(%switches_conf)->newval( $section, $param, $value );
                }
            }
            my $tied_switch = tied(%switches_conf);
            $tied_switch->WriteConfig($conf_dir . "/switches.conf")
                or $logger->logdie("Unable to write config to $conf_dir/switches.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/switches.conf" );
        } else {
            print "Switch $section already exists! (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        }
    }
}

#
#  host history
#
sub history {
    require pf::iplog;
    import pf::iplog;
    my $addr = $cmd{command}[1];
    my $date;
    $date = str2time( $cmd{command}[2] ) if ( defined $cmd{command}[1] );
    my ( $function, %params );
    if ( $addr =~ /^(\d{1,3}\.){3}\d{1,3}$/ ) {
        $function = "iplog_history_ip";
    } else {
        $function = "iplog_history_mac";
    }
    if ($date) {
        $params{'date'} = $date;
    }
    exit( print_results( $function, $addr, %params ) );
}

sub ipmachistory {
    require pf::iplog;
    import pf::iplog;
    my $addr = $cmd{command}[1];
    my ( $function, %params );
    if ( $addr =~ /^(\d{1,3}\.){3}\d{1,3}$/ ) {
        $function = "iplog_history_ip";
    } else {
        $function = "iplog_history_mac";
    }
    if (scalar(@{$cmd{command}}) == 4) {
        $params{'start_time'} = str2time( $cmd{command}[2] );
        $params{'end_time'}   = str2time( $cmd{command}[3] );
    }
    exit( print_results( $function, $addr, %params ) );
}

sub traplog {
    require pf::traplog;
    import pf::traplog;
    if (   ( scalar( @{ $cmd{'command'} } ) == 2 )
        && ( $cmd{command}[1] eq 'update' ) )
    {
        traplog_update_rrd();
    } else {
        my $nb = $cmd{'command'}[1];
        my %params;
        $params{'timespan'} = $cmd{'command'}[2];
        exit(
            print_results(
                'traplog_get_switches_with_most_traps',
                $nb, %params
            )
        );
    }
    exit;
}

#
# stop/start pf services
# return service status
#
sub service {
    my $service = $cmd{command}[1];
    my $command = $cmd{command}[2];
    require pf::services;
    import pf::services;

    $logger->info("Executing pfcmd service $service $command");

    if ( lc($command) eq 'status' ) {
        my @services;
        if ( $service eq 'pf' ) {
            @services = @pf::services::ALL_SERVICES;
        } else {
            push( @services, $service );
        }
        my @incorrectly_stopped_services     = ();
        my @services_which_should_be_started = pf::services::service_list(@services);
        print "service|shouldBeStarted|pid\n";
        foreach my $tmp (@services) {
            my $should_be_started = (
                (   grep( { $_ eq $tmp } @services_which_should_be_started )
                        > 0
                ) ? 1 : 0
            );
            my $pid = pf::services::service_ctl( $tmp, 'status' );
            if ( ($should_be_started) && ( !$pid ) ) {
                push @incorrectly_stopped_services, $tmp;
            }
            print "$tmp|$should_be_started|$pid\n";
        }
        return ( ( scalar(@incorrectly_stopped_services) > 0 ) ? 3 : 0 );
    }

    if ( lc($command) eq 'watch' ) {
        my @services;
        if ( $service eq "pf" ) {
            @services = @pf::services::ALL_SERVICES;
        } else {
            push( @services, $service );
        }
        my @services_which_should_be_started = pf::services::service_list(@services);
        my @incorrectly_stopped_services     = ();
        foreach my $tmp (@services) {
            my $should_be_started = (grep( { $_ eq $tmp } @services_which_should_be_started ) > 0);
            my $pid = pf::services::service_ctl( $tmp, 'status' );
            if ( ($should_be_started) && ( !$pid ) ) {
                push @incorrectly_stopped_services, $tmp;
            }
        }
        if (@incorrectly_stopped_services) {
            $logger->info("watch found incorrectly stopped services: " . join(", ", @incorrectly_stopped_services));
            print "The following processes are not running:\n" . " - "
                . join( "\n - ", @incorrectly_stopped_services ) . "\n";
            if ( isenabled( $Config{'servicewatch'}{'email'} ) ) {
                my %message;
                $message{'subject'} = "PF WATCHER ALERT";
                $message{'message'}
                    = "The following processes are not running:\n" . " - "
                    . join( "\n - ", @incorrectly_stopped_services ) . "\n";
                pfmailer(%message);
            }
            if ( isenabled( $Config{'servicewatch'}{'restart'} ) ) {
                $command = 'restart';
            } else {
                return 1;
            }
        } else {
            return 1;
        }
    }

    if ( lc($command) eq 'restart' ) {
        if ( lc($service) eq 'pf' ) {
            $logger->info(
                "packetfence restart ... executing stop followed by start");
            local $cmd{command}[2] = "stop";
            service();
            local $cmd{command}[2] = "start";
            service();
            return 1;
        } else {
            if ( !pf::services::service_ctl( $service, "status" ) ) {
                $command = "restart";
            }
        }
    }

    my @services;
    if ( $service ne 'pf' ) {
        # make sure that snort is not started without pfdetect
        if ($service eq 'snort') {
            if ( !pf::services::service_ctl( 'pfdetect', 'status' ) ) {
                $logger->info('addind pfdetect to list of services so that snort can be started');
                push @services, 'pfdetect';
            }
        }
        push @services, $service;
    } else {
        @services = pf::services::service_list(@pf::services::ALL_SERVICES);
    }

    my @alreadyRunningServices = ();
    if ( lc($command) eq 'start' ) {
        require pf::pfcmd::checkup;
        import pf::pfcmd::checkup;
        checkup(@services);
        my $nb_running_services = 0;
        foreach my $tmp (@pf::services::ALL_SERVICES) {
            if ( pf::services::service_ctl( $tmp, "status" ) ) {
                $nb_running_services++;
                push @alreadyRunningServices, $tmp;
            }
        }
        if ( $nb_running_services == 0 ) {
            $logger->info("saving current iptables to var/iptables.bak");
            require pf::iptables;
            pf::iptables::iptables_save( $install_dir . '/var/iptables.bak' );
        }
    }

    print "service|command\n";
    if ( $command ne 'stop' ) {
        print "config files|$command\n";
        require pf::os;
        pf::os::import_dhcp_fingerprints();
        pf::services::read_violations_conf();
        print "iptables|$command\n";
        require pf::iptables;
        pf::iptables::iptables_generate();
    }

    foreach my $srv (@services) {
        if (   ( $command eq 'start' )
            && ( grep( { $_ eq $srv } @alreadyRunningServices ) == 1 ) )
        {
            print "$srv|already running\n";
        } else {
            pf::services::service_ctl( $srv, $command );
            print "$srv|$command\n";
        }
    }

    if ( lc($command) eq 'stop' ) {
        my $nb_running_services = 0;
        foreach my $tmp (@pf::services::ALL_SERVICES) {
            if ( pf::services::service_ctl( $tmp, "status" ) ) {
                $nb_running_services++;
            }
        }
        if ( $nb_running_services == 0 ) {
            require pf::iptables;
            pf::iptables::iptables_restore( $install_dir . '/var/iptables.bak' );
        } else {
            if ( lc($service) eq 'pf' ) {
                $logger->error(
                    "Even though 'service pf stop' was called, there are still $nb_running_services services running. " 
                     . "Can't restore iptables from var/iptables.bak"
                );
            }
        }
    }
    return 0;
}

sub class {
    my ( $function, $id );
    require pf::class;
    import pf::class;
    $id = $cmd{'command'}[2];
    if ( $id && $id !~ /all/ ) {
        $function = "class_view";
    } else {
        $function = "class_view_all";
    }
    exit( print_results( $function, $id ) );
}

sub checkup {
    require pf::services;
    require pf::pfcmd::checkup;
    no warnings "once"; #avoids only used once warnings generated by the access of pf::pfcmd::checkup namespace

    my @problems = pf::pfcmd::checkup::sanity_check(pf::services::service_list(@pf::services::ALL_SERVICES));
    foreach my $entry (@problems) {
        chomp $entry->{$pf::pfcmd::checkup::MESSAGE};
        print $entry->{$pf::pfcmd::checkup::SEVERITY}  . " - " . $entry->{$pf::pfcmd::checkup::MESSAGE} . "\n";
    }

    # if there is a fatal problem, exit with status 255
    foreach my $entry (@problems) {
        if ($entry->{$pf::pfcmd::checkup::SEVERITY} eq $pf::pfcmd::checkup::FATAL) {
            exit(255);
        }
    }

    if (@problems) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

#
sub trigger {
    my ( $function, $id, %params );
    require pf::trigger;
    import pf::trigger;
    $id = $cmd{command}[2];
    if ( ( defined $cmd{command}[3] ) && ( $cmd{command}[3] ne '' ) ) {
        if ( $id eq 'all' ) {
            $id       = $cmd{command}[3];
            $function = "trigger_view_type";
        } else {
            $params{'type'} = $cmd{command}[3];
            $function = "trigger_view";
        }
    } elsif ( $id && $id !~ /all/ ) {
        $function = "trigger_view_tid";
    } else {
        $function = "trigger_view_all";
    }
    exit( print_results( $function, $id, %params ) );
}

#
sub fingerprint {
    my ( $function, $id );
    require pf::os;
    import pf::os;
    $id = $cmd{command}[2];
    if ( $id && $id ne 'all' ) {
        $function = "dhcp_fingerprint_view";
    } else {
        $function = "dhcp_fingerprint_view_all";
    }
    exit( print_results( $function, $id ) );
}

sub useragent {
    my ( $function, $id );
    require pf::useragent;
    pf::useragent->import(qw(view view_all));
    $id = $cmd{command}[2];
    if ( $id && $id ne 'all' ) {
        $function = "view";
    } else {
        $function = "view_all";
    }
    exit( print_results( $function, $id ) );
}

sub version {
    # TODO: move this code into library code and have pf::config hold the value somewhere.
    # Then report the version in Web Services API calls like for the Extreme Switches' appName
    my ( $pfrelease_fh, $release );
    open( $pfrelease_fh, '<', "$conf_dir/pf-release" )
        || $logger->logdie("Unable to open $conf_dir/pf-release: $!");
    $release = <$pfrelease_fh>;
    close($pfrelease_fh);
    print $release;
}

#
#  schedule a host scan
#
sub schedule {
    my $command = $cmd{command}[0];
    my $service;
    $service = $cmd{command}[1] if ( defined $cmd{command}[1] );
    my $option   = $cmd{schedule_options}[0];
    my $hostaddr = $cmd{schedule_options}[1];
    my %params   = format_assignment( @{ $cmd{assignment} } );

    #scan now, no cron entry
    if ( $option && $option eq 'now' ) {
        
        $logger->trace("pcmd schedule now called");

        require pf::scan;
        pf::scan::run_scan($hostaddr);

        $logger->trace("leaving pfcmd schedule now");

    # or modify cron
    } else {
        require pf::schedule;
    
        my $date = $params{date} || 0;
    
        my $cron = new pf::schedule();
        $cron->load_cron("pf");
        print join( $delimiter, ( "id", "date", "hosts" ) ) . "\n";
        if ( $option eq 'view' ) {
            if ( $hostaddr eq 'all' ) {
                print $cron->get_indexes();
            } else {
                my $cronref = $cron->get_index($hostaddr);
                if (defined($cronref)) {
                    print join( $delimiter, $cron->get_index($hostaddr) ) . "\n";
                }
            }
            return (1);
        } elsif ( $option eq 'add' ) {
            $logger->trace("Adding scheduled scan cron entry with date: $date");
            my @fields = split( /\s+/, $date );
            if (   !$date
                || scalar(@fields) != 5
                || $date !~ /^([\d\-\,\/\* ])+$/)
            {
                print "Date format incorrect $date\n";
                $logger->error("date format incorrect");
                return (0);
            } else {
                $cron->add_index( $date,
                    $bin_dir . "/pfcmd schedule now $hostaddr" );
            }
        } elsif ( $option eq 'delete' ) {
            $cron->delete_index($hostaddr);
            $cron->write_cron("pf");
            return 1;
        } elsif ( $option eq 'edit' ) {
            my $id = $hostaddr;
            my ( $oldate, $oldaddr )
                = ( $cron->get_index($id) )[ 1, 2 ];
            $hostaddr = $oldaddr;
            $hostaddr = $params{hosts} if ( $params{hosts} );
            $date     = $oldate if ( !$date );
            $logger->info("updating schedule number $id to date=$date,hostaddr=$hostaddr");
            $cron->update_index($id, $date, $bin_dir."/pfcmd schedule now $hostaddr");
        } else {
            $logger->error("Schedule Failed");
            return (0);
        }
    
        print $cron->get_indexes();
        $cron->write_cron("pf");
    }
}

#
#
#
sub config_entry {
    my ( $param, $value ) = @_;
    my ( $default, $orig_param, $dot_param, $param2, $type, $options, $val );

    $orig_param = $param;
    $dot_param  = $param;
    $dot_param =~ s/\s+/\./g;
    ( $param, $param2 ) = split( " ", $param ) if ( $param =~ /\s/ );

    if ( defined( $defaults{$orig_param}{$value} ) ) {
        $default = $defaults{$orig_param}{$value};
    } else {
        $default = "";
    }
    if ( defined( $documentation{"$param.$value"}{'options'} ) ) {
        $options = $documentation{"$param.$value"}{'options'};
        $options =~ s/\|/;/g;
    } else {
        $options = "";
    }
    if ( defined( $documentation{"$param.$value"}{'type'} ) ) {
        $type = $documentation{"$param.$value"}{'type'};
    } else {
        $type = "text";
    }
    if ( defined( $myconfig{$orig_param}{$value} ) ) {
        $val = "$dot_param.$value=$myconfig{$orig_param}{$value}";
    } else {
        $val = "$dot_param.$value=";
    }
    return join( "|", $val, $default, $options, $type ) . "\n";
}

#
# parse pf.conf and defaults from pf.conf.defaults
#
sub config {
    my $option = $cmd{command}[1];
    my $param  = $cmd{command}[2];
    my $value  = "";

    tie %documentation, 'Config::IniFiles',
        ( -file => $conf_dir . "/documentation.conf" )
        or $logger->logdie("Unable to open documentation.conf: $!");
    tie %defaults, 'Config::IniFiles', ( -file => $default_config_file )
        or $logger->logdie("Unable to open $default_config_file: $!");
    # load config if it exists
    if ( -e $config_file ) {
        tie %myconfig, 'Config::IniFiles', ( -file => $config_file )
            or $logger->logdie("Unable to open $config_file: $!");
    }
    # start with an empty file
    else {
        tie %myconfig, 'Config::IniFiles';
        tied(%myconfig)->SetFileName($config_file);
    }

    if ( lc($option) eq 'set' ) {
        if ($param =~ /^([^=]+)=(.+)?$/) {
            $param = $1;
            $value = (defined($2) ? $2 : '');
        }
        else {
            require pf::pfcmd::help;
            pf::pfcmd::help::usage("config");
        }
    }

    # get rid of spaces (a la [interface X])
    #$param =~ s/\s+/./g;

    my $parm;
    my $section;

    if ( $param =~ /^(interface)\.(.+)+\.([^.]+)$/ ) {
        $parm    = $3;
        $section = "$1 $2";
    } elsif ( $param =~ /^(proxies)\.(.+)$/ ) {
        $parm = $2;
        $section = $1;
    } else {
        my @stuff = split( /\./, $param );
        $parm = pop(@stuff);
        $section = join( " ", @stuff );
    }

    if ( lc($option) eq 'get' ) {
        if ( $param eq 'all' ) {
            foreach my $a ( sort keys(%Config) ) {
                foreach my $b ( keys( %{ $Config{$a} } ) ) {
                    print config_entry( $a, $b );
                }
            }
            exit;
        }
        if ( defined( $Config{$section}{$parm} ) ) {
            print config_entry( $section, $parm );
        } else {
            print "Unknown configuration parameter: $section.$param!\n";
            exit($pf::pfcmd::ERROR_CONFIG_UNKNOWN_PARAM);
        }
    } elsif ( lc($option) eq 'help' ) {
        if ( defined( $documentation{$param}{'description'} ) ) {
            print uc($param) . "\n";
            print "Default: $defaults{$section}{$parm}\n"
                if ( defined( $defaults{$section}{$parm} ) );
            print "Options: $documentation{$param}{'options'}\n"
                if ( defined( $documentation{$param}{'options'} ) );
            if ( ref( $documentation{$param}{'description'} ) eq 'ARRAY' ) {
                print join( "\n", @{ $documentation{$param}{'description'} } )
                    . "\n";
            } else {
                print $documentation{$param}{'description'} . "\n";
            }
        } else {
            print "No help available for $param\n";
            exit($pf::pfcmd::ERROR_CONFIG_NO_HELP);;
        }
    } elsif ( lc($option) eq 'set' ) {
        if ( !defined( $Config{$section}{$parm} ) ) {
            print "Unknown configuration parameter $section.$parm!\n";
            exit($pf::pfcmd::ERROR_CONFIG_UNKNOWN_PARAM);
        } else {

            #write out the local config only - with the new value.
            if ( defined( $myconfig{$section}{$parm} ) ) {
                if (   ( !defined( $myconfig{$section}{$param} ) )
                    || ( $defaults{$section}{$parm} ne $value ) )
                {
                    tied(%myconfig)->setval( $section, $parm, $value );
                } else {
                    tied(%myconfig)->delval( $section, $parm );
                }
            } elsif ( $defaults{$section}{$parm} ne $value ) {
                tied(%myconfig)->newval( $section, $parm, $value );
            }
            tied(%myconfig)->WriteConfig( $conf_dir . "/pf.conf" )
                or $logger->logdie("Unable to write config to $conf_dir/pf.conf. "
                    ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
            require pf::configfile;
            import pf::configfile;
            configfile_import( $conf_dir . "/pf.conf" );
        }
    }
}

#
# run reports
#
sub report {
    require pf::pfcmd::report;
    import pf::pfcmd::report;
    my $option = $cmd{command}[0];
    my $service;
    $service = $cmd{command}[1] if ( defined $cmd{command}[1] );
    my $type;
    if ( ( defined $cmd{command}[2] ) && ( $cmd{command}[2] ne '' ) ) {
        $type = $cmd{command}[2];
    } else {
        $type = 'all';
    }
    exit( print_results( "report_" . $service . "_" . $type ) );
}

sub configfiles {
    my $option = $cmd{command}[1];
    require pf::configfile;
    import pf::configfile;
    if ( $option eq "push" ) {
        configfile_import( $conf_dir . '/pf.conf' );
        configfile_import( $conf_dir . '/log.conf' );
        configfile_import( $conf_dir . '/switches.conf' );
        configfile_import( $conf_dir . '/violations.conf' );
        configfile_import( $network_config_file );
        configfile_import( $conf_dir . '/ui.conf' );
        configfile_import( $conf_dir . '/floating_network_device.conf' );
    } elsif ( $option eq "pull" ) {
        configfile_export( $conf_dir . '/pf.conf' );
        configfile_export( $conf_dir . '/log.conf' );
        configfile_export( $conf_dir . '/switches.conf' );
        configfile_export( $conf_dir . '/violations.conf' );
        configfile_export( $network_config_file );
        configfile_export( $conf_dir . '/ui.conf' );
        configfile_export( $conf_dir . '/floating_network_device.conf' );
    }
    exit;
}

#
#
#
sub reload {
    my $option = $cmd{command}[1];
    if ( $option eq "fingerprints" ) {
        require pf::os;
        my $fp_total = pf::os::import_dhcp_fingerprints({ force => $TRUE });
        $logger->info("$fp_total DHCP fingerprints reloaded");
        print "$fp_total DHCP fingerprints reloaded\n";
    } elsif ( $option eq "violations" ) {
        require pf::services;
        pf::services::read_violations_conf();
        $logger->info("Violation classes reloaded");
        print "Violation classes reloaded\n";
    }
    exit;
}

sub update {
    my $option = $cmd{command}[1];
    require LWP::UserAgent;
    my $browser = LWP::UserAgent->new;
    if ( $option eq "fingerprints" ) {
        my $response = $browser->get($dhcp_fingerprints_url);
        if ( !$response->is_success ) {
            $logger->logdie( "Unable to update DHCP fingerprints: "
                    . $response->status_line );
        } else {
            my ($fingerprints_fh);
            open( $fingerprints_fh, '>', "$dhcp_fingerprints_file" )
                || $logger->logdie(
                "Unable to open $dhcp_fingerprints_file: $!");
            my $fingerprints = $response->content;
            my ($version)
                = $fingerprints
                =~ /^#\s+dhcp_fingerprints.conf:\s+(version.+?)\n/;
            print $fingerprints_fh $fingerprints;
            close($fingerprints_fh);
            $logger->info(
                "DHCP fingerprints updated via $dhcp_fingerprints_url to $version"
            );
            print
                "DHCP fingerprints updated via $dhcp_fingerprints_url to $version\n";
            require pf::os;
            my $fp_total = pf::os::import_dhcp_fingerprints({ force => $TRUE });
            $logger->info("$fp_total DHCP fingerprints reloaded");
            print "$fp_total DHCP fingerprints reloaded\n";
        }
    } elsif ( $option eq "oui" ) {
        my $response = $browser->get($oui_url);
        if ( !$response->is_success ) {
            $logger->logdie(
                "Unable to update OUI prefixes: " . $response->status_line );
        } else {
            my ($oui_fh);
            open( $oui_fh, '>', "$oui_file" )
                || $logger->logdie("Unable to open $oui_file: $!");
            print $oui_fh $response->content;
            close($oui_fh);
            $logger->info("OUI prefixes updated via $oui_url");
            print "OUI prefixes updated via $oui_url\n";
        }
    }
    exit;
}

sub graph {
    my $graph = $cmd{command}[1];
    if (   ( $graph ne 'ifoctetshistoryuser' )
        && ( $graph ne 'ifoctetshistorymac' )
        && ( $graph ne 'ifoctetshistoryswitch' ) )
    {
        require pf::pfcmd::graph;
        import pf::pfcmd::graph;
        my $interval;
        if ( defined $cmd{command}[2] ) {
            $interval = $cmd{command}[2];
        } else {
            $interval = "day";
        }
        exit( print_graph_results( \&{"main::graph_$graph"}, $interval ) );
    } else {
        require pf::ifoctetslog;
        import pf::ifoctetslog;
        my %params;
        $params{'start_time'} = str2time( $cmd{command}[-2] );
        $params{'end_time'}   = str2time( $cmd{command}[-1] );
        my @results;
        if ( $graph eq 'ifoctetshistoryuser' ) {
            @results = ifoctetslog_graph_user( $cmd{command}[2], %params );
        } elsif ( $graph eq 'ifoctetshistorymac' ) {
            @results = ifoctetslog_graph_mac( $cmd{command}[2], %params );
        } elsif ( $graph eq 'ifoctetshistoryswitch' ) {
            $params{'ifIndex'} = $cmd{command}[3];
            @results
                = ifoctetslog_graph_switchport( $cmd{command}[2], %params );
        }
        print "count|mydate|series\n";
        foreach my $set (@results) {
            print $set->{'throughPutIn'} . "|" . $set->{'mydate'} . "|in\n";
            print $set->{'throughPutOut'} . "|" . $set->{'mydate'} . "|out\n";
        }
    }
}

sub lookup {
    my $option  = $cmd{command}[0];
    my $service = $cmd{command}[1];
    my $id      = $cmd{command}[2];

    push @INC, $bin_dir;
    if ( $service eq 'person' ) {
        require pf::person;
        import pf::person;
        require pf::lookup::person;
        my $tmp_lookup = pf::lookup::person::lookup_person($id);
        print $tmp_lookup;
    } else {
        require pf::lookup::node;
        my $tmp_lookup = pf::lookup::node::lookup_node($id);
        print $tmp_lookup;
    }
}

#
# parse ui.conf config file
#
sub ui {
    my $service  = $cmd{command}[1];
    my $option   = $cmd{command}[2];
    my $interval = $cmd{command}[3];
    if ( $service eq "menus" ) {

        Readonly my %table2key => (
            'person'    => 'pid',
            'node'      => 'mac',
            'violation' => 'id',
            'class'     => 'vid',
            'trigger'   => 'trigger',
            'scan'      => 'id',
        );

        # TODO: remove this test when we will reactivate Scan from web admin, it is no longer valid
        # check if Net::Nessus::ScanLite is installed
        my $scanLiteInstalled = 1;
        eval 'use Net::Nessus::ScanLite';
        if ($@) {
            $scanLiteInstalled = 0;
        }

        # read in configuration file
        my %uiconfig;
        my $ui_conf_file = $conf_dir . "/ui.conf";
        if ( defined( $option ) ) {
            $ui_conf_file = $conf_dir . "/" . $option;
        }
        tie %uiconfig, 'Config::IniFiles', ( -file => $ui_conf_file )
            or $logger->logdie("Unable to open $ui_conf_file: $!");

        my $string;
        foreach my $section ( tied(%uiconfig)->Sections ) {
            my @array = split( /\./, $section );
            my $service;
            $service = $array[1] if ( $array[1] );

            # don't show scan menu if feature is not installed
            next if ( ( defined $service ) && ( $service eq "scan" ) && ( !$scanLiteInstalled ) );

            $string .= join( "|", @array ) . "|";
            my @keys;

            foreach
                my $key ( split( /\s*,\s*/, $uiconfig{$section}{'display'} ) )
            {
                my $key2;
                if (   defined $service
                    && defined( $table2key{$service} )
                    && $table2key{$service} eq $key )
                {
                    $key2 = $key . "*";
                } else {
                    $key2 = $key;
                }
                $key =~ s/^-//;
                # don't show scan menu if feature is not installed
                next if ( ( $key eq "scan" ) && ( !$scanLiteInstalled ) );

                if ( defined $uiconfig{$section}{$key} ) {
                    push @keys, "$key2='$uiconfig{$section}{$key}'";
                } else {
                    push @keys, "$key2='$key2'";
                }
            }
            $string .= join( ":", @keys ) . "\n";
        }
        print $string;
    } elsif ( $service eq "dashboard" ) {
        require pf::pfcmd::dashboard;
        import pf::pfcmd::dashboard;
        $interval = 3 unless ($interval);
        exit( print_results( "nugget_" . $option, $interval ) );
    } else {
        require pf::pfcmd::help;
        pf::pfcmd::help::usage("help");
    }
}

#
# node,person,violation parser
#
# TODO: this method could be streamlined to remove all corner cases that grew in it over time
sub command_param {
    my ($type)  = @_;
    my $options = $type . "_options";
    my $option  = $cmd{$options}[0];
    my $id      = $cmd{$options}[1];

    # strip out the delimiter
    $id =~ s/$delimiter//g;
    my $function = $type;
    if ( $option eq "view" ) {
        $function .= "_view";
        $function .= "_all" if ( $id eq 'all' );
        my %params;

        #use Data::Dumper;
        #print Dumper(%cmd);
        if ( defined( $cmd{'orderby_options'} ) ) {
            $params{'orderby'} = 'order by ' . $cmd{'orderby_options'}[2];
            if ( scalar( @{ $cmd{'orderby_options'} } ) == 4 ) {
                $params{'orderby'} .= " " . $cmd{'orderby_options'}[3];
            }
        }
        if ( defined( $cmd{'limit_options'} ) ) {
            $params{'limit'}
                = 'limit '
                . $cmd{'limit_options'}[1] . ','
                . $cmd{'limit_options'}[3];
        }
        if ( defined( $cmd{'node_filter'} ) ) {
            $function .= "_all";
            $params{'where'}{'type'}  = $cmd{'node_filter'}[0];
            $params{'where'}{'value'} = $cmd{'node_filter'}[1];
        }
        exit( print_results( $function, $id, %params ) );
        return (0);
    } elsif ( $option eq "count" ) {
        $function .= "_count_all";
        my %params;
        if ( defined( $cmd{'node_filter'} ) ) {
            $params{'where'}{'type'}  = $cmd{'node_filter'}[0];
            $params{'where'}{'value'} = $cmd{'node_filter'}[1];
        }
        exit( print_results( $function, $id, %params ) );
        return (0);
    } elsif ( $option eq "add" ) {
        $function .= "_add";
    } elsif ( $option eq "edit" ) {
        $function .= "_modify";
    } elsif ( $option eq "delete" ) {
        $function .= "_delete";
    } else {
        usage("param");
    }

    my $assignment  = $type . "_assignment";
    my %params      = format_assignment( @{ $cmd{$assignment} } );
    my $returnValue = 0;
    if ( ( $function eq "node_modify" ) || ( $function eq "node_add" ) ) {
        $id = lc($id);
    }

    #print Dumper(%params);
    # run update/or delete  and check return val
    if ( $function eq "violation_add" ) {
        # test coderef existence
        if (!exists(&{$main::{$function}})) {
            print "No such sub: $function at line ".__LINE__.".\n";
        } else {
            # execute coderef main::$function sub
            $logger->info( "pfcmd calling $function for " . $params{mac} );
            &{$main::{$function}}($params{mac}, $params{vid}, %params);
        }
    } else {
        if ( $function eq "violation_delete" ) {
            my @violation_data = violation_view($id);
            if ( scalar(@violation_data) == 1 ) {
                $params{mac} = $violation_data[0]->{'mac'};
            } else {
                $params{mac} = '';
            }
        } elsif ( $function eq "violation_modify" ) {
            if ( ( !exists( $params{'mac'} ) ) || ( $params{'mac'} eq '' ) ) {
                my @violation_data = violation_view($id);
                if ( scalar(@violation_data) == 1 ) {
                    $params{mac} = $violation_data[0]->{'mac'};
                } else {
                    $params{mac} = '';
                }
            }
        }
        # test coderef existence
        if (!exists(&{$main::{$function}})) {
            print "No such sub: $function at line ".__LINE__.".\n";
        } else {

            # execute coderef main::$function sub
            $logger->info("pfcmd calling $function for $id");
            $returnValue = &{$main::{$function}}($id, %params);
        }
    }
    if ( $returnValue != 2 ) {

        #print "$function updated\n";
        if ( $function =~ /^person_add|person_modify$/ ) {
            $logger->debug(
                "$function was called - we don't need to recalculate iptables and switchport VLAN assignments"
            );
        } else {
            # TODO proper exception framework please?
            if ( ($function =~ /^node_delete$/) and ($returnValue == 0) ) {
                $logger->logdie("Cannot delete this node since there are some records in locationlog table "
                    . "indicating that this node might still be connected and active on the network "
                    . "(pfcmd line ".__LINE__.".)"
                );
            } elsif ( ($function =~ /^person_delete$/) and ($returnValue == 0) ) {
                $logger->logdie(
                    "Cannot delete this person since there are some nodes associated to it. (pfcmd line ".__LINE__.".)"
                );
            }

            if (    ($function eq 'violation_add')
                 || ( $function eq 'violation_delete' ) 
                 || ( $function eq 'violation_modify' ) ) {
                pf::enforcement::reevaluate_access( $params{mac}, $function );
            } else {
                pf::enforcement::reevaluate_access( $id, $function );
            }
        }
        return (0);
    } else {
        if ( $function =~ /^node_add$/ ) {
            print "Error adding a node: The node already exists. (pfcmd line ".__LINE__.")\n";
        } else {
            print "error: please consult log for more information\n";
        }
        return (2);
    }
}

#
# given a function name and a table will execute the function and correctly format the output
# example: print_results("node","node_view_all");
#
sub print_results {
    my ( $function, $key, %params ) = @_;
    my $total;
    my @results;
    # calling a function looked up dynamically: first test coderef existence
    my $functionName = "main::$function";
    if ( !defined(&$functionName) ) {
        print "No such sub $function at line ". __LINE__ .".\n";
    } else {
        # then execute the method (looking up using main::..)
        @results = &{$main::{$function}}($key, %params);
    }
    $total = scalar(@results);
    if ($count) {
        $offset = scalar(@results) if ( $offset > scalar(@results) );
        $count = scalar(@results) - $offset
            if ( $offset + $count > scalar(@results) );
        @results = splice( @results, $offset, $count );
    }

    my @fields = field_order();
    push @fields, keys( %{ $results[0] } ) if ( !scalar(@fields) );

    if ( scalar(@fields) ) {
        print join( $delimiter, @fields ) . "\n";
        foreach my $row (@results) {
            next
                if ( defined( $row->{'mydate'} )
                && $row->{'mydate'} =~ /^00/ );
            my @values = ();
            foreach my $field (@fields) {
                my $value = $row->{$field};
                if ( defined($value) && $value !~ /^0000-00-00 00:00:00$/ ) {

                    # little hack to reverse dates
                    if ( $value =~ /^(\d+)\/(\d+)$/ ) {
                        $value = "$2/$1";
                    } elsif ( $value =~ /^(\d+)\/(\d+)\/(\d+)$/ ) {
                        $value = "$2/$3/$1";
                    }
                    push @values, $value;
                } else {
                    push @values, "";
                }
            }
            print join( $delimiter, @values ) . "\n";
        }
    }
    return ($total);
}

# This function has dirtied my soul.  I beg forgiveness for the disgusting code that follows.
# I need a brillo pad and a long, long shower...

sub print_graph_results {
    my ( $function, $interval ) = @_;
    require Date::Parse;

    # TOTAL HACK, but we avoid using yet another module
    my %months = (
        "01" => "31",
        "02" => "28",
        "03" => "31",
        "04" => "30",
        "05" => "31",
        "06" => "30",
        "07" => "31",
        "08" => "31",
        "09" => "30",
        "10" => "31",
        "11" => "30",
        "12" => "31"
    );

    my @results;
    if ($function) {
        @results = $function->($interval);
    } else {
        print "No such sub $function\n";
        exit;
    }
    my %series;
    foreach my $result (@results) {
        next if ( $result->{'mydate'} =~ /0000/ );
        my $s = $result->{'series'};
        push( @{ $series{$s} }, $result );
    }
    my @fields = field_order();
    push @fields, keys( %{ $results[0] } ) if ( !scalar(@fields) );
    print join( "|", @fields ) . "\n";

    #determine first and last time in all series
    my $first_time = undef;
    my $last_time  = undef;
    foreach my $s ( keys(%series) ) {
        my $start_year;
        my $start_mon = 1;
        my $start_day = 1;
        my $end_year;
        my $end_mon = 1;
        my $end_day = 1;
        my @results = @{ $series{$s} };
        if ( $interval eq "day" ) {
            ( $start_year, $start_mon, $start_day )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon, $end_day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "month" ) {
            ( $start_year, $start_mon )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "year" ) {
            $start_year = $results[0]->{'mydate'};
            $end_year   = $results[ scalar(@results) - 1 ]->{'mydate'};
        }
        my $start_time = Date::Parse::str2time(
            "$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
        my $end_time = Date::Parse::str2time(
            "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
        if ( ( !defined($first_time) ) || ( $start_time < $first_time ) ) {
            $first_time = $start_time;
        }
        if ( ( !defined($last_time) ) || ( $end_time > $last_time ) ) {
            $last_time = $end_time;
        }
    }

    #add, if necessary, first and last time entries to all series
    foreach my $s ( keys(%series) ) {
        my $start_year;
        my $start_mon = 1;
        my $start_day = 1;
        my $end_year;
        my $end_mon = 1;
        my $end_day = 1;
        my @results = @{ $series{$s} };
        if ( $interval eq "day" ) {
            ( $start_year, $start_mon, $start_day )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon, $end_day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "month" ) {
            ( $start_year, $start_mon )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "year" ) {
            $start_year = $results[0]->{'mydate'};
            $end_year   = $results[ scalar(@results) - 1 ]->{'mydate'};
        }
        my $start_time = Date::Parse::str2time(
            "$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
        my $end_time = Date::Parse::str2time(
            "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
        if ( $start_time > $first_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($first_time) );
                } elsif ( $field eq "count" ) {
                    $new_record->{$field} = 0;
                } else {
                    $new_record->{$field}
                        = $results[ scalar(@results) - 1 ]->{$field};
                }
            }
            unshift( @{ $series{$s} }, $new_record );
        }
        if ( $end_time < $last_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($last_time) );
                } else {
                    $new_record->{$field}
                        = $results[ scalar(@results) - 1 ]->{$field};
                }
            }
            push( @{ $series{$s} }, $new_record );
        }
    }

    foreach my $s ( keys(%series) ) {
        my @results = @{ $series{$s} };
        my $year    = POSIX::strftime( "%Y", localtime );
        my $month   = POSIX::strftime( "%m", localtime );
        my $day     = POSIX::strftime( "%d", localtime );
        my $date;
        if ( $interval eq "day" ) {
            $date = "$year/$month/$day";
        } elsif ( $interval eq "month" ) {
            $date = "$year/$month";
        } elsif ( $interval eq "year" ) {
            $date = "$year";
        } else {
        }
        if ( $results[ scalar(@results) - 1 ]->{'mydate'} ne $date ) {
            my %tmp = %{ $results[ scalar(@results) - 1 ] };
            $tmp{'mydate'} = $date;
            push( @results, \%tmp );
        }
        push( @results, $results[0] ) if ( scalar(@results) == 1 );
        if ( $interval eq "day" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ( $start_year, $start_mon, $start_day )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon, $end_day )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $start_time
                    = Date::Parse::str2time(
                          "$start_year-$start_mon-$start_day"
                        . "T00:00:00.0000000" );
                my $end_time = Date::Parse::str2time(
                    "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
                for (
                    my $current_time = $start_time;
                    $current_time < $end_time;
                    $current_time += 86400
                    )
                {
                    my @values;
                    foreach my $field (@fields) {
                        if ( $field eq "mydate" ) {
                            push(
                                @values,
                                POSIX::strftime(
                                    "%m/%d/%Y", localtime($current_time)
                                )
                            );
                        } else {
                            push( @values, $results[$r]->{$field} );
                        }
                    }
                    print join( "|", @values ) . "\n";
                }
            }
            my ( $year, $mon, $day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $day ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            print join( "|", @values ) . "\n";

        } elsif ( $interval eq "month" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ( $start_year, $start_mon )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $mstart = $start_mon;
                for ( my $i = $start_year; $i <= $end_year; $i++ ) {
                    my $mend;
                    if ( $i == $end_year ) {
                        $mend = $end_mon;
                    } else {
                        $mend = "12";
                    }
                    for ( my $ii = $mstart; $ii <= $mend; $ii++ ) {
                        if ( !( $i == $end_year && $ii == $end_mon ) ) {
                            my @values;
                            foreach my $field (@fields) {
                                if ( $field eq "mydate" ) {
                                    push(
                                        @values,
                                        join( "/",
                                            sprintf( "%02d", $ii ),
                                            sprintf( "%02d", $i ) )
                                    );
                                } else {
                                    push( @values, $results[$r]->{$field} );
                                }
                            }
                            print join( "|", @values ) . "\n";
                        }
                    }
                    $mstart = 1;
                }
            }
            my ( $year, $mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            print join( "|", @values ) . "\n";
        } elsif ( $interval eq "year" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ($start_year) = $results[$r]->{'mydate'};
                my ($end_year)   = $results[ $r + 1 ]->{'mydate'};
                for ( my $i = $start_year; $i <= $end_year; $i++ ) {
                    if ( !( $i == $end_year ) ) {
                        my @values;
                        foreach my $field (@fields) {
                            if ( $field eq "mydate" ) {
                                push( @values, sprintf( "%02d", $i ) );
                            } else {
                                push( @values, $results[$r]->{$field} );
                            }
                        }
                        print join( "|", @values ) . "\n";
                    }
                }
            }
            my ($year) = $results[ scalar(@results) - 1 ]->{'mydate'};
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push( @values, sprintf( "%02d", $year ) );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            print join( "|", @values ) . "\n";
        }
    }
}

#
# format a hash of assignments based on the grammar
# example: format_assignment($cmd{node_assignment});
#
sub format_assignment {
    my @fields = @_;
    my ( @columns, @values, @assignment, %return );
    foreach my $array (@fields) {
        my $column     = $array->[0];
        my $value      = $array->[1];
        my $assignment = $array->[2];
        $column =~ s/$delimiter//g;
        $value  =~ s/$delimiter//g;
        $return{$column} = $value;
    }
    return (%return);
}

sub field_order {
    return pf::config::ui->instance->field_order("@ARGV");
}

=head1 AUTHOR

Dave Laporte <dave@laportestyle.org>

Kevin Amorin <kev@amorin.org>

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 Dave Laporte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2008-2012 Inverse inc.

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

