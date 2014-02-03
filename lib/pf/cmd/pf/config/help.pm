package pf::cmd::pf::config::help;
=head1 NAME

pf::cmd::pf::config::help add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::config::help

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use Role::Tiny::With;
with 'pf::cmd::roles::show_parent_help';
with 'pf::cmd::roles::need_x_args';
use pf::config;
use pf::pfcmd;

sub numberOfArgs { 1 }

sub _run {
    my ($self) = @_;
    my ($param)  = $self->args;
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

    if ( defined( $Doc_Config{$param}{'description'} ) ) {
        print uc($param) . "\n";
        print "Default: $Default_Config{$section}{$parm}\n"
            if ( defined( $Default_Config{$section}{$parm} ) );
        if ( defined( $Doc_Config{$param}{'options'} ) ) {
            my $options = $Doc_Config{$param}{'options'};
            $options = join(' , ',@$options)
                if ref $options;
            print "Options: $options\n";
        }
        if ( ref( $Doc_Config{$param}{'description'} ) eq 'ARRAY' ) {
            print join( "\n", @{ $Doc_Config{$param}{'description'} } )
                . "\n";
        } else {
            print $Doc_Config{$param}{'description'} . "\n";
        }
    } else {
        print "No help available for $param\n";
        return $pf::pfcmd::ERROR_CONFIG_NO_HELP;;
    }
    return 0;
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

