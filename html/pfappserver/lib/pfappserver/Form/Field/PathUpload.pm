package pfappserver::Form::Field::PathUpload;

=head1 NAME

pfappserver::Form::Field::Path - A path field

=head1 DESCRIPTION

This field extends the default Text field and checks if the input value is an valid path

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Text';

use pf::util;
use namespace::autoclean;
use pf::log;
use pf::file_paths qw($conf_uploads);
use MIME::Base64;
use pf::cluster;
has upload_namespace => ( is => 'rw', isa => 'Str', required => 1 );
has config_prefix => ( is => 'rw', isa => 'Str', required => 1 );
has '+writeonly' => (default => 1);
has '+noupdate' => (default => 1);

apply [
    {
        transform => sub {
            my ($value, $field) = @_;
            my $name = $field->name;
            my $id = $field->parent->field("id")->value;
            my $file = "$conf_uploads/" . $field->upload_namespace . "/${id}_$name" . $field->config_prefix;
            safe_file_update($file, decode_base64($value));
            eval { pf::cluster::sync_files([$file]) };
            if ($@) {
                get_logger->error("Error syncing file $file: $@");
            }

            $field->noupdate(0);
            return $file;
        }
    }
];

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
