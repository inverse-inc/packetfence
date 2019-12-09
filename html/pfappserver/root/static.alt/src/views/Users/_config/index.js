import store from '@/store'
import i18n from '@/utils/locale'
import { pfActions } from '@/globals/pfActions'
import {
  pfDatabaseSchema,
  buildValidationFromTableSchemas
} from '@/globals/pfDatabaseSchema'
import {
  required,
  minLength,
  minValue,
  maxLength,
  numeric
} from 'vuelidate/lib/validators'
import {
  and,
  not,
  conditional,
  compareDate,
  userExists
} from '@/globals/pfValidators'

import { format } from 'date-fns'

export const actions = [
  pfActions.set_access_duration_by_acl_user,
  pfActions.set_access_level_by_acl_user,
  pfActions.mark_as_sponsor,
  pfActions.set_role_by_acl_user,
  pfActions.set_access_durations,
  pfActions.set_tenant_id,
  pfActions.set_unreg_date_by_acl_user
]

export const passwordOptions = {
  pwlength: 8,
  upper: true,
  lower: true,
  digits: true,
  special: false,
  brackets: false,
  high: false,
  ambiguous: false
}

export const createForm = {
  single: {
    pid_overwrite: 0,
    pid: '',
    email: '',
    sponsor: store.state['session'].username, // TODO - #4395, remove when backend implements default sponsor
    password: '',
    login_remaining: null,
    gender: '',
    title: '',
    firstname: '',
    lastname: '',
    nickname: '',
    company: '',
    telephone: '',
    cell_phone: '',
    work_phone: '',
    address: '',
    apartment_number: '',
    building_number: '',
    room_number: '',
    anniversary: '',
    birthday: '',
    psk: '',
    notes: '',
    custom_field_1: '',
    custom_field_2: '',
    custom_field_3: '',
    custom_field_4: '',
    custom_field_5: '',
    custom_field_6: '',
    custom_field_7: '',
    custom_field_8: '',
    custom_field_9: ''
  },
  multiple: {
    pid_overwrite: 0,
    prefix: '',
    quantity: '',
    login_remaining: null,
    firstname: '',
    lastname: '',
    company: '',
    notes: ''
  },
  common: {
    valid_from: format(new Date(), 'YYYY-MM-DD'),
    expiration: null,
    actions: [{ 'type': 'set_access_level', 'value': null }]
  }
}

export const createValidators = (form = {}) => {
  const {
    single: {
      pid_overwrite
    } = {},
    multiple: {
      quantity = 0
    } = {},
    common: {
      valid_from,
      expiration,
      actions = []
    } = {}
  } = form
  const prefixMaxLength = pfDatabaseSchema.person.pid.maxLength - Math.floor(Math.log10(quantity || 1) + 1)
  return {
    single: buildValidationFromTableSchemas(
      pfDatabaseSchema.person, // use `person` table schema
      pfDatabaseSchema.password, // use `password` table schema
      { sponsor: pfDatabaseSchema.person.sponsor }, // `sponsor` column exists in both `person` and `password` tables, fix: overload
      {
        // additional custom validations ...
        pid: {
          [i18n.t('Username required.')]: required,
          [i18n.t('Username exists.')]: not(and(required, userExists, conditional(!pid_overwrite)))
        },
        email: {
          [i18n.t('Email address required.')]: required
        },
        password: {
          [i18n.t('Password required.')]: required,
          [i18n.t('Password must be at least 6 characters.')]: minLength(6)
        }
      }
    ),
    multiple: buildValidationFromTableSchemas(
      pfDatabaseSchema.person, // use `person` table schema
      pfDatabaseSchema.password, // use `password` table schema
      { sponsor: pfDatabaseSchema.person.sponsor }, // `sponsor` column exists in both `person` and `password` tables, fix: overload
      {
        // additional custom validations ...
        prefix: {
          [i18n.t('Username prefix required.')]: required,
          [i18n.t('Maximum {maxLength} characters.', { maxLength: prefixMaxLength })]: maxLength(prefixMaxLength)
        },
        quantity: {
          [i18n.t('Quantity must be greater than 0.')]: and(required, numeric, minValue(1))
        }
      }
    ),
    common: {
      valid_from: {
        [i18n.t('Start date required.')]: conditional(!!valid_from && valid_from !== '0000-00-00'),
        [i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
        [i18n.t('Date must be less than or equal to end date.')]: not(and(required, conditional(valid_from), not(compareDate('<=', expiration, 'YYYY-MM-DD'))))
      },
      expiration: {
        [i18n.t('End date required.')]: conditional(!!expiration && expiration !== '0000-00-00'),
        [i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
        [i18n.t('Date must be greater than or equal to start date.')]: not(and(required, conditional(expiration), not(compareDate('>=', valid_from, 'YYYY-MM-DD'))))
      },
      actions: {
        $each: {
          type: {
            [i18n.t('Action required')]: required,
            /* prevent duplicates */
            [i18n.t('Duplicate action.')]: conditional((type) => actions.filter(action => action && action.type === type).length <= 1),
            /* 'set_access_duration' requires 'set_role' */
            [i18n.t('Action requires "Set Role".')]: conditional((value) => value !== 'set_access_duration' || actions.filter(action => action && action.type === 'set_role').length > 0),
            /* 'set_access_duration' restricts 'set_unreg_date' */
            [i18n.t('Action conflicts with "Unregistration date".')]: conditional((value) => value !== 'set_access_duration' || actions.filter(action => action && action.type === 'set_unreg_date').length === 0),
            /* `set_access_durations' requires 'mark_as_sponsor' */
            [i18n.t('Action requires "Mark as sponsor".')]: conditional((value) => value !== 'set_access_durations' || actions.filter(action => action && action.type === 'mark_as_sponsor').length > 0),
            /* 'set_role' requires either 'set_access_duration' or 'set_unreg_date' */
            [i18n.t('Action requires either "Access duration" or "Unregistration date".')]: conditional((value) => value !== 'set_role' || actions.filter(action => action && ['set_access_duration', 'set_unreg_date'].includes(action.type)).length > 0),
            /* 'set_unreg_date' requires 'set_role' */
            [i18n.t('Action requires "Set Role".')]: conditional((value) => value !== 'set_unreg_date' || actions.filter(action => action && action.type === 'set_role').length > 0),
            /* 'set_unreg_date' restricts 'set_access_duration' */
            [i18n.t('Action conflicts with "Access duration".')]:  conditional((value) => value !== 'set_unreg_date' || actions.filter(action => action && action.type === 'set_access_duration').length === 0)
          },
          value: {
            [i18n.t('Value required')]: required,
          }
        }
      }
    }
  }
}
