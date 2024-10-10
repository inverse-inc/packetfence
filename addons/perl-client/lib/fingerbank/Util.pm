package fingerbank::Util;

=head1 NAME

fingerbank::Util

=head1 DESCRIPTION

Methods that helps simplify code reading

=cut

use strict;
use warnings;

use File::Copy qw(copy move);
use File::Find;
use File::Touch;
use LWP::UserAgent;
use HTTP::Message;
use Compress::Raw::Zlib;
use POSIX;
use LWP::Protocol::connect;

use fingerbank::Constant qw($TRUE $FALSE $FINGERBANK_USER $DEFAULT_BACKUP_RETENTION);
use fingerbank::Config;
use fingerbank::FilePath qw($INSTALL_PATH);

use Digest::MD5 qw(md5_hex);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
        is_enabled 
        is_disabled
        is_success
        is_error
    );
}

=head1 METHODS

=head2 is_enabled

Is the given configuration parameter considered enabled? y, yes, true, enable, enabled and 1 are all positive values

=cut

sub is_enabled {
    my ($enabled) = @_;
    if ( $enabled && $enabled =~ /^\s*(y|yes|true|enable|enabled|1)\s*$/i ) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=head2 is_disabled

Is the given configuration parameter considered disabled? n, no, false, disable, disabled and 0 are all negative values

=cut

sub is_disabled {
    my ($disabled) = @_;
    if ( !defined ($disabled) || $disabled =~ /^\s*(n|no|false|disable|disabled|0)\s*$/i ) {
        return $TRUE;
    } else {
        return $FALSE;
    }
}

=head2 is_success

Returns a true or false value based on if given error code is considered a success or not.

=cut

sub is_success {
    my ($code) = @_;

    return $FALSE if ( $code !~ /^\d+$/ );

    return $TRUE if ($code >= 200 && $code < 300);
    return $FALSE;
}

=head2 is_error

Returns a true or false value based on if given error code is considered an error or not.

=cut

sub is_error {
    my ($code) = @_;

    return $FALSE if ( $code !~ /^\d+$/ );

    return $TRUE if ($code >= 400 && $code < 600);
    return $FALSE;
}

=head2 cleanup_backup_files

Cleanup backup files that have been created while updating a file

=cut

sub cleanup_backup_files {
    my ($file, $keep) = @_;
    my $logger = fingerbank::Log::get_logger;

    $keep //= $DEFAULT_BACKUP_RETENTION;

    # extracting directory and filename from provided info
    my @parts = split('/', $file);
    my $filename = pop @parts;
    my $directory = join('/', @parts);
    my $metaquoted_name = quotemeta($filename);

    my @files;
    # we find all the backup files associated
    # They end with an underscore digits another underscore and another serie of digits
    File::Find::find({wanted => sub {
        /^$metaquoted_name\_[0-9]+\_[0-9+]/ && push @files, $File::Find::name ;
    }}, $directory);

    # we sort them by name as they contain the date
    # so that will give them in ascending order
    @files = sort(@files);
    
    # we remove the amount we want to keep
    foreach my $i (1..$keep){
        pop @files;    
    }

    # all the files remaining are unwanted
    foreach my $file (@files){
        $logger->info("Deleting backup file $file");
        unless(unlink $file){
            $logger->error("Couldn't delete file $file");
        }
    }
}

sub update_file {
    my ( %params ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my ( $status, $status_msg );

    my @require = qw(download_url destination);
    foreach ( @require ) {
        if ( !exists $params{$_} ) {
            $status_msg = "Missing parameter '$_' while trying to update file";
            $logger->warn($status_msg);
            return ( $fingerbank::Status::INTERNAL_SERVER_ERROR, $status_msg );
        }
    }


    my $is_an_update;
    if ( -f $params{'destination'} ) {
        $is_an_update = $TRUE;
    } else {
        $is_an_update = $FALSE;
    }

    ($status, $status_msg) = fetch_file(%params, $is_an_update ? ('destination' => $params{'destination'} . '.new') : ());

    if (is_error($status)) {
        return ($status, $status_msg);
    }

    if ( $is_an_update ) {
        my $date                    = POSIX::strftime( "%Y%m%d_%H%M%S", localtime );
        my $destination_backup    = $params{'destination'} . "_$date";
        my $destination_new       = $params{'destination'} . ".new";

        my $return_code;

        # We create a backup of the actual file
        $logger->debug("Backing up current file '$params{'destination'}' to '$destination_backup'");
        $return_code = copy($params{'destination'}, $destination_backup);

        # If copy operation succeed
        if ( $return_code == 1 ) {
            # We move the newly downloaded file to the existing one
            $logger->debug("Moving new file to existing one");
            $return_code = move($destination_new, $params{'destination'});
        }

        # Handling error in either copy or move operation
        if ( $return_code == 0 ) {
            $status = $fingerbank::Status::INTERNAL_SERVER_ERROR;
            $logger->warn("An error occured while copying / moving files while updating '$params{'destination'}' : $!");
        }
    }

    if ( is_success($status) ) {
        $status_msg = "Successfully updated file '$params{'destination'}'";
        $logger->info($status_msg);

        return ( $status, $status_msg );
    }

    $status_msg = "An error occured while updating file '$params{'destination'}'";
    $logger->warn($status_msg);

    return ( $status, $status_msg )
}

=head2 fetch_file

Download the latest version of a file

=cut

sub fetch_file {
    my ( %params ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my @require = qw(download_url destination);
    foreach ( @require ) {
        if ( !exists $params{$_} ) {
            my $msg = "Missing parameter '$_' while trying to fetch file";
            $logger->warn($msg);
            return ($fingerbank::Status::INTERNAL_SERVER_ERROR, $msg);
        }
    }

    my $Config = fingerbank::Config::get_config();
    my $outfile = $params{'destination'}.".download";
    my $download_url = $params{'download_url'};

    unless ( fingerbank::Config::is_api_key_configured() || (exists($params{'api_key'}) && $params{'api_key'} ne "") ) {
        my $msg = "Can't communicate with Fingerbank project without a valid API key.";
        $logger->warn($msg);
        return ($fingerbank::Status::UNAUTHORIZED, $msg);
    }

    $logger->debug("Downloading the latest version from '$download_url' to '$outfile'");

    my $ua = fingerbank::Util::get_lwp_client();
    $ua->timeout(60);   # An update query should not take more than 60 seconds

    my $api_key = ( exists($params{'api_key'}) && $params{'api_key'} ne "" ) ? $params{'api_key'} : $Config->{'upstream'}{'api_key'};    
    $params{get_params} //= {};
    my %parameters = ( key => $api_key, %{$params{get_params}} );
    my $url = URI->new($download_url);
    $url->query_form(%parameters);

    my $fh;
    unless (open($fh, ">", $outfile)) {
        undef $ua;
        my $msg = "Unable to open file $outfile in write mode";
        $logger->error($msg);
        return ($fingerbank::Status::INTERNAL_SERVER_ERROR, $msg)
    };
    my ($status, $status_msg);

    #  To avoid high memory consumption handle the decompression manually
    #  And save the file contents to file system while downloading
    my $ctx = Digest::MD5->new;
    my $req = HTTP::Request->new(GET => $url);
    my $gz = Compress::Raw::Zlib::Inflate->new(WindowBits => WANT_GZIP);
    my $res = $ua->request($req, sub {
        my ($data, $response, $protocol) = @_;
        my $out = '';
        my $content_encoding = $response->content_encoding;
        if (defined $content_encoding && ($content_encoding eq 'gzip' || $content_encoding eq 'x-gzip')) {
            $status = $gz->inflate($data, $out) ;
        } else {
            $out = $data;
        }
        print $fh $out;
        $ctx->add($out);
    });
    close($fh);

    if ( $res->is_success ) {
        $status = $fingerbank::Status::OK;
        $status_msg = "Successfully fetched '$download_url' from Fingerbank project";
        $logger->info($status_msg);
        my $md5 = $res->header('X-Fingerbank-Md5');
        my $file_md5 = $ctx->hexdigest;
        if(defined($md5) && $file_md5 ne $md5) {
            undef $ua;
            unlink($outfile) if -f $outfile;
            $logger->error("Checksum does not match for download expected '$md5' recieved '$file_md5'.");
            return ($fingerbank::Status::INTERNAL_SERVER_ERROR, "Checksum is not correct for download");
        }
        if(!rename $outfile, $params{'destination'}) {
            undef $ua;
            unlink($outfile) if -f $outfile;
            my $msg = "Cannot move $outfile to $params{destination}"; 
            $logger->error($msg);
            return ($fingerbank::Status::INTERNAL_SERVER_ERROR, $msg);
        }
        set_permissions($params{'destination'}, { 'permissions' => $fingerbank::Constant::FILE_PERMISSIONS });
    } else {
        unlink($outfile) if -f $outfile;
        $status = $fingerbank::Status::INTERNAL_SERVER_ERROR;
        $status_msg = "Failed to download latest version of file '$params{destination}' on '$download_url' with the following return code: " . $res->status_line;
        $logger->warn($status_msg);
    }
    undef $ua;

    return ($status, $status_msg);
}

=head2 get_proxy_url

=cut

sub get_proxy_url {
    my ($proto) = @_;
    my $Config = fingerbank::Config::get_config();
    
    return "" if ( !$Config->{'proxy'}{'host'} || !$Config->{'proxy'}{'port'} );

    my $proxy_host = $Config->{'proxy'}{'host'};
    my $proxy_port = $Config->{'proxy'}{'port'};

    return "$proto://$proxy_host:$proxy_port";
}

=head2 get_lwp_client

Returns a LWP::UserAgent for WWW interaction

=cut

sub get_lwp_client {
    my (%args) = @_;
    $args{use_proxy} //= $TRUE;
    my $ua = LWP::UserAgent->new(%args);

    my $Config = fingerbank::Config::get_config();

    # Proxy is enabled
    if ( $args{use_proxy} && is_enabled($Config->{'proxy'}{'use_proxy'}) ) {
        return $ua if ( !$Config->{'proxy'}{'host'} || !$Config->{'proxy'}{'port'} );

        my $verify_ssl = ( is_enabled($Config->{'proxy'}{'verify_ssl'}) ) ? $TRUE : $FALSE;

        $ua = LWP::UserAgent->new(%args, ssl_opts => { verify_hostname => $verify_ssl });
        $ua->proxy(['https', 'http', 'ftp'] => get_proxy_url("connect"));
    }
    
    $ua->default_header('Accept-Encoding' => 'gzip, x-gzip');
    $ua->agent("Fingerbank-Perl-Library/".$fingerbank::Constant::VERSION);

    return $ua;
}

=head2 get_database_path

Get database file path based on schema

=cut

sub get_database_path {
    my ( $schema ) = @_;
    return $INSTALL_PATH . "db/" . "fingerbank_$schema.db";
}

=head2 set_permissions

Sets the proper permissions for a given file / path

=cut

sub set_permissions {
    my ($path, $params) = @_;
    my $logger = fingerbank::Log::get_logger;

    my $permissions;
    if ( !$params->{'permissions'} ) {
        my %files = map { $_ => 1 } @fingerbank::FilePath::FILES;
        my %paths = map { $_ => 1 } @fingerbank::FilePath::PATHS;
        if ( exists($files{$path}) ) {
            $permissions = $fingerbank::Constant::FILE_PERMISSIONS;
        } elsif ( exists($paths{$path}) ) {
            $permissions = $fingerbank::Constant::PATH_PERMISSIONS;
        } else {
            $permissions = $fingerbank::Constant::FILE_PERMISSIONS;
        }
    } else {
        $permissions = $params->{'permissions'};
    }

    my ($login,$pass,$uid,$gid) = getpwnam($FINGERBANK_USER)
        or die "$FINGERBANK_USER not in passwd file";

    $logger->debug("Setting permissions for path '$path' | uid: '$uid' gid: '$gid' permissions: '$permissions'");

    chown $uid, $gid, $path;
    chmod $permissions, $path;
}

=head2 fix_permissions

Fix permissions of Fingerbank "important" files / paths

=cut

sub fix_permissions {
    # Handling files
    foreach my $file ( @fingerbank::FilePath::FILES ) {
        set_permissions($file);
    }

    # Handling paths
    foreach my $path ( @fingerbank::FilePath::PATHS ) {
        set_permissions($path);
    }

    # Handling specific cases
    set_permissions($fingerbank::FilePath::INSTALL_PATH . 'db/upgrade.pl', { 'permissions' => 0775 });
}

=head2

Touch each database schema file to change timestamp which will lead to invalidate active handles and recreate them

=cut

sub reset_db_handles {
    my ( $self ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my @database_files = ();
    foreach my $schema ( @fingerbank::DB::schemas ) {
        my $database_file = get_database_path($schema);
        push(@database_files, $database_file);
    }

    touch(@database_files);
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

1;
