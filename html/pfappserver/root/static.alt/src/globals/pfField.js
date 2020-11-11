/* eslint key-spacing: ["error", { "mode": "minimum" }] */
import store from '@/store'
import i18n from '@/utils/locale'

export const pfComponentType = {
  NONE:                                'none',
  DATE:                                'date',
  DATETIME:                            'datetime',
  HIDDEN:                              'hidden',
  INTEGER:                             'integer',
  PREFIXMULTIPLIER:                    'prefixmultiplier',
  SELECTONE:                           'selectone',
  SELECTMANY:                          'selectmany',
  SUBSTRING:                           'substring',
  TOGGLE:                              'toggle',
  TIME:                                'time'
}

export const pfFieldType = {
  /* Static field types */
  NONE:                                'none',
  INTEGER:                             'integer',
  SUBSTRING:                           'substring',
  CONNECTION:                          'connection',
  CONNECTION_TYPE:                     'connection_type',
  CONNECTION_SUB_TYPE:                 'connection_sub_type',
  DATE:                                'date',
  DATETIME:                            'datetime',
  GENDER:                              'gender',
  HIDDEN:                              'hidden',
  NODE_STATUS:                         'node_status',
  LDAPATTRIBUTE:                       'ldapattribute',
  LDAPFILTER:                          'ldapfilter',
  PREFIXMULTIPLIER:                    'prefixmultiplier',
  RADIUSATTRIBUTE:                     'radiusattribute',
  SELECTONE:                           'selectone',
  SELECTMANY:                          'selectmany',
  TIME_BALANCE:                        'time_balance',
  YESNO:                               'yesno',
  URL:                                 'substring',

  /* Promise field types */
  ADMINROLE:                           'adminrole',
  ADMINROLE_BY_ACL_USER:               'adminrole_by_acl_user',
  DURATION:                            'duration',
  DURATION_BY_ACL_USER:                'duration_by_acl_user',
  DURATIONS:                           'durations',
  OPTIONS:                             'options',
  REALM:                               'realm',
  ROLE:                                'role',
  ROLE_BY_NAME:                        'role_by_name',
  ROLE_BY_ACL_NODE:                    'role_by_acl_node',
  ROLE_BY_ACL_USER:                    'role_by_acl_user',
  ROOT_PORTAL_MODULE:                  'root_portal_module',
  SOURCE:                              'source',
  SSID:                                'ssid',
  SWITCHE:                             'switche',
  SWITCH_GROUP:                        'switch_group',
  TENANT:                              'tenant',
  TIME:                                'time',
  TIME_PERIOD:                         'time_period'
}

export const pfFieldTypeComponent = {
  /* native component types */
  [pfFieldType.NONE]:                  pfComponentType.NONE,
  [pfFieldType.DATE]:                  pfComponentType.DATE,
  [pfFieldType.DATETIME]:              pfComponentType.DATETIME,
  [pfFieldType.HIDDEN]:                pfComponentType.HIDDEN,
  [pfFieldType.INTEGER]:               pfComponentType.INTEGER,
  [pfFieldType.PREFIXMULTIPLIER]:      pfComponentType.PREFIXMULTIPLIER,
  [pfFieldType.SELECTONE]:             pfComponentType.SELECTONE,
  [pfFieldType.SELECTMANY]:            pfComponentType.SELECTMANY,
  [pfFieldType.SUBSTRING]:             pfComponentType.SUBSTRING,
  [pfFieldType.TOGGLE]:                pfComponentType.TOGGLE,

  /* additional component types */
  [pfFieldType.ADMINROLE]:             pfComponentType.SELECTMANY,
  [pfFieldType.ADMINROLE_BY_ACL_USER]: pfComponentType.SELECTMANY,
  [pfFieldType.CONNECTION]:            pfComponentType.SELECTONE,
  [pfFieldType.CONNECTION_TYPE]:       pfComponentType.SELECTONE,
  [pfFieldType.CONNECTION_SUB_TYPE]:   pfComponentType.SELECTONE,
  [pfFieldType.DURATION]:              pfComponentType.SELECTONE,
  [pfFieldType.DURATION_BY_ACL_USER]:  pfComponentType.SELECTONE,
  [pfFieldType.DURATIONS]:             pfComponentType.SELECTMANY,
  [pfFieldType.GENDER]:                pfComponentType.SELECTONE,
  [pfFieldType.LDAPATTRIBUTE]:         pfComponentType.SUBSTRING,
  [pfFieldType.LDAPFILTER]:            pfComponentType.SUBSTRING,
  [pfFieldType.NODE_STATUS]:           pfComponentType.SELECTONE,
  [pfFieldType.OPTIONS]:               pfComponentType.SELECTONE,
  [pfFieldType.RADIUSATTRIBUTE]:       pfComponentType.SUBSTRING,
  [pfFieldType.REALM]:                 pfComponentType.SELECTONE,
  [pfFieldType.ROLE]:                  pfComponentType.SELECTONE,
  [pfFieldType.ROLE_BY_NAME]:          pfComponentType.SELECTONE,
  [pfFieldType.ROLE_BY_ACL_NODE]:      pfComponentType.SELECTONE,
  [pfFieldType.ROLE_BY_ACL_USER]:      pfComponentType.SELECTONE,
  [pfFieldType.ROOT_PORTAL_MODULE]:    pfComponentType.SELECTONE,
  [pfFieldType.SOURCE]:                pfComponentType.SELECTONE,
  [pfFieldType.SSID]:                  pfComponentType.SELECTONE,
  [pfFieldType.SWITCHE]:               pfComponentType.SELECTONE,
  [pfFieldType.SWITCH_GROUP]:          pfComponentType.SELECTONE,
  [pfFieldType.TENANT]:                pfComponentType.SELECTONE,
  [pfFieldType.TIME]:                  pfComponentType.TIME,
  [pfFieldType.TIME_BALANCE]:          pfComponentType.SELECTONE,
  [pfFieldType.TIME_PERIOD]:           pfComponentType.SUBSTRING,
  [pfFieldType.URL]:                   pfComponentType.SUBSTRING,
  [pfFieldType.YESNO]:                 pfComponentType.TOGGLE
}

