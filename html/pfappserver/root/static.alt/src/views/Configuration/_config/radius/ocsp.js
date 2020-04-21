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

export const view = (form = {}, meta = {}) => {
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
              attrs: attributesFromMeta(meta, 'id')
            }
          ]
        },
        {
          label: i18n.t('Enable'),
          text: i18n.t('Enable OCSP checking.'),
          cols: [
            {
              namespace: 'ocsp_enable',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
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
              attrs: attributesFromMeta(meta, 'ocsp_url')
            }
          ]
        },
        {
          label: i18n.t('Use nonce'),
          text: i18n.t('If the OCSP Responder can not cope with nonce in the request, then it can be disabled here.'),
          cols: [
            {
              namespace: 'ocsp_use_nonce',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
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
              attrs: attributesFromMeta(meta, 'ocsp_timeout.interval')
            },
            {
              namespace: 'ocsp_timeout.unit',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'ocsp_timeout.unit'),
                ...{
                  allowEmpty: false
                }
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
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
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
    ocsp_url: validatorsFromMeta(meta, 'ocsp_url', i18n.t('URL')),
    ocsp_timeout: {
      interval: validatorsFromMeta(meta, 'ocsp_timeout.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'ocsp_timeout.unit', i18n.t('Unit'))
    }
  }
}
