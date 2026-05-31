package pf::Authentication::Source::HtpasswdSource;

=head1 NAME

pf::Authentication::Source::HtpasswdSource

=head1 DESCRIPTION

=cut

use pf::constants qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Source;
use pf::cluster;
use pf::util;
use pf::log;

use Apache::Htpasswd;

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => (default => 'Htpasswd');
has 'path' => (isa => 'Str', is => 'rw', required => 1);

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 available_attributes

=cut

sub available_attributes {
    my $self = shift;

    my $super_attributes = $self->SUPER::available_attributes;
    my $own_attributes = [{ value => 'username', type => $Conditions::SUBSTRING }];

    return [@$super_attributes, @$own_attributes];
}

=head2 authenticate

=cut

sub authenticate {
    my ($self, $username, $password) = @_;

    my $logger = get_logger();
    my $password_file = $self->{'path'};

    if (! -r $password_file) {
        $logger->error("unable to read password file '$password_file'");
        return ($FALSE);
    }

    my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});
    if ( (!defined($htpasswd->htCheckPassword($username, $password)))
         or ($htpasswd->htCheckPassword($username, $password) == 0) ) {

        return ($FALSE, $AUTH_FAIL_MSG);
    }

    return ($TRUE, $AUTH_SUCCESS_MSG);
}

=head2 match_in_subclass

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    local $_;

    # First check if the username is found in the htpasswd file
    my $username = $params->{'username'} || $params->{'email'};
    my $password_file = $self->{'path'};
    if ($username && -r $password_file) {
        my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly => 1});
        if ( $htpasswd->fetchPass($username) ) {
            # Username is defined in the htpasswd file
            # Let's match the htpasswd conditions alltogether.
            # We should only have conditions based on the username attribute.
            foreach my $condition (@{ $own_conditions }) {
                if ($condition->{'attribute'} eq "username") {
                    if ( $condition->matches("username", $username, $params) ) {
                        push(@{ $matching_conditions }, $condition);
                    }
                }
            }
            return ($username, undef);
        }
    }

    return (undef, undef);
}

=head2 _ensure_password_file

Make sure the password file exists and is writable. Creates an empty file if
missing so that user CRUD operations from the GUI work on a fresh source.
When the file is newly created it is fixed up for the pf user and propagated
to the other cluster members through pf::cluster::sync_files().
Returns the path on success, dies otherwise.

=cut

sub _ensure_password_file {
    my ($self) = @_;
    my $logger = get_logger();
    my $path = $self->{'path'};
    die "no path configured for this Htpasswd source\n"
        unless defined $path && $path ne '';

    if (! -e $path) {
        safe_file_update($path, "");
        fix_file_permissions($path);
        eval { pf::cluster::sync_files([$path]) };
        if ($@) {
            $logger->error("error syncing new htpasswd file '$path' to cluster: $@");
        }
    }
    return $path;
}

=head2 validate_path

Check that the configured path is usable for an htpasswd file. Returns the
empty list when the path is valid, otherwise a list of human-readable error
messages describing every problem found. The checks mirror what the
Htpasswd source form does at save time, so that the "Create new htpasswd
file" GUI action refuses to act on the same paths the form would reject.

=cut

sub validate_path {
    my ($self) = @_;
    require File::Basename;

    my $path = $self->{'path'};
    my @errors;
    if (!defined $path || $path eq '') {
        return ('no path configured for this Htpasswd source');
    }
    if ($path !~ m{^/}) {
        push @errors, "Path must be absolute, e.g. /usr/local/pf/conf/htpasswd_admins.";
    }
    my ($base, $dir) = File::Basename::fileparse($path);
    if ($base eq '' || $base eq '.' || $base eq '..') {
        push @errors, "Path must include a file name, not just a directory.";
    }
    if (-e $path) {
        if (-d $path) {
            push @errors, "Path points to an existing directory, not a file.";
        }
        elsif (!-f $path) {
            push @errors, "Path exists but is not a regular file.";
        }
        elsif (!-r $path) {
            push @errors, "The file is not readable by the user 'pf'.";
        }
    }
    elsif (defined $dir && $dir ne '') {
        # File does not exist yet. Missing intermediate directories will be
        # created by safe_file_update / pf_make_dir, so we only require that
        # the closest existing ancestor really is a directory. The IO layer
        # surfaces any real write-permission problem at create time.
        # The path must also live somewhere under the PacketFence tree so we
        # don't help an admin scatter htpasswd files in unrelated places.
        my $ancestor = $dir;
        $ancestor =~ s{/+$}{};
        while (length $ancestor && !-e $ancestor) {
            $ancestor =~ s{/[^/]+$}{};
        }
        $ancestor = '/' if $ancestor eq '';
        if (!-d $ancestor) {
            push @errors, "Closest existing ancestor '$ancestor' is not a directory.";
        }
        if ($path !~ m{^/usr/local/pf/}) {
            push @errors, "Path must live under /usr/local/pf/ (got '$path').";
        }
    }
    return @errors;
}

