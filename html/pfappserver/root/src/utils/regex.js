export const reAscii = value => /^([\x20-\x7E]+)$/.test(value)

export const reAlphaNumeric = value => /^[a-zA-Z0-9]*$/.test(value)

export const reAlphaNumericHyphenUnderscoreDot = value => /^[a-zA-Z0-9-_.]*$/.test(value)

export const reCommonName = value => /^([A-Z]+|[A-Z]+[0-9A-Z-_:]*[0-9A-Z]+)$/i.test(value)

export const reDomain = value => /^((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9*]+\.)+[a-zA-Z]{2,}))$/.test(value)

export const reEmail = value => /(^$|^(([^<>()[\]\\.,;:\s@"]+(\.[^<>()[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$)/.test(value)

export const reFilename = value => /^[^\\/?%*:|"<>]+$/.test(value)

export const reIpv4 = value => /^(([0-9]{1,3}.){3,3}[0-9]{1,3})$/i.test(value)

export const reIpv6 = value => /^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$/i.test(value)

export const reMac = value => /^([0-9a-fA-F]{2}[-:]?){5,}([0-9a-fA-F]){2}$/.test(value)

export const reNumeric = value => /^-?[0-9]*$/.test(value)

// eslint-disable-next-line no-useless-escape
export const reStaticRoute = value => /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}\/?(\d+)?\s+?(via\s+(?:[0-9]{1,3}\.){3}[0-9]{1,3}\s+?)?dev\s+[a-z,0-9\.]+$/i.test(value)
