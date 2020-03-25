import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  required
} from 'vuelidate/lib/validators'

export const view = () => {
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
              attrs: {
                readonly: true
              }
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
      password: {
        [i18n.t('Password must be defined.')]: required
      }
    }
  }
}
