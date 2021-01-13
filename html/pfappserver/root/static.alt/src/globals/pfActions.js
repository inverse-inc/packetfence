import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import {
  conditional
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const pfActionsFromMeta = (meta = {}, key = null) => {
  let fields = []
  if (Object.keys(meta).length > 0) {
    while (key.includes('.')) { // handle dot-notation keys ('.')
      let [ first, ...remainder ] = key.split('.')
      if (!(first in meta)) return {}
      key = remainder.join('.')
      let { [first]: { item: { properties: _collectionMeta } = {}, properties: _meta } } = meta
      if (_collectionMeta) {
        meta = _collectionMeta // swap ref to child
      } else {
        meta = _meta // swap ref to child
      }
    }
    let { [key]: { allowed } = {} } = meta
    if (allowed) {
      allowed.forEach(type => {
        if (pfActions[type.value]) {
          fields.push(pfActions[type.value])
        } else {
          // eslint-disable-next-line
          console.error(`Unknown configuration action ${type.text} (${type.value})`)
        }
      })
    }
  }
  return fields
}

export const pfActionValidators = (availableActions = [], formActions = []) => {
  return {
    ...(formActions || []).map((action) => {
      const { type, value } = action || {}
      const { [type]: { staticValue } = {} } = pfActions
      return {
        type: {
          ...((type)
            ? {
              // prevent duplicates
              [i18n.t('Duplicate action.')]: conditional((type) => formActions.filter(action => action && action.type === type).length <= 1)
            }
            : {
              // `type` is required
              [i18n.t('Action required')]: required
            }
          ),
          ...((type === 'no_action')
            ? {
              // prevent extras w/ 'no_action'
              [i18n.t('No other action must be defined.')]: conditional(() => formActions.filter(action => action && action.type !== 'no_action').length === 0)
            }
            : {/* noop */}
          ),
          ...((type === 'set_access_duration')
            ? {
              // 'set_access_duration' requires 'set_role'
              [i18n.t('Action requires either "Set Role" or "Role On Not Found".')]: conditional(() => formActions.filter(action => action && ['set_role', 'set_role_on_not_found'].includes(action.type)).length > 0),
              // 'set_access_duration' restricts 'set_unreg_date'
              [i18n.t('Action conflicts with "Unregistration date".')]: conditional(() => formActions.filter(action => action && action.type === 'set_unreg_date').length === 0)
            }
            : {/* noop */}
          ),
          ...((type === 'set_access_durations')
            ? {
              // `set_access_durations' requires 'mark_as_sponsor'
              [i18n.t('Action requires "Mark as sponsor".')]: conditional(() => formActions.filter(action => action && action.type === 'mark_as_sponsor').length > 0)
            }
            : {/* noop */}
          ),
          ...((type === 'set_role')
            ? {
              // 'set_role' requires either 'set_access_duration' or 'set_unreg_date'
              [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: conditional(() => formActions.filter(action => action && ['set_access_duration', 'set_unreg_date'].includes(action.type)).length > 0)
            }
            : {/* noop */}
          ),
          ...((type === 'set_role_on_not_found')
            ? {
              // 'set_role_on_not_found' requires either 'set_access_duration' or 'set_unreg_date'
              [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: conditional(() => formActions.filter(action => action && ['set_access_duration', 'set_unreg_date'].includes(action.type)).length > 0)
            }
            : {/* noop */}
          ),
          ...((type === 'set_role_from_source')
            ? {
              // 'set_role_from_source' requires either ('set_access_duration' or 'set_unreg_date') and 'set_role'
              [i18n.t('Action requires either ("Access duration" or "Unregistration date") and "Set Role".')]: conditional(() => formActions.filter(action => action && ['set_access_duration', 'set_unreg_date'].includes(action.type)).length > 0 && formActions.filter(action => action && ['set_role'].includes(action.type)).length > 0)
            }
            : {/* noop */}
          ),
          ...((type === 'set_unreg_date')
            ? {
              // 'set_unreg_date' requires 'set_role'
              [i18n.t('Action requires either "Set Role" or "Role On Not Found".')]: conditional(() => formActions.filter(action => action && ['set_role', 'set_role_on_not_found'].includes(action.type)).length > 0),
              // 'set_unreg_date' restricts 'set_access_duration'
              [i18n.t('Action conflicts with "Access duration".')]: conditional(() => formActions.filter(action => action && action.type === 'set_access_duration').length === 0)
            }
            : {/* noop */}
          )
        },
        value: {
          ...((value)
            ? (() => {
              let pfAction = availableActions.filter((pfAction) => pfAction.value === type)[0]
              return ('validators' in pfAction)
                ? pfAction.validators // dynamic `value` validators
                : {}
            })()
            : {/* noop */}
          ),
          ...((!value && !staticValue)
            ? {
              // `value` required
              [i18n.t('Value required')]: required
            }
            : {/* noop */}
          )
        }
      }
    })
  }
}

export const pfActions = {
  bandwidth_balance_from_source: {
    value: 'bandwidth_balance_from_source',
    text: i18n.t('Bandwidth balance from authentication source'),
    types: [fieldType.NONE]
  },
  default_actions: {
    value: 'default_actions',
    text: i18n.t('Execute module default actions'),
    types: [fieldType.NONE]
  },
  destination_url: {
    value: 'destination_url',
    text: i18n.t('Destination URL'),
    types: [fieldType.URL]
  },
  mark_as_sponsor: {
    value: 'mark_as_sponsor',
    text: i18n.t('Mark as sponsor'),
    types: [fieldType.HIDDEN],
    staticValue: '1',
    default: '1'
  },
  no_action: {
    value: 'no_action',
    text: i18n.t('No action'),
    types: [fieldType.NONE]
  },
  on_failure: {
    value: 'on_failure',
    text: i18n.t('On failure'),
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  on_success: {
    value: 'on_success',
    text: i18n.t('On success'),
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  role_from_source: {
    value: 'role_from_source',
    text: i18n.t('Role from authentication source'),
    types: [fieldType.NONE]
  },
  set_access_duration: {
    value: 'set_access_duration',
    text: i18n.t('Access duration'),
    types: [fieldType.DURATION]
  },
  set_access_duration_by_acl_user: {
    value: 'set_access_duration',
    text: i18n.t('Access duration'),
    types: [fieldType.DURATION_BY_ACL_USER]
  },
  set_access_durations: {
    value: 'set_access_durations',
    text: i18n.t('Sponsor access durations'),
    types: [fieldType.DURATIONS]
  },
  set_access_level: {
    value: 'set_access_level',
    text: i18n.t('Access level'),
    types: [fieldType.ADMINROLE]
  },
  set_access_level_by_acl_user: {
    value: 'set_access_level',
    text: i18n.t('Access level'),
    types: [fieldType.ADMINROLE_BY_ACL_USER]
  },
  set_bandwidth_balance: {
    value: 'set_bandwidth_balance',
    text: i18n.t('Bandwidth balance'),
    types: [fieldType.PREFIXMULTIPLIER]
  },
  set_role: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE]
  },
  set_role_by_name: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_NAME]
  },
  set_role_by_acl_user: {
    value: 'set_role',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_ACL_USER]
  },
  set_role_on_not_found: {
    value: 'set_role_on_not_found',
    text: i18n.t('Role On Not Found'),
    types: [fieldType.ROLE_BY_NAME]
  },
  set_role_from_source: {
    value: 'set_role_from_source',
    text: i18n.t('Role from source'),
    types: [fieldType.SELECTONE]
  },
  set_tenant_id: {
    value: 'set_tenant_id',
    text: i18n.t('Tenant ID'),
    types: [fieldType.TENANT]
  },
  set_time_balance: {
    value: 'set_time_balance',
    text: i18n.t('Time balance'),
    types: [fieldType.TIME_BALANCE]
  },
  set_unreg_date: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    types: [fieldType.DATETIME],
    props: {
      placeholder: '0000-00-00 00:00:00'
    }
  },
  set_unreg_date_by_acl_user: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    types: [fieldType.DATETIME],
    props: {
      placeholder: '0000-00-00 00:00:00',
    }
  },
  time_balance_from_source: {
    value: 'time_balance_from_source',
    text: i18n.t('Time balance from authentication source'),
    types: [fieldType.NONE]
  },
  unregdate_from_source: {
    value: 'unregdate_from_source',
    text: i18n.t('Unregistration date from authentication source'),
    types: [fieldType.NONE]
  },
  unregdate_from_sponsor_source: {
    value: 'unregdate_from_sponsor_source',
    text: i18n.t('Unregistration date from sponsor source'),
    types: [fieldType.NONE]
  }
  /* keys are alphabetical, please insert new actions in order above */
}

