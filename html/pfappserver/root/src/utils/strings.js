export const cleanMac = mac => {
  if (mac) {
    mac = mac.toLowerCase().replace(/([^0-9a-f])/gi, '')
    if (mac.length === 12) {
      return `${mac[0]}${mac[1]}:${mac[2]}${mac[3]}:${mac[4]}${mac[5]}:${mac[6]}${mac[7]}:${mac[8]}${mac[9]}:${mac[10]}${mac[11]}`
    }
  }
  return mac
}

export const toKebabCase = (string, delim = '-') => string &&
  string
    .match(/[A-Z]{2,}(?=[A-Z][a-z]+[0-9]*|\b)|[A-Z]?[a-z]+[0-9]*|[A-Z]|[0-9]+/g)
    .map(c => c.toLowerCase())
    .join(delim)


export const toBinary = string => {
  const codeUnits = Uint16Array.from(
    { length: string.length },
    (element, index) => string.charCodeAt(index)
  )
  const charCodes = new Uint8Array(codeUnits.buffer)
  let result = ''
  charCodes.forEach((char) => {
    result += String.fromCharCode(char)
  })
  return result
}

// https://stackoverflow.com/a/53433503
const fromCharCode = String.fromCharCode
export const utf8ToBase64 = ((btoa, replacer) => {
  return (inputString, BOMit) => btoa((BOMit ? "\xEF\xBB\xBF" : "") + inputString.replace(/[\x80-\uD7ff\uDC00-\uFFFF]|[\uD800-\uDBFF][\uDC00-\uDFFF]?/g, replacer))
})(btoa, (nonAsciiChars) => {
  // make the UTF string into a binary UTF-8 encoded string
  var point = nonAsciiChars.charCodeAt(0)
  if (point >= 0xD800 && point <= 0xDBFF) {
    var nextcode = nonAsciiChars.charCodeAt(1)
    if (nextcode !== nextcode) // NaN because string is 1 code point long
      return fromCharCode(0xef/*11101111*/, 0xbf/*10111111*/, 0xbd/*10111101*/)
    // https://mathiasbynens.be/notes/javascript-encoding#surrogate-formulae
    if (nextcode >= 0xDC00 && nextcode <= 0xDFFF) {
      point = (point - 0xD800) * 0x400 + nextcode - 0xDC00 + 0x10000
      if (point > 0xffff)
        return fromCharCode(
          (0x1e/*0b11110*/<<3) | (point>>>18),
          (0x2/*0b10*/<<6) | ((point>>>12)&0x3f/*0b00111111*/),
          (0x2/*0b10*/<<6) | ((point>>>6)&0x3f/*0b00111111*/),
          (0x2/*0b10*/<<6) | (point&0x3f/*0b00111111*/)
        )
    }
    else
      return fromCharCode(0xef, 0xbf, 0xbd)
  }
  if (point <= 0x007f)
    return nonAsciiChars
  else if (point <= 0x07ff)
    return fromCharCode((0x6<<5)|(point>>>6), (0x2<<6)|(point&0x3f))
  else
    return fromCharCode(
      (0xe/*0b1110*/<<4) | (point>>>12),
      (0x2/*0b10*/<<6) | ((point>>>6)&0x3f/*0b00111111*/),
      (0x2/*0b10*/<<6) | (point&0x3f/*0b00111111*/)
    )
})