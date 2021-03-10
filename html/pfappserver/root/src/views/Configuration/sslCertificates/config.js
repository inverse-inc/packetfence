export const certificates = [
  'http',
  'radius'
]

export const certificateServices = {
  http: ['haproxy-portal', 'httpd.admin', 'haproxy-admin'],
  radius: ['radiusd-auth']
}

export const strings = {
  common_name:  'Common name (CN)', // i18n defer
  issuer:       'Issuer', // i18n defer
  not_after:    'Not after', // i18n defer
  not_before:   'Not before', // i18n defer
  serial:       'Serial', // i18n defer
  subject:      'Subject', // i18n defer
}
