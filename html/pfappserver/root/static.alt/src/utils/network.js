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
  }
}

export default network
