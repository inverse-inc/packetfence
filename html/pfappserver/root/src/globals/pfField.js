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

  [pfFieldType.ADMINROLE]: () =>
    store.dispatch('config/getAdminRoles').then(() => store.getters['config/adminRolesList']),

  [pfFieldType.ADMINROLE_BY_ACL_USER]: () =>
    store.dispatch('session/getAllowedUserAccessLevels').then(() => store.getters['session/allowedUserAccessLevelsList']),

  [pfFieldType.CONNECTION]: () =>
    [
      {
        group: i18n.t('Types'),
        options: [
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
        options: [
          { value: 'EAP', text: 'EAP' },
          { value: 'Ethernet', text: 'Ethernet' },
          { value: 'Web-Auth', text: 'Web-Auth' },
          { value: 'Wireless', text: 'Wireless' }
        ]
      }
    ],

  [pfFieldType.CONNECTION_TYPE]: () =>
    [
      { text: 'Wireless-802.11-NoEAP', value: 'Wireless-802.11-NoEAP' },
      { text: 'Ethernet-Web-Auth', value: 'Ethernet-Web-Auth' },
      { text: 'SNMP-Traps', value: 'SNMP-Traps' },
      { text: 'Inline', value: 'Inline' },
      { text: 'Ethernet-EAP', value: 'Ethernet-EAP' },
      { text: 'Ethernet-NoEAP', value: 'Ethernet-NoEAP' },
      { text: 'Wireless-Web-Auth', value: 'Wireless-Web-Auth' },
      { text: 'Wireless-802.11-EAP', value: 'Wireless-802.11-EAP' },
      { text: 'VPN-Access', value: 'VPN-Access' },
      { text: 'CLI-Access', value: 'CLI-Access' }
    ],

  [pfFieldType.CONNECTION_SUB_TYPE]: () =>
    [
      { text: '3Com-Wireless', value: '3Com-Wireless' },
      { text: 'Actiontec-Wireless', value: 'Actiontec-Wireless' },
      { text: 'AirFortress-EAP', value: 'AirFortress-EAP' },
      { text: 'AKA', value: 'AKA' },
      { text: 'AKA2', value: 'AKA2' },
      { text: 'Arcot-Systems-EAP', value: 'Arcot-Systems-EAP' },
      { text: 'Cisco-LEAP', value: 'Cisco-LEAP' },
      { text: 'Cisco-MS-CHAPv2', value: 'Cisco-MS-CHAPv2' },
      { text: 'Cogent-Biomentric-EAP', value: 'Cogent-Biomentric-EAP' },
      { text: 'CRYPTOCard', value: 'CRYPTOCard' },
      { text: 'Defender-Token', value: 'Defender-Token' },
      { text: 'DeviceConnect-EAP', value: 'DeviceConnect-EAP' },
      { text: 'DSS-Unilateral', value: 'DSS-Unilateral' },
      { text: 'DynamID', value: 'DynamID' },
      { text: 'EAP-AKA', value: 'EAP-AKA' },
      { text: 'EAP-FAST', value: 'EAP-FAST' },
      { text: 'EAP-GTC', value: 'EAP-GTC' },
      { text: 'EAP-IKEv2', value: 'EAP-IKEv2' },
      { text: 'EAP-MD5', value: 'EAP-MD5' },
      { text: 'EAP-MSCHAPv2', value: 'EAP-MSCHAPv2' },
      { text: 'EAP-SIM', value: 'EAP-SIM' },
      { text: 'EAP-TLS', value: 'EAP-TLS' },
      { text: 'EAP-TTLS', value: 'EAP-TTLS' },
      { text: 'EKEv1', value: 'EKEv1' },
      { text: 'FAST', value: 'FAST' },
      { text: 'Generic-Token-Card', value: 'Generic-Token-Card' },
      { text: 'GPSK', value: 'GPSK' },
      { text: 'GTC', value: 'GTC' },
      { text: 'HTTP-Digest', value: 'HTTP-Digest' },
      { text: 'Identity', value: 'Identity' },
      { text: 'IKEv2', value: 'IKEv2' },
      { text: 'KEA', value: 'KEA' },
      { text: 'KEA-Validate', value: 'KEA-Validate' },
      { text: 'LEAP', value: 'LEAP' },
      { text: 'Link', value: 'Link' },
      { text: 'MAKE', value: 'MAKE' },
      { text: 'MD5', value: 'MD5' },
      { text: 'MD5-Challenge', value: 'MD5-Challenge' },
      { text: 'Microsoft-MS-CHAPv2', value: 'Microsoft-MS-CHAPv2' },
      { text: 'MOBAC', value: 'MOBAC' },
      { text: 'MS-Authentication-TLV', value: 'MS-Authentication-TLV' },
      { text: 'MSCHAPv2', value: 'MSCHAPv2' },
      { text: 'NAK', value: 'NAK' },
      { text: 'Nokia-IP-Smart-Card', value: 'Nokia-IP-Smart-Card' },
      { text: 'None', value: 'None' },
      { text: 'Notification', value: 'Notification' },
      { text: 'One-Time-Password', value: 'One-Time-Password' },
      { text: 'OTP', value: 'OTP' },
      { text: 'PAX', value: 'PAX' },
      { text: 'PEAP', value: 'PEAP' },
      { text: 'PSK', value: 'PSK' },
      { text: 'PWD', value: 'PWD' },
      { text: 'Remote-Access-Service', value: 'Remote-Access-Service' },
      { text: 'Rob-EAP', value: 'Rob-EAP' },
      { text: 'RSA-Public-Key', value: 'RSA-Public-Key' },
      { text: 'RSA-SecurID-EAP', value: 'RSA-SecurID-EAP' },
      { text: 'SAKE', value: 'SAKE' },
      { text: 'SecurID-EAP', value: 'SecurID-EAP' },
      { text: 'SecuriSuite-EAP', value: 'SecuriSuite-EAP' },
      { text: 'SentriNET', value: 'SentriNET' },
      { text: 'SIM', value: 'SIM' },
      { text: 'SPEKE', value: 'SPEKE' },
      { text: 'SRP-SHA1', value: 'SRP-SHA1' },
      { text: 'TLS', value: 'TLS' },
      { text: 'TNC', value: 'TNC' },
      { text: 'TTLS', value: 'TTLS' },
      { text: 'Zonelabs', value: 'Zonelabs' }
    ],

  [pfFieldType.GENDER]: () =>
    [
      { text: i18n.t('Male'), value: 'm' },
      { text: i18n.t('Female'), value: 'f' },
      { text: i18n.t('Other'), value: 'o' }
    ],

  [pfFieldType.NODE_STATUS]: () =>
    [
      { text: i18n.t('Registered'), value: 'reg' },
      { text: i18n.t('Unregistered'), value: 'unreg' },
      { text: i18n.t('Pending'), value: 'pending' }
    ],

  [pfFieldType.DURATION]: () =>
    store.dispatch('config/getBaseGuestsAdminRegistration').then(() => store.getters['config/accessDurationsList']),

  [pfFieldType.DURATION_BY_ACL_USER]: () =>
    store.dispatch('session/getAllowedUserAccessDurations').then(() => store.getters['session/allowedUserAccessDurationsList']),

  [pfFieldType.DURATIONS]: () =>
    store.dispatch('config/getBaseGuestsAdminRegistration').then(() => store.getters['config/accessDurationsList']),

  [pfFieldType.OPTIONS]: ({ field }) => {
    if (field === undefined) {
      throw new Error('Missing `field` in pfFieldTypeValues[pfFieldType.OPTIONS]')
    }
    if (field.options) {
      return field.options
    }
    return []
  },

  [pfFieldType.REALM]: () =>
    store.dispatch('config/getRealms', store.getters['session/tenantIdMask']).then(() => store.getters['config/realmsList']),

  [pfFieldType.ROLE]: () =>
    store.dispatch('config/getRoles').then(items => [
      { value: null, text: i18n.t('empty - None') },
      ...items.map((item) => {
        return { value: item.category_id, text: ((item.notes) ? `${item.name} - ${item.notes}` : `${item.name}`) }
      })
    ]),

  [pfFieldType.ROLE_BY_NAME]: () =>
    store.dispatch('config/getRoles').then(items => {
      return (items || []).map((item) => {
        return { value: item.name, text: item.name }
      })
    }),

  [pfFieldType.ROLE_BY_ACL_NODE]: () =>
    store.dispatch('session/getAllowedNodeRoles').then(() => store.getters['session/allowedNodeRolesList']),

  [pfFieldType.ROLE_BY_ACL_USER]: () =>
    store.dispatch('session/getAllowedUserRoles').then(() => store.getters['session/allowedUserRolesList']),

  [pfFieldType.ROOT_PORTAL_MODULE]: () =>
    store.dispatch('config/getPortalModules').then(() => store.getters['config/rootPortalModulesList']),

  [pfFieldType.SOURCE]: () =>
    store.dispatch('config/getSources').then(() => store.getters['config/sourcesList']),

  [pfFieldType.SSID]: () =>
    store.dispatch('config/getSsids').then(() => store.getters['config/ssidsList']),

  [pfFieldType.SWITCHE]: () =>
    store.dispatch('config/getSwitches').then(() => store.getters['config/switchesList']),

  [pfFieldType.SWITCH_GROUP]: () =>
    store.dispatch('config/getSwitchGroups').then(() => store.getters['config/switchGroupsList']),

  [pfFieldType.TENANT]: () =>
    store.dispatch('config/getTenants').then(() => store.getters['config/tenantsList']),

  [pfFieldType.TIME_BALANCE]: () =>
    [
      { text: i18n.t('1 hour'), value: '1h' },
      { text: i18n.t('3 hours'), value: '3h' },
      { text: i18n.t('12 hours'), value: '12h' },
      { text: i18n.t('1 day'), value: '1D' },
      { text: i18n.t('2 days'), value: '2D' },
      { text: i18n.t('3 days'), value: '3D' },
      { text: i18n.t('5 days'), value: '5D' }
    ],

  [pfFieldType.YESNO]: () =>
    [
      { text: i18n.t('Yes'), value: 'yes' },
      { text: i18n.t('No'), value: 'no' }
    ]
}