=head2 create_file

Create the password file for this source on disk (empty) and propagate it to
all cluster members. Idempotent: if the file already exists, nothing is
written. Validates the configured path first (same rules as the source
form) and dies with the validation message when the path is unusable.
Returns a hashref { created => 0|1 } indicating whether the file was newly
created. Dies on write errors.

=cut

sub create_file {
    my ($self) = @_;
    my @errors = $self->validate_path;
    if (@errors) {
        die join("\n", @errors) . "\n";
    }
    my $path = $self->{'path'};
    my $already = -e $path ? 1 : 0;
    $self->_ensure_password_file;
    return { created => $already ? 0 : 1 };
}

=head2 file_exists

Return a boolean indicating whether the configured htpasswd file exists on
the local filesystem. No cluster check is performed.

=cut

sub file_exists {
    my ($self) = @_;
    my $path = $self->{'path'};
    return 0 unless defined $path && $path ne '';
    return -e $path ? 1 : 0;
}

=head2 list_users

Return the list of usernames defined in the htpasswd file.

=cut

sub list_users {
    my ($self) = @_;
    my $path = $self->{'path'};
    return [] unless defined $path && $path ne '' && -r $path;

    my $htpasswd = Apache::Htpasswd->new({ passwdFile => $path, ReadOnly => 1 });
    my @users = $htpasswd->fetchUsers();
    return [ sort @users ];
}

=head2 set_user

Add or update a user in the htpasswd file and sync the file to all cluster
members. Dies on validation errors or htpasswd library errors.

=cut

sub set_user {
    my ($self, $username, $password) = @_;
    my $logger = get_logger();

    die "username must not be empty\n"
        if !defined $username || $username eq '';
    die "username must not contain ':' or whitespace\n"
        if $username =~ /[:\s]/;
    die "password must not be empty\n"
        if !defined $password || $password eq '';

    my $path = $self->_ensure_password_file;
    my $htpasswd = Apache::Htpasswd->new({ passwdFile => $path });
    my $ok;
    if ($htpasswd->fetchPass($username)) {
        $ok = $htpasswd->htpasswd($username, $password, { 'overwrite' => 1 });
    } else {
        $ok = $htpasswd->htpasswd($username, $password);
    }
    unless ($ok) {
        die "unable to write user '$username' to '$path': " . $htpasswd->error . "\n";
    }
    fix_file_permissions($path);

    eval { pf::cluster::sync_files([$path]) };
    if ($@) {
        $logger->error("error syncing htpasswd file '$path' to cluster: $@");
    }
    return $TRUE;
}

=head2 delete_user

Remove a user from the htpasswd file and sync the file to all cluster members.
Returns true even if the user did not exist. Dies on htpasswd library errors.

=cut

sub delete_user {
    my ($self, $username) = @_;
    my $logger = get_logger();

    die "username must not be empty\n"
        if !defined $username || $username eq '';

    my $path = $self->{'path'};
    return $TRUE unless defined $path && $path ne '' && -e $path;

    my $htpasswd = Apache::Htpasswd->new({ passwdFile => $path });
    return $TRUE unless $htpasswd->fetchPass($username);

    unless ($htpasswd->htDelete($username)) {
        die "unable to delete user '$username' from '$path': " . $htpasswd->error . "\n";
    }

    eval { pf::cluster::sync_files([$path]) };
    if ($@) {
        $logger->error("error syncing htpasswd file '$path' to cluster: $@");
    }
    return $TRUE;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
