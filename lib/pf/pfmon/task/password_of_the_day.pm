package pf::pfmon::task::password_of_the_day;

=head1 NAME

pf::pfmon::task::password_of_the_day - class for pfmon task password generation

=cut

=head1 DESCRIPTION

pf::pfmon::task::password_of_the_day

=cut

use strict;
use warnings;
use Moose;
use pf::person;
use pf::password;
use pf::authentication;
use pf::util;
use pf::web qw (i18n_format );
use pf::web::guest;
use DateTime;
use DateTime::Format::MySQL;
use pf::log;

extends qw(pf::pfmon::task);

=head2 run

run the password generation task

=cut

sub run {
    my ( $self ) = @_;
    my $now = DateTime->now(time_zone => "local");
    my $logger = get_logger();
    my $sources = pf::authentication::getAuthenticationSourcesByType("Potd");
    my $new_password;
    foreach my $source (@{$sources}) {
        unless (person_exist($source->{id})) {
            $logger->info("Create Person $source->{id}");
            person_add($source->{id}, (potd => 'yes'));
            $new_password = pf::password::generate($source->{id},[{type => 'valid_from', value => $now},{type => 'expiration', value => pf::config::access_duration($source->{password_rotation})}],undef,'0',$source);
            $self->send_email((pid => $source->{id}, password => $new_password, email => $source->{password_email_update}, expiration => $new_password->{expiration}));
            next;
        }
        my $password = pf::password::view($source->{id});
        if(defined($password)){
            my $valid_from = $password->{valid_from};
            $valid_from = DateTime::Format::MySQL->parse_datetime($valid_from);
            $valid_from->set_time_zone("local");
            if ( ($now->epoch - $valid_from->epoch) > pf::util::normalize_time($source->{password_rotation})) {
                $new_password = pf::password::generate($source->{id},[{type => 'valid_from', value => $now},{type => 'expiration', value => pf::config::access_duration($source->{password_rotation})}],undef,'0',$source);
                $self->send_email((pid => $source->{id},password => $new_password, email => $source->{password_email_update},expiration => $new_password->{expiration}));
            }
        }
    }
}

=head2 send_email

send the password of the day to the email addresses

=cut

sub send_email {
    my ( $self, %info ) = @_;
    %info = (
        'subject'   => i18n_format(
            "New password of the day"
        ),
        %info
    );
    pf::web::guest::send_template_email(
            $pf::web::guest::TEMPLATE_EMAIL_PASSWORD_OF_THE_DAY, $info{'subject'}, \%info
    );

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

