import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationWebServicesViewFields = (context = {}) => {
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
          label: i18n.t('Username'),
          text: i18n.t('The webservices user name.'),
          fields: [
            {
              key: 'user',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'user'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'user', 'Username')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          text: i18n.t('The webservices password.'),
          fields: [
            {
              key: 'pass',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'pass'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'pass', 'Password')
            }
          ]
        }
      ]
    }
  ]
}
