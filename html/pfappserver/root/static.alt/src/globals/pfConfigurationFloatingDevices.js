import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormToggle from '@/components/pfFormToggle'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'

const {
  required,
  integer,
  macAddress,
  ipAddress
} = require('vuelidate/lib/validators')

export const pfConfigurationFloatingDevicesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('MAC') }), // re-label
  pfConfigurationListColumns.ip,
  pfConfigurationListColumns.pvid,
  pfConfigurationListColumns.taggedVlan,
  pfConfigurationListColumns.trunkPort
]

export const pfConfigurationFloatingDevicesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('MAC') }), // re-text
  pfConfigurationListFields.ip
]

export const pfConfigurationFloatingDeviceViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
  return [
    {
      tab: null, // ignore tabs
      fields: [
        {
          label: i18n.t('MAC Address'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('MAC address required.')]: required,
                [i18n.t('Enter a valid MAC address.')]: macAddress()
              }
            }
          ]
        },
        {
          label: i18n.t('IP Address'),
          fields: [
            {
              key: 'ip',
              component: pfFormInput,
              validators: {
                [i18n.t('IP address required.')]: required,
                [i18n.t('Enter a valid IP address.')]: ipAddress
              }
            }
          ]
        },
        {
          label: i18n.t('Native VLAN'),
          text: i18n.t('VLAN in which PacketFence should put the port.'),
          fields: [
            {
              key: 'pvid',
              component: pfFormInput,
              attrs: {
                filter: regExp.integerPositive
              },
              validators: {
                [i18n.t('Native VLAN required.')]: required,
                [i18n.t('Enter a valid Native VLAN.')]: integer
              }
            }
          ]
        },
        {
          label: i18n.t('Trunk Port'),
          text: i18n.t('The port must be configured as a muti-vlan port.'),
          fields: [
            {
              key: 'trunkPort',
              component: pfFormToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          label: i18n.t('Tagged VLANs'),
          text: i18n.t('Comma separated list of VLANs. If the port is a multi-vlan, these are the VLANs that have to be tagged on the port.'),
          fields: [
            {
              key: 'taggedVlan',
              component: pfFormInput
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationFloatingDeviceViewDefaults = (context = {}) => {
  return {
    id: null
  }
}
