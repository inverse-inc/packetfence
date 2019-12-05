import filters from '@/utils/filters'
import i18n from '@/utils/locale'
import {
  pfDatabaseSchema,
  buildValidationFromTableSchemas
} from '@/globals/pfDatabaseSchema'
import {
  isMacAddress,
  userExists,
  nodeExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const form = {
  mac: null,
  status: 'reg',
  pid: null,
  category_id: null,
  unreg_date: null,
  notes: null
}

export const createValidations = buildValidationFromTableSchemas(
  pfDatabaseSchema.node, // use `node` table schema
  {
    mac: {
      [i18n.t('MAC address required.')]: required,
      [i18n.t('Invalid MAC address.')]: isMacAddress,
      [i18n.t('MAC address exists.')]: nodeExists
    },
    pid: {
      [i18n.t('Owner does not exist.')]: userExists
    }
  }
)

export const updateValidations = buildValidationFromTableSchemas(
  pfDatabaseSchema.node, // use `node` table schema
  {
    pid: {
      [i18n.t('Username required.')]: required,
      [i18n.t('Owner does not exist.')]: userExists
    },
  }
)

export const ipLogFields = [
  {
    key: 'ip',
    label: i18n.t('IP Address'),
    sortable: true
  },
  {
    key: 'start_time',
    label: i18n.t('Start Time'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  },
  {
    key: 'end_time',
    label: i18n.t('End Time'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true
  }
]

export const locationLogFields = [
  {
    key: 'switch',
    label: i18n.t('Switch/AP'),
    sortable: true
  },
  {
    key: 'connection_type',
    label: i18n.t('Connection Type'),
    sortable: true
  },
  {
    key: 'dot1x_username',
    label: i18n.t('Username'),
    sortable: true
  },
  {
    key: 'start_time',
    label: i18n.t('Start Time'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  },
  {
    key: 'end_time',
    label: i18n.t('End Time'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  }
]

export const securityEventFields = [
  {
    key: 'description',
    label: i18n.t('Security Event'),
    sortable: true
  },
  {
    key: 'start_date',
    label: i18n.t('Start Time'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  },
  {
    key: 'release_date',
    label: i18n.t('Release Date'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  },
  {
    key: 'status',
    label: i18n.t('Status'),
    sortable: true,
    class: 'text-nowrap'
  },
  {
    key: 'buttons',
    label: '',
    locked: true,
    class: 'text-right'
  }
]

export const dhcpOption82Fields =[
  {
    key: 'created_at',
    label: i18n.t('Created At'),
    sortable: true,
    formatter: filters.shortDateTime,
    class: 'text-nowrap'
  },
  {
    key: 'vlan',
    label: i18n.t('VLAN'),
    sortable: true
  },
  {
    key: 'switch_id',
    label: i18n.t('Switch IP'),
    sortable: true,
    class: 'text-nowrap'
  },
  {
    key: 'option82_switch',
    label: i18n.t('Switch MAC'),
    sortable: true,
    class: 'text-nowrap'
  },
  {
    key: 'port',
    label: i18n.t('Port'),
    sortable: true
  },
  {
    key: 'module',
    label: i18n.t('Module'),
    sortable: true
  },
  {
    key: 'host',
    label: i18n.t('Host'),
    sortable: true
  }
]
