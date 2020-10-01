/* eslint-disable camelcase */
import store from '@/store'
import i18n from '@/utils/locale'
import acl from '@/utils/acl'
import {
  pfActions,
  pfActionValidators
} from '@/globals/pfActions'
import {
  pfDatabaseSchema,
  buildValidatorsFromColumnSchemas,
  buildValidatorsFromTableSchemas
} from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import {
  and,
  not,
  conditional,
  compareDate,
  userNotExists,
  sourceExists,
  categoryIdNumberExists, // validate category_id/bypass_role_id (Number) exists
  categoryIdStringExists // validate category_id/bypass_role_id (String) exists
} from '@/globals/pfValidators'
import {
  required,
  minLength,
  minValue,
  maxLength,
  numeric
} from 'vuelidate/lib/validators'

import { format } from 'date-fns'

export const userActions = [
  pfActions.set_access_duration_by_acl_user,
  pfActions.set_access_level_by_acl_user,
  pfActions.mark_as_sponsor,
  pfActions.set_role_by_acl_user,
  pfActions.set_access_durations,
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
    sponsor: '',
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
      actions = [],
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
          [i18n.t('Username exists.')]: not(and(required, userNotExists, conditional(!pid_overwrite)))
        },
        password: {
          [i18n.t('Password required.')]: required,
          [i18n.t('Password must be at least 6 characters.')]: minLength(6)
        },
        email: {
          [i18n.t('Email required.')]: required
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
        [i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD')
        /* TODO
         * https://github.com/inverse-inc/packetfence/issues/5592
        [i18n.t('Date must be less than or equal to end date.')]: not(and(required, conditional(valid_from), not(compareDate('<=', expiration, 'YYYY-MM-DD'))))
        */
      },
      expiration: {
        [i18n.t('End date required.')]: conditional(!!expiration && expiration !== '0000-00-00')
        /* TODO
         * https://github.com/inverse-inc/packetfence/issues/5592
        [i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
        [i18n.t('Date must be less than 2038-01-01.')]: compareDate('<=', new Date('2037-12-31 23:59:59'), 'YYYY-MM-DD'),
        [i18n.t('Date must be greater than or equal to start date.')]: not(and(required, conditional(expiration), not(compareDate('>=', valid_from, 'YYYY-MM-DD'))))
        */
      },
      actions: pfActionValidators(userActions, actions)
    }
  }
}

export const updateValidators = (form = {}) => {
  const {
    actions = [],
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
        [i18n.t('Date must be less than or equal to end date.')]: not(and(required, conditional(valid_from), not(compareDate('<=', expiration, 'YYYY-MM-DD'))))
      },
      expiration: {
        [i18n.t('End date required.')]: conditional(!hasPassword || (!!expiration && expiration !== '0000-00-00'))
        /* TODO
         * https://github.com/inverse-inc/packetfence/issues/5592
        [i18n.t('Date must be less than 2038-01-01.')]: compareDate('<=', new Date('2037-12-31 23:59:59'), 'YYYY-MM-DD'),
        [i18n.t('Date must be greater than or equal to start date.')]: not(and(required, conditional(expiration), not(compareDate('>=', valid_from, 'YYYY-MM-DD'))))
        */
      },
      email: {
        [i18n.t('Email address required.')]: required
      },
      psk: {
        [i18n.t('Minimum 8 characters.')]: minLength(8)
      },
      actions: pfActionValidators(userActions, actions)
    }
  )
}

export const importForm = {
  valid_from: format(new Date(), pfDatabaseSchema.password.valid_from.datetimeFormat),
  expiration: null,
  actions: [{ type: 'set_access_level', value: null }]
}

export const importValidators = (form = {}) => {
  const {
    actions = [],
    expiration,
    valid_from
  } = form
  return {
    valid_from: {
      [i18n.t('Start date required.')]: conditional(!!valid_from && valid_from !== '0000-00-00')
      /* TODO
       * https://github.com/inverse-inc/packetfence/issues/5592
      [i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
      [i18n.t('Date must be less than or equal to end date.')]: not(and(required, conditional(valid_from), not(compareDate('<=', expiration, 'YYYY-MM-DD'))))
      */
    },
    expiration: {
      [i18n.t('End date required.')]: conditional(!!expiration && expiration !== '0000-00-00')
      /* TODO
       * https://github.com/inverse-inc/packetfence/issues/5592
      [i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
      [i18n.t('Date must be less than 2038-01-01.')]: compareDate('<=', new Date('2037-12-31 23:59:59'), 'YYYY-MM-DD'),
      [i18n.t('Date must be greater than or equal to start date.')]: not(and(required, conditional(expiration), not(compareDate('>=', valid_from, 'YYYY-MM-DD'))))
      */
    },
    actions: {
      ...pfActionValidators(userActions, actions),
      ...{
        [i18n.t('Action required.')]: required
      }
    }
  }
}

