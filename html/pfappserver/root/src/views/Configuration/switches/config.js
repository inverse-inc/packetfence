import i18n from '@/utils/locale'
import { pfFieldType as fieldType } from '@/globals/pfField'

export const inlineTriggers = {
  always: {
    value: 'always',
    text: i18n.t('Always'),
    types: [fieldType.NONE]
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [fieldType.INTEGER]
  },
  mac: {
    value: 'mac',
    text: i18n.t('MAC Address'),
    types: [fieldType.SUBSTRING]
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('Wi-Fi Network SSID'),
    types: [fieldType.SUBSTRING]
  }
}
