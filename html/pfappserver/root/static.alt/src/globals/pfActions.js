import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import bytes from '@/utils/bytes'
import i18n from '@/utils/locale'
import {
  conditional,
  isDateFormat,
  isValidUnregDateByAclUser
} from '@/globals/pfValidators'
import {
  maxValue,
  minValue,
  numeric,
  required,
  url
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
    text: i18n.t('Set the bandwidth balance from the auth source'),
    types: [fieldType.NONE]
  },
  default_formActions: {
    value: 'default_formActions',
    text: i18n.t('Execute module default formActions'),
    types: [fieldType.NONE]
  },
  destination_url: {
    value: 'destination_url',
    text: i18n.t('Destination URL'),
    types: [fieldType.URL],
    validators: {
      [i18n.t('Value must be a URL.')]: url
    }
  },
  on_failure: {
    value: 'on_failure',
    text: i18n.t('on_failure'),
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  on_success: {
    value: 'on_success',
    text: i18n.t('on_success'),
    types: [fieldType.ROOT_PORTAL_MODULE]
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
    text: i18n.t('Do not perform an action'),
    types: [fieldType.NONE]
  },
  role_from_source: {
    value: 'role_from_source',
    text: i18n.t('Set role from the authentication source'),
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
    types: [fieldType.PREFIXMULTIPLIER],
    validators: {
      [i18n.t('Value must be greater than {min}bytes.', { min: bytes.toHuman(schema.node.bandwidth_balance.min) })]: minValue(schema.node.bandwidth_balance.min),
      [i18n.t('Value must be less than {max}bytes.', { max: bytes.toHuman(schema.node.bandwidth_balance.max) })]: maxValue(schema.node.bandwidth_balance.max)
    }
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
    types: [fieldType.TENANT],
    validators: {
      [i18n.t('Value must be numeric.')]: numeric
    }
  },
  set_time_balance: {
    value: 'set_time_balance',
    text: i18n.t('Time balance'),
    types: [fieldType.TIME_BALANCE]
  },
  set_unreg_date: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    placeholder: 'YYYY-MM-DD HH:mm:ss',
    /* TODO - Workaround for Issue #4672
     * types: [fieldType.DATETIME],
     * moments: ['1 days', '1 weeks', '1 months', '1 years'],
     */
    types: [fieldType.SUBSTRING]
    /* TODO
     * https://github.com/inverse-inc/packetfence/issues/5592
    validators: {
      [i18n.t('Invalid date.')]: isDateFormat('YYYY-MM-DD')
    }
     */
  },
  set_unreg_date_by_acl_user: {
    value: 'set_unreg_date',
    text: i18n.t('Unregistration date'),
    placeholder: 'YYYY-MM-DD HH:mm:ss',
    /* TODO - Workaround for Issue #4672
     * types: [fieldType.DATETIME],
     * moments: ['1 days', '1 weeks', '1 months', '1 years'],
     */
    types: [fieldType.SUBSTRING]
    /* TODO
     * https://github.com/inverse-inc/packetfence/issues/5592
    validators: {
      [i18n.t('Invalid date.')]: isDateFormat('YYYY-MM-DD'),
      // Limit maximum date w/ current user ACL
      [i18n.t('Date exceeds maximum allowed by current user.')]: isValidUnregDateByAclUser('YYYY-MM-DD')
    }
     */
  },
  time_balance_from_source: {
    value: 'time_balance_from_source',
    text: i18n.t('Set the time balance from the auth source'),
    types: [fieldType.NONE]
  },
  unregdate_from_source: {
    value: 'unregdate_from_source',
    text: i18n.t('Set unregistration date from the authentication source'),
    types: [fieldType.NONE]
  },
  unregdate_from_sponsor_source: {
    value: 'unregdate_from_sponsor_source',
    text: i18n.t('Set unregistration date from the sponsor source'),
    types: [fieldType.NONE]
  }
  /* keys are alphabetical, please insert new actions in order above */
}
