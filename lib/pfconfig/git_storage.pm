package pfconfig::git_storage;

use strict;
use warnings;

use pfconfig::config;
use pf::util qw(isenabled);
use pf::log;

sub config {
    my ($proto) = @_;
    return $pfconfig::config::INI_CONFIG->section("git_storage");
}

sub is_enabled {
    my ($proto) = @_;
    return isenabled($proto->config->{status});
}

sub conf_directory {
    my ($proto) = @_;
    return $proto->config->{conf_directory};
}

sub git_directory {
    my ($proto) = @_;
    return $proto->config->{git_directory};
}

sub commit_file {
    my ($proto, $src) = @_;

    get_logger->info("Pushing $src to git_storage");

    my $file = $src;

    # Strip the prefix of the directory
    my $conf_directory = $proto->conf_directory;
    if($src =~ /^$conf_directory/) {
        $file = $src;
        $file =~ s|^$conf_directory||;
    }

    # Ensure there isn't a prefixing slash
    $file = substr($file, 1) if($file =~ /^\//);

    my $tries = 0;
    my $last_error;
    my $success;
	while(!$success && $tries <= 3) {
        $tries ++;
        system("cd ".$proto->git_directory." && git pull");
        if($? != 0) {
            $last_error = "Unable to pull repository";
            sleep 3;
            next;
            #return (undef, "Unable to pull repository");
        }

        system("cp -a $src ".$proto->git_directory."/".$file);
        if($? != 0) {
            $last_error = "Unable to copy $src into git repository $file";
            sleep 3;
            next;
            #return (undef, "Unable to copy $src into git repository $file");
        }

        system("cd ".$proto->git_directory." && git add ".$proto->git_directory."/".$file . " && git commit --allow-empty -m 'update $file' && git push");
        if($? != 0) {
            $last_error = "Unable to push repository. Please retry the change.";
            sleep 3;
            next;
            #return (undef, "Unable to push repository. Please retry the change.");
        }

        $last_error = undef;
        $success = 1;
    }

    if($last_error) {
        return (undef, $last_error);
    }
    else {
        return (1, "Updated $file in git storage");
    }
}

sub update {
    my ($proto) = @_;

    if(!$proto->is_enabled) {
        get_logger->error("git_storage isn't enabled. Refusing to update.");
        return 0;
    }

    system("cd ".$proto->git_directory." && git pull");
    if($? != 0) {
        #TODO: implement retries
        get_logger->error("Unable to pull repository");
        return 0;
    }
    system("cp -a ".$proto->git_directory."/* ".$proto->conf_directory."/");
    if($? != 0) {
        #TODO: implement retries
        get_logger->error("Unable to copy repository files");
        return 0;
    }

    return 1;
}

1;
