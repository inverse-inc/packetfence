package ConfigStore::HierarchyTest;

use Moo;
use pf::ConfigStore;
use pf::ConfigStore::Hierarchy;

extends qw(pf::ConfigStore);
with qw(pf::ConfigStore::Hierarchy);

sub default_section { undef }

sub topLevelGroup { "group default" }

sub _formatGroup {
    return "group ".$_[1];
}

1;

