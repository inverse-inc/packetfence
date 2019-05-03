import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

const {
  integer,
  minValue
} = require('vuelidate/lib/validators')

export const pfConfigurationInlineViewFields = (context = {}) => {
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
          label: i18n.t('Accounting'),
          text: i18n.t('Should we handle accouting data for inline clients? This controls inline accouting tasks in pfmon.'),
          fields: [
            {
              key: 'accounting',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Accounting session timeout'),
          text: i18n.t(`Accounting sessions created by pfbandwidthd that haven't been updated for more than this amount of seconds will be considered inactive. This should be higher than the interval at which pfmon runs Defaults to 300 - 5 minutes.`),
          fields: [
            {
              key: 'layer3_accounting_session_timeout',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'layer3_accounting_session_timeout'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'layer3_accounting_session_timeout', 'Timeout'),
                ...{
                  [i18n.t('Must be numeric')]: integer,
                  [i18n.t('Minimum {minValue}', { minValue: 1 })]: minValue(1)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Accounting sync interval'),
          text: i18n.t('Interval at which pfbandwidthd should dump collected information into the database. This should be lower than the interval at which pfmon runs. Defaults to 41 seconds.'),
          fields: [
            {
              key: 'layer3_accounting_sync_interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'layer3_accounting_sync_interval'),
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'layer3_accounting_sync_interval', 'Interval'),
                ...{
                  [i18n.t('Must be numeric')]: integer,
                  [i18n.t('Minimum {minValue}', { minValue: 1 })]: minValue(1)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Ports redirect'),
          text: i18n.t(`Ports to intercept and redirect for trapped and unregistered systems. Defaults to 80/tcp (HTTP), 443/tcp (HTTPS). Redirecting 443/tcp (SSL) will work, although users might get certificate errors if you didn't install a valid certificate or if you don't use DNS (although IP-based certificates supposedly exist). Redirecting 53/udp (DNS) seems to have issues and is also not recommended.`),
          fields: [
            {
              key: 'ports_redirect',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ports_redirect'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ports_redirect', 'Ports')
            }
          ]
        },
        {
          label: i18n.t('Reauthenticate node'),
          text: i18n.t('Should have to reauthenticate the node if vlan change.'),
          fields: [
            {
              key: 'should_reauth_on_vlan_change',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('SNAT Interface'),
          text: i18n.t('Comma-delimited list of interfaces used to SNAT inline level 2 traffic.'),
          fields: [
            {
              key: 'interfaceSNAT',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'interfaceSNAT'),
                ...{
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'interfaceSNAT', 'Interfaces')
            }
          ]
        }
      ]
    }
  ]
}
