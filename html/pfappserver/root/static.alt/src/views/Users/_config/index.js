import store from '@/store'
import i18n from '@/utils/locale'
import { pfActions } from '@/globals/pfActions'
import {
  pfDatabaseSchema,
  buildValidatorsFromTableSchemas
} from '@/globals/pfDatabaseSchema'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import {
  and,
  not,
  conditional,
  compareDate,
  userExists
} from '@/globals/pfValidators'
import {
  required,
  minLength,
  minValue,
  maxLength,
  numeric
} from 'vuelidate/lib/validators'

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

export const actionValidators = (form = {}) => {
  const {
    actions = []
  } = form
  return {
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
      expiration
    } = {}
  } = form
  const prefixMaxLength = pfDatabaseSchema.person.pid.maxLength - Math.floor(Math.log10(quantity || 1) + 1)
  return {
    single: buildValidatorsFromTableSchemas(
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
    multiple: buildValidatorsFromTableSchemas(
      pfDatabaseSchema.person, // use `person` table schema
      pfDatabaseSchema.password, // use `password` table schema
      { sponsor: pfDatabaseSchema.person.sponsor }, // `sponsor` column exists in both `person` and `password` tables, fix: overload
      {
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
      actions: actionValidators(form)
    }
  }
}

export const updateValidators = (form = {}) => {
  const {
    expiration,
    valid_from
  } = form
  const hasPassword = !!expiration
  return buildValidatorsFromTableSchemas(
    pfDatabaseSchema.person, // use `person` table schema
    // pfDatabaseSchema.password, // use `password` table schema
    { sponsor: pfDatabaseSchema.person.sponsor }, // `sponsor` column exists in both `person` and `password` tables, fix: overload
    {
      valid_from: {
        [i18n.t('Start date required.')]: conditional(!hasPassword || (!!valid_from && valid_from !== '0000-00-00')),
        [i18n.t('Date must be less than or equal to end date.')]: not(and(required, conditional(valid_from), not(compareDate('<=', expiration, 'YYYY-MM-DD'))))
      },
      expiration: {
        [i18n.t('End date required.')]: conditional(!hasPassword || (!!expiration && expiration !== '0000-00-00')),
        [i18n.t('Date must be greater than or equal to start date.')]: not(and(required, conditional(expiration), not(compareDate('>=', valid_from, 'YYYY-MM-DD'))))
      },
      email: {
        [i18n.t('Email address required.')]: required
      },
      psk: {
        [i18n.t('Minimum 8 characters.')]: minLength(8)
      },
      actions: (hasPassword) ? actionValidators(form) : {}
    }
  )
}

export const nodeFields = [
  {
    key: 'tenant_id',
    label: i18n.t('Tenant'),
    sortable: true
  },
  {
    key: 'status',
    label: i18n.t('Status'),
    sortable: true,
    visible: true
  },
  {
    key: 'online',
    label: i18n.t('Online/Offline'),
    sortable: true
  },
  {
    key: 'mac',
    label: i18n.t('MAC Address'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'detect_date',
    label: i18n.t('Detected Date'),
    sortable: true,
    formatter: formatter.datetimeIgnoreZero,
    class: 'text-nowrap'
  },
  {
    key: 'regdate',
    label: i18n.t('Registration Date'),
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero,
    class: 'text-nowrap'
  },
  {
    key: 'unregdate',
    label: i18n.t('Unregistration Date'),
    sortable: true,
    visible: true,
    formatter: formatter.datetimeIgnoreZero,
    class: 'text-nowrap'
  },
  {
    key: 'computername',
    label: i18n.t('Computer Name'),
    sortable: true,
    visible: true
  },
  {
    key: 'ip4log.ip',
    label: i18n.t('IPv4 Address'),
    sortable: true
  },
  {
    key: 'ip6log.ip',
    label: i18n.t('IPv6 Address'),
    sortable: true
  },
  {
    key: 'device_class',
    label: i18n.t('Device Class'),
    sortable: true,
    visible: true
  },
  {
    key: 'device_manufacturer',
    label: i18n.t('Device Manufacturer'),
    sortable: true
  },
  {
    key: 'device_score',
    label: i18n.t('Device Score'),
    sortable: true
  },
  {
    key: 'device_type',
    label: i18n.t('Device Type'),
    sortable: true
  },
  {
    key: 'device_version',
    label: i18n.t('Device Version'),
    sortable: true
  },
  {
    key: 'dhcp6_enterprise',
    label: i18n.t('DHCPv6 Enterprise'),
    sortable: true
  },
  {
    key: 'dhcp6_fingerprint',
    label: i18n.t('DHCPv6 Fingerprint'),
    sortable: true
  },
  {
    key: 'dhcp_fingerprint',
    label: i18n.t('DHCP Fingerprint'),
    sortable: true
  },
  {
    key: 'category_id',
    label: i18n.t('Role'),
    sortable: true,
    formatter: formatter.categoryId
  },
  {
    key: 'locationlog.connection_type',
    label: i18n.t('Connection Type'),
    sortable: true
  },
  {
    key: 'locationlog.session_id',
    label: i18n.t('Session ID'),
    sortable: true
  },
  {
    key: 'locationlog.switch',
    label: i18n.t('Switch Identifier'),
    sortable: true
  },
  {
    key: 'locationlog.switch_ip',
    label: i18n.t('Switch IP Address'),
    sortable: true
  },
  {
    key: 'locationlog.switch_mac',
    label: i18n.t('Switch MAC Address'),
    sortable: true
  },
  {
    key: 'locationlog.ssid',
    label: i18n.t('SSID'),
    sortable: true
  },
  {
    key: 'locationlog.vlan',
    label: i18n.t('VLAN'),
    sortable: true
  },
  {
    key: 'bypass_vlan',
    label: i18n.t('Bypass VLAN'),
    sortable: true
  },
  {
    key: 'bypass_role_id',
    label: i18n.t('Bypass Role'),
    sortable: true,
    formatter: formatter.bypassRoleId
  },
  {
    key: 'notes',
    label: i18n.t('Notes'),
    sortable: true
  },
  {
    key: 'voip',
    label: i18n.t('VoIP'),
    sortable: true
  },
  {
    key: 'last_arp',
    label: i18n.t('Last ARP'),
    sortable: true,
    formatter: formatter.datetimeIgnoreZero,
    class: 'text-nowrap'
  },
  {
    key: 'last_dhcp',
    label: i18n.t('Last DHCP'),
    sortable: true,
    formatter: formatter.datetimeIgnoreZero,
    class: 'text-nowrap'
  },
  {
    key: 'machine_account',
    label: i18n.t('Machine Account'),
    sortable: true
  },
  {
    key: 'autoreg',
    label: i18n.t('Auto Registration'),
    sortable: true
  },
  {
    key: 'bandwidth_balance',
    label: i18n.t('Bandwidth Balance'),
    sortable: true
  },
  {
    key: 'time_balance',
    label: i18n.t('Time Balance'),
    sortable: true
  },
  {
    key: 'user_agent',
    label: i18n.t('User Agent'),
    sortable: true
  },
  /* TODO $can
  {
    key: 'security_event.open_security_event_id',
    label: i18n.t('Security Event Open'),
    sortable: true,
    class: 'text-nowrap',
    formatter: (this.$can.apply(null, ['read', 'security_events']))
      ? formatter.securityEventIdsToDescCsv
      : formatter.noAdminRolePermission
  },
  */
  /* TODO - #4166
  {
    key: 'security_event.open_count',
    label: i18n.t('Security Event Open Count'),
    sortable: true,
    class: 'text-nowrap'
  },
  */
  /* TODO $can
  {
    key: 'security_event.close_security_event_id',
    label: i18n.t('Security Event Closed'),
    sortable: true,
    class: 'text-nowrap',
    formatter: (this.$can.apply(null, ['read', 'security_events']))
      ? formatter.securityEventIdsToDescCsv
      : formatter.noAdminRolePermission
  }
  */
  /* TODO - #4166
  {
    key: 'security_event.close_count',
    label: i18n.t('Security Event Closed Count'),
    sortable: true,
    class: 'text-nowrap'
  }
  */
]

export const securityEventFields = [
  {
    key: 'status',
    label: i18n.t('Status'),
    sortable: true
  },
  /* TODO $can
  {
    key: 'security_event_id',
    label: i18n.t('Event'),
    required: true,
    sortable: true,
    formatter: (this.$can.apply(null, ['read', 'security_events']))
      ? formatter.securityEventIdToDesc
      : formatter.noAdminRolePermission
  },
  */
  {
    key: 'mac',
    label: i18n.t('MAC'),
    sortable: true
  },
  {
    key: 'notes',
    label: i18n.t('Description'),
    sortable: true
  },
  {
    key: 'start_date',
    label: i18n.t('Start Date'),
    sortable: true,
    formatter: formatter.datetimeIgnoreZero
  },
  {
    key: 'release_date',
    label: i18n.t('Release Date'),
    sortable: true,
    formatter: formatter.datetimeIgnoreZero
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]