import {
  BaseInput,
  BaseInputGroupDate,
  BaseInputGroupDateTime,
  BaseInputGroupMultiplier,
  BaseInputNumber,
  BaseInputChosenMultiple,
  BaseInputChosenOne
} from '@/components/new'

export const useField = (field) => {
  if (field) {
    let { props = {}, types = [] } = field
    for (let t = 0; t < types.length; t++) { // may allow multiple component `types`, use only 1st match
      let type = types[t]
      if (type in pfFieldTypeValues) { // may inherit multiple values, combines all possible values
        props.options = props.options || [] // build :options
        Promise.resolve(pfFieldTypeValues[type]()).then(options => { // handle Promises
          const values = props.options.map(option => option.value) // fast map
          for (let option of options) {
            if (!values.includes(option.value)) // ignore duplicates
              props.options.push(option)
          }
        })
      }
      switch (pfFieldTypeComponent[type]) {
        case pfComponentType.SELECTMANY:
          return { is: BaseInputChosenMultiple, ...props }
          // break

        case pfComponentType.SELECTONE:
          return { is: BaseInputChosenOne, ...props }
          // break

        case pfComponentType.DATE:
          return { is: BaseInputGroupDate, ...props }
          // break

        case pfComponentType.DATETIME:
          return { is: BaseInputGroupDateTime, ...props }
          // break

        case pfComponentType.PREFIXMULTIPLIER:
          return { is: BaseInputGroupMultiplier, ...props }
          // break

        case pfComponentType.SUBSTRING:
          return { is: BaseInput, ...props }
          // break

        case pfComponentType.INTEGER:
          return { is: BaseInputNumber, ...props }
          // break

        case pfComponentType.HIDDEN:
        case pfComponentType.NONE:
          return undefined
          // break

        default:
          // eslint-disable-next-line
          console.error(`Unhandled pfComponentType '${pfFieldTypeComponent[type]}' for pfFieldType '${type}'`)
      }
    }
  }
}
