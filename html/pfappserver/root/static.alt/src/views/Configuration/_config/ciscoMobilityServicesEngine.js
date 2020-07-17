import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const view = (_, meta = {}) => {
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
              attrs: attributesFromMeta(meta, 'url')
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
              attrs: attributesFromMeta(meta, 'user')
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
              attrs: attributesFromMeta(meta, 'pass')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  return {
    url: validatorsFromMeta(meta, 'url', 'URL'),
    user: validatorsFromMeta(meta, 'user', i18n.t('Username')),
    pass: validatorsFromMeta(meta, 'pass', i18n.t('Password'))
  }
}