export const importFields = [
  {
    value: 'pid',
    text: i18n.t('PID'),
    types: [fieldType.SUBSTRING],
    required: true,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.pid, { required })
  },
  {
    value: 'password',
    text: i18n.t('Password'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.password.password)
  },
  {
    value: 'title',
    text: i18n.t('Title'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.title)
  },
  {
    value: 'firstname',
    text: i18n.t('First Name'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.firstname)
  },
  {
    value: 'lastname',
    text: i18n.t('Last Name'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.lastname)
  },
  {
    value: 'nickname',
    text: i18n.t('Nickname'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.nickname)
  },
  {
    value: 'email',
    text: i18n.t('Email'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.email)
  },
  {
    value: 'sponsor',
    text: i18n.t('Sponsor'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.sponsor)
  },
  {
    value: 'anniversary',
    text: i18n.t('Anniversary'),
    types: [fieldType.DATE],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.anniversary)
  },
  {
    value: 'birthday',
    text: i18n.t('Birthday'),
    types: [fieldType.DATE],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.birthday)
  },
  {
    value: 'address',
    text: i18n.t('Address'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.address)
  },
  {
    value: 'apartment_number',
    text: i18n.t('Apartment Number'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.apartment_number)
  },
  {
    value: 'building_number',
    text: i18n.t('Building Number'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.building_number)
  },
  {
    value: 'room_number',
    text: i18n.t('Room Number'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.room_number)
  },
  {
    value: 'company',
    text: i18n.t('Company'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.company)
  },
  {
    value: 'gender',
    text: i18n.t('Gender'),
    types: [fieldType.GENDER],
    required: false,
    formatter: formatter.genderFromString,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.gender)
  },
  {
    value: 'lang',
    text: i18n.t('Language'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.lang)
  },
  {
    value: 'notes',
    text: i18n.t('Notes'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.notes)
  },
  {
    value: 'portal',
    text: i18n.t('Portal'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.portal)
  },
  {
    value: 'psk',
    text: i18n.t('PSK'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.psk)
  },
  {
    value: 'category_id',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_ACL_NODE],
    required: false,
    formatter: formatter.categoryIdFromIntOrString,
    validators: buildValidatorsFromColumnSchemas({
      [i18n.t('Role does not exist.')]: categoryIdNumberExists,
      [i18n.t('Role does not exist.')]: categoryIdStringExists
    })
  },
  {
    value: 'source',
    text: i18n.t('Source'),
    types: [fieldType.SOURCE],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.source, { [i18n.t('Invalid source.')]: sourceExists })
  },
  {
    value: 'telephone',
    text: i18n.t('Telephone'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.telephone)
  },
  {
    value: 'cell_phone',
    text: i18n.t('Cellular Phone'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.cell_phone)
  },
  {
    value: 'work_phone',
    text: i18n.t('Work Phone'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.work_phone)
  },
  {
    value: 'custom_field_1',
    text: i18n.t('Custom Field 1'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_1)
  },
  {
    value: 'custom_field_2',
    text: i18n.t('Custom Field 2'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_2)
  },
  {
    value: 'custom_field_3',
    text: i18n.t('Custom Field 3'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_3)
  },
  {
    value: 'custom_field_4',
    text: i18n.t('Custom Field 4'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_4)
  },
  {
    value: 'custom_field_5',
    text: i18n.t('Custom Field 5'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_5)
  },
  {
    value: 'custom_field_6',
    text: i18n.t('Custom Field 6'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_6)
  },
  {
    value: 'custom_field_7',
    text: i18n.t('Custom Field 7'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_7)
  },
  {
    value: 'custom_field_8',
    text: i18n.t('Custom Field 8'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_8)
  },
  {
    value: 'custom_field_9',
    text: i18n.t('Custom Field 9'),
    types: [fieldType.SUBSTRING],
    required: false,
    validators: buildValidatorsFromColumnSchemas(pfDatabaseSchema.person.custom_field_9)
  }
]

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
  {
    key: 'security_event.open_security_event_id',
    label: i18n.t('Security Event Open'),
    sortable: true,
    class: 'text-nowrap',
    formatter: (acl.$can('read', 'security_events'))
      ? formatter.securityEventIdsToDescCsv
      : formatter.noAdminRolePermission
  },
  /* TODO - #4166
  {
    key: 'security_event.open_count',
    label: i18n.t('Security Event Open Count'),
    sortable: true,
    class: 'text-nowrap'
  },
  */
  {
    key: 'security_event.close_security_event_id',
    label: i18n.t('Security Event Closed'),
    sortable: true,
    class: 'text-nowrap',
    formatter: (acl.$can('read', 'security_events'))
      ? formatter.securityEventIdsToDescCsv
      : formatter.noAdminRolePermission
  }
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
  {
    key: 'security_event_id',
    label: i18n.t('Event'),
    required: true,
    sortable: true,
    formatter: (acl.$can('read', 'security_events'))
      ? formatter.securityEventIdToDesc
      : formatter.noAdminRolePermission
  },
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
