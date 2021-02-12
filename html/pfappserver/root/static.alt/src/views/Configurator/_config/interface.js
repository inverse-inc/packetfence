import i18n from '@/utils/locale'
import {
  typeFormatter,
  sortColumns
} from '@/views/Configuration/_config/interface'
import {
  minValue,
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'is_running',
    label: i18n.t('Status'),
    visible: true
  },
  {
    key: 'id',
    label: i18n.t('Logical Name'),
    required: true,
    sortable: true,
    visible: true,
    sort: sortColumns.id
  },
  {
    key: 'ipaddress',
    label: i18n.t('IP Address'),
    sortable: true,
    visible: true,
    sort: sortColumns.ipaddress
  },
  {
    key: 'network',
    label: i18n.t('Default Network'),
    sortable: true,
    visible: true,
    sort: sortColumns.network
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    visible: true,
    formatter: typeFormatter
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const networkValidators = () => {
  return {
    dns_servers: {
      [i18n.t('At least one DNS server is required.')]: required
    },
    gateway: {
      [i18n.t('Default gateway required.')]: required
    },
    hostname: {
      [i18n.t('Hostname required.')]: required
    },
    management_type: {
      [i18n.t('One interface has to be of type management.')]: minValue(1)
    }
  }
}