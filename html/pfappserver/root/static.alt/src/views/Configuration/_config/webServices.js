import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

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
              attrs: attributesFromMeta(meta, 'user')
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
              attrs: attributesFromMeta(meta, 'pass')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  return {
    user: validatorsFromMeta(meta, 'user', i18n.t('Username')),
    pass: validatorsFromMeta(meta, 'pass', i18n.t('Password'))
  }
}
