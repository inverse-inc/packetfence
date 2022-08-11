export const certificates = [
  'http',
  'radius'
]

export const certificateServices = {
  http: ['haproxy-portal', 'haproxy-admin'],
  radius: ['radiusd-auth']
}

export const strings = {
  common_name:      'Common name (CN)', // i18n defer
  issuer:           'Issuer', // i18n defer
  not_after:        'Not after', // i18n defer
  not_before:       'Not before', // i18n defer
  serial:           'Serial', // i18n defer
  subject:          'Subject', // i18n defer
  subject_alt_name: 'Subject Alternative Names', // i18n defer
}

export const sortSslKeys = ['serial', 'issuer', 'not_before', 'not_after', 'subject', 'common_name', 'subject_alt_name']

export const recomposeRDNSequence = (subject = '') => {
  const o = {}
  subject.split(',').forEach(item => {
    const [k, v] = item.trim().split('=')
    switch (k) {
      case 'C':
        o.country = v
        break
      case 'ST':
        o.state = v
        break
      case 'L':
        o.locality = v
        break
      case 'O':
        o.organization_name = v
        break
      case 'CN':
        o.common_name = v
        break
    }
  })
  return o
}

export const recomposeSAN = (sans = []) => {
  const o = {}
  sans.forEach(san => {
    const [k, v] = san.split(':', 2)
    switch (k) {
      case 'DNS':
        o.dns_names = ('dns_names' in o)
          ? [...o.dns_names.split(','), v].join(',')
          : v
        break
      case 'IP':
        o.ip_addresses = ('ip_addresses' in o)
          ? [...o.ip_addresses.split(','), v].join(',')
          : v
        break
      }
  })
  return o
}
