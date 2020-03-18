import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '@/views/Configuration/_config'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          label: i18n.t('API Key'),
          text: i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.'),
          cols: [
            {
              namespace: 'upstream.api_key',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'upstream.api_key')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    upstream: {
      api_key: validatorsFromMeta(meta, 'upstream.api_key', i18n.t('Key'))
    }
  }
}
