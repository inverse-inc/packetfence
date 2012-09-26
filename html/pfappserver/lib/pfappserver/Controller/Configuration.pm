package pfappserver::Controller::Configuration;

=head1 NAME

pfappserver::Controller::Configuration - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use Date::Parse;
use HTTP::Status qw(:constants is_error is_success);
use Moose;
use namespace::autoclean;
use POSIX;

# imported only for the $TIME_MODIFIER_RE regex. Ideally shouldn't be 
# imported but it's better than duplicating regex all over the place.
use pf::config;

BEGIN {extends 'Catalyst::Controller'; }

=head1 METHODS

=cut

=head2 auto

Allow only authenticated users

=cut
sub auto :Private {
    my ($self, $c) = @_;

    unless ($c->user_exists()) {
        $c->response->status(HTTP_UNAUTHORIZED);
        $c->response->location($c->req->referer);
        $c->stash->{template} = 'admin/unauthorized.tt';
        $c->detach();
        return 0;
    }

    return 1;
}

=head2 _format_section

=cut
sub _format_section :Private {
    my ($self, $entries_ref) = @_;

    for (my $i = 0; $i < scalar @{$entries_ref}; $i++) {
        my $entry_ref = $entries_ref->[$i];

        # Try to be smart. Description that refers to a comma-delimited list must be bigger.
        if ($entry_ref->{type} eq "text" && $entry_ref->{description} =~ m/comma-delimite/i) {
            $entry_ref->{type} = 'text-large';
        }

        # Value should always be defined for toggles (checkbox and select)
        elsif ($entry_ref->{type} eq "toggle") {
            $entry_ref->{value} = $entry_ref->{default_value} unless ($entry_ref->{value});

            # Switch to a popup list (select) when the toggle has no enabled/disabled options
            if ($entry_ref->{options}->[0] ne "enabled") {
                $entry_ref->{type} = "select";
            }
        }

        elsif ($entry_ref->{type} eq "date") {
            my $time = str2time($entry_ref->{value} || $entry_ref->{default_value});
            $entry_ref->{value} = POSIX::strftime("%m/%d/%Y", localtime($time));
        }
        
        # Extract unit from time
        elsif ($entry_ref->{type} eq "time") {
            my $value = $entry_ref->{value} || $entry_ref->{default_value};
            if ($value =~ m/(\d+)($TIME_MODIFIER_RE)/) {
                my ($interval, $unit) = ($1, $2);
                $entry_ref->{unit} = $unit;
                if (defined $entry_ref->{value}) {
                    $entry_ref->{value} = $interval;
                } elsif ($entry_ref->{default_value} =~ m/(\d+)($TIME_MODIFIER_RE)/) {
                    my ($interval, $unit) = ($1, $2);
                    $entry_ref->{default_value} = $interval;
                }
            }
        }

        # Limited formatting from text to html
        $entry_ref->{description} =~ s/</&lt;/g; # convert < to HTML entity
        $entry_ref->{description} =~ s/>/&gt;/g; # convert > to HTML entity
        $entry_ref->{description} =~ s/(\S*(&lt;|&gt;)\S*)\b/<code>$1<\/code>/g; # enclose strings that contain < or >
        $entry_ref->{description} =~ s/(\S+\.(html|tt|pm|pl|txt))\b(?!<\/code>)/<code>$1<\/code>/g; # enclose strings that ends with .html, .tt, etc
        $entry_ref->{description} =~ s/^ \* (.+?)$/<li>$1<\/li>/mg; # create list elements for lines beginning with " * "
        $entry_ref->{description} =~ s/(<li>.*<\/li>)/<ul>$1<\/ul>/s; # create lists from preceding substitution
        $entry_ref->{description} =~ s/\"([^\"]+)\"/<i>$1<\/i>/mg; # enclose strings surrounded by double quotes
        $entry_ref->{description} =~ s/(https?:\/\/\S+)/<a href="$1">$1<\/a>/g;
    }
}

=head2 _update_section

