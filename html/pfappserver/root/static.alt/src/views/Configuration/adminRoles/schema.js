import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'adminRoleIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'adminRoleIdNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getAdminRoles').then(response => {
        return response.filter(adminRole => adminRole.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaAction = yup.string().nullable().required(i18n.t('Action required.'))
const schemaActions = yup.array().ensure().of(schemaAction)

const schemaAllowedAccessLevel = yup.string().nullable().required(i18n.t('Access level required.'))
const schemaAllowedAccessLevels = yup.array().ensure().of(schemaAllowedAccessLevel)

const schemaAllowedRole = yup.string().nullable().required(i18n.t('Role required.'))
const schemaAllowedRoles = yup.array().ensure().of(schemaAllowedRole)

const schemaAllowedAccessDuration = yup.string().nullable().required(i18n.t('Duration required.'))
const schemaAllowedAccessDurations = yup.array().ensure().of(schemaAllowedAccessDuration)

const schemaAllowedAction = yup.string().nullable().required(i18n.t('Action required.'))
const schemaAllowedActions = yup.array().ensure().of(schemaAllowedAction)

const schemaAllowedNodeRole = yup.string().nullable().required(i18n.t('Role required.'))
const schemaAllowedNodeRoles = yup.array().ensure().of(schemaAllowedNodeRole)

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .adminRoleIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    description: yup.string().nullable().label(i18n.t('Description')),
    actions: schemaActions.required(i18n.t('Actions required.')),
    allowed_access_levels: schemaAllowedAccessLevels,
    allowed_roles: schemaAllowedRoles,
    allowed_access_durations: schemaAllowedAccessDurations,
    allowed_unreg_date: yup.string().nullable().label(i18n.t('Date/time')),
    allowed_actions: schemaAllowedActions,
    allowed_node_roles: schemaAllowedNodeRoles
  })
}
