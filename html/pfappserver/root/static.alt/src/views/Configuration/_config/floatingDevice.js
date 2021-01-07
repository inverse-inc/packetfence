import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasFloatingDevices,
  floatingDeviceExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: 'MAC',
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'ip',
    label: 'IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'pvid',
    label: 'Native VLAN', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'taggedVlan',
    label: `Tagged VLAN's`, // i18n defer
    sortable: false,
    visible: true
  },
  {
    key: 'trunkPort',
    label: 'Trunk Port', // i18n defer
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
    text: i18n.t('MAC'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'ip',
    text: i18n.t('IP Address'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'floating_device', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by MAC or IP address'),
    searchableOptions: {
      searchApiEndpoint: 'config/floating_devices',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'ip', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'floating_devices' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [
          {
            op: 'or',
            values: [
              { field: 'id', op: 'contains', value: quickCondition },
              { field: 'ip', op: 'contains', value: quickCondition }
            ]
          }
        ]
      }
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    trunkPort
  } = form
  const {
    isNew = false,
    isClone = false
  } = meta
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('MAC Address'),
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
          label: i18n.t('IP Address'),
          cols: [
            {
              namespace: 'ip',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ip')
            }
          ]
        },
        {
          label: i18n.t('Native VLAN'),
          text: i18n.t('VLAN in which PacketFence should put the port.'),
          cols: [
            {
              namespace: 'pvid',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'pvid')
            }
          ]
        },
        {
          label: i18n.t('Trunk Port'),
          text: i18n.t('The port must be configured as a muti-vlan port.'),
          cols: [
            {
              namespace: 'trunkPort',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          if: (trunkPort === 'yes'),
          label: i18n.t('Tagged VLANs'),
          text: i18n.t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.'),
          cols: [
            {
              namespace: 'taggedVlan',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'taggedVlan')
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
      ...validatorsFromMeta(meta, 'id', 'MAC'),
      ...{
        [i18n.t('Floating Device exists.')]: not(and(required, conditional(isNew || isClone), hasFloatingDevices, floatingDeviceExists))
      }
    },
    ip: validatorsFromMeta(meta, 'ip', 'IP'),
    pvid: validatorsFromMeta(meta, 'pvid', 'VLAN'),
    taggedVlan: validatorsFromMeta(meta, 'taggedVlan', 'VLAN')
  }
}
