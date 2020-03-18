import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
// import {
//   attributesFromMeta,
//   validatorsFromMeta
// } from '@/views/Configuration/_config'
import {
  required
} from 'vuelidate/lib/validators'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Username'),
          text: i18n.t('Administrator username.'),
          cols: [
            {
              namespace: 'administrator.pid',
              component: pfFormInput,
              // attrs: attributesFromMeta(meta, 'pid')
            }
          ]
        },
        {
          label: i18n.t('Password'),
          cols: [
            {
              namespace: 'administrator.password',
              component: pfFormPassword,
              attrs: {
                generate: true
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = () => {
  return {
    administrator: {
      pid: {
        [i18n.t('Username must be defined.')]: required
      },
      password: {
        [i18n.t('Password must be defined.')]: required
      }
    }
  }
}
