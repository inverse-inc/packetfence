import store from '@/store'
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
  // include packetfence domain in local hosts
  let internalHost = false
  if (store.state.$_bases.cache.general.domain) {
    const packetfenceDomain = store.state.$_bases.cache.general.domain.toLowerCase()
    internalHost = packetfenceDomain === _host || RegExp(`.${packetfenceDomain}$`, 'i').test(_host)
  }
  const isIpv4 = reIpv4(_host)
  const isIpv6 = reIpv6(_host)
  // don't split IPv4 or IPv6
  if (isIpv4 || isIpv6) {
    return { internalHost: true, tld: _host, port, isIpv4, isIpv6 }
  }
  const [tld, domain, ...subdomains] = _host.split('.').reverse()
  return { internalHost, tld, port, domain, subdomain: subdomains.reverse().join('.') }
}

export const sortHosts = (a, b) => {
  // internal hosts first
  if (a.internalHost !== b.internalHost) {
    return b.internalHost - a.internalHost
  }
  const hostsA = (a.internalHost && (a.isIpv4 || a.isIpv6))
    ? a.host.split('.')
    : a.host.split('.').reverse()
  const hostsB = (b.internalHost && (b.isIpv4 || b.isIpv6))
    ? b.host.split('.')
    : b.host.split('.').reverse()
  for (let h = 0; h <= Math.min(hostsA.length, hostsB.length); h++) {
    if (hostsA.length <= h) {
      return -1
    }
    if (hostsB.length <= h) {
      return 1
    }
    if (hostsA[h] !== hostsB[h]) {
      return `${hostsA[h]}`.localeCompare(`${hostsB[h]}`)
    }
  }
}

export const decorateHost = host => {
  const { tld, domain, subdomain, port } = splitHost(host)
  let decorated = ''
  if (port) {
    decorated = `:${port}`
  }
  if (tld) {
    decorated = `${tld}${decorated}`
  }
  if (domain) {
    decorated = `${domain}.${decorated}`
  }
  if (subdomain) {
    decorated = `${subdomain}.${decorated}`
  }
  return decorated
}

export const useHosts = communication => {
  return Object.entries(communication).reduce((hosts, [device, value]) => {
    const { all_hosts_cache = {} } = value
    const hosts_cache = Object.entries(all_hosts_cache)
    for (let i = 0; i < hosts_cache.length; i++) {
      let [host, device_cache] = hosts_cache[i]
      host = host.toLowerCase()
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

export const rgbaProto = (proto, port, opacity = 1) => {
  switch (proto) {
    case 'TCP':
      return `rgb(0, 255, 0, ${opacity})`
      // break
    case 'UDP':
      return `rgb(0, 0, 255, ${opacity})`
      // break
    case 'UNKNOWN':
      return `rgb(255, 0, 0, ${opacity})`
      // break
    default:
      return `rgb(0, 0, 0, ${opacity})`
  }
  /*
  switch (true) {
    case (+item.port < 1024):
      return 'rgb(40, 167, 69)' // success
      // break
    case (+item.port < 49152):
        return 'rgb(255, 193, 7)' // warning
      // break
    default:
      return 'rgb(220, 53, 69)' // danger
  }
  */
}
