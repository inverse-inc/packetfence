package pf::Authentication::EmailFilteringRole;

=head1 NAME

pf::Authentication::EmailFilteringRole -

=head1 DESCRIPTION

pf::Authentication::EmailFilteringRole

=cut

use strict;
use warnings;
use Moose::Role;
use pf::util qw(expand_csv isenabled);
use pf::constants qw($TRUE $FALSE);
use pf::config qw(%Config);
use List::MoreUtils qw(any);

has 'allowed_domains' => (isa => 'Maybe[ArrayRef[Str]]', is => 'rw');
has 'banned_domains' => (isa => 'Maybe[ArrayRef[Str]]', is => 'rw');
has 'allow_localdomain' => (isa => 'Str', is => 'rw', default => 'yes');

=head2 BUILDARGS

BUILDARGS

=cut

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my %hash;
    if (@_ == 1) {
        if (ref($_[0]) ne 'HASH') {
            return $class->$orig(@_);
        }

        %hash = %{$_[0]};
    } else {
        %hash = @_;
    }

    for my $f (qw(allowed_domains banned_domains)) {
        next unless exists $hash{$f};
        $hash{$f} = [ map { split(/\r?\n/) } expand_csv($hash{$f} // '')];
    }

    my $args = $class->$orig(\%hash);
    return $args;
};


=head2 isEmailAllowed

checks if email is allowed

=cut

sub isEmailAllowed {
    my ($self, $email) = @_;
    $email = lc($email);
    if (any {$email =~ $_} $self->banned_email_regexes) {
        return $FALSE;
    }

    my @allowed = $self->allowed_email_regexes;
    if (@allowed) {
        return (any {$email =~ $_} @allowed) ? $TRUE : $FALSE;
    }

    return $TRUE;
}

=head2 banned_email_regexes

banned email regexes

=cut

sub banned_email_regexes {
    my ($self) = @_;
    my @banned = make_email_regexes($self->banned_domains);
    if (!isenabled($self->allow_localdomain)) {
        push @banned, localdomain_regexes();
    }

    return @banned;
}

=head2 allowed_email_regexes

allowed email regexes

=cut

sub allowed_email_regexes {
    my ($self) = @_;
    my @allowed = make_email_regexes($self->allowed_domains);
    if (@allowed && isenabled($self->allow_localdomain)) {
        push @allowed, localdomain_regexes();
    }

    return @allowed;
}

=head2 localdomain_regexes

Return list of email regexes for matching the the local domain

=cut

sub localdomain_regexes {
    my $domain = lc($Config{general}{domain});
    return make_email_regexes([$domain,"*.$domain"]);
}

=head2 make_email_regexes

Create an array of email regexes from a list of domain wildcards

=cut

sub make_email_regexes {
    my ($domain_wildcards) = @_;
    return map { make_email_regex($_) } @{$domain_wildcards // []};
}

=head2 make_email_regex

Make an email regex from a domain wildcard

=cut

sub make_email_regex {
    my ($domain_wildcard) = @_;
    local $_;
    $domain_wildcard = lc($domain_wildcard);
    if ($domain_wildcard =~ /\*/) {
        $domain_wildcard =~ s/\./\\./g;
        $domain_wildcard =~ s/\*/\.\*/g;
        $domain_wildcard = "\@$domain_wildcard\$";
        return qr/$domain_wildcard/;
    }

    return qr/@\Q$domain_wildcard\E$/;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

