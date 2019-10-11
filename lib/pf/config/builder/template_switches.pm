package pf::config::builder::template_switches;

=head1 NAME

pf::config::builder::template_switches -

=head1 DESCRIPTION

pf::config::builder::template_switches

=cut

use strict;
use warnings;
use base qw(pf::config::builder);
use pf::mini_template;

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    my $type = $id;
    $entry->{type} = $type;
    my @errors;
    for my $k (qw(acceptVlan acceptRole reject disconnect coa)) {
        next unless exists $entry->{$k};
        my $ras = $entry->{$k};
        if (!defined $ras || $ras eq '') {
            next;
        }
        $entry->{$k} = make_radius_attribute_set(\@errors, $ras);
    }

    if (@errors) {
        push @{$buildData->{errors}}, { switch => $id, message => "Error building attributes", errors => \@errors };
        return undef;
    }

    my ($vendor, undef) = split /::/, $type, 2;
    push @{$buildData->{entries}{'::VENDORS'}{$vendor}}, { value => $type, label => $entry->{description} };

    return $entry;
}

sub make_radius_attribute_set {
    my ($errors, $radius_attr_set) = @_;
    my @set = map { make_radius_attribute($errors, $_)  } split /\n/, $radius_attr_set;
    return \@set;
}

=head2 make_radius_attribute

make_radius_attribute

=cut

sub make_radius_attribute {
    my ($errors, $ra) = @_;
    my ($n, $tmpl_text) = split / *= */, $ra, 2;
    my $v;
    if ($n =~ /([^:]+):(.*)/) {
        $n = $2;
        $v = $1;
    }

    my $attr = {
        name => $n, (defined $v ? (vendor => $v ) : () )
    };

    my $tmpl = eval {
        pf::mini_template->new($tmpl_text)
    };
    if ($@) {
        push @{$errors}, { %$attr, message => $@ };
        return;
    }
    $attr->{tmpl} = $tmpl;
    return $attr;
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

