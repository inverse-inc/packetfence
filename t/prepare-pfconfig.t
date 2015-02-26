#!/usr/bin/perl

BEGIN {
    # log4perl init
    use constant INSTALL_DIR => '/usr/local/pf';
    use lib INSTALL_DIR . "/lib";
    use lib INSTALL_DIR . "/t";
    use pfconfig::log;
    use PfFilePaths;
}

use pfconfig::manager;

pfconfig::manager->new->expire_all;
