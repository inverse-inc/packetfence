package pf::cmd::pf::pfconfig;
=head1 NAME

pf::cmd::pf::pfconfig add documentation

=head1 SYNOPSIS

pfcmd pfonfig expire|reload|list|show|get|clear_overlay

=head1 DESCRIPTION

pf::cmd::pf::pfconfig

=cut

use strict;
use warnings;
use pfconfig::manager;
use pfconfig::util;
use base qw(pf::base::cmd::action_cmd);

=head2 new

expire pfconfig's namespace

=cut

sub action_expire {
    my ($self) = @_;
    my ($namespace) = $self->action_args;
    my $manager = pfconfig::manager->new;
    $manager->expire($namespace);
    return 0;
}

sub parse_expire {
    my ($self,@args) = @_;
    return @args == 1;
}

=head2 new

reload pfconfig

=cut

sub action_reload {
    my ($self) = @_;
    my $manager = pfconfig::manager->new;
    $manager->expire_all();
    return 0;
}

=head2 new

show from cache pfconfig's namespace

=cut

sub action_show {
    my ($self) = @_;
    my ($full_namespace) = $self->action_args;
    my ($namespace, @args) = pfconfig::util::parse_namespace($full_namespace);
    my $manager = pfconfig::manager->new;
    if(defined($namespace)){
        my @namespaces = $manager->list_namespaces();
        if ( grep {$_ eq $namespace} @namespaces){
            use Data::Dumper;
            print Dumper($manager->get_cache($full_namespace));
        }
    }
    return 0; 
}

=head2 new

list all pfconfig's namespaces

=cut

sub action_list {
    my ($self) = @_;
    my $manager = pfconfig::manager->new;
    my @namespaces = $manager->list_namespaces();
    foreach my $namespace (@namespaces){
        print "$namespace\n";
    }
    return 0;
}

=head2 new

get from socket pfconfig's namespace

=cut

sub action_get {
    my ($self) = @_;
    my ($namespace) = $self->action_args;
    if(defined($namespace)){
        use pfconfig::cached;
        use Data::Dumper;
        my $obj = pfconfig::cached->new;
        my $response = $obj->_get_from_socket($namespace, "element");
        print Dumper($response);
    }
    return 0;
}

=head2 new

clear_overlay of pfconfig

=cut

sub action_clear_overlay {
    my ($self) = @_;
    my $manager = pfconfig::manager->new;
    $manager->clear_overlayed_namespaces(); 
    return 0;
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
