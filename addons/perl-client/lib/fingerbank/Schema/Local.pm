package fingerbank::Schema::Local;

use Moose;
use namespace::autoclean;

use fingerbank::FilePath qw($INSTALL_PATH);

extends 'DBIx::Class::Schema';

our $VERSION = "4.1";

sub ordered_schema_versions {
    return ("1.0", "2.0", "2.1", "2.2", "2.3", "3.0", "3.1", "4.0", "4.1");
}

__PACKAGE__->load_classes;

__PACKAGE__->load_components(qw/Schema::Versioned/);
__PACKAGE__->upgrade_directory("$INSTALL_PATH/db/upgrade/");

__PACKAGE__->meta->make_immutable;

1;
