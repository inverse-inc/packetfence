import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'roleNameNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'roleNameNotExistsExcept',
    message: message || i18n.t('Network exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getRoles').then(response => {
        return response.filter(role => role.name.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    id,
    form,
    isNew,
    isClone
  } = props

  // reactive variables for `yup.when`
  const { dhcpd } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Network required.'))
      .roleNameNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Network exists.')),
    description: yup.string().nullable(),
    algorithm: yup.string().nullable(),
    dhcpd: yup.string().nullable(),
    dhcp_start: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().isIpv4().required(i18n.t('IPv4 address required.'))
      : yup.string().nullable().isIpv4()
    ),
    dhcp_end: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().isIpv4().required(i18n.t('IPv4 address required.'))
      : yup.string().nullable().isIpv4()
    ),
    dhcp_default_lease_time: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().required(i18n.t('Time required.'))
      : yup.string().nullable()
    ),
    dhcp_max_lease_time: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().required(i18n.t('Time required.'))
      : yup.string().nullable()
    ),
    dns: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().required(i18n.t('IPv4 addresses required.'))
      : yup.string().nullable()
    ),
    gateway: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().isIpv4().required(i18n.t('IPv4 address required.'))
      : yup.string().nullable().isIpv4()
    ),
    ip_reserved: yup.string().nullable(),
    ip_assigned: yup.string().nullable(),
    netmask: yup.string().nullable().required(i18n.t('Netmask required.')).isIpv4(),
    next_hop: yup.string().nullable().required(i18n.t('Router IP required.')).isIpv4(),
    pool_backend: yup.string().when('dhcpd', () => (dhcpd === 'enabled') // reactive
      ? yup.string().nullable().required(i18n.t('Type required.'))
      : yup.string().nullable()
    ),
    portal_fqdn: yup.string().nullable().isFQDN(),
    type: yup.string().nullable().required(i18n.t('Type required.')),
  })
}
