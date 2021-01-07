import store from '@/store'
import { pfActions as actions } from '@/globals/pfActions'
import { pfFieldType as fieldType } from '@/globals/pfField'
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

const schemaAction = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', type => ((type && (actions[type].types.includes(fieldType.NONE) || actions[type].types.includes(fieldType.HIDDEN)))
      ? yup.string().nullable()
      : yup.string().nullable().required(i18n.t('Value required.'))
    ))
})

const schemaActionsTransliterations = Object.keys(actions).reduce((transliterations, key) => {
  return { ...transliterations, [key]: actions[key].text }
}, {})

export const schemaActions = yup.array().ensure()
  .unique(i18n.t('Duplicate action.'))
  // prevent extras w/ 'no_action'
  .ifThenRequires(
    i18n.t('"{no_action}" prohibits other actions.', schemaActionsTransliterations),
    ({ type }) => type === 'no_action',
    ({ type }) => type === 'no_action'
  )
  // 'set_access_duration' requires 'set_role'
  .ifThenRequires(
    i18n.t('"{set_access_duration}" requires either "{set_role}", "{set_role_from_source}" or "{set_role_on_not_found}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_access_duration',
    ({ type }) => ['set_role', 'set_role_from_source', 'set_role_on_not_found'].includes(type)
  )
  // `set_access_durations' requires 'mark_as_sponsor'
  .ifThenRequires(
    i18n.t('"{set_access_durations}" requires "{mark_as_sponsor}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_access_durations',
    ({ type }) => type !== 'mark_as_sponsor'
  )
  // 'set_role' requires either 'set_access_duration' or 'set_unreg_date'
  .ifThenRequires(
    i18n.t('"{set_role}" requires either "{set_access_duration}" or "{set_unreg_date}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_role',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_role_from_source' requires either ('set_access_duration' or 'set_unreg_date') and 'set_role'
  .ifThenRequires(
    i18n.t('"{set_role_from_source}" requires either "{set_access_duration}" or "{set_unreg_date}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_role_from_source',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_role_on_not_found' requires either 'set_access_duration' or 'set_unreg_date'
  .ifThenRequires(
    i18n.t('"{set_role_on_not_found}" requires either "{set_access_duration}" or "{set_unreg_date}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_role_on_not_found',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_unreg_date' requires either 'set_role' or 'set_role_on_not_found'
  .ifThenRequires(
    i18n.t('"{set_unreg_date}" requires either "{set_role}" or "{set_role_on_not_found}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_unreg_date',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_unreg_date' restricts 'set_access_duration'
  .ifThenRequires(
    i18n.t('"{set_unreg_date}" conflicts with "{set_access_duration}".', schemaActionsTransliterations),
    ({ type }) => type === 'set_unreg_date',
    ({ type }) => type === 'set_access_duration'
  )
  .of(schemaAction)

const schemaCondition = yup.object({
  attribute: yup.string().label(i18n.t('Attribute')).required(i18n.t('Attribute required.')),
  operator: yup.string().label(i18n.t('Operator')).required(i18n.t('Operator required.')),
  value: yup.string().label(i18n.t('Value')).required(i18n.t('Value required.'))
})

const schemaConditions = yup.array().ensure().unique(i18n.t('Duplicate condition.')).of(schemaCondition)

const schemaRule = yup.object({
  status: yup.string(),
  id: yup.string().label(i18n.t('Name'))
    .isAlpha()
    .max(255, i18n.t('Maximum 255 characters.')),
  description: yup.string()
    .max(255, i18n.t('Maximum 255 characters.')),
  match: yup.string(),
  actions: schemaActions.label(i18n.t('Action')),
  conditions: schemaConditions.label(i18n.t('Condition')).meta({ invalidFeedback: i18n.t('Condition contains one or more errors.') })
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


    administration_rules: schemaRules.meta({ invalidFeedback: i18n.t('Administration rule contains one or more errors.') }),
    authentication_rules: schemaRules.meta({ invalidFeedback: i18n.t('Authentication rule contains one or more errors.') }),
    port: yup.string().isPort(),

    access_token_param: yup.string().label(i18n.t('Parameter')),
    access_token_path: yup.string().label(i18n.t('Path')),
    account_sid: yup.string().label(i18n.t('SID')),
    api_key: yup.string().label(i18n.t('API key')),
    api_login_id: yup.string().label(i18n.t('ID')),
    auth_token: yup.string().label(i18n.t('Token')),
    authenticate_realm: yup.string().label(i18n.t('Authentication realm')),
    authorization_source_id: yup.string().label(i18n.t('Authorization source')),
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
    host: yup.string().label(i18n.t('Host')),
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
    person_mappings: schemaPersonMappings.meta({ invalidFeedback: i18n.t('Mappings contain one or more errors.') }),
    protected_resource_url: yup.string().label(i18n.t('URL')),
    proxy_addresses: yup.string().label(i18n.t('Addresses')),
    public_client_key: yup.string().label(i18n.t('Key')),
    publishable_key: yup.string().label(i18n.t('Key')),
    radius_secret: yup.string().label(i18n.t('Secret')),
    redirect_url: yup.string().label(i18n.t('URL')),
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
    twilio_phone_number: yup.string().label(i18n.t('Phone number')),
    user_header: yup.string().label(i18n.t('Header')),
    usernameattribute: yup.string().label(i18n.t('Username attribute')),
  })
}

export default schema
