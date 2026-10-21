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

export const schema = () => yup.object({
  admin: schemaAuth,
  auths: schemaAuths,
  cluster: schemaClusters,
  iptables: schemaIptables,
})

export default schema
