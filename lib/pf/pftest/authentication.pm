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
use pf::constants;
use base qw(pf::cmd);
use pf::Authentication::constants qw($LOGIN_SUCCESS $LOGIN_FAILURE $LOGIN_CHALLENGE);
use pf::util::console;

sub parseArgs { $_[0]->args >= 2 }
our $indent = "  ";

sub _run {
    my ($self) = @_;
    require pf::authentication;
    import pf::authentication;
    my $colors = pf::util::console::colors();
    my ($user,$pass,@source_ids) = $self->args;
    my @sources;
    if (@source_ids) {
        @sources = grep { $_ }  map { getAuthenticationSource($_) } @source_ids;
    } else {
        @sources = @pf::authentication::authentication_sources;
    }

    my @CONTEXTS_TO_TEST = (
        $pf::constants::realm::ADMIN_CONTEXT,
        $pf::constants::realm::PORTAL_CONTEXT,
    );

    print "Testing authentication for \"$user\"\n\n";
    eval {
        foreach my $source (@sources) {
            foreach my $context (@CONTEXTS_TO_TEST) {
                next if($source->type eq "SAML");
                print "Authenticating against '" . $source->id . "' in context '$context'\n";
                my ($result,$message) = pf::authentication::authenticate({username => $user, password => $pass, context => $context}, $source);
                $message = '' unless defined $message;
                if ($result == $LOGIN_SUCCESS) {
                    print $colors->{success}, $indent,"Authentication SUCCEEDED against ",$source->id," ($message)$colors->{reset}\n";
                }
                elsif ($result == $LOGIN_CHALLENGE) {
                    print $colors->{warning}, $indent,"Authentication CHALLENGE return for ",$source->id," (Challenge message $message->{message})$colors->{reset}\n";
                } else {
                    print $colors->{error}, $indent,"Authentication FAILED against ",$source->id," ($message)$colors->{reset}\n";
                }
                my $matched;
                foreach my $class ( @Rules::CLASSES ) {
                    if( $matched = pf::authentication::match2([$source], {username => $user, rule_class => $class, context => $context})) {
                        print $colors->{success},$indent ,"Matched against ",$source->id," for '$class' rules\n";
                        {
                            local $indent = $indent x 2;
                            foreach my $action (@{$matched->{actions}}) {
                                print $indent ,$action->type," : ",$action->value,"\n";
                            }
                        }
                    } else {
                        print $colors->{error}, $indent,"Did not match against ",$source->id," for '$class' rules\n";
                    }
                }
                print "$colors->{reset}\n";
            }
        }
    };
    print $colors->{reset};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
