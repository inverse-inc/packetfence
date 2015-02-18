package pf::pftest::authentication;
=head1 NAME

pf::pftest::authentication add documentation

=head1 SYNOPSIS

pftest authentication user password [sources ..]

=head1 DESCRIPTION

pf::pftest::authentication

=cut

use strict;
use warnings;
use pf::cmd;
use base qw(pf::cmd);
use Term::ANSIColor;
use IO::Interactive qw(is_interactive);

sub parseArgs { $_[0]->args >= 2 }
our $indent = "  ";

sub _run {
    my ($self) = @_;
    require pf::authentication;
    import pf::authentication;
    require pf::config;
    import pf::config;
    my $show_color = colors_supported();;
    my ($user,$pass,@source_ids) = $self->args;
    my @sources;
    if (@source_ids) {
        @sources = grep { $_ }  map { getAuthenticationSource($_) } @source_ids;
    } else {
        @sources = @pf::authentication::authentication_sources;
    }


    print "Testing authentication for \"$user\"\n\n";
    eval {
        foreach my $source (@sources) {
            print "Authenticating against " . $source->id . "\n";
            my ($result,$message) = $source->authenticate($user,$pass);
            $message = '' unless defined $message;
            if ($result) {
                print color $pf::config::Config{advanced}{pfcmd_success_color} if $show_color;
                print $indent,"Authentication SUCCEEDED against ",$source->id," ($message) \n";
            } else {
                print color $pf::config::Config{advanced}{pfcmd_error_color} if $show_color;
                print $indent,"Authentication FAILED against ",$source->id," ($message) \n";
            }
            print color 'reset' if $show_color;
            my $actions;
            if( $actions = pf::authentication::match([$source], {username => $user})) {
                print color $pf::config::Config{advanced}{pfcmd_success_color} if $show_color;
                print $indent ,"Matched against ",$source->id,"\n";
                if(ref($actions)) {
                    local $indent = $indent x 2;
                    foreach my $action (@$actions) {
                        print $indent ,$action->type," : ",$action->value,"\n";
                    }
                }
            } else {
                print color $pf::config::Config{advanced}{pfcmd_error_color} if $show_color;
                print $indent,"Did not match against ",$source->id,"\n";
            }
            print color 'reset' if $show_color;
            print "\n";
        }
    };
    print color 'reset' if $show_color;
}

sub colors_supported { return is_interactive() }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

