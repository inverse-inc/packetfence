import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and
} from '@/globals/pfValidators'
import {
  integer,
  required,
  minValue,
  maxValue
} from 'vuelidate/lib/validators'
import { search as deviceSearch } from './device'
import { search as dhcpFingerprintSearch } from './dhcpFingerprint'
import { search as dhcpV6EnterpriseSearch } from './dhcpV6Enterprise'
import { search as dhcpV6FingerprintSearch } from './dhcpV6Fingerprint'
import { search as dhcpVendorSearch } from './dhcpVendor'
import { search as macVendorSearch } from './macVendor'
import { search as userAgentSearch } from './userAgent'

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'device_id',
    label: 'Device', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'score',
    label: 'Score', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'created_at',
    label: 'Created', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'updated_at',
    label: 'Updated', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'fingerbankCombination', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or device'),
    searchableOptions: {
      searchApiEndpoint: `fingerbank/local/combinations`,
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'fingerbankCombinations' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'device_id', op: 'equals', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          if: (!isNew && !isClone),
          label: 'Identifier', // i18n defer
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                disabled: true
              }
            }
          ]
        },
        {
          label: 'DHCP Fingerprint', // i18n defer
          cols: [
            {
              namespace: 'dhcp_fingerprint_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: dhcpFingerprintSearch
              }
            }
          ]
        },
        {
          label: 'DHCP Vendor', // i18n defer
          cols: [
            {
              namespace: 'dhcp_vendor_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: dhcpVendorSearch
              }
            }
          ]
        },
        {
          label: 'DHCPv6 Fingerprint', // i18n defer
          cols: [
            {
              namespace: 'dhcp6_fingerprint_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: dhcpV6FingerprintSearch
              }
            }
          ]
        },
        {
          label: 'DHCPv6 Enterprise', // i18n defer
          cols: [
            {
              namespace: 'dhcp6_enterprise_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: dhcpV6EnterpriseSearch
              }
            }
          ]
        },
        {
          label: 'MAC Vendor (OUI)', // i18n defer
          cols: [
            {
              namespace: 'mac_vendor_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: macVendorSearch
              }
            }
          ]
        },
        {
          label: 'User Agent', // i18n defer
          cols: [
            {
              namespace: 'user_agent_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: userAgentSearch
              }
            }
          ]
        },
        {
          label: 'Device', // i18n defer
          cols: [
            {
              namespace: 'device_id',
              component: pfFormChosen,
              attrs: {
                collapseObject: true,
                placeholder: i18n.t('Type to search'),
                trackBy: 'value',
                label: 'text',
                searchable: true,
                internalSearch: false,
                preserveSearch: true,
                clearOnSelect: false,
                allowEmpty: false,
                optionsLimit: 100,
                optionsSearchFunction: deviceSearch
              }
            }
          ]
        },
        {
          label: 'Version', // i18n defer
          cols: [
            {
              namespace: 'version',
              component: pfFormInput
            }
          ]
        },
        {
          label: 'Score', // i18n defer
          cols: [
            {
              namespace: 'score',
              component: pfFormInput,
              attrs: {
                type: 'number',
                step: 1
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    device_id: {
      [i18n.t('Device required.')]: required
    },
    score: {
      [i18n.t('Score required.')]: required,
      [i18n.t('Integers only.')]: integer,
      [i18n.t('Invalid Score.')]: and(minValue(0), maxValue(100))
    }
  }
}
