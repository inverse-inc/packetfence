package pf::cmd::pf::config::get;
=head1 NAME

pf::cmd::pf::config::get add documentation

=cut

=head1 DESCRIPTION

pf::cmd::pf::config::get

=cut

use strict;
use warnings;

use base qw(pf::cmd);
use pf::config;
use pf::pfcmd;
use Role::Tiny::With;
with 'pf::cmd::roles::show_parent_help';
with 'pf::cmd::roles::need_x_args';

sub numberOfArgs { 1 }

sub _run {
    my ($self) = @_;
    my ($param) = $self->args;
    my ($parm,$section) = $self->parseParam($param);
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
sub config_entry {
    my ( $param, $value ) = @_;
    my ( $default, $orig_param, $dot_param, $param2, $type, $options, $val );

    $orig_param = $param;
    $dot_param  = $param;
    $dot_param =~ s/\s+/\./g;
    ( $param, $param2 ) = split( " ", $param ) if ( $param =~ /\s/ );

    if ( defined( $Default_Config{$orig_param}{$value} ) ) {
        $default = $Default_Config{$orig_param}{$value};
    } else {
        $default = "";
    }
    if ( defined( $Doc_Config{"$param.$value"}{'options'} ) ) {
        $options = $Doc_Config{"$param.$value"}{'options'};
        $options = join(";",@$options);
    } else {
        $options = "";
    }
    if ( defined( $Doc_Config{"$param.$value"}{'type'} ) ) {
        $type = $Doc_Config{"$param.$value"}{'type'};
    } else {
        $type = "text";
    }
    if ( defined( $Config{$orig_param}{$value} ) ) {
        $val = "$dot_param.$value=$Config{$orig_param}{$value}";
    } else {
        $val = "$dot_param.$value=";
    }
    return join( "|", $val, $default, $options, $type ) . "\n";
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

