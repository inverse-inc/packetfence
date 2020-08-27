import i18n from '@/utils/locale'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import {
  integer,
  minValue
} from 'vuelidate/lib/validators'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Accounting'),
          text: i18n.t('Should we handle accouting data for inline clients? This controls inline accouting tasks in pfcron.'),
          cols: [
            {
              namespace: 'accounting',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Accounting session timeout'),
          text: i18n.t(`Accounting sessions created by pfbandwidthd that haven't been updated for more than this amount of seconds will be considered inactive. This should be higher than the interval at which pfcron runs Defaults to 300 - 5 minutes.`),
          cols: [
            {
              namespace: 'layer3_accounting_session_timeout',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'layer3_accounting_session_timeout')
            }
          ]
        },
        {
          label: i18n.t('Accounting sync interval'),
          text: i18n.t('Interval at which pfbandwidthd should dump collected information into the database. This should be lower than the interval at which pfcron runs. Defaults to 41 seconds.'),
          cols: [
            {
              namespace: 'layer3_accounting_sync_interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'layer3_accounting_sync_interval')
            }
          ]
        },
        {
          label: i18n.t('Ports redirect'),
          text: i18n.t(`Ports to intercept and redirect for trapped and unregistered systems. Defaults to 80/tcp (HTTP), 443/tcp (HTTPS). Redirecting 443/tcp (SSL) will work, although users might get certificate errors if you didn't install a valid certificate or if you don't use DNS (although IP-based certificates supposedly exist). Redirecting 53/udp (DNS) seems to have issues and is also not recommended.`),
          cols: [
            {
              namespace: 'ports_redirect',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ports_redirect')
            }
          ]
        },
        {
          label: i18n.t('Reauthenticate node'),
          text: i18n.t('Should have to reauthenticate the node if vlan change.'),
          cols: [
            {
              namespace: 'should_reauth_on_vlan_change',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('SNAT Interface'),
          text: i18n.t('Comma-separated list of interfaces used to SNAT inline level 2 traffic.'),
          cols: [
            {
              namespace: 'interfaceSNAT',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'interfaceSNAT'),
                ...{
                  rows: 3
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
    layer3_accounting_session_timeout: {
      ...validatorsFromMeta(meta, 'layer3_accounting_session_timeout', i18n.t('Timeout')),
      ...{
        [i18n.t('Must be numeric')]: integer,
        [i18n.t('Minimum {minValue}', { minValue: 1 })]: minValue(1)
      }
    },
    layer3_accounting_sync_interval: {
      ...validatorsFromMeta(meta, 'layer3_accounting_sync_interval', i18n.t('Interval')),
      ...{
        [i18n.t('Must be numeric')]: integer,
        [i18n.t('Minimum {minValue}', { minValue: 1 })]: minValue(1)
      }
    },
    ports_redirect: validatorsFromMeta(meta, 'ports_redirect', i18n.t('Ports')),
    interfaceSNAT: validatorsFromMeta(meta, 'interfaceSNAT', i18n.t('Interfaces'))
  }
}
