/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import i18n from '@/utils/locale'

export const pfFieldType = {
  NONE:                    'none',
  INTEGER:                 'integer',
  SUBSTRING:               'substring',
  CONNECTION_TYPE:         'connection_type',
  CONNECTION_SUB_TYPE:     'connection_sub_type',
  DATE:                    'date',
  DATETIME:                'datetime',
  GENDER:                  'gender',
  PREFIXMULTIPLIER:        'prefixmultiplier',
  SELECTMANY:              'selectmany',
  TIME_BALANCE:            'time_balance',
  YESNO:                   'yesno',

  /* Promise based field types */
  ADMINROLE:               'adminrole',
  DURATION:                'duration',
  OPTIONS:                 'options',
  REALM:                   'realm',
  ROLE:                    'role',
  ROLE_BY_NAME:            'role_by_name',
  SOURCE:                  'source',
  SWITCHE:                 'switche',
  SWITCH_GROUP:            'switch_group',
  TENANT:                  'tenant'
}

export const pfFieldTypeValues = {}

pfFieldTypeValues[pfFieldType.ADMINROLE] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.ADMINROLE](context)')
  }
  $store.dispatch('config/getAdminRoles')
  return $store.getters['config/adminRolesList']
}
pfFieldTypeValues[pfFieldType.DURATION] = ({ $store }) => {
  $store.dispatch('config/getBaseGuestsAdminRegistration')
  return $store.getters['config/accessDurationsList']
}
pfFieldTypeValues[pfFieldType.OPTIONS] = ({ field }) => {
  let options = []
  if (field === undefined) {
    throw new Error('Missing `field` in pfFieldTypeValues[pfFieldType.OPTIONS](context)')
  }
  if (field.options) {
    options = field.options.map(o => {
      // pfFieldType uses the 'name' attribute as the label.
      const { text } = o
      if (text) {
        o.name = text
      }
      return o
    })
  }
  return options
}
pfFieldTypeValues[pfFieldType.REALM] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.REALM](context)')
  }
  $store.dispatch('config/getRealms')
  return $store.getters['config/realmsList']
}
pfFieldTypeValues[pfFieldType.ROLE] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.ROLE](context)')
  }
  $store.dispatch('config/getRoles')
  return $store.getters['config/rolesList']
}
pfFieldTypeValues[pfFieldType.ROLE_BY_NAME] = (context = {}) => {
  const { $store } = context
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.ROLE_BY_NAME](context)')
  }
  $store.dispatch('config/getRoles')
  return pfFieldTypeValues[pfFieldType.ROLE](context).map(role => { return { value: role.name, name: role.name } })
}
pfFieldTypeValues[pfFieldType.SOURCE] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.SOURCE](context)')
  }
  $store.dispatch('config/getSources')
  return $store.getters['config/sourcesList']
}
pfFieldTypeValues[pfFieldType.SWITCHE] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.SWITCHE](context)')
  }
  $store.dispatch('config/getSwitches')
  return $store.getters['config/switchesList']
}
pfFieldTypeValues[pfFieldType.SWITCH_GROUP] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.SWITCH_GROUP](context)')
  }
  $store.dispatch('config/getSwitchGroups')
  return $store.getters['config/switchGroupsList']
}
pfFieldTypeValues[pfFieldType.TENANT] = ({ $store }) => {
  if ($store === undefined) {
    throw new Error('Missing `$store` in pfFieldTypeValues[pfFieldType.TENANT](context)')
  }
  $store.dispatch('config/getTenants')
  return $store.getters['config/tenantsList']
}
pfFieldTypeValues[pfFieldType.CONNECTION_TYPE] = () => {
  return [
    { name: 'Wireless-802.11-NoEAP', value: 'Wireless-802.11-NoEAP' },
    { name: 'Ethernet-Web-Auth', value: 'Ethernet-Web-Auth' },
    { name: 'SNMP-Traps', value: 'SNMP-Traps' },
    { name: 'Inline', value: 'Inline' },
    { name: 'Ethernet-EAP', value: 'Ethernet-EAP' },
    { name: 'Ethernet-NoEAP', value: 'Ethernet-NoEAP' },
    { name: 'Wireless-Web-Auth', value: 'Wireless-Web-Auth' },
    { name: 'Wireless-802.11-EAP', value: 'Wireless-802.11-EAP' }
  ]
}
pfFieldTypeValues[pfFieldType.CONNECTION_SUB_TYPE] = () => {
  return [
    { name: 'AKA', value: 'AKA' },
    { name: 'AirFortress-EAP', value: 'AirFortress-EAP' },
    { name: 'Arcot-Systems-EAP', value: 'Arcot-Systems-EAP' },
    { name: 'Base', value: 'Base' },
    { name: 'CRYPTOCard', value: 'CRYPTOCard' },
    { name: 'Cisco-LEAP', value: 'Cisco-LEAP' },
    { name: 'Cisco-MS-CHAPv2', value: 'Cisco-MS-CHAPv2' },
    { name: 'Cogent-Biomentric-EAP', value: 'Cogent-Biomentric-EAP' },
    { name: 'DSS-Unilateral', value: 'DSS-Unilateral' },
    { name: 'Defender-Token', value: 'Defender-Token' },
    { name: 'DeviceConnect-EAP', value: 'DeviceConnect-EAP' },
    { name: 'DynamID', value: 'DynamID' },
    { name: 'EAP-3Com-Wireless', value: 'EAP-3Com-Wireless' },
    { name: 'EAP-AKA2', value: 'EAP-AKA2' },
    { name: 'EAP-Actiontec-Wireless', value: 'EAP-Actiontec-Wireless' },
    { name: 'EAP-EVEv1', value: 'EAP-EVEv1' },
    { name: 'EAP-FAST', value: 'EAP-FAST' },
    { name: 'EAP-GPSK', value: 'EAP-GPSK' },
    { name: 'EAP-HTTP-Digest', value: 'EAP-HTTP-Digest' },
    { name: 'EAP-IKEv2', value: 'EAP-IKEv2' },
    { name: 'EAP-Link', value: 'EAP-Link' },
    { name: 'EAP-MOBAC', value: 'EAP-MOBAC' },
    { name: 'EAP-MSCHAP-V2', value: 'EAP-MSCHAP-V2' },
    { name: 'EAP-PAX', value: 'EAP-PAX' },
    { name: 'EAP-PSK', value: 'EAP-PSK' },
    { name: 'EAP-PWD', value: 'EAP-PWD' },
    { name: 'EAP-SAKE', value: 'EAP-SAKE' },
    { name: 'EAP-SPEKE', value: 'EAP-SPEKE' },
    { name: 'EAP-TLS', value: 'EAP-TLS' },
    { name: 'EAP-TTLS', value: 'EAP-TTLS' },
    { name: 'Generic-Token-Card', value: 'Generic-Token-Card' },
    { name: 'Identity', value: 'Identity' },
    { name: 'KEA', value: 'KEA' },
    { name: 'KEA-Validate', value: 'KEA-Validate' },
    { name: 'MAKE', value: 'MAKE' },
    { name: 'MD5-Challenge', value: 'MD5-Challenge' },
    { name: 'MS-Authentication-TLV', value: 'MS-Authentication-TLV' },
    { name: 'MS-CHAP-V2', value: 'MS-CHAP-V2' },
    { name: 'MS-EAP-Authentication', value: 'MS-EAP-Authentication' },
    { name: 'Microsoft-MS-CHAPv2', value: 'Microsoft-MS-CHAPv2' },
    { name: 'NAK', value: 'NAK' },
    { name: 'Nokia-IP-Smart-Card', value: 'Nokia-IP-Smart-Card' },
    { name: 'None', value: 'None' },
    { name: 'Notification', value: 'Notification' },
    { name: 'One-Time-Password', value: 'One-Time-Password' },
    { name: 'PEAP', value: 'PEAP' },
    { name: 'RSA-Public-Key', value: 'RSA-Public-Key' },
    { name: 'RSA-SecurID-EAP', value: 'RSA-SecurID-EAP' },
    { name: 'Remote-Access-Service', value: 'Remote-Access-Service' },
    { name: 'Rob-EAP', value: 'Rob-EAP' },
    { name: 'SIM', value: 'SIM' },
    { name: 'SRP-SHA1', value: 'SRP-SHA1' },
    { name: 'SecurID-EAP', value: 'SecurID-EAP' },
    { name: 'SecuriSuite-EAP', value: 'SecuriSuite-EAP' },
    { name: 'SentriNET', value: 'SentriNET' },
    { name: 'VALUE', value: 'VALUE' },
    { name: 'Zonelabs', value: 'Zonelabs' }
  ]
}
pfFieldTypeValues[pfFieldType.GENDER] = () => {
  return [
    { name: i18n.t('Male'), value: 'm' },
    { name: i18n.t('Female'), value: 'f' },
    { name: i18n.t('Other'), value: 'o' }
  ]
}
pfFieldTypeValues[pfFieldType.TIME_BALANCE] = () => {
  return [
    { name: i18n.t('1 hour'), value: '1h' },
    { name: i18n.t('3 hours'), value: '3h' },
    { name: i18n.t('12 hours'), value: '12h' },
    { name: i18n.t('1 day'), value: '1D' },
    { name: i18n.t('2 days'), value: '2D' },
    { name: i18n.t('3 days'), value: '3D' },
    { name: i18n.t('5 days'), value: '5D' }
  ]
}
pfFieldTypeValues[pfFieldType.YESNO] = () => {
  return [
    { name: i18n.t('Yes'), value: 'yes' },
    { name: i18n.t('No'), value: 'no' }
  ]
}
