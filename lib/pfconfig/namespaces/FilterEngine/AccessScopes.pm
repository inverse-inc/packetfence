package pfconfig::namespaces::FilterEngine::AccessScopes;

=head1 NAME

pfconfig::namespaces::FilterEngine::AccessScopes - Base class for scoped filter engine

=cut

=head1 DESCRIPTION

pfconfig::namespaces::FilterEngine::AccessScopes

=cut

use strict;
use warnings;
use pfconfig::namespaces::config;
use pf::AccessScopes;
use pf::log;
use pf::IniFiles;

use base 'pfconfig::namespaces::resource';

sub parentConfig {
    my ($self) = @_;
    my $class = ref($self) || $self;
    die "${class}::parentConfig has not been implemented\n";
}


sub build {
    my ($self)            = @_;
    my $config   = $self->parentConfig;
    $config->init;
    my $file = $config->{file};
    my $ini = pf::IniFiles->new(%{$config->{added_params}}, -file => $file, -allowempty => 1);
    unless ($ini) {
        my $error_msg = join("\n", @pf::IniFiles::errors, "");
        get_logger->error($error_msg);
        warn($error_msg);
        return {};
    }

    my $asb = pf::AccessScopes->new();
    my ($errors, $accessScopes) = $asb->build($ini);
    for my $err (@{ $errors // [] }) {
        my $error_msg =  "$file: $err->{rule}) $err->{message}";
        get_logger->error($error_msg);
        warn($error_msg);
    }

    return $accessScopes;
}

=head2 _error

Record and display an error that occured while building the engine

=cut

sub _error {
    my ($self, $msg, $add_info) = @_;
    my $long_msg = $msg. (defined($add_info) ? " : $add_info" : '');
    $long_msg .= "\n" unless $long_msg =~ /\n\z/s;
    warn($long_msg);
    get_logger->error($long_msg);
    push @{$self->{errors}}, $msg;
}

sub build_filter {
    my ($self, $filters_scopes, $parsed_conditions, $data) = @_;
    my $condition = eval { $self->build_filter_condition($parsed_conditions) };
    if ($condition) {
        push @{$filters_scopes->{$data->{scope}}}, pf::filter->new({
            answer    => $data,
            condition => $condition,
        });
    } else {
        $self->_error("Error build rule '$data->{_rule}'", $@)
    }
}

sub build_filter_condition {
    my ($self, $parsed_condition) = @_;
    if (ref $parsed_condition) {
        local $_;
        my ($type, @parsed_conditions) = @$parsed_condition;
        my $conditions = [map {$self->build_filter_condition($_)} @parsed_conditions];
        if($type eq 'NOT' ) {
            return pf::condition::not->new({condition => $conditions->[0]});
        }
        my $module = $type eq 'AND' ? 'pf::condition::all' : 'pf::condition::any';
        return $module->new({conditions => $conditions});
    }
    my $condition = $self->{prebuilt_conditions}->{$parsed_condition};
    return $condition if defined $condition;
    die "condition '$parsed_condition' was not found\n";
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
