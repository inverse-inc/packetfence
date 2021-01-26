This plugin implements the pfdns services required by PacketFence.

An example Corefile would look like the following: 
    # passthrough for the example.com domain and subdomains
    example.com.:53 {
        proxy . /etc/resolv.conf
        log stdout
        errors stderr
    }
    
    # passthrough for the Active-Directory services
    _msdcs.example.local.:53 {
        proxy . 10.0.0.10
    }
    
    # all other domains are subject to interception 
    .:53 {
        pfdns {
            enforcement true
            redirectTo  192.168.181.134
            blackhole localhost.localdomain. 127.0.0.1
        }
        # Anything not handled by pfdns will be resolved normally 
        proxy . /etc/resolv.conf
        log stdout
        errors stderr
    }
