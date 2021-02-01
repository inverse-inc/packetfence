export const ipv4ToInt = (ip) => ip.split('.').reduce((int, oct) => (int << 8) + parseInt(oct, 10), 0) >>> 0

export const intToIpv4 = (int) => [(int >>> 24) & 0xFF, (int >>> 16) & 0xFF, (int >>> 8) & 0xFF, int & 0xFF].join('.')

export const cidrToIpv4 = (cidr) => cidr.split('/', 1)[0] || cidr

export const cidrToRange = (cidr) => {
  let [ ip, bits = 32 ] = cidr.split('/')
  let host_bits = 32 - +bits
  let i = ipv4ToInt(ip)
  let start = (i >> host_bits) << host_bits
  let end = start | ((1 << host_bits) - 1)
  return [intToIpv4(start), intToIpv4(end)]
}

export const connectionTypeToAttributes = (connectionType) => {
  const cType = String(connectionType)
  let attributes = {
    isWired: false,
    isWireless: false,
    isSNMP: false,
    isEAP: false,
    is8021X: false,
    isMacAuth: false
  }
  if (/inline/i.test(cType)) {
    return attributes
  }
  if (/^wireless-802\.11/i.test(cType)) {
    attributes.isWireless = true
  } else {
    attributes.isWired = true
  }
  if (/^snmp/i.test(cType)) {
    attributes.isSNMP = true
    return attributes
  }
  if (cType.toLowerCase() === 'wired_mac_auth' || cType.toLowerCase() === 'ethernet-noeap') {
    attributes.isMacAuth = true
  }
  if (/eap$/i.test(cType) && /noeap$/i.test(cType)) {
    attributes.isEAP = true
    attributes.is8021X = true
  } else {
    attributes.isMacAuth = true
  }
  return attributes
}

export const ipv4NetmaskToSubnet = (ip, netmask) => {
  const _ip = (ip || '').split('.').map(i => parseInt(i))
  const _netmask = (netmask || '').split('.').map(n => parseInt(n))
  let subnet = []
  _ip.forEach((_, idx) => {
    subnet.push(_ip[idx] & _netmask[idx])
  })
  return subnet.join('.')
}

export const ipv4Sort = (a, b) => {
  if (!!a && !b) { return 1 } else if (!a && !!b) { return -1 } else if (!a && !b) { return 0 }
  const intA = ipv4ToInt(a)
  const intB = ipv4ToInt(b)
  return (intA === intB) ? 0 : ((intA > intB) ? 1 : -1)
}

export const ipv4InSubnet = (ip, subnet) => {
  const _ip = (ip || '').split('.').map(i => parseInt(i))
  const _subnet = (subnet || '').replace(/(\.0)+$/, '').split('.').map(s => parseInt(s))
  return _ip.reduce((result, d, index) => {
    return result && (index >= _subnet.length || d === _subnet[index])
  }, true)
}

export default {
  ipv4ToInt,
  intToIpv4,
  cidrToIpv4,
  cidrToRange,
  connectionTypeToAttributes,
  ipv4NetmaskToSubnet,
  ipv4Sort,
  ipv4InSubnet
}
