package pfconfig::refresh_last_touch_cache;

use pfconfig::cached;
use pfconfig::cached_scalar;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # Categorized by feature, pay attention when modifying
    @EXPORT = qw(
        refresh_last_touch_cache
    );
}

sub refresh_last_touch_cache {
    tie my $dummy, 'pfconfig::cached_scalar', 'resource::fqdn';
    tied($dummy)->FETCH();
}

1;
