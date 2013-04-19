package pf::pfcmd;

=head1 NAME

pf::pfcmd - module for the PacketFence command line interface.

=cut

=head1 DESCRIPTION

pf::pfcmd contains the functions necessary for the command line interface
F</usr/local/pf/bin/pfcmd> to parse the options.

=cut
use strict;
use warnings;

use Log::Log4perl;
use Readonly;
use Regexp::Common qw(net);

# some constants used by pfcmd

# exit status
Readonly our $ERROR_CONFIG_UNKNOWN_PARAM => 10;
Readonly our $ERROR_CONFIG_NO_HELP => 11;

# if you change something here, make sure
#   - not to allow unquoted stuff interpreted by the shell
#   - update the appropriate regexp in lib/pfcmd/pfcmd.pm grammar too
#   - update the generic pid regex in pf::person (not meant for shell safety)
# TODO try to consolidate what we should accept as a pid
my $pid_re = qr{(?: 
    ( [a-zA-Z0-9\-\_\.\@\/\:\+\!,]+ )                               # unquoted allowed
    |                                                               # OR
    \" ( [&=?\(\)\/,0-9a-zA-Z_\*\.\-\:\;\@\ \+\!\^\[\]\|\#\\]+ ) \" # quoted allowed
)}xo;

sub parseCommandLine {
    my ($commandLine) = @_;
    my $logger = Log::Log4perl::get_logger("pf::pfcmd");
    $logger->debug("starting to parse '$commandLine'");

    $commandLine =~ s/\s+$//;
    my ($main, $params) = split( / +/, $commandLine, 2 );
    #make sure params contains at least an empty string
    $params = '' if (! defined($params));

    my %regexp = (
        'checkup'         => qr{ ^ $ }xms,
        'class'           => qr{ ^ (view) \s+ ( all | \d+ ) $ }xms,
        'config'          => qr{ ^ ( get | set | help )
                                   \s+
                                   ( [ a-zA-Z0-9_@\.\:=/\-,?]+)
                                 $ }xms,
        'configfiles'     => qr{ ^ ( push | pull ) $ }xms,
        'fingerprint'     => qr{ ^ (view) 
                                   \s+ 
                                   ( all | \d+ (?: ,\d+)* ) 
                                 $ }xms,
        'floatingnetworkdeviceconfig'
                          => qr/ ^ ( get | delete )
                                   \s+
                                   ( all | $RE{net}{MAC} | stub )
                                 $  /xms,
        'graph'           => qr/ ^ (?:
                                     ( nodes | registered
                                       | unregistered
                                       | violations ) 
                                     (?:
                                       \s+
                                       ( day | month | year )
                                     )?
                                     |
                                     ( ifoctetshistorymac )
                                     \s+
                                     ( $RE{net}{MAC} )
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )
                                     \s* [,] \s*
                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                     |
                                     ( ifoctetshistoryswitch )
                                     \s+
                                     ( $RE{net}{IPv4} )
                                     \s+
                                     ( \d+)
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )
                                     \s* [,] \s*
                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                     |
                                     ( ifoctetshistoryuser )
                                     \s+
                                     ( [a-zA-Z0-9\-\_\.\@]+ )
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )
                                     \s* [,] \s*
                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                   )
                                 $ /xms,
        'help'            => qr{ ^ ( [a-z]* ) $ }xms,
        'history'         => qr/ ^
                                   ( $RE{net}{IPv4} | $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     ( [^,=]+ )
                                   )?
                                 $ /xms,
        'ifoctetshistorymac' => qr/ ^
                                   ( $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )

                                     \s* [,] \s*

                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                   )?
                                 $ /xms,
        'ifoctetshistoryswitch' => qr/ ^
                                   ( $RE{net}{IPv4} )
                                   \s+
                                   ( \d+)
                                   (?:
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )

                                     \s* [,] \s*

                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                   )?
                                 $ /xms,
        'ifoctetshistoryuser' => qr{ ^
                                   ( [a-zA-Z0-9\-\_\.\@]+ )
                                   (?:
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )

                                     \s* [,] \s*

                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                   )?
                                 $ }xms,
        'import' => qr{ ^ 
                            ( nodes )                # import nodes
                            \s+
                            ( [a-zA-Z0-9_\-\.\/]+ )   # strict filename with path regexp
                        $  }xms,
        'interfaceconfig' => qr{ ^ ( get | delete )
                                   \s+
                                   ( all | [a-z0-9\.\:]+ )
                                 $  }xms,
        'ipmachistory'    => qr/ ^
                                   ( $RE{net}{IPv4} | $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )

                                     \s* [,] \s*

                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                   )?
                                 $ /xms,
        'locationhistorymac' => qr/ ^
                                   ( $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     ( [^,=]+ )
                                   )?
                                 $ /xms,
        'locationhistoryswitch' => qr/ ^
                                   ( $RE{net}{IPv4} )
                                   \s+
                                   ( \d+ )
                                   (?:
                                     \s+
                                     ( [^,=]+ )
                                   )?
                                 $ /xms,
        'lookup'          => qr{ ^(?: 
                                       ( person ) \s+ $pid_re
                                   | 
                                       ( node ) \s+ ( $RE{net}{MAC} )
                                 )$  }xms,
        'manage'          => qr/ ^ 
                                   (?:
                                     ( deregister )
                                     \s+
                                     ( $RE{net}{MAC} )
                                     |
                                     ( vclose | vopen )
                                     \s+
                                     ( $RE{net}{MAC} )
                                     \s+
                                     ( \d+ )
                                   )
                                 $ /xms,
        'networkconfig'   => qr/ ^ ( get | delete )
                                   \s+
                                   ( all | $RE{net}{IPv4} )
                                 $  /xms,
        'node'            => qr/ ^ (?:
                                     ( view )
                                     \s+
                                     (?: 
                                         ( all ) 
                                       | ( $RE{net}{MAC} ) 
                                         # TODO be more strict on category names (but no time now)
                                       | (?: ( category | pid  ) \s* [=] \s* $pid_re )
                                     )
                                     (?:
                                       \s+ ( order ) \s+ ( by )
                                       \s+ ( [a-z0-9_]+ )
                                       (?: \s+ ( asc | desc ))?
                                     )?
                                     (?:
                                       \s+ ( limit )
                                       \s+ ( \d+ )
                                       \s* [,] \s*
                                       ( \d+ )
                                     )?
                                     |
                                     ( count )
                                     \s+
                                     (?: 
                                         ( all ) 
                                       | ( $RE{net}{MAC} ) 
                                         # TODO be more strict on category names (but no time now)
                                       | (?: ( category | pid  ) \s* [=] \s* $pid_re )
                                     )
                                     |
                                     ( delete )
                                     \s+ ( $RE{net}{MAC} )
                                   )
                                 $ /xms,
         'nodeaccounting'   => qr/ ^ ( view )
                                   \s+
                                   (?:
                                       ( all ) 
                                       | ( $RE{net}{MAC} )
                                   )
                                 $ /xms,
         'nodecategory'    => qr{ ^ (?:
                                     (view) \s+ (all|\d+)
                                   )
                                   |
                                   (?:
                                     (delete) \s+ (\s+)
                                   )
                                 $  }xms,
        'nodeuseragent'   => qr{ ^ (view) 
                                   \s+ 
                                   ( all | \d+ (?: ,\d+)* ) 
                                 $ }xms,
        'person'          => qr{ ^ (view)
                                   \s+
                                   (?: 
                                       ( all ) | $pid_re
                                   )
                                 $ }xms,
        'reload'          => qr{ ^ ( fingerprints | violations ) $  }xms,
        'report'          => qr{ ^ (?: #for grouping only
                                     ( active | inactive | openviolations 
                                       | os | osclass | registered | statics | ssid
                                       | unknownprints | unknownuseragents | unregistered
                                       | connectiontype | connectiontypereg | osclassbandwidth
                                       | nodebandwidth
                                     )
                                     |
                                     (?: #for grouping only
                                       ( openviolations | os | osclass 
                                         | registered | statics | ssid
                                         | unknownprints | unknownuseragents | unregistered 
                                         | connectiontype | connectiontypereg
                                       )
                                       \s+
                                       ( all | active )
                                     )
                                     |
                                     (?: #for grouping only
                                       ( osclassbandwidth ) \s+ ( all | day | week | month | year )
                                     )
                                   )
                                 $  }xms,
        'schedule'        => qr{ ^ (?:
                                     ( view )
                                     \s+
                                     ( all | \d+ )
                                     |
                                     ( delete )
                                     \s+
                                     ( \d+ )
                                   )
                                 $ }xms,
        'service'         => qr{ ^ ( dhcpd | httpd | pfdns | pfdetect 
                                     | pf | pfdhcplistener | pfmon 
                                     | pfsetvlan | radiusd | snmptrapd 
                                     | snort | suricata | httpd\.webservices | httpd\.admin | httpd\.portal)
                                   \s+
                                   ( restart | start | status | stop
                                     | watch )
                                 $  }xms,
        'switchconfig'    => qr/ ^ ( get | delete ) 
                                   \s+
                                   ( all | default | $RE{net}{IPv4} )
                                 $  /xms,
        'switchlocation'  => qr/ ^ ( view )
                                   \s+
                                   ($RE{net}{IPv4})
                                   \s+
                                   (\d+)
                                 $  /xms,
        'traplog'         => qr{ ^ (?:
                                     ( update )
                                     |
                                     (?:
                                       most \s+
                                       ( \d+ ) \s+
                                       ( day | week | total )
                                     )
                                   )
                                 $ }xms,
        'trigger'         => qr{ ^ ( view ) 
                                   \s+
                                   ( all | \d+ )
                                   (?:
                                     \s+
                                     ( scan | detect )
                                   )?
                                 $ }xms,
        'ui'              => qr{ ^ 
                                   (?:
                                     (?:
                                       ( dashboard )
                                       \s+
                                       ( current_grace | current_activity 
                                         | current_node_status )
                                     )
                                     |
                                     (?:
                                       ( dashboard )
                                       \s+
                                       ( recent_violations_opened
                                         | recent_violations_closed
                                         | recent_violations
                                         | recent_registrations )
                                       (?:
                                         \s+ ( \d+ )
                                       )?
                                     )
                                     |
                                     (?:
                                       ( menus )
                                       (?:
                                         \s+ file \s* [=] \s* 
                                         ( [a-zA-Z\-_.]+ )
                                       )?
                                     )
                                   )
                                 $  }xms,
        'update'          => qr{ ^ ( fingerprints | oui ) $  }xms,
        'useragent'       => qr{ ^ (view) 
                                   \s+ 
                                   ( all | \d+ ) 
                                 $ }xms,
        'version'         => qr{ ^ $ }xms,
        'violation'       => qr{ ^ ( view )
                                   \s+
                                   ( all | \d+ )
                                 $ }xms,
        'violationconfig' => qr{ ^ ( get | delete )
                                   \s+
                                   ( all | defaults | \d+ )
                                 $  }xms,
    );
    $logger->debug("main cmd argument is " . ($main || 'undefined'));
    if ( defined($main) && exists($regexp{$main}) ) {
        my %cmd;
        if ($params =~ $regexp{$main}) {
            $cmd{'command'}[0] = $main;
            push @{$cmd{'command'}}, $1 if (defined($1));
            push @{$cmd{'command'}}, $2 if (defined($2));
            push @{$cmd{'command'}}, $3 if (defined($3));
            push @{$cmd{'command'}}, $4 if (defined($4));
            push @{$cmd{'command'}}, $5 if (defined($5));
            push @{$cmd{'command'}}, $6 if (defined($6));
            push @{$cmd{'command'}}, $7 if (defined($7));
            push @{$cmd{'command'}}, $8 if (defined($8));
            push @{$cmd{'command'}}, $9 if (defined($9));
            push @{$cmd{'command'}}, $10 if (defined($10));
            push @{$cmd{'command'}}, $11 if (defined($11));
            push @{$cmd{'command'}}, $12 if (defined($12));
            push @{$cmd{'command'}}, $13 if (defined($13));
            push @{$cmd{'command'}}, $14 if (defined($14));
            push @{$cmd{'command'}}, $15 if (defined($15));
            push @{$cmd{'command'}}, $16 if (defined($16));
            push @{$cmd{'command'}}, $17 if (defined($17));
            push @{$cmd{'command'}}, $18 if (defined($18));
            push @{$cmd{'command'}}, $19 if (defined($19));
            push @{$cmd{'command'}}, $20 if (defined($20));
            push @{$cmd{'command'}}, $21 if (defined($21));
            if ($main eq 'manage') {
                push @{$cmd{'manage_options'}}, $cmd{'command'}[1];
                push @{$cmd{'manage_options'}}, $cmd{'command'}[2];
                push @{$cmd{'manage_options'}}, $cmd{'command'}[3] if ($cmd{'command'}[3]);
            }
            if ($main eq 'node') {
                push @{$cmd{'node_options'}}, $cmd{'command'}[1];
                push @{$cmd{'node_options'}}, $cmd{'command'}[2];
                if ($cmd{'command'}[1] eq 'view') {
                    if (defined($4)) {
                        # node filter is either capture 5 or 6 (with or without quotes)
                        push @{$cmd{'node_filter'}}, ($4, $5 ? $5 : $6);
                    }
                    if (defined($7)) {
                        push @{$cmd{'orderby_options'}}, ($7, $8, $9, $10);
                    }
                    if (defined($11)) {
                        push @{$cmd{'limit_options'}}, ($11, $12, ',', $13);
                    }
                }
                if ($cmd{'command'}[1] eq 'count') {
                    if (defined($17)) {
                        # node filter is either capture 18 or 19 (with or without quotes)
                        push @{$cmd{'node_filter'}}, ($17, $18 ? $18 : $19);
                    }
                }
            }
            if ($main eq 'nodecategory') {
                push @{$cmd{'nodecategory_options'}}, $cmd{'command'}[1];
                push @{$cmd{'nodecategory_options'}}, $cmd{'command'}[2];
            }
            if ($main eq 'person') {
                push @{$cmd{'person_options'}}, $cmd{'command'}[1];
                push @{$cmd{'person_options'}}, $cmd{'command'}[2];
            }
            if ($main eq 'schedule') {
                push @{$cmd{'schedule_options'}}, $cmd{'command'}[1];
                push @{$cmd{'schedule_options'}}, $cmd{'command'}[2];
            }
            if ($main eq 'violation') {
                push @{$cmd{'violation_options'}}, $cmd{'command'}[1];
                push @{$cmd{'violation_options'}}, $cmd{'command'}[2];
            }
        } else {
            if ($main =~ m{ ^ (?:
                            node | person | interfaceconfig | networkconfig
                            | switchconfig | violationconfig | violation
                            | manage | schedule | nodecategory
                            | floatingnetworkdeviceconfig
                              ) $ }xms ) {
                return parseWithGrammar($commandLine);
            }
            @{$cmd{'command'}} = ('help', $main);
        }
        return %cmd;
    }
    
    return parseWithGrammar($commandLine);
}


sub parseWithGrammar {
    my ($commandLine) = @_;
    require pf::pfcmd::pfcmd_pregrammar;
    import pf::pfcmd::pfcmd_pregrammar;
    my $parser = pfcmd_pregrammar->new();

    my $result = $parser->start($commandLine);
    my %cmd;
    $cmd{'grammar'} = ( defined($result) ? 1 : 0 );
    return %cmd;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
