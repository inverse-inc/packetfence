import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '../'
import {
  and,
  not,
  conditional,
  hasRadiusEaps,
  radiusEapExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'Identifier', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'default_eap_type',
    label: 'Default EAP', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'tls_tlsprofile',
    label: 'TLS Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'ttls_tlsprofile',
    label: 'TTLS Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'peap_tlsprofile',
    label: 'PEAP Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'fast_config',
    label: 'Fast Profile', // i18n defer
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
      return { name: 'radiusEap', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier'),
    searchableOptions: {
      searchApiEndpoint: 'config/radiusd/eap_profiles',
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
      defaultRoute: { name: 'radiusEaps' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition }
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
  const {
    not_deletable: notDeletable = false
  } = form
  const isEditable = (isNew || isClone || !notDeletable)

  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Identifier'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Default EAP Type'),
          cols: [
            {
              namespace: 'default_eap_type',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'default_eap_type'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Expires'),
          cols: [
            {
              namespace: 'timer_expire.interval',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'timer_expire.interval'),
                disabled: !isEditable
              }
            },
            {
              namespace: 'timer_expire.unit',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'timer_expire.unit'),
                disabled: !isEditable,
                allowEmpty: false
              }
            }
          ]
        },
        {
          label: i18n.t('Ignore Unknown EAP Types'),
          cols: [
            {
              namespace: 'ignore_unknown_eap_types',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' },
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Cisco Accounting Username Bug'),
          cols: [
            {
              namespace: 'cisco_accounting_username_bug',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' },
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Max Sessions'),
          cols: [
            {
              namespace: 'max_sessions',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'max_sessions'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('EAP Authentication Types'),
          cols: [
            {
              namespace: 'eap_authentication_types',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'eap_authentication_types'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('TLS Profile'),
          cols: [
            {
              namespace: 'tls_tlsprofile',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'tls_tlsprofile'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('TTLS Profile'),
          cols: [
            {
              namespace: 'ttls_tlsprofile',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'ttls_tlsprofile'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('PEAP Profile'),
          cols: [
            {
              namespace: 'peap_tlsprofile',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'peap_tlsprofile'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Fast Profile'),
          cols: [
            {
              namespace: 'fast_config',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'fast_config'),
                disabled: !isEditable
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Identifier')),
      ...{
        [i18n.t('EAP profile exists.')]: not(and(required, conditional(isNew || isClone), hasRadiusEaps, radiusEapExists))
      }
    }
  }
}
