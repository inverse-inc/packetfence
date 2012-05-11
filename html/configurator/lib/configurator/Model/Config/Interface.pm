package configurator::Model::Config::Interface;
use Moose;
use namespace::autoclean;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";

use pf::config;
use Config::IniFiles;

extends 'Catalyst::Model';

=head1 NAME

pfws::Model::Config::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

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

my $pf_conf = undef;

sub _pf_conf {
  my ($self) = @_;
  # FIXME do it once per Model instance instead?
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  unless (defined $pf_conf) {
    my %conf;
    tie %conf, 'Config::IniFiles', ( -file => "$conf_dir/pf.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) || !%conf ) {
      # FIXME: unsupported by Log::Log4perl::Catalyst
      $logger->logdie("Error reading pf.conf: " . join( "\n", @errors ) . "\n" );
    }

    foreach my $section ( tied(%conf)->Sections ) {
      foreach my $key ( keys %{ $conf{$section} } ) {
        $conf{$section}{$key} =~ s/\s+$//;
      }
    }
  
    $pf_conf = \%conf;
  }

  return $pf_conf;
}

sub sectionExists {
  my ($self, $section) = @_;

  return $TRUE if ($section eq 'all');

  my $section_name = "interface $section";
  my $pf_conf = $self->_pf_conf();
  my $tied_conf = tied(%$pf_conf);
  return $tied_conf->SectionExists($section_name);
}

sub get {
  my ($self, $section) = @_;
  # FIXME do it once per Model instance instead?
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  $logger->debug("interface $section requested");

  my $pf_conf = $self->_pf_conf();
  # TODO columns should be auto-detected and displayed based on ui.conf (like print_results does)
  my @columns = qw(ip mask type enforcement gateway vip);
  my @resultset = (["interface", @columns]);
  foreach my $s ( keys %$pf_conf ) {
    if ( $s =~ /^interface (.+)$/ ) {
      my $interface_name = $1;
      if ( ( $section eq 'all' ) || ( $section eq $interface_name ) ) {
        my @values;
        foreach my $column (@columns) {
          push @values, ( $pf_conf->{$s}->{$column} || '' );
        }
        push @resultset, [$interface_name, @values];
      }
    }
  }

  if ($#resultset > 0) {
    return \@resultset;
  }
  else {
    # Section not found
    return undef;
  }
}

sub remove {
  my ($self, $section) = @_;
  # FIXME do it once per Model instance instead?
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  if ( $section eq 'all' ) {
    die "This interface can't be deleted\n";
  }

  my $section_name = "interface $section";
  my $pf_conf = $self->_pf_conf();
  my $tied_conf = tied(%$pf_conf);
  if ( $tied_conf->SectionExists($section_name) ) {
    $tied_conf->DeleteSection($section_name);
    $tied_conf->WriteConfig($conf_dir . "/pf.conf")
      or $logger->logdie("Unable to write config to $conf_dir/pf.conf. "
                         ."You might want to check the file's permissions.");
    # The following snippet updates the database
    require pf::configfile;
    import pf::configfile;
    configfile_import( $conf_dir . "/pf.conf" );
  } else {
    # Section not found
    return undef;
  }
  
  return "Successfully deleted $section";
}

sub edit {
  my ($self, $section, $assignments) = @_;
  # FIXME do it once per Model instance instead?
  my $logger = Log::Log4perl::get_logger(__PACKAGE__);

  if ( $section eq 'all' ) {
    die "This interface can't be deleted\n";
  }

  my $section_name = "interface $section";
  my $pf_conf = $self->_pf_conf();
  my $tied_conf = tied(%$pf_conf);
  if ( $tied_conf->SectionExists($section_name) ) {
    foreach my $assignment (@$assignments) {
      my ( $param, $value ) = @$assignment;
      if ( defined( $pf_conf->{$section_name}{$param} ) ) {
        $tied_conf->setval( $section_name, $param, $value );
      } else {
        $tied_conf->newval( $section_name, $param, $value );
      }
    }
    $tied_conf->WriteConfig($conf_dir . "/pf.conf")
      or $logger->logdie("Unable to write config to $conf_dir/pf.conf. "
                         ."You might want to check the file's permissions.\n");
    # The following snippet updates the database
    require pf::configfile;
    import pf::configfile;
    configfile_import( $conf_dir . "/pf.conf" );
  } else {
    # Section not found
    return undef;
  }

  return "Successfully modified $section";
}

sub add {
  my ($self, $section, $assignments) = @_;

  if ( $section eq 'all' ) {
    die "This is a reserved interface name\n";
  }

  my $section_name = "interface $section";
  my $pf_conf = $self->_pf_conf();
  my $tied_conf = tied(%$pf_conf);
  if ( !($tied_conf->SectionExists($section_name)) ) {
    foreach my $assignment (@$assignments) {
      $tied_conf->AddSection($section_name);
      my ( $param, $value ) = @$assignment;
      $tied_conf->newval( $section_name, $param, $value );
    }
    $tied_conf->WriteConfig($conf_dir . "/pf.conf")
      or die "Unable to write config to $conf_dir/pf.conf. "
        ."You might want to check the file's permissions.\n";
    require pf::configfile;
    import pf::configfile;
    configfile_import( $conf_dir . "/pf.conf" );
  } else {
    die "Interface $section already exists\n";
  }

  return "Successfully created $section";
}

__PACKAGE__->meta->make_immutable;

1;
