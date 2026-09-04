import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'connectorIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'connectorIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getConnectors').then(response => {
        return response.filter(connector => connector.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaNetwork = yup.string().nullable()
  .required(i18n.t('Network required.'))
  .isCIDR()

const schemaNetworks = yup.array().ensure()
  .unique(i18n.t('Duplicate network.'))
  .of(schemaNetwork)

const schemaFingerbankEnvironment = yup.object().shape({
  name: yup.string().nullable()
    .required(i18n.t('Environment variable required.')),
  value: yup.string().nullable()
    .required(i18n.t('Value required.'))
})

const schemaFingerbankEnvironments = yup.array().ensure()
  .unique(i18n.t('Duplicate environment variable.'), ({ name }) => name)
  .of(schemaFingerbankEnvironment)

// Site networking: VLAN interfaces and static routes applied on the remote
// connector host. Mirrors pfappserver::Form::Config::Connector.
const reInterfaceName = /^[A-Za-z0-9_-]+$/
const reHostCidr = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d{1,2})$/

yup.addMethod(yup.string, 'isHostCidr', function (message) {
  return this.test({
    name: 'isHostCidr',
    message: message || i18n.t('Must be a host IPv4 address with a prefix length (e.g. 10.10.100.1/24).'),
    test: value => {
      if (['', null, undefined].includes(value)) return true
      const m = reHostCidr.exec(value)
      if (!m) return false
      const octets = m.slice(1, 5).map(Number)
      const prefix = Number(m[5])
      if (octets.some(o => o > 255) || prefix < 1 || prefix > 32) return false
      if (prefix >= 31) return true
      const ip = ((octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]) >>> 0
      const mask = (0xFFFFFFFF << (32 - prefix)) >>> 0
      const network = (ip & mask) >>> 0
      const broadcast = (network | (~mask >>> 0)) >>> 0
      return ip !== network && ip !== broadcast
    }
  })
})

const schemaInterface = yup.object().shape({
  parent: yup.string().nullable()
    .required(i18n.t('Parent interface required.'))
    .max(10, i18n.t('Maximum 10 characters.'))
    .matches(reInterfaceName, i18n.t('Letters, digits, "_" and "-" only.')),
  vlan: yup.string().nullable()
    .required(i18n.t('VLAN ID required.'))
    .isVLAN(i18n.t('VLAN ID must be between 1 and 4094.'))
    .test('vlan-max', i18n.t('VLAN ID must be between 1 and 4094.'), value => ['', null, undefined].includes(value) || +value <= 4094),
  cidr: yup.string().nullable()
    .required(i18n.t('IP address required.'))
    .isHostCidr(),
  dhcp: yup.string().nullable(),
  dns_server: yup.string().nullable(),
  dhcp_start: yup.string().nullable().isIpv4()
    .when('dhcp', {
      is: 'enabled',
      then: schema => schema.required(i18n.t('Range start required when DHCP is enabled.'))
    }),
  dhcp_end: yup.string().nullable().isIpv4()
    .when('dhcp', {
      is: 'enabled',
      then: schema => schema.required(i18n.t('Range end required when DHCP is enabled.'))
    }),
  dhcp_default_lease_time: yup.string().nullable()
    .test('positive', i18n.t('Must be a positive number of seconds.'), value => ['', null, undefined].includes(value) || (+value > 0 && Number.isInteger(+value))),
  dhcp_max_lease_time: yup.string().nullable()
    .test('positive', i18n.t('Must be a positive number of seconds.'), value => ['', null, undefined].includes(value) || (+value > 0 && Number.isInteger(+value))),
  dns: yup.string().nullable()
    .test('ipv4-list', i18n.t('Comma separated IPv4 addresses.'), value => ['', null, undefined].includes(value) || `${value}`.split(',').every(ip => /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.test(ip.trim()))),
  gateway: yup.string().nullable().isIpv4(),
  domain_name: yup.string().nullable()
    .matches(/^[A-Za-z0-9.-]*$/, i18n.t('Letters, digits, "." and "-" only.'))
})

const schemaInterfaces = yup.array().ensure()
  .unique(i18n.t('Duplicate VLAN interface.'), ({ parent, vlan }) => `${parent}.${vlan}`)
  .of(schemaInterface)

const schemaRoute = yup.object().shape({
  destination: yup.string().nullable()
    .required(i18n.t('Destination required.'))
    .isCIDR()
    .test('not-default', i18n.t('The default route cannot be managed from here.'), value => !value || !/\/0$/.test(value)),
  gateway: yup.string().nullable()
    .isIpv4()
    .test('gateway-or-interface', i18n.t('A gateway or an interface is required.'), function (value) {
      const { interface: dev } = this.parent || {}
      return !!(value || dev)
    }),
  interface: yup.string().nullable()
    .max(15, i18n.t('Maximum 15 characters.'))
    .matches(/^[A-Za-z0-9_.-]*$/, i18n.t('Letters, digits, ".", "_" and "-" only.'))
})

const schemaRoutes = yup.array().ensure()
  .unique(i18n.t('Duplicate route.'), ({ destination }) => destination)
  .of(schemaRoute)

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Connector ID required.'))
      .isUUID()
      .connectorIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Connector ID exists.')),
    description: yup.string()
      .nullable()
      .required(i18n.t('Description required.'))
      .label(i18n.t('Description')),
    secret: yup.string()
      .nullable()
      .required(i18n.t('Secret required.'))
      .label(i18n.t('Secret')),
    networks: schemaNetworks,
    fingerbank_environment: schemaFingerbankEnvironments,
    interfaces: schemaInterfaces,
    routes: schemaRoutes
  })
}
