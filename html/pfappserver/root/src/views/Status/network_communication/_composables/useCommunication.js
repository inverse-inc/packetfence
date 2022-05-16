import {
  reIpv4,
  reIpv6,
} from '@/utils/regex'

export const decorateDevice = d => {
  return `${d[0]}${d[1]}:${d[2]}${d[3]}:${d[4]}${d[5]}:${d[6]}${d[7]}:${d[8]}${d[9]}:${d[10]}${d[11]}`
}

export const useDevices = communication => {
  return Object.entries(communication).reduce((devices, [device, value]) => {
    if (!(device in devices)) {
      devices[device] = { hosts: {}, protocols: {} }
    }
    const { all_hosts_cache = {} } = value
    const hosts_cache = Object.entries(all_hosts_cache)
    for (let i = 0; i < hosts_cache.length; i++) {
      const [host, device_cache] = hosts_cache[i]
      const protocols = Object.entries(device_cache)
      for (let p = 0; p < protocols.length; p++) {
        const [_protocol, count] = protocols[p]
        const protocol = decorateProtocol(_protocol)
        devices[device].hosts[host] = (devices[device].hosts[host] || 0) + count
        devices[device].protocols[protocol] = (devices[device].protocols[protocol] || 0) + count
      }
    }
    return devices
  }, {})
}

export const splitHost = host => {
  // host may have port appended, discard
  const [_host, port] = host.toLowerCase().split(':')
  // don't split IPv4 or IPv6
  if (reIpv4(_host) || reIpv6(_host)) {
    return { tld: _host, port }
  }
  const [tld, ...subdomains] = _host.split('.').reverse()
  return { tld, port, subdomain: subdomains.reverse().join('.') }
}

export const decorateHost = host => {
  const { tld, subdomain, port } = splitHost(host)
  const tldPort = tld + ((port) ? `:${port}`: '' )
  if (subdomain) {
    return `${subdomain}.${tldPort}`
  }
  return tldPort
}

export const useHosts = communication => {
  return Object.entries(communication).reduce((hosts, [device, value]) => {
    const { all_hosts_cache = {} } = value
    const hosts_cache = Object.entries(all_hosts_cache)
    for (let i = 0; i < hosts_cache.length; i++) {
      const [host, device_cache] = hosts_cache[i]
      if (host) {
        if (!(host in hosts)) {
          hosts[host] = { devices: {}, protocols: {} }
        }
        hosts[host]['devices'][device] = Object.values(device_cache).reduce((sum, value) => {
          return sum + value
        }, 0)
        const protocols = Object.entries(device_cache)
        for (let p = 0; p < protocols.length; p++) {
          const [_protocol, count] = protocols[p]
          const protocol = decorateProtocol(_protocol)
          hosts[host].protocols[protocol] = (hosts[host].protocols[protocol] || 0) + count
        }
      }
    }
    return hosts
  }, {})
}

export const splitProtocol = protocol => {
  // early version does not include proto in 'proto:port'
  const [port, proto = 'UNKNOWN'] = protocol.split(':').reverse()
  return { proto, port }
}

export const decorateProtocol = protocol => {
  const { proto, port } = splitProtocol(protocol)
  return `${proto.toUpperCase()}:${port}`
}

export const useProtocols = communication => {
  return Object.entries(communication).reduce((protocols, [device, value]) => {
    const { all_hosts_cache = {} } = value
    const hosts_cache = Object.entries(all_hosts_cache)
    for (let i = 0; i < hosts_cache.length; i++) {
      const [host, device_cache] = hosts_cache[i]
      const _protocols = Object.entries(device_cache)
      for (let p = 0; p < _protocols.length; p++) {
        const [_protocol, count] = _protocols[p]
        const protocol = decorateProtocol(_protocol)
        if (!(protocol in protocols)) {
          protocols[protocol] = { devices: { [device]: count }, hosts: { [host]: count } }
        }
        else {
          protocols[protocol].devices[device] = (protocols[protocol].devices[device] || 0) + count
          protocols[protocol].hosts[host] = (protocols[protocol].hosts[host] || 0) + count
        }
      }
    }
    return protocols
  }, {})
}
