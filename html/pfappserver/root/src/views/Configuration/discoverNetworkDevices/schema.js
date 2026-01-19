import i18n from '@/utils/locale'
import yup from '@/utils/yup'

// CIDR address validation regex (IPv4 with optional /16-32 prefix)
export const reCidr = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?:\/(?:1[6-9]|2[0-9]|3[0-2]))?$/

// SNMP community string validation (printable ASCII per RFC 1157)
// Characters 32-126 (space through tilde), no control characters
export const reSnmpCommunity = /^[\x20-\x7E]+$/

// Schema for custom CIDR address
export const schemaCustomAddress = yup.string().nullable()
  .test('is-cidr', i18n.t('Invalid CIDR format. Use format like 192.168.1.0/24 (prefix /16-32)'), value => {
    if (!value || value.trim() === '') return true // optional field
    return reCidr.test(value)
  })

// Schema for SNMP community string
export const schemaSnmpCommunity = yup.string().nullable()
  .max(255, i18n.t('Community string must be 255 characters or less.'))
  .test('is-printable-ascii', i18n.t('Community string must contain only printable ASCII characters (RFC 1157).'), value => {
    if (!value || value.trim() === '') return true // allow empty
    return reSnmpCommunity.test(value)
  })

export default () => {
  return yup.object().shape({
    customAddress: schemaCustomAddress,
    snmpCommunity: schemaSnmpCommunity
  })
}
