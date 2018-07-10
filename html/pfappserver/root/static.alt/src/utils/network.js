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
    if (cType.search(new RegExp(/inline/i)) !== -1) {
      return attributes
    }
    if (cType.search(new RegExp(/^wireless-802\.11/i)) !== -1) {
      attributes.isWireless = true
    } else {
      attributes.isWired = true
    }
    if (cType.search(new RegExp(/^snmp/i)) !== -1) {
      attributes.isSNMP = true
      return attributes
    }
    if (cType.toLowerCase() === 'wired_mac_auth' || cType.toLowerCase() === 'ethernet-noeap') {
      attributes.isMacAuth = true
    }
    if (cType.search(new RegExp(/eap$/i)) !== -1 && cType.search(new RegExp(/noeap$/i)) === -1) {
      attributes.isEAP = true
      attributes.is8021X = true
    } else {
      attributes.isMacAuth = true
    }
    return attributes
  }
}

export default network
