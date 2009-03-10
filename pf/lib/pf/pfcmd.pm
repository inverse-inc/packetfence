#
# Copyright 2009 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#

package pf::pfcmd;

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use Regexp::Common qw(net);

sub parseCommandLine {
    my ($commandLine) = @_;
    my $logger = Log::Log4perl::get_logger("pf::pfcmd");
    $logger->info("starting to parse '$commandLine'");

    $commandLine =~ s/\s+$//;
    my ($main, $params) = split( / +/, $commandLine, 2 );
    #make sure params contains at least an empty string
    $params = '' if (! defined($params));

    my %regexp = (
        'class'           => qr{ ^ (view) \s+ ( all | \d+ ) $ }xms,
        'config'          => qr{ ^ ( get | set | help )
                                   \s+
                                   ( [a-zA-Z0-9_\.\:=]+)
                                 $ }xms,
        'configfiles'     => qr{ ^ ( push | pull ) $ }xms,
        'fingerprint'     => qr{ ^ (view) 
                                   \s+ 
                                   ( all | \d+ (?: ,\d+)* ) 
                                 $ }xms,
        'graph'           => qr{ ^ (?:
                                     ( nodes | registered
                                       | unregistered
                                       | violations ) 
                                     (?:
                                       \s+
                                       ( day | month | year )
                                     )?
                                   )
                                 $ }xms,
        'help'            => qr{ ^ ( [a-z]* ) $ }xms,
        'history'         => qr{ ^
                                   ( $RE{net}{IPv4} | $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     ( [^,=]+ )
                                   )?
                                 $ }xms,
        'ifoctetshistorymac' => qr{ ^
                                   ( $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     start_time \s* [=] \s*
                                     ( [^,=]+ )

                                     \s* [,] \s*

                                     end_time \s* [=] \s*
                                     ( [^,=]+ )
                                   )?
                                 $ }xms,
        'interfaceconfig' => qr{ ^ ( get | delete )
                                   \s+
                                   ( all | [a-z0-9\.\:]+ )
                                 $  }xms,
        'locationhistorymac' => qr{ ^
                                   ( $RE{net}{MAC} )
                                   (?:
                                     \s+
                                     ( [^,=]+ )
                                   )?
                                 $ }xms,
        'locationhistoryswitch' => qr{ ^
                                   ( $RE{net}{IPv4} )
                                   \s+
                                   ( \d+ )
                                   (?:
                                     \s+
                                     ( [^,=]+ )
                                   )?
                                 $ }xms,
        'lookup'          => qr{ ^ ( person | node ) 
                                   \s+
                                   ( [0-9a-zA-Z_\-\.\:]+ )
                                 $  }xms,
        'manage'          => qr{ ^ 
                                   (?:
                                     ( freemac | deregister )
                                     \s+
                                     ( $RE{net}{MAC} )
                                     |
                                     ( vclose | vopen )
                                     \s+
                                     ( $RE{net}{MAC} )
                                     \s+
                                     ( \d+ )
                                   )
                                 $ }xms,
        'networkconfig'   => qr/ ^ ( get | delete )
                                   \s+
                                   ( all | $RE{net}{IPv4} )
                                 $  /xms,
        'nodecategory'    => qr{ ^ (view) \s+ (\w+) $  }xms,
        'reload'          => qr{ ^ ( fingerprints | violations ) $  }xms,
        'report'          => qr{ ^ (?: #for grouping only
                                     ( active | inactive | openviolations 
                                       | os | osclass | registered | statics 
                                       | unknownprints | unregistered )
                                     |
                                     (?: #for grouping only
                                       ( openviolations | os | osclass 
                                         | registered | statics
                                         | unknownprints | unregistered 
                                       )
                                       \s+
                                       ( all | active )
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
        'service'         => qr{ ^ ( dhcpd | httpd | named | pfdetect 
                                     | pf | pfdhcplistener | pfmon 
                                     | pfredirect | pfsetvlan | snmptrapd 
                                     | snort )
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
        'version'         => qr{ ^ $ }xms,
        'violationconfig' => qr{ ^ ( get | delete )
                                   \s+
                                   ( all | defaults | \d+ )
                                 $  }xms,
    );
    $logger->info("main is $main");
    if ( exists($regexp{$main}) ) {
        my %cmd;
        if ($params =~ $regexp{$main}) {
            $cmd{'command'}[0] = $main;
            push @{$cmd{'command'}}, $1 if ($1);
            push @{$cmd{'command'}}, $2 if ($2);
            push @{$cmd{'command'}}, $3 if ($3);
            push @{$cmd{'command'}}, $4 if ($4);
            push @{$cmd{'command'}}, $5 if ($5);
            push @{$cmd{'command'}}, $6 if ($6);
            push @{$cmd{'command'}}, $7 if ($7);
            push @{$cmd{'command'}}, $8 if ($8);
            if ($main eq 'manage') {
                push @{$cmd{'manage_options'}}, $cmd{'command'}[1];
                push @{$cmd{'manage_options'}}, $cmd{'command'}[2];
                push @{$cmd{'manage_options'}}, $cmd{'command'}[3] if ($cmd{'command'}[3]);
            }
            if ($main eq 'schedule') {
                push @{$cmd{'schedule_options'}}, $cmd{'command'}[1];
                push @{$cmd{'schedule_options'}}, $cmd{'command'}[2];
            }
            use Data::Dumper;
            $logger->info("returning " . Dumper(%cmd));
        } else {
            if ($main =~ m{ ^ (?:
                            node | person | interfaceconfig | networkconfig
                            | switchconfig | violationconfig | violation
                            | manage | graph | schedule | 
                            | ifoctetshistoryswitch 
                            | ifoctetshistoryuser | ipmachistory
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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
