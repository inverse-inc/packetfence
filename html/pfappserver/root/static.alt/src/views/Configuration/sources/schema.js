import store from '@/store'
import { pfActionsSchema as schemaActions } from '@/globals/pfActions'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

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

const schemaHost = yup.string().nullable().label(i18n.t('Host'))

const schemaHosts = yup.array().ensure().of(schemaHost).label(i18n.t('Hosts'))

const schemaRule = yup.object({
  status: yup.string(),
  id: yup.string().nullable().label(i18n.t('Name'))
    .isAlphaNumericHyphen()
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

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .sourceIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    administration_rules: schemaRules,
    authentication_rules: schemaRules,
    access_scope: yup.string().label(i18n.t('Scope')),
    access_token_param: yup.string().label(i18n.t('Parameter')),
    access_token_path: yup.string().label(i18n.t('Path')),
    account_sid: yup.string().label(i18n.t('SID')),
    api_key: yup.string().label(i18n.t('API key')),
    api_login_id: yup.string().label(i18n.t('ID')),
    auth_token: yup.string().label(i18n.t('Token')),
    authenticate_realm: yup.string().label(i18n.t('Realm')),
    authorization_source_id: yup.string().label(i18n.t('Source')),
    authorize_path: yup.string().label(i18n.t('Path')),
    basedn: yup.string().label(i18n.t('Base DN')),
    cert_file: yup.string().label(i18n.t('File')),
    cert_id: yup.string().label(i18n.t('ID')),
    client_id: yup.string().label(i18n.t('ID')),
    client_secret: yup.string().label(i18n.t('Secret')),
    description: yup.string().label(i18n.t('Description')),
    domains: yup.string().label(i18n.t('Domains')),
    email_address: yup.string().label(i18n.t('Email')),
    group_header: yup.string().label(i18n.t('Header')),
    host: schemaHosts,
    identity_token: yup.string().label(i18n.t('Token')),
    idp_ca_cert_path: yup.string().label(i18n.t('Path')),
    idp_cert_path: yup.string().label(i18n.t('Path')),
    idp_entity_id: yup.string().label(i18n.t('Entity ID')),
    idp_metadata_path: yup.string().label(i18n.t('Path')),
    key_file: yup.string().label(i18n.t('File')),
    merchant_id: yup.string().label(i18n.t('ID')),
    password_email_update: yup.string().label(i18n.t('Email')),
    path: yup.string().label(i18n.t('Path')),
    paypal_cert_file: yup.string().label(i18n.t('File')),
    person_mappings: schemaPersonMappings,
    port: yup.string().label(i18n.t('Port')).isPort(),
    protected_resource_url: yup.string().label(i18n.t('URL')),
    proxy_addresses: yup.string().label(i18n.t('Addresses')),
    public_client_key: yup.string().label(i18n.t('Key')),
    publishable_key: yup.string().label(i18n.t('Key')),
    radius_secret: yup.string().label(i18n.t('Secret')),
    redirect_url: yup.string().label(i18n.t('URL')),
    scope: yup.string().label(i18n.t('Scope')),
    secret_key: yup.string().label(i18n.t('Key')),
    secret: yup.string().label(i18n.t('Secret')),
    server1_address: yup.string().label(i18n.t('Address')),
    server2_address: yup.string().label(i18n.t('Address')),
    shared_secret_direct: yup.string().label(i18n.t('Secret')),
    shared_secret: yup.string().label(i18n.t('Secret')),
    site: yup.string().label(i18n.t('URL')),
    sp_cert_path: yup.string().label(i18n.t('Path')),
    sp_entity_id: yup.string().label(i18n.t('Entity ID')),
    sp_key_path: yup.string().label(i18n.t('Path')),
    terminal_id: yup.string().label(i18n.t('ID')),
    transaction_key: yup.string().label(i18n.t('Key')),
    twilio_phone_number: yup.string().label(i18n.t('Phone')),
    user_header: yup.string().label(i18n.t('Header')),
    usernameattribute: yup.string().label(i18n.t('Attribute')),
  })
}

export default schema
