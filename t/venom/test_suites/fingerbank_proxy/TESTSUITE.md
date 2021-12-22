# fingerbank_proxy

Test that the Fingerbank Perl library and Fingerbank Collector are able to work behind a proxy

## Requirements

## Scenario steps
1. Setup Fingerbank to proxy its traffic to linux02:8888 (tinyproxy)
1. Drop all traffic to WAN via iptables (except 8.8.8.8 DNS server)
1. Ensure the Fingerbank Perl library is able to perform an API call
1. Ensure the Fingerbank Collector is able to perform an API call

## Teardown steps
1. Unconfigure the proxy in Fingerbank
1. Allow all traffic in iptables

