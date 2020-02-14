import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasNetworkBehaviorPolicies,
  networkBehaviorPolicyExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: i18n.t('Description'),
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
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = (context = {}) => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'network_behavior_policy', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by identifier or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/network_behavior_policies',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'network_behavior_policies' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'description', op: 'contains', value: quickCondition }
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
          label: i18n.t('Profile Name'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew && !isClone)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          cols: [
            {
              namespace: 'description',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'description')
            }
          ]
        },
        {
          label: 'Devices Included',
          text: i18n.t('The list of Fingerbank devices that will be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the childs of the selected devices. Leaving this empty will have all devices impacted by this policy.'),
          cols: [
            {
              namespace: 'devices_included',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'devices_included'),
              validators: validatorsFromMeta(meta, 'devices_included', 'Device')
            }
          ]
        },
        {
          label: 'Devices Excluded',
          text: i18n.t('The list of Fingerbank devices that should not be impacted by this Network Behavior Policy. Devices of this list implicitely includes all the childs of the selected devices.'),
          cols: [
            {
              namespace: 'devices_included',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'devices_included'),
              validators: validatorsFromMeta(meta, 'devices_included', 'Device')
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
      ...validatorsFromMeta(meta, 'id', i18n.t('Name')),
      ...{
        [i18n.t('Name exists.')]: not(and(required, conditional(isNew || isClone), hasNetworkBehaviorPolicies, networkBehaviorPolicyExists))
      }
    },
    description: validatorsFromMeta(meta, 'description', i18n.t('Description')),
    device_registration_allowed_devices: validatorsFromMeta(meta, 'devices_included', 'Device')
  }
}
