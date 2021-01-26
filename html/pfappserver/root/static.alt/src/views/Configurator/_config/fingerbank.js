import Vue from 'vue'
import store from '@/store'
import i18n from '@/utils/locale'
import pfButton from '@/components/pfButton'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '@/views/Configuration/_config'
import {
  conditional
} from '@/globals/pfValidators'

export const view = (form = {}, meta = {}) => {
  const {
    account: {
      name
    } = {},
    accountIsInvalid = false,
  } = meta
  const { upstream = {} } = form
  const { api_key = '' } = upstream
  return [
    {
      tab: null, // ignore tabs
      rows: [
        {
          if: !name,
          label: null,
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: `<div class="alert alert-info">
                  <h4 class="alert-heading">${i18n.t('This step is optional')}</h4>
                  ${i18n.t('You can visit the official <a href="{link}" target="_new">registration page</a> to create an account and get an API key.', { link: 'https://api.fingerbank.org/users/register' })}
                  </div>`
              }
            }
          ]
        },
        {
          label: i18n.t('API Key'),
          text: i18n.t('API key to interact with upstream Fingerbank project. Changing this value requires to restart the Fingerbank collector.'),
          cols: [
            {
              namespace: 'upstream.api_key',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'upstream.api_key'),
                stateMap: { false: false, true: name ? true : null },
                readonly: name
              }
            }
          ]
        },
        {
          if: !name,
          label: true, // trick to keep bottom margin in pfConfigView
          cols: [
            {
              component: pfButton,
              attrs: {
                label: i18n.t('Verify'),
                class: 'col-sm-4 col-lg-3 col-xl-2',
                variant: accountIsInvalid ? 'outline-danger' : 'outline-primary',
                disabled: api_key.length === 0
              },
              listeners: {
                click: () => {
                  return store.dispatch('$_fingerbank/setGeneralSettings', { upstream: { ...upstream, quiet: true } }).then(() => {
                    Vue.set(meta, 'accountIsInvalid', false)
                    store.dispatch('$_fingerbank/getAccountInfo').then(info => {
                      Vue.set(meta, 'account', info)
                    })
                  }).catch(() => {
                    Vue.set(meta, 'accountIsInvalid', true)
                  })
                }
              }
            },
            {
              component: pfFormHtml,
              attrs: {
                html: accountIsInvalid ? '<div class="small text-danger p-2">' + i18n.t('Invalid API key') + '</div>' : ''
              }
            }
          ]
        },
        {
          if: name,
          label: true, // trick to keep bottom margin in pfConfigView
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: '<div class="alert alert-info">' + i18n.t('The API key is associated to Github account <b>{name}</b>', { name }) + '</div>'
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  const {
    account = null
  } = meta
  return {
    upstream: {
      api_key: validatorsFromMeta(meta, 'upstream.api_key', i18n.t('Key'))
    },
    api_key_is_registered: {
      [i18n.t('No valid API key specified.')]: conditional(account !== null)
    }
  }
}
