import i18n from '@/utils/locale'
import { pfFieldType } from '@/globals/pfField'

export const filters = {
  connection_sub_type: {
    value: 'connection_sub_type',
    text: i18n.t('Connection Sub Type'),
    types: [pfFieldType.CONNECTION_SUB_TYPE]
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection Type'),
    types: [pfFieldType.CONNECTION_TYPE]
  },
  network: {
    value: 'network',
    text: i18n.t('Network'),
    types: [pfFieldType.SUBSTRING]
  },
  node_role: {
    value: 'node_role',
    text: i18n.t('Node role'),
    types: [pfFieldType.ROLE_BY_NAME]
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [pfFieldType.INTEGER]
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [pfFieldType.REALM],
    props: {
      taggable: true,
      tagPlaceholder: i18n.t('Click to add new Realm')
    }
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('SSID'),
    types: [pfFieldType.SSID],
    props: {
      taggable: true,
      tagPlaceholder: i18n.t('Click to add new SSID')
    }
  },
  switch: {
    value: 'switch',
    text: i18n.t('Switch'),
    types: [pfFieldType.SWITCHE]
  },
  switch_group: {
    value: 'switch_group',
    text: i18n.t('Switch Group'),
    types: [pfFieldType.SWITCH_GROUP]
  },
  switch_mac: {
    value: 'switch_mac',
    text: i18n.t('Switch MAC'),
    types: [pfFieldType.SUBSTRING]
  },
  switch_port: {
    value: 'switch_port',
    text: i18n.t('Switch Port'),
    types: [pfFieldType.SUBSTRING]
  },
  tenant: {
    value: 'tenant',
    text: i18n.t('Tenant'),
    types: [pfFieldType.TENANT]
  },
  time: {
    value: 'time',
    text: i18n.t('Time period'),
    types: [pfFieldType.SUBSTRING]
  },
  uri: {
    value: 'uri',
    text: i18n.t('URI'),
    types: [pfFieldType.SUBSTRING]
  },
  fqdn: {
    value: 'fqdn',
    text: i18n.t('FQDN'),
    types: [pfFieldType.SUBSTRING]
  },
  vlan: {
    value: 'vlan',
    text: i18n.t('VLAN'),
    types: [pfFieldType.SUBSTRING]
  }
}
