import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const view = (form, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Username'),
          text: i18n.t('The webservices user name.'),
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
          text: i18n.t('The webservices password.'),
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

export const validators = (form, meta = {}) => {
  return {
    user: pfConfigurationValidatorsFromMeta(meta, 'user', i18n.t('Username')),
    pass: pfConfigurationValidatorsFromMeta(meta, 'pass', i18n.t('Password'))
  }
}
