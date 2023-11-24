package fingerbank::DB_Factory;

=head1 NAME

fingerbank::DB_Factory

=head1 DESCRIPTION

Factory to create database connections

=cut

use Moose;
use namespace::autoclean;

use fingerbank::Constant qw($SQLITE_DB_TYPE);
use fingerbank::DB::SQLite;
use fingerbank::Config;
use fingerbank::Log;
use fingerbank::Util qw(is_enabled);
use List::MoreUtils qw(any);

sub instantiate {
    my ($self, %args) = @_;
    
    my $logger = fingerbank::Log::get_logger;
    my $Config = fingerbank::Config::get_config;

    if($args{type}) {
        $args{forced_type} = $args{type};
    }

    $args{type} //= $SQLITE_DB_TYPE;
    my $type = $args{forced_type} // $args{type};

    $logger->debug("Using SQLite as database for schema ".$args{schema});
    return fingerbank::DB::SQLite->new(%args);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

