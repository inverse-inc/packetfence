import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'vlanForInterfaceNotExistsExcept', function (except, message) {
  let { id: exceptId = '', vlan: exceptVlan = '' } = except
  return this.test({
    name: 'vlanForInterfaceNotExistsExcept',
    message: message || i18n.t('VLAN exists for {interface}.', { interface: exceptId }),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getInterfaces').then(response => {
        return response.filter(iface => {
          const ifaceMaster = iface.master || ''
          const ifaceVlan = iface.vlan || ''
          if (ifaceMaster.toLowerCase() === exceptId.toLowerCase()) {
            if (+ifaceVlan !== +exceptVlan)
              return +ifaceVlan === +value
          }
          return false
        }).length === 0
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
  const { master = id, vlan } = form

  return yup.object().shape({
    vlan: yup.string()
      .nullable()
      .required(i18n.t('VLAN required.'))
      .isVLAN()
      .vlanForInterfaceNotExistsExcept((!isNew && !isClone) ? { id: master, vlan } : { id: master }, i18n.t('VLAN exists for {interface}.', { interface: master })),
    ipaddress: yup.string().nullable().isIpv4('Invalid IPv4 Address.'),
    ipv6_address: yup.string().nullable().isIpv6('Invalid IPv6 Address.'),
    netmask: yup.string().nullable().isIpv4('Invalid Netmask.'),
    reg_network: yup.string().nullable().isCIDR('Invalid CIDR.'),
  })
}
