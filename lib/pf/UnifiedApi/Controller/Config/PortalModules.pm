package pf::UnifiedApi::Controller::Config::PortalModules;

=head1 NAME

pf::UnifiedApi::Controller::Config::PortalModules - 

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::PortalModules



=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config::Subtype);

has 'config_store_class' => 'pf::ConfigStore::PortalModule';
has 'form_class' => 'pfappserver::Form::Config::PortalModule';
has 'primary_key' => 'portal_module_id';

use pf::ConfigStore::PortalModule;
use pfappserver::Form::Config::PortalModule;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::Facebook;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::Github;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::Google;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::Instagram;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::LinkedIn;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::OpenID;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::Pinterest;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::Twitter;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth::WindowsLive;
use pfappserver::Form::Config::PortalModule::Authentication::Billing;
use pfappserver::Form::Config::PortalModule::Authentication::Blackhole;
use pfappserver::Form::Config::PortalModule::Authentication::Choice;
use pfappserver::Form::Config::PortalModule::Authentication::Email;
use pfappserver::Form::Config::PortalModule::Authentication::Login;
use pfappserver::Form::Config::PortalModule::Authentication::Null;
use pfappserver::Form::Config::PortalModule::Authentication::OAuth;
use pfappserver::Form::Config::PortalModule::Authentication::Password;
use pfappserver::Form::Config::PortalModule::Authentication::SAML;
use pfappserver::Form::Config::PortalModule::Authentication::SMS;
use pfappserver::Form::Config::PortalModule::Authentication::Sponsor;
use pfappserver::Form::Config::PortalModule::Authentication;
use pfappserver::Form::Config::PortalModule::Chained;
use pfappserver::Form::Config::PortalModule::Choice;
use pfappserver::Form::Config::PortalModule::FixedRole;
use pfappserver::Form::Config::PortalModule::Message;
use pfappserver::Form::Config::PortalModule::Provisioning;
use pfappserver::Form::Config::PortalModule::Root;
use pfappserver::Form::Config::PortalModule::SelectRole;
use pfappserver::Form::Config::PortalModule::Survey;
use pfappserver::Form::Config::PortalModule::URL;

our %TYPES_TO_FORMS = (
    map { $_ => "pfappserver::Form::Config::PortalModule::$_" } qw(
        Authentication::OAuth::Facebook
        Authentication::OAuth::Github
        Authentication::OAuth::Google
        Authentication::OAuth::Instagram
        Authentication::OAuth::LinkedIn
        Authentication::OAuth::OpenID
        Authentication::OAuth::Pinterest
        Authentication::OAuth::Twitter
        Authentication::OAuth::WindowsLive
        Authentication::Billing
        Authentication::Blackhole
        Authentication::Choice
        Authentication::Email
        Authentication::Login
        Authentication::Null
        Authentication::OAuth
        Authentication::Password
        Authentication::SAML
        Authentication::SMS
        Authentication::Sponsor
        Authentication
        Chained
        Choice
        FixedRole
        Message
        Provisioning
        Root
        SelectRole
        Survey
        URL
    )
);

sub type_lookup {
    return \%TYPES_TO_FORMS;
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

