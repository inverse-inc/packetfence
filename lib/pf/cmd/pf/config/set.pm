package pf::cmd::pf::config::set;
=head1 NAME

pf::cmd::pf::config::set add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::config::set

=cut

use strict;
use warnings;
use pf::log;
use pf::config;
use base qw(pf::cmd);
use Role::Tiny::With;
with 'pf::cmd::roles::show_parent_help';
with 'pf::cmd::roles::need_x_args';
our $ERROR_CONFIG_UNKNOWN_PARAM = 10;
our $ERROR_CONFIG_NO_HELP = 11;

sub numberOfArgs { 1 }

sub _run {
    my ($self) = @_;
    my ($param)  = $self->args;
    my $value  = "";

    if ($param =~ /^([^=]+)=(.+)?$/) {
        $param = $1;
        $value = (defined($2) ? $2 : '');
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

    if ( !defined( $Config{$section}{$parm} ) ) {
        print "Unknown configuration parameter $section.$parm!\n";
        exit($ERROR_CONFIG_UNKNOWN_PARAM);
    } else {

        #write out the local config only - with the new value.
        if ( defined( $Config{$section}{$parm} ) ) {
            if (   ( !defined( $Config{$section}{$param} ) )
                || ( $Default_Config{$section}{$parm} ne $value ) )
            {
                $cached_pf_config->setval( $section, $parm, $value );
            } else {
                $cached_pf_config->delval( $section, $parm );
            }
        } elsif ( $Default_Config{$section}{$parm} ne $value ) {
            $cached_pf_config->newval( $section, $parm, $value );
        }
        $cached_pf_config->RewriteConfig()
            or get_logger->logdie("Unable to write config to $pf_config_file. "
                ."You might want to check the file's permissions. (pfcmd line ".__LINE__.".)"); # web ui hack
        require pf::configfile;
        import pf::configfile;
        configfile_import( $conf_dir . "/pf.conf" );
    }
}

sub parseParam {
    my ($self,$param) = @_;
    my ($parm,$section);

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
    return ($parm,$section);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

