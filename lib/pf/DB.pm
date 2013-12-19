package pf::DB;

=head1 NAME

pf::DB add documentation

=cut

=head1 DESCRIPTION

pf::DB

=cut

use strict;
use warnings;

use Rose::DB;
use pf::config;
use List::MoreUtils qw(any);
our @ISA = qw(Rose::DB);

__PACKAGE__->use_private_registry;

# Register your lone data source using the default type and domain
our $DB_Config = $Config{'database'};

#Adding a config reload callback that will disconnect the database when a change in the db configuration has been found
$cached_pf_config->addPostReloadCallbacks(
    'reload_db_config' => sub {
        pf::DB->new->disconnect;
        my $new_db_config = $pf::config::Config{'database'};
        if ( any { $DB_Config->{$_} ne $new_db_config->{$_} }
            qw(host port user pass db) ) {
            pf::DB->modify_db(
                database => $new_db_config->{db},
                host     => $new_db_config->{host},
                username => $new_db_config->{user},
                password => $new_db_config->{pass},
                port     => $new_db_config->{port},
            );
        }
        $DB_Config = $new_db_config;
    }
);

__PACKAGE__->register_db(
    domain   => pf::DB->default_domain,
    type     => pf::DB->default_type,
    driver   => 'mysql',
    database => $DB_Config->{db},
    host     => $DB_Config->{host},
    username => $DB_Config->{user},
    password => $DB_Config->{pass},
    port     => $DB_Config->{port},
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

