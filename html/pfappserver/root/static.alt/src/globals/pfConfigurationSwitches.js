import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'

const {
  required,
  ipAddress
} = require('vuelidate/lib/validators')

export const pfConfigurationSwitchesListColumns = [
  Object.assign(pfConfigurationListColumns.id, { label: i18n.t('Identifier') }), // re-label
  pfConfigurationListColumns.description,
  pfConfigurationListColumns.group,
  pfConfigurationListColumns.type,
  pfConfigurationListColumns.mode,
  pfConfigurationListColumns.buttons
]

export const pfConfigurationSwitchesListFields = [
  Object.assign(pfConfigurationListFields.id, { text: i18n.t('Identifier') }), // re-text
  pfConfigurationListFields.description,
  pfConfigurationListFields.mode,
  pfConfigurationListFields.type
]

export const pfConfigurationSwitchViewFields = (context = {}) => {
  const { isNew = false, isClone = false } = context
  console.log('pfConfigurationSwitchViewFields')
  return [
    {
      tab: i18n.t('Definition'),
      fields: [
        {
          label: i18n.t('Identifier'),
          fields: [
            {
              key: 'id',
              component: pfFormInput,
              attrs: {
                disabled: (!isNew && !isClone)
              },
              validators: {
                [i18n.t('Identifier required.')]: required,
                [i18n.t('IP addresses only.')]: ipAddress
              }
            }
          ]
        },
        {
          label: i18n.t('Description'),
          fields: [
            {
              key: 'notes',
              component: pfFormInput
            }
          ]
        }
      ]
    },
    {
      tab: i18n.t('Roles'),
      disabled: true,
      fields: []
    },
    {
      tab: i18n.t('Inline'),
      disabled: true,
      fields: []
    },
    {
      tab: i18n.t('RADIUS'),
      disabled: true,
      fields: []
    },
    {
      tab: i18n.t('SNMP'),
      disabled: true,
      fields: []
    },
    {
      tab: i18n.t('CLI'),
      disabled: true,
      fields: []
    },
    {
      tab: i18n.t('Web Services'),
      disabled: true,
      fields: []
    }
  ]
}

export const pfConfigurationSwitchViewDefaults = (context = {}) => {
  return {
    id: null,
    useCoA: 'Y',
    VoIPLLDPDetect: 'Y',
    VoIPCDPDetect: 'Y',
    VoIPDHCPDetect: 'Y',
    uplink_dynamic: 'dynamic'
  }
}
