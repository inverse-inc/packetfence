import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationCiscoMobilityServicesEngineViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Enable MSE'),
          fields: [
            {
              key: 'enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('URL of MSE service'),
          fields: [
            {
              key: 'url',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'url'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'url', 'URL')
            }
          ]
        },
        {
          label: i18n.t('Username'),
          text: i18n.t('Username for MSE service.'),
          fields: [
            {
              key: 'user',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'user'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'user', i18n.t('Username'))
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('Password for MSE service.'),
          fields: [
            {
              key: 'pass',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'pass'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'pass', i18n.t('Password'))
            }
          ]
        }
      ]
    }
  ]
}
