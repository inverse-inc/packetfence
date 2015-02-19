package pfconfig::backend::mysql;

=head1 NAME

pfconfig::backend::mysql

=cut

=head1 DESCRIPTION

pfconfig::backend::mysql

=cut

use strict;
use warnings;
use Sereal::Encoder;
use Sereal::Decoder;
use DBI;

use base 'pfconfig::backend';

sub init {
  # abstact
}

sub _get_db {
  my ($self) = @_;
  my $db = DBI->connect("DBI:mysql:database=pf;host=localhost",
                         "pf", "pf",
                         {'RaiseError' => 1});
  return $db 
}


sub get {
  my ($self, $key) = @_;
  my $db = $self->_get_db();
  my $statement = $db->prepare("SELECT value FROM keyed WHERE id=".$db->quote($key));
  $statement->execute();
  my $element;
  while(my $row = $statement->fetchrow_hashref()){
    my $decoder = Sereal::Decoder->new;
    $element = $decoder->decode($row->{value});
  }
  $db->disconnect();
  return $element;
} 

sub set {
  my ($self, $key, $value) = @_;
  my $db = $self->_get_db();
  my $encoder = Sereal::Encoder->new;
  $value = $encoder->encode($value);
  my $result = $db->do("REPLACE INTO keyed (id, value) VALUES(?,?)", undef, $key, $value);
  $db->disconnect();
  return $result;
}

sub remove {
  my ($self, $key) = @_;
  my $db = $self->_get_db();
  my $result = $db->do("DELETE FROM keyed where id=?", undef, $key);
  $db->disconnect();
  return $result;
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

