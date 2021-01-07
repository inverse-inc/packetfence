import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
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
          label: i18n.t('Domain'),
          text: i18n.t('Domain name of PacketFence system. Changing this requires to restart haproxy-portal.'),
          cols: [
            {
              namespace: 'domain',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'domain')
            }
          ]
        },
        {
          label: i18n.t('Hostname'),
          text: i18n.t('Hostname of PacketFence system. This is concatenated with the domain in Apache rewriting rules and therefore must be resolvable by clients. Changing this requires to restart haproxy-portal.'),
          cols: [
            {
              namespace: 'hostname',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'hostname')
            }
          ]
        },
        {
          label: i18n.t('DHCP servers'),
          text: i18n.t('Comma-separated list of DHCP servers.'),
          cols: [
            {
              namespace: 'dhcpservers',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'dhcpservers'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Timezone'),
          text: i18n.t(`System's timezone in string format. List generated from Perl library DateTime::TimeZone. When left empty, it will use the timezone of the server. You will need to reboot the server after changing this setting.`),
          cols: [
            {
              namespace: 'timezone',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'timezone'),
                ...{
                  optionsLimit: 500
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  return {
    domain: validatorsFromMeta(meta, 'domain', i18n.t('Domain')),
    hostname: validatorsFromMeta(meta, 'hostname', i18n.t('Hostname')),
    dhcpservers: validatorsFromMeta(meta, 'dhcpservers', i18n.t('Servers')),
    timezone: validatorsFromMeta(meta, 'timezone', i18n.t('Timezone'))
  }
}
