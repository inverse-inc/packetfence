const network = {
  connectionTypeToAttributes (connectionType) {
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
  },
  ipv4NetmaskToSubnet (ip, netmask) {
    const _ip = ip.split('.').map(i => parseInt(i))
    const _netmask = netmask.split('.').map(n => parseInt(n))
    let subnet = []
    _ip.forEach((_, idx) => {
      subnet.push(_ip[idx] & _netmask[idx])
    })
    return subnet.join('.')
  },
  ipv4Sort (a, b) {
    if (!!a && !b) { return 1 } else if (!a && !!b) { return -1 } else if (!a && !b) { return 0 }
    const aa = a.split('.')
    const bb = b.split('.')
    var resulta = aa[0] * 0x1000000 + aa[1] * 0x10000 + aa[2] * 0x100 + aa[3] * 1
    var resultb = bb[0] * 0x1000000 + bb[1] * 0x10000 + bb[2] * 0x100 + bb[3] * 1
    return (resulta === resultb) ? 0 : ((resulta > resultb) ? 1 : -1)
  }
}

export default network
