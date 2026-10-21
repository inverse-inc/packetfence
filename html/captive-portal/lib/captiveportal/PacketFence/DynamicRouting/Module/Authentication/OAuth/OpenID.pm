package captiveportal::PacketFence::DynamicRouting::Module::Authentication::OAuth::OpenID;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::OpenID

=head1 DESCRIPTION

OpenID OAuth module

=cut

use Moose;
use pf::config qw(%Config);
use pf::log;
use pf::person qw(person_view);
use JSON ();
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

has '+source' => (
    isa => 'pf::Authentication::Source::OpenIDSource',
    lazy => 1,
    builder => '_build_source',
);

has 'token_scheme' => (is => 'rw', default => sub {"auth-header:Bearer"});

=head2 _extract_username_from_response

Extract the username from the response of the provider

=cut

sub _extract_username_from_response {
    my ($self, $info) = @_;
    my $source = $self->source;
    my $username = $source->username_attribute;
    if (!exists $info->{$username}) {
        return $self->SUPER::_extract_username_from_response($info);
    }

    return $info->{$source->username_attribute} // $self->SUPER::_extract_username_from_response($info);
}

=head2 save_provider_info

Keep the known OpenID attributes (advanced.openid_attributes) of the provider
response so they can be used in the source rules.

A list of plain values (e.g. groups) is kept as a comma separated string so it
can be matched with "contains", a boolean (e.g. email_verified) as "true" or
"false". Other values (nested objects) can't be matched and are skipped.

=cut

sub save_provider_info {
    my ($self, $info) = @_;
    my (%attributes, @skipped);
    for my $attribute (@{$Config{advanced}{openid_attributes} // []}) {
        my $value = $info->{$attribute};
        next if !defined $value;
        if (JSON::is_bool($value)) {
            $value = $value ? 'true' : 'false';
        }
        elsif (ref($value) eq 'ARRAY' && !grep { !defined($_) || ref($_) } @$value) {
            $value = join(',', @$value);
        }
        elsif (ref($value)) {
            push @skipped, $attribute;
            next;
        }
        $attributes{$attribute} = $value;
    }
    get_logger->debug("OpenID attribute(s) that can't be used in the source rules (not a plain value): " . join(", ", @skipped)) if @skipped;

    $self->session->{openid_attributes} = \%attributes;
}

sub auth_source_params_child {
    my ($self) = @_;
    my $info = person_view($self->username());
    return $self->source->map_from_person($info);
}

=head2 auth_source_params

The parameters available for source matching, with the OpenID attributes kept
by save_provider_info.

An OpenID attribute never replaces a parameter PacketFence computed (username,
mac, connection_type, ...) nor a person mapping: those are set first and an
attribute with the same name is skipped (logged when it collides with a
parameter computed by PacketFence).

=cut

sub auth_source_params {
    my ($self) = @_;
    my $params = $self->SUPER::auth_source_params();
    my $attributes = $self->session->{openid_attributes} // {};
    # names set from the person table (see OpenIDSource::map_from_person): the
    # person mapping takes precedence, as expected, so this isn't reported
    my $source = $self->source;
    my %person_mapped = map { $_ => 1 } ($source->username_attribute, map { $_->{openid_field} } @{$source->person_mappings // []});
    my @skipped;
    for my $attribute (sort keys %$attributes) {
        if (exists $params->{$attribute}) {
            push @skipped, $attribute unless $person_mapped{$attribute};
            next;
        }
        $params->{$attribute} = $attributes->{$attribute};
    }
    get_logger->info("OpenID attribute(s) not used in the source rules, PacketFence sets a parameter of the same name: " . join(", ", @skipped)) if @skipped;
    return $params;
}

sub _build_source {
    my ($self) = @_;
    return $self->app->profile->getSourceByType('OpenID');
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

