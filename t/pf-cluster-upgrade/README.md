# Test suite for addons/upgrade/pf-cluster-upgrade.sh

The suite drives every phase of the cluster upgrade tool against a fake
cluster: `ssh`, `pfcmd`, `systemctl`, `cluster/node`, `cluster/sync` and
`do-upgrade.sh` are intercepted, and every command issued is recorded. What is
then checked is the actual sequence of commands against what Clustering Guide
12.4 prescribes.

No setup is needed and nothing outside a temporary directory is touched — the
suite reaches no network and no real host.

## Running the tests

```
cd t/pf-cluster-upgrade/
make test
```

Or directly:

```
bash pf-cluster-upgrade.tests </dev/null
```

Close stdin as shown. Two checks describe what the tool does *without* a
terminal, and on a terminal they would measure the terminal instead.

## What the suite does not cover

The fakes never execute the `RS_*` remote blocks; they only record them. The
suite therefore proves that the right commands go to the right nodes in the
right order — not how PacketFence reacts to them. The tool's own README lists
the paths that no real run has exercised.
