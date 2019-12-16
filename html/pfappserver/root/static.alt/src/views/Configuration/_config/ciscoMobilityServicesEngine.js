import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Enable MSE'),
          cols: [
            {
              namespace: 'enabled',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('URL of MSE service'),
          cols: [
            {
              namespace: 'url',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'url')
            }
          ]
        },
        {
          label: i18n.t('Username'),
          text: i18n.t('Username for MSE service.'),
          cols: [
            {
              namespace: 'user',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'user')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('Password for MSE service.'),
          cols: [
            {
              namespace: 'pass',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'pass')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    url: pfConfigurationValidatorsFromMeta(meta, 'url', 'URL'),
    user: pfConfigurationValidatorsFromMeta(meta, 'user', i18n.t('Username')),
    pass: pfConfigurationValidatorsFromMeta(meta, 'pass', i18n.t('Password'))
  }
}