=cut
sub _update_section :Private {
    my ($self, $c) = @_;

    my $entries_ref = $c->model('Config::Pf')->read($c->action->name);
    my $data = {};

    foreach my $config (@{$entries_ref}) {
        if (exists($c->request->params->{$config->{parameter}})) {
            $data->{$config->{parameter}} = $c->request->params->{$config->{parameter}};
            if ($data->{$config->{parameter}} && $config->{type} eq 'time') {
                my $unit = $c->request->params->{$config->{parameter} . '_unit'};
                $data->{$config->{parameter}} .= $unit if ($unit);
            }
            elsif (exists($data->{$config->{parameter}}) && $config->{type} eq 'toggle') {
                $data->{$config->{parameter}} = 'disabled' unless ($data->{$config->{parameter}});
            }
        }
    }

    my ( $status, $message ) = $c->model('Config::Pf')->update($data);

    if (is_error($status)) {
        $c->response->status($status);
    }
    $c->stash->{status_msg} = $message;
    $c->stash->{current_view} = 'JSON';
}

=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($c->controller('Admin')->action_for('configuration'), ('general')));
    $c->detach();
}

=head2 general

=cut
sub general :Local {
    my ( $self, $c ) = @_;

    $c->stash->{section} = $c->action->name;
    $c->stash->{template} = 'configuration/section.tt';

    if ($c->request->method eq 'POST') {
        $self->_update_section($c);
    }
    else {
        $c->stash->{params} = $c->model('Config::Pf')->read($c->action->name);
        $self->_format_section($c->stash->{params});
    }
}

=head2 network

=cut
sub network :Local {
    my ( $self, $c ) = @_;

    $c->stash->{section} = $c->action->name;
    $c->stash->{template} = 'configuration/section.tt';

    if ($c->request->method eq 'POST') {
        $self->_update_section($c);
    }
    else {
        $c->stash->{params} = $c->model('Config::Pf')->read($c->action->name);
        $self->_format_section($c->stash->{params});
    }
}

=head2 proxies

=cut
sub proxies :Local {
    my ( $self, $c ) = @_;

    $c->stash->{section} = $c->action->name;
    $c->stash->{template} = 'configuration/section.tt';

    if ($c->request->method eq 'POST') {
        $self->_update_section($c);
    }
    else {
        $c->stash->{params} = $c->model('Config::Pf')->read($c->action->name);
        $self->_format_section($c->stash->{params});
    }
}

=head2 trapping

=cut
sub trapping :Local {
    my ( $self, $c ) = @_;

    $c->stash->{section} = $c->action->name;
    $c->stash->{template} = 'configuration/section.tt';

    if ($c->request->method eq 'POST') {
        $self->_update_section($c);
    }
    else {
        $c->stash->{params} = $c->model('Config::Pf')->read($c->action->name);
        $self->_format_section($c->stash->{params});
    }
}

=head2 registration

=cut
sub registration :Local {
    my ( $self, $c ) = @_;

    $c->stash->{section} = $c->action->name;
    $c->stash->{template} = 'configuration/section.tt';

    if ($c->request->method eq 'POST') {
        $self->_update_section($c);
    }
    else {
        $c->stash->{params} = $c->model('Config::Pf')->read($c->action->name);
        $self->_format_section($c->stash->{params});
    }
}

=head2 violations

=cut

sub violations :Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'configuration/violations.tt';

    my ($status, $result) = $c->model('Config::Violations')->read_violation('all');
    if (is_success($status)) {
        $c->stash->{violations} = $result;
    }
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head2 soh

=cut

sub soh :Local {
    my ( $self, $c ) = @_;

    $c->stash->{template} = 'configuration/soh.tt';

    my ($status, $result) = $c->model('SoH')->filters();
    if (is_success($status)) {
        $c->stash->{filters} = $result;

        ($status, $result) = $c->model('Config::Violations')->read_violation('all');
        if (is_success($status)) {
            $c->stash->{violations} = $result;
        }
    }
    if (is_error($status)) {
        $c->response->status($status);
        $c->stash->{status_msg} = $result;
        $c->stash->{current_view} = 'JSON';
    }
}

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
