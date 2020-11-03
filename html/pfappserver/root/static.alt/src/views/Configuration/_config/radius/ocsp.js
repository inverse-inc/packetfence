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
  hasRadiusOcsps,
  radiusOcspExists
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
      return { name: 'radiusOcsp', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier'),
    searchableOptions: {
      searchApiEndpoint: 'config/radiusd/ocsp_profiles',
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
      defaultRoute: { name: 'radiusOcsps' }
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
          label: i18n.t('Enable'),
          text: i18n.t('Enable OCSP checking.'),
          cols: [
            {
              namespace: 'ocsp_enable',
              component: pfFormRangeToggleDefault,
              attrs: {
                tooltip: false,
                values: { checked: 'yes', unchecked: 'no', default: placeholder(meta, 'ocsp_enable') },
                icons: { checked: 'check', unchecked: 'times' },
                colors: { checked: 'var(--primary)', default: (placeholder(meta, 'ocsp_enable') === 'Y') ? 'var(--primary)' : '' },
                tooltips: { checked: i18n.t('yes'), unchecked: i18n.t('no'), default: i18n.t('Default ({default})', { default: placeholder(meta, 'ocsp_enable') }) },
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Override Responder URL'),
          text: i18n.t('Override the OCSP Responder URL from the certificate.'),
          cols: [
            {
              namespace: 'ocsp_override_cert_url',
              component: pfFormRangeToggleDefault,
              attrs: {
                tooltip: false,
                values: { checked: 'yes', unchecked: 'no', default: placeholder(meta, 'ocsp_override_cert_url') },
                icons: { checked: 'check', unchecked: 'times' },
                colors: { checked: 'var(--primary)', default: (placeholder(meta, 'ocsp_override_cert_url') === 'Y') ? 'var(--primary)' : '' },
                tooltips: { checked: i18n.t('yes'), unchecked: i18n.t('no'), default: i18n.t('Default ({default})', { default: placeholder(meta, 'ocsp_override_cert_url') }) },
                disabled: !isEditable
              }
            }
          ]
        },
        {
          if: form.ocsp_override_cert_url === 'yes',
          label: i18n.t('Responder URL'),
          text: i18n.t('The overridden OCSP Responder URL.'),
          cols: [
            {
              namespace: 'ocsp_url',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'ocsp_url'),
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Use nonce'),
          text: i18n.t('If the OCSP Responder can not cope with nonce in the request, then it can be disabled here.'),
          cols: [
            {
              namespace: 'ocsp_use_nonce',
              component: pfFormRangeToggleDefault,
              attrs: {
                tooltip: false,
                values: { checked: 'yes', unchecked: 'no', default: placeholder(meta, 'ocsp_use_nonce') },
                icons: { checked: 'check', unchecked: 'times' },
                colors: { checked: 'var(--primary)', default: (placeholder(meta, 'ocsp_use_nonce') === 'Y') ? 'var(--primary)' : '' },
                tooltips: { checked: i18n.t('yes'), unchecked: i18n.t('no'), default: i18n.t('Default ({default})', { default: placeholder(meta, 'ocsp_use_nonce') }) },
                disabled: !isEditable
              }
            }
          ]
        },
        {
          label: i18n.t('Response timeout'),
          text: i18n.t('Number of seconds to wait for the OCSP response. 0 uses system default.'),
          cols: [
            {
              namespace: 'ocsp_timeout.interval',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'ocsp_timeout.interval'),
                disabled: !isEditable
              }
            },
            {
              namespace: 'ocsp_timeout.unit',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'ocsp_timeout.unit'),
                disabled: !isEditable,
                allowEmpty: false
              }
            }
          ]
        },
        {
          label: i18n.t('Response softfail'),
          text: i18n.t(`Treat OCSP response errors as 'soft' failures and still accept the certificate.`),
          cols: [
            {
              namespace: 'ocsp_softfail',
              component: pfFormRangeToggleDefault,
              attrs: {
                tooltip: false,
                values: { checked: 'yes', unchecked: 'no', default: placeholder(meta, 'ocsp_softfail') },
                icons: { checked: 'check', unchecked: 'times' },
                colors: { checked: 'var(--primary)', default: (placeholder(meta, 'ocsp_softfail') === 'Y') ? 'var(--primary)' : '' },
                tooltips: { checked: i18n.t('yes'), unchecked: i18n.t('no'), default: i18n.t('Default ({default})', { default: placeholder(meta, 'ocsp_softfail') }) },
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
        [i18n.t('OCSP profile exists.')]: not(and(required, conditional(isNew || isClone), hasRadiusOcsps, radiusOcspExists))
      }
    },
    ocsp_enable: validatorsFromMeta(meta, 'ocsp_enable', i18n.t('Enable')),
    ocsp_override_cert_url: validatorsFromMeta(meta, 'ocsp_override_cert_url', i18n.t('URL')),
    ocsp_softfail: validatorsFromMeta(meta, 'ocsp_softfail', i18n.t('Response')),
    ocsp_timeout: validatorsFromMeta(meta, 'ocsp_timeout', i18n.t('Response timeout')),
    ocsp_url: validatorsFromMeta(meta, 'ocsp_url', i18n.t('URL')),
    ocsp_use_nonce: validatorsFromMeta(meta, 'ocsp_use_nonce', i18n.t('Nonce'))
  }
}
