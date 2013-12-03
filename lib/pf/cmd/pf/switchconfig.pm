package pf::cmd::pf::switchconfig;
=head1 NAME

pf::cmd::pf::switchconfig add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::switchconfig

=cut

use strict;
use warnings;
use pf::log;
use pf::file_paths;
use base qw(pf::base::cmd::action_cmd);

sub action_get {
    my ($self) = @_;
    my ($action,$id) = $self->args;
}

sub parse_get {
    my ($self) = @_;
    my ($action,$id) = $self->args;
    return defined $id;
}

sub action_add {
    my ($self) = @_;
    print "add\n";
}

sub action_delete {
    my ($self) = @_;
    my ($action,$id) = $self->args;
    require pf::ConfigStore::Switch;
    require pf::configfile;
    my $config = pf::ConfigStore::Switch->new;
    if($config->remove($id)) {
        $config->commit();
        pf::configfile::configfile_import($switches_config_file);
        print "\"$id\" succesfully deleted\n";
    } else {
        print STDERR "\"$id\" switch can't be deleted\n";
    }
}

sub parse_delete {
    my ($self) = @_;
    my ($action,$id) = $self->args;
    return defined $id;
}

sub action_edit {
    my ($self) = @_;
    my ($action,$id) = $self->args;
}

sub switchconfig {
    my %cmd;
    my $delimiter;
    my $logger = get_logger();
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
        delete $switches_conf_tmp{'127.0.0.1'};
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
        if ( $section =~ /^(default|all)$/ ) {
            print "This switch can't be deleted (Error at line ".__LINE__." in pfcmd)\n";
            exit;
        } else {
            if ( tied(%switches_conf)->SectionExists($section) ) {
                tied(%switches_conf)->DeleteSection($section);
                my $tied_switch = tied(%switches_conf);
                $tied_switch->RewriteConfig()
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
            $tied_switch->RewriteConfig()
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
            $tied_switch->RewriteConfig()
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

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

