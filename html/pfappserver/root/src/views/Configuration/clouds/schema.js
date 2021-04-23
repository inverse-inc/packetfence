import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'cloudIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'cloudIdExistsExcept',
    message: message || i18n.t('Hostname or IP Address exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getClouds').then(response => {
        return response.filter(cloud => cloud.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Hostname or IP Address required.'))
      .cloudIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Hostname or IP Address exists.')),
    password: yup.string().nullable().label(i18n.t('Secret or Key')),
    username: yup.string().nullable().label(i18n.t('Username')),
    port: yup.string().nullable().label(i18n.t('Port')),
    vsys: yup.string().nullable().label(i18n.t('Number')),
    deviceid: yup.string().nullable().label(i18n.t('DeviceID')),
    transport: yup.string().nullable().label(i18n.t('Transport')),
    nac_name: yup.string().nullable().label(i18n.t('Name')),
    categories: yup.array().ensure().label(i18n.t('Roles')).of(yup.string().nullable().label(i18n.t('Role'))),
    networks: yup.string().nullable().label(i18n.t('Networks')),
    cache_timeout: yup.string().nullable().label(i18n.t('Timeout')),
    username_format: yup.string().nullable().label(i18n.t('Format')),
    default_realm: yup.string().nullable().label(i18n.t('Realm'))
  })
}

export default schema
