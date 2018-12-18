package captiveportal::PacketFence::DynamicRouting::Module::SSL_Inspection;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::SSL_Inspection

=head1 DESCRIPTION

SSL Inspection module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';
with 'captiveportal::Role::Routed';


use Tie::IxHash;
use pf::log;
use List::Util qw(first);
use pf::config;
use pf::violation;
use pf::config::violation;
use pf::config::util;
use pf::web::guest;
use pf::util;
use pf::node;
use pf::constants;
use fingerbank::Model::Device;

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/ssl_inspection/ios' => \&ios,
        '/ssl_inspection/android' => \&android,
        '/ssl_inspection/osx' => \&osx,
        '/ssl_inspection/windows' => \&windows,
        '/ssl_inspection/chrome' => \&chrome,
        '/ssl_inspection/firefox' => \&firefox,
        '/ssl_inspection/opera' => \&opera,
        '/ssl_inspection/other' => \&other,
        # fallback to the index
        '/captive-portal' => \&index,
    );
    return \%map;
});

has 'skipable' => (is => 'rw', default => sub {1});

has 'ssl_path' => (is => 'rw', required => 1);


=head2 index

Present 

=cut

sub index {
    my ($self) = @_;

    my $node_info = node_view($self->current_mac);
    my $device_name = $node_info->{device_type};
    
    if($self->app->request->param('next')){
        $self->done();
        return;
    }

# Check if Firefox or Opera browser first    
    if ($self->app->current_user_agent =~ /Firefox/) { $self->firefox(); }
    elsif ($self->app->current_user_agent =~ /OPR/) { $self->opera(); }
    elsif (fingerbank::Model::Device->is_a($device_name, 'iOS')) { $self->ios(); }
    elsif (fingerbank::Model::Device->is_a($device_name, 'Android OS')) { $self->android(); }
    elsif (fingerbank::Model::Device->is_a($device_name, 'Mac OS X or macOS')) { $self->osx(); }
    elsif (fingerbank::Model::Device->is_a($device_name, 'Windows OS')) { $self->windows(); }
    elsif (fingerbank::Model::Device->is_a($device_name, 'Chrome OS')) { $self->chrome(); }
    else { $self->other(); }
}


=head2 ios

ios

=cut

sub ios {
    my ($self) = @_;

    $self->render('ssl_inspection/ios.html', {
        title => "iOS",
	ssl_path => $self->ssl_path, 
    });
}

=head2 android

android

=cut

sub android {
    my ($self) = @_;

    $self->render('ssl_inspection/android.html', {
        title => "Android",
	ssl_path => $self->ssl_path, 
    });
}

=head2 osx

xos

=cut

sub osx {
    my ($self) = @_;

    $self->render('ssl_inspection/osx.html', {
        title => "macOS",
	ssl_path => $self->ssl_path, 
    });
}

=head2 windows

Windows

=cut

sub windows {
    my ($self) = @_;

    $self->render('ssl_inspection/windows.html', {
        title => "Windows",
	ssl_path => $self->ssl_path, 
    });
}

=head2 chrome

chrome

=cut

sub chrome {
    my ($self) = @_;

    $self->render('ssl_inspection/chrome.html', {
        title => "Chrome OS",
	ssl_path => $self->ssl_path, 
    });
}

=head2 firefox

Firefox

=cut

sub firefox {
    my ($self) = @_;

    $self->render('ssl_inspection/firefox.html', {
        title => "Firefox",
	ssl_path => $self->ssl_path, 
    });
}

=head2 opera

Opera

=cut

sub opera {
    my ($self) = @_;

    $self->render('ssl_inspection/opera.html', {
        title => "Opera",
	ssl_path => $self->ssl_path, 
    });
}

=head2 other

other

=cut

sub other {
    my ($self) = @_;

    $self->render('ssl_inspection/other.html', {
        title => "Other",
	ssl_path => $self->ssl_path, 
    });
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

