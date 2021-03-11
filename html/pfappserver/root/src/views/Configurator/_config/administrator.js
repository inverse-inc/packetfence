import store from '@/store'
import i18n from '@/utils/locale'
import pfButton from '@/components/pfButton'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import {
  required
} from 'vuelidate/lib/validators'

export const view = (form = {}) => {
  let {
    administrator: {
      password = ''
    } = {}
  } = form
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
        },
        {
          if: password,
          label: true, // trick to keep bottom margin in pfConfigView
          cols: [
            {
              component: pfButton,
              attrs: {
                label: i18n.t('Copy to Clipboard'),
                class: 'col-sm-7 col-lg-5 col-xl-4',
                variant: 'outline-primary'
              },
              listeners: {
                click: () => {
                  try {
                    navigator.clipboard.writeText(password).then(() => {
                      store.dispatch('notification/info', { message: i18n.t('Password copied to clipboard') })
                    }).catch(() => {
                      store.dispatch('notification/danger', { message: i18n.t('Could not copy password to clipboard.') })
                    })
                  } catch (e) {
                    store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
                  }
                }
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
