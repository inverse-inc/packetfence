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
    agent_download_uri: yup.string().nullable().label('URI'),
    alt_agent_download_uri: yup.string().nullable().label('URI'),
    android_agent_download_uri: yup.string().nullable().label('URI'),
    android_download_uri: yup.string().nullable().label('URI'),
    api_password: yup.string().nullable().label(i18n.t('Password')),
    api_username: yup.string().nullable().label(i18n.t('Username')),
    api_url: yup.string().nullable().label('URL'),
    applicationID: yup.string().nullable().label('ID'),
    applicationSecret: yup.string().nullable().label(i18n.t('Secret')),
    apply_role: yup.string().nullable(),
    autoregister: yup.string().nullable(),
    broadcast: yup.string().nullable(),
    boarding_host: yup.string().nullable().label(i18n.t('Host')),
    boarding_port: yup.string().nullable().label(i18n.t('Port')),
    ca_cert_path: yup.string().nullable(),
    can_sign_profile: yup.string().nullable(),
    category: yup.array().ensure().of(yup.string().nullable()),
    cert_chain: yup.string().nullable(),
    certificate: yup.string().nullable(),
    client_id: yup.string().nullable().label(i18n.t('Key')),
    client_secret: yup.string().nullable().label(i18n.t('Secret')),
    critical_issues_threshold: yup.string().nullable(),
    description: yup.string().nullable(),
    device_type_detection: yup.string().nullable(),
    domains: yup.string().nullable().label(i18n.t('Domains')),
    dpsk: yup.string().nullable(),
    eap_type: yup.string().nullable(),
    enforce: yup.string().nullable(),
    host: yup.string().nullable().label(i18n.t('Host')),
    ios_agent_download_uri: yup.string().nullable().label('URI'),
    ios_download_uri: yup.string().nullable().label('URI'),
    login_url: yup.string().nullable(),
    mac_osx_agent_download_uri: yup.string().nullable().label('URI'),
    non_compliance_security_event: yup.string().nullable(),
    oses: yup.array().ensure().of(yup.string().nullable()),
    passcode: yup.string().nullable(),
    password: yup.string().nullable().label(i18n.t('Secret')),
    pki_provider: yup.string().nullable(),
    port: yup.string().nullable(),
    private_key: yup.string().nullable(),
    protocol: yup.string().nullable(),
    psk_size: yup.string().nullable(),
    query_computers: yup.string().nullable(),
    query_mobiledevices: yup.string().nullable(),
    refresh_token: yup.string().nullable().label(i18n.t('Token')),
    role_to_apply: yup.string().nullable(),
    security_type: yup.string().nullable(),
    server_certificate_path: yup.string().nullable(),
    ssid: yup.string().nullable().label('SSID'),
    sync_pid: yup.string().nullable(),
    table_for_agent: yup.string().nullable().label(i18n.t('Table')),
    table_for_mac: yup.string().nullable().label(i18n.t('Table')),
    tenant_code: yup.string().nullable().label(i18n.t('Tenant code')),
    tenantID: yup.string().nullable().label('ID'),
    username: yup.string().nullable().label(i18n.t('Username')),
    win_agent_download_uri: yup.string().nullable().label('URI'),
    windows_agent_download_uri: yup.string().nullable().label('URI'),
    windows_phone_download_uri: yup.string().nullable().label('URI')
  })
}

export default schema
