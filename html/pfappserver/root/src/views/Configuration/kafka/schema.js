import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { reIpv4 } from '@/utils/regex'

const schemaAuth = yup.object({
  user: yup.string().nullable().required().label(i18n.t('Username')),
  pass: yup.string().nullable().required().label(i18n.t('Password')),
})

const schemaAuths = yup.array().ensure().unique(i18n.t('Duplicate username'), ({ name }) => name).of(schemaAuth)

const schemaCluster = yup.object({
  name: yup.string().nullable().required().label(i18n.t('Name')),
  value: yup.string().nullable().required().label(i18n.t('Value')),
})

const schemaClusters = yup.array().ensure().unique(i18n.t('Duplicate key'), ({ name }) => name).of(schemaCluster)

const schemaIpv4OrMgmtip = yup.string().nullable().required().label(i18n.t('IPv4'))
  .test({
    name: 'isIpv4OrMgmtip',
    message: i18n.t('Invalid IPv4 Address.'),
    test: value => ['', null, undefined].includes(value)
                   || value === '%mgmtip%'
                   || reIpv4(value),
  })

const schemaIpv4s = yup.array().ensure().of(schemaIpv4OrMgmtip)

const schemaIptables = yup.object({
  clients: schemaIpv4s,
  cluster_ips: schemaIpv4s,
})

const schemaSsl = yup.object({
  enabled: yup.string().nullable(),
  ca_id: yup.string().nullable().when('enabled', {
    is: 'enabled',
    then: yup.string().nullable().required(i18n.t('Certificate Authority required when mTLS is enabled.')),
  }),
  cn: yup.string().nullable().when('enabled', {
    is: 'enabled',
    then: yup.string().nullable().required(i18n.t('Common Name required when mTLS is enabled.')),
  }),
  dns_names: yup.string().nullable(),
  ip_addresses: yup.string().nullable(),
  peer_ca: yup.string().nullable(),
  listener: yup.string().nullable(),
})

export const schema = () => yup.object({
  admin: schemaAuth,
  auths: schemaAuths,
  cluster: schemaClusters,
  iptables: schemaIptables,
  ssl: schemaSsl,
})

export default schema
