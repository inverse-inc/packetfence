import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const view = (form = {}, meta = {}) => {
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'domain')
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
              attrs: pfConfigurationAttributesFromMeta(meta, 'hostname')
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
                ...pfConfigurationAttributesFromMeta(meta, 'dhcpservers'),
                ...{
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Timezone'),
          text: i18n.t(`System's timezone in string format. List generated from Perl library DateTime::TimeZone. When left empty, it will use the timezone of the server.`),
          cols: [
            {
              namespace: 'timezone',
              component: pfFormChosen,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'timezone'),
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

export const validators = (form = {}, meta = {}) => {
  return {
    domain: pfConfigurationValidatorsFromMeta(meta, 'domain', i18n.t('Domain')),
    hostname: pfConfigurationValidatorsFromMeta(meta, 'hostname', i18n.t('Hostname')),
    dhcpservers: pfConfigurationValidatorsFromMeta(meta, 'dhcpservers', i18n.t('Servers')),
    timezone: pfConfigurationValidatorsFromMeta(meta, 'timezone', i18n.t('Timezone'))
  }
}
