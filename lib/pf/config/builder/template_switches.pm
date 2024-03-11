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
use pf::util::radius_dictionary qw($RADIUS_DICTIONARY);
use pf::constants::template_switch qw(
    @RADIUS_ATTRIBUTE_SETS
    @SUPPORTS
);

our %SetToSupports = (
    voip => [qw(RadiusVoip)],
);

sub buildEntry {
    my ($self, $buildData, $id, $entry) = @_;
    my $type = $id;
    $entry->{type} = $type;
    my @supports = @SUPPORTS;
    for my $k (@RADIUS_ATTRIBUTE_SETS) {
        next unless exists $entry->{$k};
        my $ras = delete $entry->{$k};
        if (!defined $ras || $ras eq '') {
            next;
        }

        if (exists $SetToSupports{$k}) {
            push @supports, @{$SetToSupports{$k}};
        }

        my ($ras_errors, $set) = make_radius_attribute_set($ras);
        if (@$ras_errors) {
            push @{$buildData->{errors}}, { switch => $id, message => "Error building RADIUS scope $k", errors => $ras_errors };
        } else {
            $entry->{$k} = $set;
        }
    }

    if ($entry->{nasPortToIfindex}) {
        my $tmpl_text= $entry->{nasPortToIfindex};
        my $tmpl = eval {
            pf::mini_template->new($tmpl_text)
        };
        if ($@) {
            push @{$buildData->{errors}}, { message => $@, text => $tmpl_text };
        }
        $entry->{nasPortToIfindex} = $tmpl;
    }

    @supports = sort @supports;
    my ($vendor, undef) = split /::/, $type, 2;
    push @{ $buildData->{entries}{'::VENDORS'}{$vendor} },
    {
        value    => $type,
        label    => $entry->{description},
        supports => \@supports,
        is_template => 1,
    };

    return $entry;
}

sub make_radius_attribute_set {
    my ($radius_attr_set) = @_;
    my @errors;
    my @set = map { make_radius_attribute(\@errors, $_)  } split /\n/, $radius_attr_set;
    return \@errors, \@set;
}

=head2 make_radius_attribute

make_radius_attribute

=cut

sub make_radius_attribute {
    my ($errors, $ra) = @_;
    my ($n, $tmpl_text) = split / *= */, $ra, 2;
    if (!defined $tmpl_text) {
        push @{$errors}, { name => 'unknown', text => $ra, message => "is not a valid radius attribute" };
        return;
    }

    my $v;
    if ($n =~ /([^:]+):(.*)/) {
        $n = $2;
        $v = $1;
    } else {
        if (exists $RADIUS_DICTIONARY->{avendors}{$n}) {
            $v = $RADIUS_DICTIONARY->{avendors}{$n};
        }
    }

    my $attr = {
        name => $n, (defined $v ? (vendor => $v ) : () )
    };

    my $tmpl = eval {
        pf::mini_template->new($tmpl_text)
    };
    if ($@) {
        push @{$errors}, { %$attr, message => $@, text => $ra };
        return;
    }
    $attr->{tmpl} = $tmpl;
    return $attr;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

