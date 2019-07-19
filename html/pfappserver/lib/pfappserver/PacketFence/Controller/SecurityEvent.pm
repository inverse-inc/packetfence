package pfappserver::PacketFence::Controller::SecurityEvent;

=head1 NAME

pfappserver::PacketFence::Controller::SecurityEvent - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;
use JSON::MaybeXS;

use pf::log;
use pf::config;
use pf::constants::role qw(@ROLES);
use pf::Switch::constants;
use pf::constants::trigger qw($TRIGGER_MAP);
use pf::factory::condition::security_event;
use Switch;
use pf::fingerbank;
use fingerbank::Model::Device;
use fingerbank::Model::DHCP_Fingerprint;
use fingerbank::Model::DHCP_Vendor;
use fingerbank::Model::DHCP6_Fingerprint;
use fingerbank::Model::DHCP6_Enterprise;
use fingerbank::Model::MAC_Vendor;



BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'security_event', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'SECURITY_EVENTS_READ' },
        list   => { AdminRole => 'SECURITY_EVENTS_READ' },
        create => { AdminRole => 'SECURITY_EVENTS_CREATE' },
        clone  => { AdminRole => 'SECURITY_EVENTS_CREATE' },
        update => { AdminRole => 'SECURITY_EVENTS_UPDATE' },
        toggle => { AdminRole => 'SECURITY_EVENTS_UPDATE' },
        remove => { AdminRole => 'SECURITY_EVENTS_DELETE' },
    },
);

=head1 METHODS

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    my ($status, $result);
    my ($model, $security_events, $security_event_default, $roles, $triggers, $templates);

    $model =  $c->model('Config::SecurityEvents');
    ($status, $result) = $model->readAll();
    if (is_success($status)) {
        $security_events = $result;
    }
    my @roles = map {{ name => $_ }} @ROLES;
    ($status, $result) = $c->model('Config::Roles')->listFromDB();
    if (is_success($status)) {
        push(@roles, @$result);
    }
    ($status, $security_event_default) = $model->read('defaults');
    $triggers = $model->listTriggers();
    $c->stash(
        trigger_types => [sort(keys(%pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE))],
        current_model_instance => $model,
        current_form_instance =>
              $c->form("SecurityEvent",
                       security_events => $security_events,
                       placeholders => $security_event_default,
                       roles => \@roles,
                       triggers => $triggers,
                      )
             );
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'security_event/list.tt';
    $c->forward('list');
}

=head2 toggle

toggle on or off the security_event

=cut
sub toggle : Chained('object') :PathPart('toggle') :Args(1) {
    my ($self, $c, $toggle) = @_;
    my $stash = $c->stash;
    my $item_id = $stash->{id};
    my $enabled = $toggle eq 'yes' ? 'Y' : 'N';
    my $model = $self->getModel($c);
    my ($status,$status_msg) = $model->update(
        $item_id,
        {enabled => $enabled},
    );
    if (is_success($status)) {
        $self->_commitChanges($c);
    }

    $self->audit_current_action($c, status => $status);
    $c->response->status($status);
    $c->stash(
        status_msg => $status_msg,
        current_view => 'JSON',
    );
}

sub prettify_trigger {
    my ($self, $trigger) = @_;

    my @parts = split('::', $trigger);
    my $type = lc($parts[0]);
    my $tid = lc($parts[1]);

    my $pretty_type = $type;
    my $pretty_value;
    if($type eq "device") {
        my ($status, $elem) = fingerbank::Model::Device->read($tid);
        $pretty_value = $elem->name if(is_success($status));
    }
    elsif($type eq "dhcp_fingerprint") {
        my ($status, $elem) = fingerbank::Model::DHCP_Fingerprint->read($tid);
        $pretty_value = $elem->{value} if(is_success($status));
    }
    elsif($type eq "dhcp_vendor"){
        my ($status, $elem) = fingerbank::Model::DHCP_Vendor->read($tid);
        $pretty_value = $elem->{value} if(is_success($status));
    }
    elsif($type eq "dhcp6_fingerprint"){
        my ($status, $elem) = fingerbank::Model::DHCP6_Fingerprint->read($tid);
        $pretty_value = $elem->{value} if(is_success($status));
    }
    elsif($type eq "dhcp6_enterprise"){
        my ($status, $elem) = fingerbank::Model::DHCP6_Enterprise->read($tid);
        $pretty_value = $elem->{value} if(is_success($status));
    }
    elsif($type eq "mac_vendor"){
        my ($status, $elem) = fingerbank::Model::MAC_Vendor->read($tid);
        $pretty_value = $elem->{name} if(is_success($status));
    }
    else {
        $pretty_value = (defined($TRIGGER_MAP->{$type}) && defined($TRIGGER_MAP->{$type}->{$tid})) ?
                        $TRIGGER_MAP->{$type}->{$tid} : undef;
    }
    $pretty_value = (defined($pretty_value)) ? $pretty_value : $parts[1];

    return {type => $pretty_type, value => $pretty_value};
}

sub parse_triggers {
    my ($self,$triggers) = @_;
    my @splitted_triggers;
    my @pretty_triggers;
    foreach my $trigger (split ',', $triggers) {
        if($trigger =~ /\((.+)\)/){
          push @splitted_triggers, [split('&', $1)];
          push @pretty_triggers, [ map { $self->prettify_trigger($_); } split('&', $1) ];
        }
        else {
          push @splitted_triggers, [($trigger)];
          push @pretty_triggers, [($self->prettify_trigger($trigger))];
        }
    }

    return (\@splitted_triggers,\@pretty_triggers);
}

=head2 after view

=cut

after view => sub {
    my ($self, $c, $id) = @_;
    if (!$c->stash->{action_uri}) {
        if ($c->stash->{item}) {
            ($c->stash->{splitted_triggers}, $c->stash->{pretty_triggers}) =
                $self->parse_triggers($c->stash->{item}->{trigger});
            $c->stash->{trigger_map} = $pf::constants::trigger::TRIGGER_MAP;
            $c->stash->{json_event_triggers} = encode_json([ map { ($pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE{$_}{event}) ? $_ : () } keys %pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE ]);
            $c->stash->{template} = 'security_event/view.tt';
            $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->stash->{id}]);
        } else {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
        }
    }
};

=head2 after create

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    $c->stash->{trigger_map} = $pf::constants::trigger::TRIGGER_MAP;
    $c->stash->{json_event_triggers} = encode_json([ map { ($pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE{$_}{event}) ? $_ : () } keys %pf::factory::condition::security_event::TRIGGER_TYPE_TO_CONDITION_TYPE ]);
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'security_event/view.tt';
    }
    if ($c->request->method eq 'POST' ) {
        pf::fingerbank::clear_cache();
    }
};

after [qw(update)] => sub {
    my ($self, $c) = @_;
    pf::fingerbank::clear_cache();
};

=head2 after list

=cut

after list => sub {
    my ($self, $c) = @_;

    if (is_success($c->response->status)) {
        # Sort security_events by id and keep the defaults template at the top
        my @items = sort {
            if ($a->{id} eq 'defaults') {
                -1;
            } else {
                int($a->{id}) <=> int($b->{id});
            }
        } @{$c->stash->{items}};
        $c->stash->{items} = \@items;
        my ($status, $result) = $c->model('Config::Profile')->readAllIds();
        if (is_success($status)) {
            $c->stash->{profiles} = $result;
        }
    }
};

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
