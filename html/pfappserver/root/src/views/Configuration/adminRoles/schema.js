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

//const schemaDisallowedRole = yup.string().nullable().required(i18n.t('Role required.'))
const schemaDisallowedRoles = yup.array().ensure().of(schemaAllowedRole)

const schemaAllowedAccessDuration = yup.string().nullable().required(i18n.t('Duration required.'))
const schemaAllowedAccessDurations = yup.array().ensure().of(schemaAllowedAccessDuration)

const schemaAllowedAction = yup.string().nullable().required(i18n.t('Action required.'))
const schemaAllowedActions = yup.array().ensure().of(schemaAllowedAction)

const schemaAllowedNodeRole = yup.string().nullable().required(i18n.t('Role required.'))
const schemaAllowedNodeRoles = yup.array().ensure().of(schemaAllowedNodeRole)

//const schemaDisallowedNodeRole = yup.string().nullable().required(i18n.t('Role required.'))
const schemaDisallowedNodeRoles = yup.array().ensure().of(schemaAllowedNodeRole)

const schemaAllowedNodeBypassVlan = yup.string().nullable().required(i18n.t('VLAN required.'))
const schemaAllowedNodeBypassVlans = yup.array().ensure().unique(i18n.t('Duplicate VLAN.')).of(schemaAllowedNodeBypassVlan)

export default (props) => {
  const {
    form,
    id,
    isNew,
    isClone
  } = props

  const {
    allowed_roles = [],
    disallowed_roles = [],
    allowed_node_roles = [],
    disallowed_node_roles = [],
    allowed_node_bypass_roles = [],
    disallowed_node_bypass_roles = []
  } = form || {}

  return yup.object().shape({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .adminRoleIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    description: yup.string()
      .nullable()
      .required(i18n.t('Description required.'))
      .label(i18n.t('Description')),
    actions: schemaActions.required(i18n.t('Actions required.')),
    allowed_access_levels: schemaAllowedAccessLevels,
    allowed_roles: (disallowed_roles.length > 0)
      ? yup.array().ensure().max(0, i18n.t('Cannot combine with Disallowed user roles.'))
      : schemaAllowedRoles,
    disallowed_roles: (allowed_roles.length > 0)
      ? yup.array().ensure().max(0, i18n.t('Cannot combine with Allowed user roles.'))
      : schemaDisallowedRoles,
    allowed_access_durations: schemaAllowedAccessDurations,
    allowed_unreg_date: yup.string().nullable().label(i18n.t('Date/time')),
    allowed_actions: schemaAllowedActions,
    allowed_node_roles: (disallowed_node_roles.length > 0)
      ? yup.array().ensure().max(0, i18n.t('Cannot combine with Disallowed node roles.'))
      : schemaAllowedNodeRoles,
    disallowed_node_roles: (allowed_node_roles.length > 0)
      ? yup.array().ensure().max(0, i18n.t('Cannot combine with Allowed node roles.'))
      : schemaDisallowedNodeRoles,
    allowed_node_bypass_vlans: schemaAllowedNodeBypassVlans,
    allowed_node_bypass_roles: (disallowed_node_bypass_roles.length > 0)
      ? yup.array().ensure().max(0, i18n.t('Cannot combine with Disallowed node bypass roles.'))
      : schemaAllowedRoles,
    disallowed_node_bypass_roles: (allowed_node_bypass_roles.length > 0)
      ? yup.array().ensure().max(0, i18n.t('Cannot combine with Allowed node bypass roles.'))
      : schemaDisallowedNodeRoles,
    disable_bypass_vlan: yup.string().nullable()
  })
}
