import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
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
          label: i18n.t('Bounce duration'),
          text: i18n.t('Delay to wait between the shut / no-shut on a port. Some OS need a higher value than others. Default should be reasonable for almost every OS but is too long for the usual proprietary OS.'),
          cols: [
            {
              namespace: 'bounce_duration.interval',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'bounce_duration.interval')
            },
            {
              namespace: 'bounce_duration.unit',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'bounce_duration.unit')
            }
          ]
        },
        {
          label: i18n.t('Trap limiting'),
          text: i18n.t('Controls whether or not the trap limit feature is enabled. Trap limiting is a way to limit the damage done by malicious users or misbehaving switch that sends too many traps to PacketFence causing it to be overloaded. Trap limiting is controlled by the trap limit threshold and trap limit action parameters. Default is enabled.'),
          cols: [
            {
              namespace: 'trap_limit',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Trap limiting threshold'),
          text: i18n.t('Maximum number of SNMP traps that a switchport can send to PacketFence within a minute without being flagged as DoS. Defaults to 100.'),
          cols: [
            {
              namespace: 'trap_limit_threshold',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'trap_limit_threshold')
            }
          ]
        },
        {
          label: i18n.t('Trap limit action'),
          text: i18n.t(`Action that PacketFence will take if the snmp_traps.trap_limit_threshold is reached. Defaults to none. Email will send an email every hour if the limit's still reached. shut will shut the port on the switch and will also send an email even if email is not specified.`),
          cols: [
            {
              namespace: 'trap_limit_action',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'trap_limit_action')
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (_, meta = {}) => {
  return {
    bounce_duration: {
      interval: validatorsFromMeta(meta, 'bounce_duration.interval', i18n.t('Interval')),
      unit: validatorsFromMeta(meta, 'bounce_duration.unit', i18n.t('Unit'))
    },
    trap_limit_threshold: validatorsFromMeta(meta, 'trap_limit_threshold', i18n.t('Limit')),
    trap_limit_action: validatorsFromMeta(meta, 'trap_limit_action', i18n.t('Action'))
  }
}
