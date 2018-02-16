# API

## IP2MAC

```
curl http://127.0.0.1:22222/api/v1/dhcp/ip/192.168.0.2 | python -m json.tool
```

```
{
    "result": {
        "IP": "192.168.0.2",
        "MAC": "10:1f:74:b2:f6:a5"
    }
}
```

## MAC2IP

```
curl http://127.0.0.1:22222/api/v1/dhcp/mac/10:1f:74:b2:f6:a5 | python -m json.tool
```

```
{
    "result": {
        "IP": "192.168.0.2",
        "MAC": "10:1f:74:b2:f6:a5"
    }
}
```

## Release IP

```
curl -X "DELETE" http://127.0.0.1:22222/api/v1/dhcp/mac/10:1f:74:b2:f6:a5 | python -m json.tool
```


## Statistics

```
curl http://127.0.0.1:22222/api/v1/dhcp/stats/eth1.137 | python -m json.tool
```

```
   "192.168.0.0/24": {
        "Category": "registration",
        "Free": 253,
        "Interface": "eth1.137",
        "Members": {
            "10:1f:74:b2:f6:a5": "192.168.0.2"
        },
        "Network": "192.168.0.0/24",
        "Options": {
            "OptionDomainName": "inlinel2.fabianfence",
            "OptionDomainNameServer": "10.10.0.1",
            "OptionIPAddressLeaseTime": "123",
            "OptionNetBIOSOverTCPIPNameServer": "172.20.135.2",
            "OptionRouter": "192.168.0.1",
            "OptionSubnetMask": "255.255.255.0"
        }
    }
```

## Add,modify options

### For a MAC address

#### ADD

```
curl -H "Content-Type: application/json" -d '[{"option":51,"value":"123","type":"int"},{"option":44,"value":"172.20.135.2","type":"ipaddr"}]' http://127.0.0.1:22222/options/mac/10:1f:74:b2:f6:a5/
```

#### Remove

```
curl -X "DELETE" http://127.0.0.1:22222/api/v1/dhcp/options/mac/10:1f:74:b2:f6:a5/
```

### For a Network

#### ADD

```
curl -H "Content-Type: application/json" -d '[{"option":51,"value":"123","type":"int"},{"option":44,"value":"172.20.135.2","type":"ipaddr"}]' http://127.0.0.1:22222/options/network/192.168.0.0/
```

#### Remove

```
curl -X "DELETE" http://127.0.0.1:22222/api/v1/dhcp/options/network/192.168.0.0/
```
