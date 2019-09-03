import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationGeneralViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    }
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Domain'),
          text: i18n.t('Domain name of PacketFence system. Changing this requires to restart haproxy-portal.'),
          fields: [
            {
              key: 'domain',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'domain'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'domain', i18n.t('Domain'))
            }
          ]
        },
        {
          label: i18n.t('Hostname'),
          text: i18n.t('Hostname of PacketFence system. This is concatenated with the domain in Apache rewriting rules and therefore must be resolvable by clients. Changing this requires to restart haproxy-portal.'),
          fields: [
            {
              key: 'hostname',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'hostname'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'hostname', i18n.t('Hostname'))
            }
          ]
        },
        {
          label: i18n.t('DHCP servers'),
          text: i18n.t('Comma-separated list of DHCP servers.'),
          fields: [
            {
              key: 'dhcpservers',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcpservers'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcpservers', i18n.t('Servers'))
            }
          ]
        },
        {
          label: i18n.t('Timezone'),
          text: i18n.t(`System's timezone in string format. List generated from Perl library DataTime::TimeZone. When left empty, it will use the timezone of the server.`),
          fields: [
            {
              key: 'timezone',
              component: pfFormChosen,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'timezone'),
                ...{
                  optionsLimit: 500
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'timezone', i18n.t('Timezone'))
            }
          ]
        }
      ]
    }
  ]
}
