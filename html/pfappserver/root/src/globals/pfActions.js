import { MysqlDatabase } from '@/globals/mysql'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { compareAsc, format, getYear, setYear, isValid, parse } from 'date-fns'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const setUnregDateTextFn = value => {
  const reDate = /^([0-9]{1,4})-([0-9]{2})-([0-9]{2})/
  if (value && reDate.test(value)) {
    // eslint-disable-next-line no-unused-vars
    const [_, y, m, d] = value.match(reDate)
    if (+y < 1970) { // ensure parse-able string
      value = `1970-${m}-${d}`
    }
  }
  const date = parse(value, 'yyyy-MM-dd')
  if (date instanceof Date && isValid(date)) {
    const now = new Date()
    if (compareAsc(date, now) < 0) {
      const year = getYear(now)
      const normalized = setYear(date, year)
      let unreg_date = format(normalized, 'YYYY-MM-DD')
      if (compareAsc(normalized, now) < 0) {
        unreg_date = format(setYear(normalized, year + 1), 'YYYY-MM-DD')
      }
      return i18n.t(`Past dates dynamically increase up to 1 year in the future (eg ${unreg_date}).`, { unreg_date })
    }
  }
}

export const pfActions = {
  bandwidth_balance_from_source: {
    value: 'bandwidth_balance_from_source',
    text: 'Bandwidth balance from authentication source', // i18n defer
    types: [fieldType.NONE]
  },
  default_actions: {
    value: 'default_actions',
    text: 'Execute module default actions', // i18n defer
    types: [fieldType.NONE]
  },
  destination_url: {
    value: 'destination_url',
    text: 'Destination URL', // i18n defer
    types: [fieldType.URL]
  },
  mark_as_sponsor: {
    value: 'mark_as_sponsor',
    text: 'Mark as sponsor', // i18n defer
    types: [fieldType.HIDDEN],
    staticValue: '1',
    default: '1'
  },
  no_action: {
    value: 'no_action',
    text: 'No action', // i18n defer
    types: [fieldType.NONE]
  },
  on_failure: {
    value: 'on_failure',
    text: 'On failure', // i18n defer
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  on_success: {
    value: 'on_success',
    text: 'On success', // i18n defer
    types: [fieldType.ROOT_PORTAL_MODULE]
  },
  role_from_source: {
    value: 'role_from_source',
    text: 'Role from authentication source', // i18n defer
    types: [fieldType.NONE]
  },
  set_access_duration: {
    value: 'set_access_duration',
    text: 'Access duration', // i18n defer
    types: [fieldType.DURATION]
  },
  set_access_duration_by_acl_user: {
    value: 'set_access_duration',
    text: 'Access duration', // i18n defer
    types: [fieldType.DURATION_BY_ACL_USER]
  },
  set_access_durations: {
    value: 'set_access_durations',
    text: 'Sponsor access durations', // i18n defer
    types: [fieldType.DURATIONS]
  },
  set_access_level: {
    value: 'set_access_level',
    text: 'Access level', // i18n defer
    types: [fieldType.ADMINROLE]
  },
  set_access_level_by_acl_user: {
    value: 'set_access_level',
    text: 'Access level', // i18n defer
    types: [fieldType.ADMINROLE_BY_ACL_USER]
  },
  set_bandwidth_balance: {
    value: 'set_bandwidth_balance',
    text: 'Bandwidth balance', // i18n defer
    types: [fieldType.PREFIXMULTIPLIER]
  },
  set_role: {
    value: 'set_role',
    text: 'Role', // i18n defer
    types: [fieldType.ROLE]
  },
  set_role_by_name: {
    value: 'set_role',
    text: 'Role', // i18n defer
    types: [fieldType.ROLE_BY_NAME]
  },
  set_role_by_acl_user: {
    value: 'set_role',
    text: 'Role', // i18n defer
    types: [fieldType.ROLE_BY_ACL_USER]
  },
  set_role_on_not_found: {
    value: 'set_role_on_not_found',
    text: 'Role On Not Found', // i18n defer
    types: [fieldType.ROLE_BY_NAME]
  },
  set_role_from_source: {
    value: 'set_role_from_source',
    text: 'Role from source', // i18n defer
    types: [fieldType.SELECTONE]
  },
  set_time_balance: {
    value: 'set_time_balance',
    text: 'Time balance', // i18n defer
    types: [fieldType.TIME_BALANCE]
  },
  trigger_radius_mfa: {
    value: 'trigger_radius_mfa',
    text: i18n.t('Trigger RADIUS MFA'),
    types: [fieldType.SELECTONE]
  },
  trigger_portal_mfa: {
    value: 'trigger_portal_mfa',
    text: i18n.t('Trigger Portal MFA'),
    types: [fieldType.SELECTONE]
  },
  set_unreg_date: {
    value: 'set_unreg_date',
    text: 'Unregistration date', // i18n defer
    types: [fieldType.DATE],
    props: {
      placeholder: '0000-00-00',
      textFn: setUnregDateTextFn
    }
  },
  set_unreg_date_by_acl_user: {
    value: 'set_unreg_date',
    text: 'Unregistration date', // i18n defer
    types: [fieldType.DATE],
    props: {
      placeholder: '0000-00-00',
      textFn: setUnregDateTextFn
    }
  },
  time_balance_from_source: {
    value: 'time_balance_from_source',
    text: 'Time balance from authentication source', // i18n defer
    types: [fieldType.NONE]
  },
  unregdate_from_source: {
    value: 'unregdate_from_source',
    text: 'Unregistration date from authentication source', // i18n defer
    types: [fieldType.NONE]
  },
  unregdate_from_sponsor_source: {
    value: 'unregdate_from_sponsor_source',
    text: 'Unregistration date from sponsor source', // i18n defer
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
        case type === 'set_role':
        case pfActions[type].types.includes(fieldType.NONE):
        case pfActions[type].types.includes(fieldType.HIDDEN):
          return yup.string().nullable()
          // break
        case type === 'destination_url':
          return yup.string().nullable()
            .required(i18n.t('Value required.'))
            .url(i18n.t('Value must be a URL.'))
          // break
        case type === 'set_bandwidth_balance':
          return yup.string().nullable()
            .required(i18n.t('Value required.'))
            .maxAsInt(MysqlDatabase.node.bandwidth_balance.max)
            .minAsInt(MysqlDatabase.node.bandwidth_balance.min)
          // break
        case type === 'set_access_level':
        case type === 'set_access_level_by_acl_user':
          return yup.array().ensure()
            .of(yup.string().nullable())
            .required(i18n.t('Level(s) required.'))
          // break
        case type === 'set_access_durations':
          return yup.array().nullable()
            .of(yup.string().nullable())
            .required(i18n.t('Duration(s) required.'))
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
