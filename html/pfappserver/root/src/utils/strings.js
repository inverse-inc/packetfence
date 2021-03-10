const strings = {
  cleanMac (mac) {
    if (mac) {
      mac = mac.toLowerCase().replace(/([^0-9a-f])/gi, '')
      if (mac.length === 12) {
        return `${mac[0]}${mac[1]}:${mac[2]}${mac[3]}:${mac[4]}${mac[5]}:${mac[6]}${mac[7]}:${mac[8]}${mac[9]}:${mac[10]}${mac[11]}`
      }
    }
    return null
  }
}

export default strings