const pfActionsTransliterations = Object.keys(pfActions).reduce((transliterations, key) => {
  return { ...transliterations, [key]: pfActions[key].text }
}, {})

const pfActionSchema = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', type => {
      switch (true) {
        case type === 'destination_url':
          return yup.string().nullable()
            .required(i18n.t('Value required.'))
            .url(i18n.t('Value must be a URL.'))
          // break
        case type === 'set_bandwidth_balance':
          return yup.string().nullable()
            .required(i18n.t('Value required.'))
            .maxAsInt(schema.node.bandwidth_balance.max)
            .minAsInt(schema.node.bandwidth_balance.min)
          // break
        case type === 'set_role':
        case pfActions[type].types.includes(fieldType.NONE):
        case pfActions[type].types.includes(fieldType.HIDDEN):
          return yup.string().nullable()
          // break
        default:
          return yup.string().nullable()
            .required(i18n.t('Value required.'))
      }
    })
})

export const pfActionsSchema = yup.array().ensure()
  .unique(i18n.t('Duplicate action.'), ({ type }) => type)
  // prevent extras w/ 'no_action'
  .ifThenRestricts(
    i18n.t('"{no_action}" prohibits other actions.', pfActionsTransliterations),
    ({ type }) => type === 'no_action',
    ({ type }) => type !== 'no_action'
  )
  // 'set_access_duration' requires 'set_role'
  .ifThenRequires(
    i18n.t('"{set_access_duration}" requires either "{set_role}", "{set_role_from_source}" or "{set_role_on_not_found}".', pfActionsTransliterations),
    ({ type }) => type === 'set_access_duration',
    ({ type }) => ['set_role', 'set_role_from_source', 'set_role_on_not_found'].includes(type)
  )
  // `set_access_durations' requires 'mark_as_sponsor'
  .ifThenRequires(
    i18n.t('"{set_access_durations}" requires "{mark_as_sponsor}".', pfActionsTransliterations),
    ({ type }) => type === 'set_access_durations',
    ({ type }) => type !== 'mark_as_sponsor'
  )
  // 'set_role' requires either 'set_access_duration' or 'set_unreg_date'
  .ifThenRequires(
    i18n.t('"{set_role}" requires either "{set_access_duration}" or "{set_unreg_date}".', pfActionsTransliterations),
    ({ type }) => type === 'set_role',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_role_from_source' requires either ('set_access_duration' or 'set_unreg_date') and 'set_role'
  .ifThenRequires(
    i18n.t('"{set_role_from_source}" requires either "{set_access_duration}" or "{set_unreg_date}".', pfActionsTransliterations),
    ({ type }) => type === 'set_role_from_source',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_role_on_not_found' requires either 'set_access_duration' or 'set_unreg_date'
  .ifThenRequires(
    i18n.t('"{set_role_on_not_found}" requires either "{set_access_duration}" or "{set_unreg_date}".', pfActionsTransliterations),
    ({ type }) => type === 'set_role_on_not_found',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_unreg_date' requires either 'set_role' or 'set_role_on_not_found'
  .ifThenRequires(
    i18n.t('"{set_unreg_date}" requires either "{set_role}" or "{set_role_on_not_found}".', pfActionsTransliterations),
    ({ type }) => type === 'set_unreg_date',
    ({ type }) => ['set_access_duration', 'set_unreg_date'].includes(type)
  )
  // 'set_unreg_date' restricts 'set_access_duration'
  .ifThenRestricts(
    i18n.t('"{set_unreg_date}" conflicts with "{set_access_duration}".', pfActionsTransliterations),
    ({ type }) => type === 'set_unreg_date',
    ({ type }) => type === 'set_access_duration'
  )
  .of(pfActionSchema)
