package captiveportal::Controller::UserCreate;

use Moose;
use namespace::autoclean;
use pf::sms_carrier;
use pf::util::add_ldap;
use pf::web::util;
use pf::custom::ldap_add_config qw(%LdapAddConfig);
use List::MoreUtils qw(any);

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::Controller::UserCreate - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

=head2 /usercreate


=cut

sub begin : Private {
    my ($self, $c) = @_;
    if (exists $LdapAddConfig{allowed_profiles}) {
        my $name = $c->profile->name;
        $self->showError($c, "Not allowed to access this resource") unless any { $_ eq $name } @{$LdapAddConfig{allowed_profiles} // [] };
    }
}

sub index : Path : Args(0) {
    my ($self, $c) = @_;
    $c->stash(
        template     => 'user_create.html',
        sms_carriers => sms_carrier_view_all(),
        post_uri => $c->uri_for('create'),
    );
}

=head2 /usercreate/create

=cut

sub create : Local {
    my ($self, $c) = @_;
    my $request = $c->request;
    my %userinfo;

    foreach my $param (qw(firstname lastname phone email mobileprovider by_email by_sms aup_signed)) {
        $userinfo{$param} = $request->param($param);
    }
    $c->stash(\%userinfo);

    if ($self->validate($c, \%userinfo)) {
        eval {
            pf::util::add_ldap::add_new_user(\%userinfo);
            $c->stash({
                template => 'sent_message.html',
            });
        };
        if ($@) {
            $c->log->error($@);
            $c->stash({txt_validation_error => $@});
            $c->detach('index');
        }
    }
    else {
        $c->detach('index');
    }
}

=head2 validate

validate parameters

=cut

sub validate {
    my ($self, $c, $userinfo) = @_;
    my $aup_signed = $userinfo->{aup_signed};
    unless ($aup_signed) {
        $c->stash({txt_validation_error => 'Please accept the term and conditions' });
        return 0;
    }

    my $firstname = $userinfo->{firstname};
    if (length($firstname) == 0 ) {
        $c->stash({txt_validation_error => 'Please supply your first name' });
        return 0;
    }

    my $lastname = $userinfo->{lastname};
    if (length($lastname) == 0 ) {
        $c->stash({txt_validation_error => 'Please supply your last name' });
        return 0;
    }

    my $mobileprovider = $userinfo->{mobileprovider};
    if (length($mobileprovider) == 0 ) {
        $c->stash({txt_validation_error => 'Please supply your mobileprovider' });
        return 0;
    }

    my $phone = $userinfo->{phone};
    unless (pf::web::util::validate_phone_number($phone)) {
        $c->stash({txt_validation_error => 'Please supply your phone number' });
        return 0;
    }

    my $email = $userinfo->{email};
    unless (pf::web::util::is_email_valid($email)) {
        $c->stash({txt_validation_error => 'Please supply your email address' });
        return 0;
    }

    return 1;
}

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
