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

export const importFields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [fieldType.SUBSTRING],
    required: true
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [fieldType.SUBSTRING],
    required: true
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [fieldType.SUBSTRING],
    required: false
  },
  {
    value: 'mode',
    text: i18n.t('Mode'),
    types: [fieldType.SUBSTRING],
    required: false
  }
]
