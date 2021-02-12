import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'realmIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'realmIdentifierNotExistsExcept',
    message: message || i18n.t('Realm exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getRealms').then(response => {
        return response.filter(role => role.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaServer = yup.string().nullable()

const schemaServers = yup.array().ensure().of(schemaServer)

export default (props) => {
  const {
    id,
    form,
    isNew,
    isClone
  } = props

  // reactive variables for `yup.when`
  const { permit_custom_attributes } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Realm required.'))
      .realmIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Realm exists.')),
    eap: yup.string().nullable().label('EAP'),
    domain: yup.string().nullable().label(i18n.t('Domain')),
    options: yup.string().nullable().label(i18n.t('Options')),
    radius_auth: schemaServers,
    radius_auth_proxy_type: yup.string().nullable().label(i18n.t('Type')),
    radius_acct: schemaServers,
    radius_acct_proxy_type: yup.string().nullable().label(i18n.t('Type')),
    eduroam_options: yup.string().nullable().label(i18n.t('Options')),
    eduroam_radius_auth: schemaServers,
    eduroam_radius_auth_proxy_type: yup.string().nullable().label(i18n.t('Type')),
    eduroam_radius_acct: schemaServers,
    eduroam_radius_acct_proxy_type: yup.string().nullable().label(i18n.t('Type')),
    ldap_source: yup.string()
      .when('permit_custom_attributes', () => (permit_custom_attributes === 'enabled')
        ? yup.string().nullable().required(i18n.t('Source required.'))
        : yup.string().nullable()
      ),
    ldap_source_ttls_pap: yup.string().nullable().label(i18n.t('Source')),
    edir_source: yup.string().nullable().label(i18n.t('Source'))
  })
}
