import store from '@/store'
import { pfActionsSchema as schemaActions } from '@/globals/pfActions'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'sourceIdExists', function (message) {
  return this.test({
    name: 'sourceIdExists',
    message: message || i18n.t('Identifier does not exist.'),
    test: (value) => {
      if (!value) return true
      return store.dispatch('config/getSources').then(response => {
        return response.filter(source => source.id.toLowerCase() === value.toLowerCase()).length > 0
      }).catch(() => {
        return true
      })
    }
  })
})

yup.addMethod(yup.string, 'sourceIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'sourceIdNotExistsExcept',
    message: message || i18n.t('Source exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSources').then(response => {
        return response.filter(source => source.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaCondition = yup.object({
  attribute: yup.string().nullable().label(i18n.t('Attribute')).required(i18n.t('Attribute required.')),
  operator: yup.string().nullable().label(i18n.t('Operator')).required(i18n.t('Operator required.')),
  value: yup.string().nullable().label(i18n.t('Value')).required(i18n.t('Value required.'))
})

const schemaConditions = yup.array().ensure().unique(i18n.t('Duplicate condition.')).of(schemaCondition)

const schemaDomain = yup.string().required(i18n.t('Domain required.')).isDomain()

const schemaDomains = yup.array().ensure().unique(i18n.t('Duplicate domain.')).of(schemaDomain)

const schemaHost = yup.string().nullable().label(i18n.t('Host'))

const schemaHosts = yup.array().ensure().of(schemaHost).label(i18n.t('Hosts'))

const schemaRule = yup.object({
  status: yup.string(),
  id: yup.string().nullable().label(i18n.t('Name'))
    .isAlphaNumericHyphenUnderscoreDot()
    .max(255),
  description: yup.string().nullable()
    .max(255),
  match: yup.string(),
  actions: schemaActions.label(i18n.t('Action')),
  conditions: schemaConditions.label(i18n.t('Condition'))
})

const schemaRules = yup.array().ensure().unique(i18n.t('Duplicate rule.'), ({ id }) => id).of(schemaRule)

const schemaPersonMapping = yup.object({
  person_field: yup.string().nullable().required('Person field required.'),
  openid_field: yup.string().nullable().required('OpenID field required.')
})

const schemaPersonMappings = yup.array().ensure().unique(i18n.t('Duplicate mapping.')).of(schemaPersonMapping)

const schemaServer = yup.string().nullable()

const schemaServers = yup.array().ensure().of(schemaServer)

export const schema = (props) => {
  const {
    form,
    id,
    isNew,
    isClone
  } = props

  const {
    cert_file_upload,
    idp_ca_cert_path_upload,
    idp_cert_path_upload,
    idp_metadata_path_upload,
    key_file_upload,
    path_upload,
    paypal_cert_file_upload,
    sp_cert_path_upload,
    sp_key_path_upload,

  } = form || {}

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .sourceIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    administration_rules: schemaRules,
    authentication_rules: schemaRules,
    authentication_url: yup.string().nullable().required(i18n.t('URL required.')),
    authorization_url: yup.string().nullable().required(i18n.t('URL required.')),
    access_scope: yup.string().label(i18n.t('Scope')),
    access_token_param: yup.string().label(i18n.t('Parameter')),
    access_token_path: yup.string().label(i18n.t('Path')),
    account_sid: yup.string().label(i18n.t('SID')),
    allowed_domains: schemaDomains,
    api_key: yup.string().label(i18n.t('API key')),
    api_login_id: yup.string().label(i18n.t('ID')),
    auth_token: yup.string().label(i18n.t('Token')),
    authenticate_realm: yup.string().label(i18n.t('Realm')),
    authorization_source_id: yup.string().label(i18n.t('Source')),
    authorize_path: yup.string().label(i18n.t('Path')),
    banned_domains: schemaDomains,
    basedn: yup.string().label(i18n.t('Base DN')),
    cert_file: yup.string()
      .when('cert_file_upload', () => {
        return (!cert_file_upload)
          ? yup.string().nullable().required(i18n.t('Certificate required.'))
          : yup.string().nullable()
      }),
    cert_id: yup.string().label(i18n.t('ID')),
    client_cert_file: yup.string().nullable().label(i18n.t('Client certificate')),
    client_id: yup.string().label(i18n.t('Client ID')),
    client_key_file: yup.string().nullable().label(i18n.t('Client key')),
    client_secret: yup.string().label(i18n.t('Secret')),
    description: yup.string().label(i18n.t('Description')).required(i18n.t('Description required.')),
    domains: yup.string().label(i18n.t('Domains')),
    email_address: yup.string().label(i18n.t('Email')),
    encryption: yup.string().nullable().label(i18n.t('Encryption')),
    group_header: yup.string().label(i18n.t('Header')),
    hash_passwords: yup.string().nullable().label(i18n.t('Hash')),
    host: schemaHosts,
    identity_token: yup.string().label(i18n.t('Token')),
    idp_ca_cert_path: yup.string()
      .when('idp_ca_cert_path_upload', () => {
        return (!idp_ca_cert_path_upload)
          ? yup.string().nullable().required(i18n.t('Certificate required.'))
          : yup.string().nullable()
      }),
    idp_cert_path: yup.string()
      .when('idp_cert_path_upload', () => {
        return (!idp_cert_path_upload)
          ? yup.string().nullable().required(i18n.t('Certificate required.'))
          : yup.string().nullable()
      }),
    idp_entity_id: yup.string().label(i18n.t('Entity ID')),
    idp_metadata_path: yup.string()
      .when('idp_metadata_path_upload', () => {
        return (!idp_metadata_path_upload)
          ? yup.string().nullable().required(i18n.t('Metadata required.'))
          : yup.string().nullable()
      }),
    key_file: yup.string()
    .when('key_file_upload', () => {
      return (!key_file_upload)
        ? yup.string().nullable().required(i18n.t('Key required.'))
        : yup.string().nullable()
    }),
    merchant_id: yup.string().label(i18n.t('ID')),
    password_email_update: yup.string().nullable().label(i18n.t('Email')),
    path: yup.string()
      .when('path_upload', () => {
        return (!path_upload)
          ? yup.string().nullable().required(i18n.t('File/path required.'))
          : yup.string().nullable()
      }),
    payment_type: yup.string().nullable().label(i18n.t('Payment type')),
    paypal_cert_file: yup.string()
      .when('paypal_cert_file_upload', () => {
        return (!paypal_cert_file_upload)
          ? yup.string().nullable().required(i18n.t('Certificate required.'))
          : yup.string().nullable()
      }),
    person_mappings: schemaPersonMappings,
    port: yup.string().label(i18n.t('Port')).isPort(),
    protected_resource_url: yup.string().label(i18n.t('URL')),
    proxy_addresses: yup.string().label(i18n.t('Addresses')),
    public_client_key: yup.string().label(i18n.t('Key')),
    publishable_key: yup.string().label(i18n.t('Key')),
    radius_secret: yup.string().label(i18n.t('Secret')),
    redirect_url: yup.string().label(i18n.t('URL')),
    scope: yup.string().nullable().label(i18n.t('Scope')),
    secret_key: yup.string().label(i18n.t('Key')),
    secret: yup.string().label(i18n.t('Secret')),
    server1_address: yup.string().label(i18n.t('Address')),
    server2_address: yup.string().label(i18n.t('Address')),
    shared_secret_direct: yup.string().label(i18n.t('Secret')),
    shared_secret: yup.string().label(i18n.t('Secret')),
    site: yup.string().label(i18n.t('URL')),
    sp_cert_path: yup.string()
      .when('psp_cert_path_upload', () => {
        return (!sp_cert_path_upload)
          ? yup.string().nullable().required(i18n.t('Certificate required.'))
          : yup.string().nullable()
      }),
    sp_entity_id: yup.string().label(i18n.t('Entity ID')),
    sp_key_path: yup.string()
      .when('sp_key_path_upload', () => {
        return (!sp_key_path_upload)
          ? yup.string().nullable().required(i18n.t('Key required.'))
          : yup.string().nullable()
      }),
    tenant_id: yup.string().label(i18n.t('Tenant ID')),
    terminal_id: yup.string().label(i18n.t('ID')),
    transaction_key: yup.string().label(i18n.t('Key')),
    twilio_phone_number: yup.string().label(i18n.t('Phone')),
    user_header: yup.string().label(i18n.t('Header')),
    usernameattribute: yup.string().label(i18n.t('Attribute')),
    eduroam_options: yup.string().nullable().label(i18n.t('Options')),
    eduroam_radius_auth: schemaServers,
    eduroam_radius_auth_proxy_type: yup.string().nullable().label(i18n.t('Type')),
    eduroam_operator_name: yup.string().label(i18n.t('Operator Name')),
  })
}

export default schema

export { yup }
