import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import {
  pfConfigurationListColumns,
  pfConfigurationListFields
} from '@/globals/pfConfiguration'

const {
  required,
  alphaNum
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
  return [
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
            [i18n.t('Alphanumeric value required.')]: alphaNum
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
