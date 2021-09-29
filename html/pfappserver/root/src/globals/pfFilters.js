import { pfFieldType as fieldType } from '@/globals/pfField'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const pfFilters = {
  connection_sub_type: {
    value: 'connection_sub_type',
    text: i18n.t('Connection Sub Type'),
    types: [fieldType.CONNECTION_SUB_TYPE]
  },
  connection_type: {
    value: 'connection_type',
    text: i18n.t('Connection Type'),
    types: [fieldType.CONNECTION_TYPE]
  },
  network: {
    value: 'network',
    text: i18n.t('Network'),
    types: [fieldType.SUBSTRING]
  },
  node_role: {
    value: 'node_role',
    text: i18n.t('Node role'),
    types: [fieldType.ROLE_BY_NAME]
  },
  port: {
    value: 'port',
    text: i18n.t('Port'),
    types: [fieldType.INTEGER]
  },
  realm: {
    value: 'realm',
    text: i18n.t('Realm'),
    types: [fieldType.REALM],
    props: {
      taggable: true,
      tagPlaceholder: i18n.t('Click to add new Realm')
    }
  },
  ssid: {
    value: 'ssid',
    text: i18n.t('SSID'),
    types: [fieldType.SSID],
    props: {
      taggable: true,
      tagPlaceholder: i18n.t('Click to add new SSID'),
      internalSearch: false,
      caseSensitiveSearch: true
    }
  },
  switch: {
    value: 'switch',
    text: i18n.t('Switch'),
    types: [fieldType.SWITCHE]
  },
  switch_group: {
    value: 'switch_group',
    text: i18n.t('Switch Group'),
    types: [fieldType.SWITCH_GROUP]
  },
  switch_mac: {
    value: 'switch_mac',
    text: i18n.t('Switch MAC'),
    types: [fieldType.SUBSTRING]
  },
  switch_port: {
    value: 'switch_port',
    text: i18n.t('Switch Port'),
    types: [fieldType.SUBSTRING]
  },
  tenant: {
    value: 'tenant',
    text: i18n.t('Tenant'),
    types: [fieldType.TENANT]
  },
  time: {
    value: 'time',
    text: i18n.t('Time period'),
    types: [fieldType.SUBSTRING]
  },
  uri: {
    value: 'uri',
    text: i18n.t('URI'),
    types: [fieldType.SUBSTRING]
  },
  fqdn: {
    value: 'fqdn',
    text: i18n.t('FQDN'),
    types: [fieldType.SUBSTRING]
  },
  vlan: {
    value: 'vlan',
    text: i18n.t('VLAN'),
    types: [fieldType.SUBSTRING]
  }
}

const pfFilterSchema = yup.object({
  type: yup.string().required(i18n.t('Type required.')),
  match: yup.string() //
    .when('type', type => {
      const schema = yup.string().nullable()
        .required(i18n.t('Match required'))
        .max(255)
      switch (true) {
        case type === 'fqdn':
          return schema.isFQDN()
          // break
        case type === 'switch_mac':
          return schema.isMAC()
          // break
        case ['port', 'switch_port'].includes(type):
          return schema.isPort()
          // break
        case type === 'vlan':
          return schema.isVLAN()
          // break
        default:
          return schema
      }
    })
})

export const pfFiltersSchema = yup.array().ensure().unique(i18n.t('Duplicate filter.')).of(pfFilterSchema)
