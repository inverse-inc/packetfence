import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'floatingDeviceIdentifierNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'floatingDeviceIdentifierNotExistsExcept',
    message: message || i18n.t('MAC Address exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getFloatingDevices').then(response => {
        return response.filter(floatingDevice => floatingDevice.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('MAC Address required.'))
      .isMAC(i18n.t('Invalid MAC address.'))
      .floatingDeviceIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('MAC Address exists.')),
    ip: yup.string().nullable().label('IP'),
    pvid: yup.string().nullable().label('VLAN')
      .required(i18n.t('VLAN required.')),
    taggedVlan: yup.string().nullable().label('VLAN')
  })
}