export const pfFieldTypeOperators = {
  [pfFieldType.CONNECTION]: [
    { text: 'is', value: 'is' },
    { text: 'is not', value: 'is not' }
  ],
  [pfFieldType.LDAPATTRIBUTE]: [
    { text: 'is', value: 'is' },
    { text: 'starts', value: 'starts' },
    { text: 'equals', value: 'equals' },
    { text: 'not_equals', value: 'not_equals' },
    { text: 'contains', value: 'contains' },
    { text: 'ends', value: 'ends' },
    { text: 'matches regexp', value: 'matches regexp' },
    { text: 'is member of', value: 'is member of' }
  ],
  [pfFieldType.LDAPFILTER]: [
    { text: 'match filter', value: 'match filter' }
  ],
  [pfFieldType.SUBSTRING]: [
    { text: 'starts', value: 'starts' },
    { text: 'equals', value: 'equals' },
    { text: 'contains', value: 'contains' },
    { text: 'ends', value: 'ends' },
    { text: 'matches regexp', value: 'matches regexp' }
  ],
  [pfFieldType.TIME]: [
    { text: 'is before', value: 'is before' },
    { text: 'is after', value: 'is after' }
  ],
  [pfFieldType.TIME_PERIOD]: [
    { text: 'in_time_period', value: 'in_time_period' }
  ]
}

