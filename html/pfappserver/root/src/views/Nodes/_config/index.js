import filters from '@/utils/filters'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import {
  MysqlDatabase,
  validatorFromColumnSchemas
} from '@/globals/mysql'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import { yup as yupRoles } from '@/views/Configuration/roles/schema'
import { yup as yupUsers } from '@/views/Users/schema'

export const createForm = {
  mac: null,
  status: 'reg',
  pid: null,
  category_id: null,
  unreg_date: null,
  notes: null
}

export const importFields = [
  {
    value: 'mac',
    text: i18n.t('MAC Address'),
    types: [fieldType.SUBSTRING],
    required: true,
    validator: yup.string().nullable()
      .required(i18n.t('MAC required.'))
      .isMAC(i18n.t('Invalid MAC address.'))
      .concat(validatorFromColumnSchemas(MysqlDatabase.node.mac))
  },
  {
    value: 'status',
    text: i18n.t('Status'),
    types: [fieldType.NODE_STATUS],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.status)
  },
  {
    value: 'autoreg',
    text: i18n.t('Auto Registration'),
    types: [fieldType.YESNO],
    required: false,
    formatter: formatter.yesNoFromString,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.autoreg)
  },
  {
    value: 'bandwidth_balance',
    text: i18n.t('Bandwidth Balance'),
    types: [fieldType.PREFIXMULTIPLIER],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.bandwidth_balance)
  },
  {
    value: 'bypass_role_id',
    text: i18n.t('Bypass Role'),
    types: [fieldType.ROLE],
    required: false,
    formatter: formatter.categoryIdFromIntOrString,
    validator: yupRoles.string().nullable()
      .roleNameOrCategoryIdentifierExists(i18n.t('Role does not exist.'))
  },
  {
    value: 'bypass_vlan',
    text: i18n.t('Bypass VLAN'),
    types: [fieldType.SUBSTRING],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.bypass_vlan)
  },
  {
    value: 'computername',
    text: i18n.t('Computer Name'),
    types: [fieldType.SUBSTRING],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.computername)
  },
  {
    value: 'regdate',
    text: i18n.t('Datetime Registered'),
    types: [fieldType.DATETIME],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.regdate)
  },
  {
    value: 'unregdate',
    text: i18n.t('Datetime Unregistered'),
    types: [fieldType.DATETIME],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.unregdate)
  },
  {
    value: 'notes',
    text: i18n.t('Notes'),
    types: [fieldType.SUBSTRING],
    required: false,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.notes)
  },
  {
    value: 'pid',
    text: i18n.t('Owner'),
    types: [fieldType.SUBSTRING],
    required: false,
    validator: yupUsers.string().nullable()
      .pidExists(i18n.t('Owner does not exist.'))
      .concat(validatorFromColumnSchemas(MysqlDatabase.node.pid))
  },
  {
    value: 'category_id',
    text: i18n.t('Role'),
    types: [fieldType.ROLE_BY_ACL_NODE],
    required: false,
    formatter: formatter.categoryIdFromIntOrString,
    validator: yupRoles.string().nullable()
      .roleNameOrCategoryIdentifierExists(i18n.t('Role does not exist.'))
  },
  {
    value: 'voip',
    text: i18n.t('VoIP'),
    types: [fieldType.YESNO],
    required: false,
    formatter: formatter.yesNoFromString,
    validator: validatorFromColumnSchemas(MysqlDatabase.node.voip)
  }
]

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
    tdClass: 'text-right'
  }
]

export const dhcpOption82Fields = [
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
