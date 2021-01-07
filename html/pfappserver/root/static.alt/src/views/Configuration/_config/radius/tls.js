import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggleDefault from '@/components/pfFormRangeToggleDefault'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '../'
import {
  and,
  not,
  conditional,
  hasRadiusTlss,
  radiusTlsExists
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
    key: 'certificate_profile',
    label: 'Certificate Profile', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'ocsp',
    label: 'OCSP Profile', // i18n defer
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
      return { name: 'radiusTls', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier'),
    searchableOptions: {
      searchApiEndpoint: 'config/radiusd/tls_profiles',
      defaultSortKeys: ['id', 'not_deletable'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'radiusTlss' }
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

export const placeholder = (meta = {}, key = null) => {
  const { [key]: { placeholder = null } = {} } = meta
  return placeholder
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
          label: i18n.t('Certificate Profile'),
          cols: [
            {
              namespace: 'certificate_profile',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'certificate_profile'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('DH File'),
          cols: [
            {
              namespace: 'dh_file',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dh_file'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('CA Path'),
          cols: [
            {
              namespace: 'ca_path',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'ca_path'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Cipher List'),
          cols: [
            {
              namespace: 'cipher_list',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'cipher_list'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('ECDH Curve'),
          cols: [
            {
              namespace: 'ecdh_curve',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'ecdh_curve'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Disable TLSv1.2'),
          cols: [
            {
              namespace: 'disable_tlsv1_2',
              component: pfFormRangeToggleDefault,
              attrs: {
                tooltip: false,
                values: { checked: 'yes', unchecked: 'no', default: placeholder(meta, 'disable_tlsv1_2') },
                icons: { checked: 'check', unchecked: 'times' },
                colors: { checked: 'var(--primary)', default: (placeholder(meta, 'disable_tlsv1_2') === 'Y') ? 'var(--primary)' : '' },
                tooltips: { checked: i18n.t('yes'), unchecked: i18n.t('no'), default: i18n.t('Default ({default})', { default: placeholder(meta, 'disable_tlsv1_2') }) },
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('OCSP Profile'),
          cols: [
            {
              namespace: 'ocsp',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'ocsp'),
                disabled: !isEditable
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  const {
    isNew = false,
    isClone = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', i18n.t('Identifier')),
      ...{
        [i18n.t('TLS profile exists.')]: not(and(required, conditional(isNew || isClone), hasRadiusTlss, radiusTlsExists))
      }
    },
    ca_path: validatorsFromMeta(meta, 'ca_path', i18n.t('CA Path')),
    certificate_profile: validatorsFromMeta(meta, 'certificate_profile', i18n.t('Certificate Profile')),
    cipher_list: validatorsFromMeta(meta, 'cipher_list', i18n.t('Cipher List')),
    dh_file: validatorsFromMeta(meta, 'dh_file', i18n.t('DH File')),
    ecdh_curve: validatorsFromMeta(meta, 'ecdh_curve', i18n.t('ECDH Curve')),
    ocsp: validatorsFromMeta(meta, 'ocsp', i18n.t('OCSP Profile'))
  }
}