export const pfFieldTypeValues = {
  [pfFieldType.ADMINROLE]: () => {
    store.dispatch('config/getAdminRoles')
    return store.getters['config/adminRolesList']
  },
  [pfFieldType.ADMINROLE_BY_ACL_USER]: () => {
    store.dispatch('session/getAllowedUserAccessLevels')
    return store.getters['session/allowedUserAccessLevelsList']
  },
  [pfFieldType.CONNECTION]: () => {
    return [
      {
        group: i18n.t('Types'),
        items: [
          { value: 'Ethernet-EAP', text: 'Ethernet-EAP' },
          { value: 'Ethernet-NoEAP', text: 'Ethernet-NoEAP' },
          { value: 'Ethernet-Web-Auth', text: 'Ethernet-Web-Auth' },
          { value: 'Inline', text: 'Inline' },
          { value: 'SNMP-Traps', text: 'SNMP-Traps' },
          { value: 'Wireless-802.11-EAP', text: 'Wireless-802.11-EAP' },
          { value: 'Wireless-802.11-NoEAP', text: 'Wireless-802.11-NoEAP' },
          { value: 'Wireless-Web-Auth', text: 'Wireless-Web-Auth' }
        ]
      },
      {
        group: i18n.t('Groups'),
        items: [
          { value: 'EAP', text: 'EAP' },
          { value: 'Ethernet', text: 'Ethernet' },
          { value: 'Web-Auth', text: 'Web-Auth' },
          { value: 'Wireless', text: 'Wireless' }
        ]
      }
    ]
  },
  [pfFieldType.CONNECTION_TYPE]: () => {
    return [
      { name: 'Wireless-802.11-NoEAP', value: 'Wireless-802.11-NoEAP' },
      { name: 'Ethernet-Web-Auth', value: 'Ethernet-Web-Auth' },
      { name: 'SNMP-Traps', value: 'SNMP-Traps' },
      { name: 'Inline', value: 'Inline' },
      { name: 'Ethernet-EAP', value: 'Ethernet-EAP' },
      { name: 'Ethernet-NoEAP', value: 'Ethernet-NoEAP' },
      { name: 'Wireless-Web-Auth', value: 'Wireless-Web-Auth' },
      { name: 'Wireless-802.11-EAP', value: 'Wireless-802.11-EAP' },
      { name: 'VPN-Access', value: 'VPN-Access' },
      { name: 'CLI-Access', value: 'CLI-Access' }
    ]
  },
  [pfFieldType.CONNECTION_SUB_TYPE]: () => {
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
  },
  [pfFieldType.GENDER]: () => {
    return [
      { name: i18n.t('Male'), value: 'm' },
      { name: i18n.t('Female'), value: 'f' },
      { name: i18n.t('Other'), value: 'o' }
    ]
  },
  [pfFieldType.NODE_STATUS]: () => {
    return [
      { name: i18n.t('Registered'), value: 'reg' },
      { name: i18n.t('Unregistered'), value: 'unreg' },
      { name: i18n.t('Pending'), value: 'pending' }
    ]
  },
  [pfFieldType.DURATION]: () => {
    store.dispatch('config/getBaseGuestsAdminRegistration')
    return store.getters['config/accessDurationsList']
  },
  [pfFieldType.DURATION_BY_ACL_USER]: () => {
    store.dispatch('session/getAllowedUserAccessDurations')
    return store.getters['session/allowedUserAccessDurationsList']
  },
  [pfFieldType.DURATIONS]: () => {
    store.dispatch('config/getBaseGuestsAdminRegistration')
    return store.getters['config/accessDurationsList']
  },
  [pfFieldType.OPTIONS]: ({ field }) => {
    let options = []
    if (field === undefined) {
      throw new Error('Missing `field` in pfFieldTypeValues[pfFieldType.OPTIONS]')
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
  },
  [pfFieldType.REALM]: () => {
    return store.dispatch('config/getRealms', store.getters['session/tenantIdMask']).then(() => store.getters['config/realmsList'])
  },
  [pfFieldType.ROLE]: () => {
    store.dispatch('config/getRoles')
    return store.getters['config/rolesList']
  },
  [pfFieldType.ROLE_BY_NAME]: () => {
    store.dispatch('config/getRoles')
    return pfFieldTypeValues[pfFieldType.ROLE]().map(role => { return { value: role.name, name: role.name } })
  },
  [pfFieldType.ROLE_BY_ACL_NODE]: () => {
    store.dispatch('session/getAllowedNodeRoles')
    return store.getters['session/allowedNodeRolesList']
  },
  [pfFieldType.ROLE_BY_ACL_USER]: () => {
    store.dispatch('session/getAllowedUserRoles')
    return store.getters['session/allowedUserRolesList']
  },
  [pfFieldType.ROOT_PORTAL_MODULE]: () => {
    store.dispatch('config/getPortalModules')
    return store.getters['config/rootPortalModulesList']
  },
  [pfFieldType.SOURCE]: () => {
    store.dispatch('config/getSources')
    return store.getters['config/sourcesList']
  },
  [pfFieldType.SSID]: () => {
    store.dispatch('config/getSsids')
    return store.getters['config/ssidsList']
  },
  [pfFieldType.SWITCHE]: () => {
    store.dispatch('config/getSwitches')
    return store.getters['config/switchesList']
  },
  [pfFieldType.SWITCH_GROUP]: () => {
    store.dispatch('config/getSwitchGroups')
    return store.getters['config/switchGroupsList']
  },
  [pfFieldType.TENANT]: () => {
    store.dispatch('config/getTenants')
    return store.getters['config/tenantsList']
  },
  [pfFieldType.TIME_BALANCE]: () => {
    return [
      { name: i18n.t('1 hour'), value: '1h' },
      { name: i18n.t('3 hours'), value: '3h' },
      { name: i18n.t('12 hours'), value: '12h' },
      { name: i18n.t('1 day'), value: '1D' },
      { name: i18n.t('2 days'), value: '2D' },
      { name: i18n.t('3 days'), value: '3D' },
      { name: i18n.t('5 days'), value: '5D' }
    ]
  },
  [pfFieldType.YESNO]: () => {
    return [
      { name: i18n.t('Yes'), value: 'yes' },
      { name: i18n.t('No'), value: 'no' }
    ]
  }
}
