import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'provisionerIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'provisionerIdExistsExcept',
    message: message || i18n.t('ID exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getProvisionings').then(response => {
        return response.filter(provisioning => provisioning.id.toLowerCase() === value.toLowerCase()).length === 0
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
      .required(i18n.t('ID required.'))
      .provisionerIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('ID exists.')),
    access_token: yup.string().nullable().label(i18n.t('Token')),
    agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    alt_agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    api_username: yup.string().nullable().label(i18n.t('Username')),
    api_password: yup.string().nullable().label(i18n.t('Password')),
    applicationID: yup.string().nullable().label(i18n.t('ID')),
    applicationSecret: yup.string().nullable().label(i18n.t('Secret')),
    boarding_host: yup.string().nullable().label(i18n.t('Host')),
    client_id: yup.string().nullable().label(i18n.t('Key')),
    client_secret: yup.string().nullable().label(i18n.t('Secret')),
    domains: yup.string().nullable().label(i18n.t('Domains')),
    host: yup.string().nullable().label(i18n.t('Host')),
    password: yup.string().nullable().label(i18n.t('Secret')),
    refresh_token: yup.string().nullable().label(i18n.t('Token')),
    ssid: yup.string().nullable().label(i18n.t('SSID')),
    table_for_agent: yup.string().nullable().label(i18n.t('Table')),
    table_for_mac: yup.string().nullable().label(i18n.t('Table')),
    tenant_code: yup.string().nullable().label(i18n.t('Tenant code')),
    tenantID: yup.string().nullable().label(i18n.t('ID')),
    username: yup.string().nullable().label(i18n.t('Username')),
    android_agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    android_download_uri: yup.string().nullable().label(i18n.t('URI')),
    ios_agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    ios_download_uri: yup.string().nullable().label(i18n.t('URI')),
    mac_osx_agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    win_agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    windows_agent_download_uri: yup.string().nullable().label(i18n.t('URI')),
    windows_phone_download_uri: yup.string().nullable().label(i18n.t('URI')),
  })
}

export default schema
