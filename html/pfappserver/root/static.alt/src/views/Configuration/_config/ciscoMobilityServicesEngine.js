import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: 'Enable MSE', // i18n defer
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
          label: 'URL of MSE service', // i18n defer
          cols: [
            {
              namespace: 'url',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'url')
            }
          ]
        },
        {
          label: 'Username', // i18n defer
          text: i18n.t('Username for MSE service.'),
          cols: [
            {
              namespace: 'user',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'user')
            }
          ]
        },
        {
          label: 'Password', // i18n defer
          text: i18n.t('Password for MSE service.'),
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

export const validators = (form = {}, meta = {}) => {
  return {
    url: validatorsFromMeta(meta, 'url', 'URL'),
    user: validatorsFromMeta(meta, 'user', i18n.t('Username')),
    pass: validatorsFromMeta(meta, 'pass', i18n.t('Password'))
  }
}
