import i18n from '@/utils/locale'
import pfButtonService from '@/components/pfButtonService'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '@/views/Configuration/_config'

export const view = (form, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Domain'),
          text: i18n.t('Domain name of PacketFence system.'),
          cols: [
            {
              namespace: 'general.domain',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'general.domain')
            }
          ]
        },
        {
          label: i18n.t('Hostname'),
          text: i18n.t('Hostname of PacketFence system. This is concatenated with the domain in Apache rewriting rules and therefore must be resolvable by clients. Changing this requires to restart haproxy-portal.'),
          cols: [
            {
              namespace: 'general.hostname',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'general.hostname')
            }
          ]
        },
        {
          label: i18n.t('Timezone'),
          text: i18n.t(`System's timezone in string format. List generated from Perl library DateTime::TimeZone. When left empty, it will use the timezone of the server.`),
          cols: [
            {
              namespace: 'general.timezone',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'general.timezone'),
                ...{
                  optionsLimit: 500
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Track Configuration'),
          text: i18n.t('This service will track all changes to the configuration. Notice that the content of all files (except domain.conf) under /usr/local/pf/conf will be tracked, including passwords.'),
          cols: [
            {
              component: pfButtonService,
              attrs: {
                service: 'tracking-config',
                'hide-details': true,
                start: true,
                stop: true,
                class: 'px-0 col-md-7 col-lg-5 col-xl-4'
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form, meta = {}) => {
  return {
    general: {
      domain: validatorsFromMeta(meta, 'general.domain', i18n.t('Domain')),
      hostname: validatorsFromMeta(meta, 'general.hostname', i18n.t('Hostname')),
      timezone: validatorsFromMeta(meta, 'general.timezone', i18n.t('Timezone'))
    }
  }
}
