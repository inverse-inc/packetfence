package pfconfig::git_storage;

use strict;
use warnings;

use pfconfig::config;
use pf::util qw(isenabled);
use pf::log;
use File::Basename;

sub config {
    my ($proto) = @_;
    return $pfconfig::config::INI_CONFIG->section("git_storage");
}

sub is_enabled {
    my ($proto) = @_;
    return isenabled($proto->config->{status});
}

sub should_k8s_deploy {
    my ($proto) = @_;
    return isenabled($proto->config->{k8s_deploy});
}

sub conf_directory {
    my ($proto) = @_;
    return $proto->config->{conf_directory};
}

sub fingerbank_conf_directory {
    my ($proto) = @_;
    return $proto->config->{fingerbank_conf_directory};
}

sub git_directory {
    my ($proto) = @_;
    return $proto->config->{git_directory};
}

sub commit_file {
    my ($proto, $src, $dst, %opts) = @_;

    my $unprefixed_dst = $dst;

    $opts{push} //= 1;

    $dst = $proto->git_directory . "/" . $dst;
    get_logger->info("Pushing $src to git_storage $dst");

    my $tries = 0;
    my $last_error;
    my $success;
	while(!$success && $tries <= 3) {
        $tries ++;

        ($success, $last_error) = $proto->pull();
        if(!$success) {
            sleep 3;
            next;
        }

        my $basedir = dirname($dst);
        system("mkdir -p $basedir");
        if($? != 0) {
            $last_error = "Unable to create directory for file $dst";
            sleep 3;
            next;
        }

        system("cp -a $src $dst");
        if($? != 0) {
            $last_error = "Unable to copy $src into git repository $dst";
            sleep 3;
            next;
        }

        system("cd ".$proto->git_directory." && git add -f $unprefixed_dst && git commit --allow-empty -m 'update $unprefixed_dst'");
        if($? != 0) {
            $last_error = "Unable to commit to repository. Please retry the change.";
            sleep 3;
            next;
        }

        if($opts{push}) {
            ($success, $last_error) = $proto->push();
            if(!$success) {
                sleep 3;
                next;
            }
        }

        $last_error = undef;
        $success = 1;
    }

    if($last_error) {
        return (undef, $last_error);
    }
    else {
        return (1, "Updated $unprefixed_dst in git storage");
    }
}

sub delete_file {
    my ($proto, $file, %opts) = @_;

    $opts{push} //= 1;

    my $tries = 0;
    my $last_error;
    my $success;
	while(!$success && $tries <= 3) {
        $tries ++;

        ($success, $last_error) = $proto->pull();
        if(!$success) {
            sleep 3;
            next;
        }

        system("cd ".$proto->git_directory." && git rm $file && git commit --allow-empty -m 'delete $file'");
        if($? != 0) {
            $last_error = "Unable to commit to repository. Please retry the change.";
            sleep 3;
            next;
        }

        if($opts{push}) {
            ($success, $last_error) = $proto->push();
            if(!$success) {
                sleep 3;
                next;
            }
        }

        $last_error = undef;
        $success = 1;
    }

    if($last_error) {
        return (undef, $last_error);
    }
    else {
        return (1, "Delete $file in git storage");
    }
}

sub pull {
    my ($proto) = @_;
    
    system("cd ".$proto->git_directory." && git pull");
    if($? != 0) {
        return (0, "Unable to pull repository.");
    }

    return (1, undef);
}

sub push {
    my ($proto) = @_;

    system("cd ".$proto->git_directory." && git push");
    if($? != 0) {
        return (0, "Unable to push repository. Please retry the change.");
    }

    return (1, undef);
}

sub update {
    my ($proto) = @_;

    my $tries = 0;
    my $last_error;
    my $success;
	while(!$success && $tries <= 3) {
        $tries ++;
        if(!$proto->is_enabled) {
            get_logger->error("git_storage isn't enabled. Refusing to update.");
            return 0;
        }

        system("cd ".$proto->git_directory." && git pull");
        if($? != 0) {
            $last_error = "Unable to pull repository";
            sleep 3;
            next;
        }
        system("cp -a ".$proto->git_directory."/conf/* ".$proto->conf_directory."/");
        if($? != 0) {
            $last_error = "Unable to copy conf/ repository files";
            sleep 3;
            next;
        }

        system("cp -a ".$proto->git_directory."/fingerbank/conf/* ".$proto->fingerbank_conf_directory."/");
        if($? != 0) {
            $last_error = "Unable to copy fingerbank/conf/ repository files";
            sleep 3;
            next;
        }

        $last_error = undef;
        $success = 1;
    }

    if($last_error) {
        get_logger->error($last_error);
        return 0;
    }
    else {
        return 1;
    }
}

sub k8s_deploy {
    my ($self) = @_;

}

1;
