import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import { pfSearchConditionType as conditionType } from '@/globals/pfSearch'
import {
  and,
  not,
  conditional,
  hasProvisionings,
  provisioningExists
} from '@/globals/pfValidators'
import {
  required
} from 'vuelidate/lib/validators'

export const columns = [
  {
    key: 'id',
    label: i18n.t('Identifier'),
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: i18n.t('Description'),
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: i18n.t('Type'),
    sortable: true,
    visible: true
  },
  {
    key: 'buttons',
    label: '',
    locked: true
  }
]

export const fields = [
  {
    value: 'id',
    text: i18n.t('Identifier'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'description',
    text: i18n.t('Description'),
    types: [conditionType.SUBSTRING]
  },
  {
    value: 'type',
    text: i18n.t('Type'),
    types: [conditionType.SUBSTRING]
  }
]

export const config = () => {
  return {
    columns,
    fields,
    rowClickRoute (item) {
      return { name: 'provisioning', params: { id: item.id } }
    },
    searchPlaceholder: i18n.t('Search by id or description'),
    searchableOptions: {
      searchApiEndpoint: 'config/provisionings',
      defaultSortKeys: ['id'],
      defaultSearchCondition: {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: null },
            { field: 'description', op: 'contains', value: null },
            { field: 'type', op: 'contains', value: null }
          ]
        }]
      },
      defaultRoute: { name: 'provisionings' }
    },
    searchableQuickCondition: (quickCondition) => {
      return {
        op: 'and',
        values: [{
          op: 'or',
          values: [
            { field: 'id', op: 'contains', value: quickCondition },
            { field: 'description', op: 'contains', value: quickCondition },
            { field: 'type', op: 'contains', value: quickCondition }
          ]
        }]
      }
    }
  }
}

export const viewFields = {
  id: (form = {}, meta = {}) => {
    const {
      isNew = false,
      isClone = false
    } = meta
    return {
      label: i18n.t('Provisioning ID'),
      cols: [
        {
          namespace: 'id',
          component: pfFormInput,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'id'),
            ...{
              disabled: (!isNew && !isClone)
            }
          },
          validators: {
            ...pfConfigurationValidatorsFromMeta(meta, 'id', 'ID'),
            ...{
              [i18n.t('ID exists.')]: not(and(required, conditional(isNew || isClone), hasProvisionings, provisioningExists))
            }
          }
        }
      ]
    }
  },
  access_token: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Access token'),
      cols: [
        {
          namespace: 'access_token',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'access_token'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'access_token', i18n.t('Token'))
        }
      ]
    }
  },
  agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Agent download URI'),
      cols: [
        {
          namespace: 'agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'agent_download_uri', 'URI')
        }
      ]
    }
  },
  alt_agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Alt agent download URI'),
      cols: [
        {
          namespace: 'alt_agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'alt_agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'alt_agent_download_uri', 'URI')
        }
      ]
    }
  },
  android_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Android download URI'),
      cols: [
        {
          namespace: 'android_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'android_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'android_download_uri', 'URI')
        }
      ]
    }
  },
  android_agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Android agent download URI'),
      cols: [
        {
          namespace: 'android_agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'android_agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'android_agent_download_uri', 'URI')
        }
      ]
    }
  },
  api_password: (form = {}, meta = {}) => {
    return {
      label: i18n.t('API password'),
      cols: [
        {
          namespace: 'api_password',
          component: pfFormPassword,
          attrs: pfConfigurationAttributesFromMeta(meta, 'api_password'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'api_password', i18n.t('Password'))
        }
      ]
    }
  },
  api_username: (form = {}, meta = {}) => {
    return {
      label: i18n.t('API username'),
      cols: [
        {
          namespace: 'api_username',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'api_username'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'api_username', i18n.t('Username'))
        }
      ]
    }
  },
  api_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Api uri'),
      cols: [
        {
          namespace: 'api_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'api_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'api_uri', 'URI')
        }
      ]
    }
  },
  boarding_host: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Boarding host'),
      cols: [
        {
          namespace: 'boarding_host',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'boarding_host'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'boarding_host', i18n.t('Host'))
        }
      ]
    }
  },
  boarding_port: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Boarding port'),
      cols: [
        {
          namespace: 'boarding_port',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'boarding_port'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'boarding_port', i18n.t('Port'))
        }
      ]
    }
  },
  broadcast: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Broadcast network'),
      text: i18n.t('Uncheck this box if you are using a hidden SSID.'),
      cols: [
        {
          namespace: 'broadcast',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: '1', unchecked: '0' }
          }
        }
      ]
    }
  },
  can_sign_profile: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Sign Profile'),
      cols: [
        {
          namespace: 'can_sign_profile',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: '1', unchecked: '0' }
          }
        }
      ]
    }
  },
  category: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Roles'),
      text: i18n.t('Nodes with the selected roles will be affected.'),
      cols: [
        {
          namespace: 'category',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'category'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'category', i18n.t('Roles'))
        }
      ]
    }
  },
  cert_chain: (form = {}, meta = {}) => {
    return {
      label: i18n.t('The certificate chain for the signer certificate'),
      text: i18n.t('The certificate chain of the signer certificate in PEM format.'),
      cols: [
        {
          namespace: 'cert_chain',
          component: pfFormTextarea,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'cert_chain'),
            ...{
              rows: 5
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'cert_chain', i18n.t('Chain'))
        }
      ]
    }
  },
  certificate: (form = {}, meta = {}) => {
    return {
      label: i18n.t('The certificate for signing profiles'),
      text: i18n.t('The certificate for signing in PEM format.'),
      cols: [
        {
          namespace: 'certificate',
          component: pfFormTextarea,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'certificate'),
            ...{
              rows: 5
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'certificate', i18n.t('Certificate'))
        }
      ]
    }
  },
  client_id: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Client Key'),
      cols: [
        {
          namespace: 'client_id',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'client_id'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'client_id', i18n.t('Key'))
        }
      ]
    }
  },
  client_secret: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Client Secret'),
      cols: [
        {
          namespace: 'client_secret',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'client_secret'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'client_secret', i18n.t('Secret'))
        }
      ]
    }
  },
  applicationID: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Application ID'),
      cols: [
        {
          namespace: 'applicationID',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'applicationID'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'applicationID', i18n.t('Application ID'))
        }
      ]
    }
  },
  applicationSecret: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Application Secret'),
      cols: [
        {
          namespace: 'applicationSecret',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'applicationSecret'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'applicationSecret', i18n.t('Application Secret'))
        }
      ]
    }
  },
  tenantID: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Tenant ID'),
      cols: [
        {
          namespace: 'tenantID',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'tenantID'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'tenantID', i18n.t('Tenant ID'))
        }
      ]
    }
  },
  loginUrl: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Login Url'),
      cols: [
        {
          namespace: 'loginUrl',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'loginUrl'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'loginUrl', i18n.t('Login Url'))
        }
      ]
    }
  },
  critical_issues_threshold: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Critical issues threshold'),
      text: i18n.t('The minimum number of critical issues a device needs to have before it gets isolated. 0 deactivates it.'),
      cols: [
        {
          namespace: 'critical_issues_threshold',
          component: pfFormInput,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'critical_issues_threshold'),
            ...{
              type: 'number',
              step: 1
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'critical_issues_threshold', i18n.t('Threshold'))
        }
      ]
    }
  },
  description: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Description'),
      cols: [
        {
          namespace: 'description',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'description'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'description', i18n.t('Description'))
        }
      ]
    }
  },
  device_type_detection: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Automatic device detection'),
      cols: [
        {
          namespace: 'device_type_detection',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  domains: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Authorized domains'),
      text: i18n.t('A comma-separated list of domains that will be resolved with the correct IP addresses.'),
      cols: [
        {
          namespace: 'domains',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'domains'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'domains', i18n.t('Domains'))
        }
      ]
    }
  },
  dpsk: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Enable DPSK'),
      text: i18n.t('Define if the PSK needs to be generated'),
      cols: [
        {
          namespace: 'dpsk',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: '1', unchecked: '0' }
          }
        }
      ]
    }
  },
  eap_type: (form = {}, meta = {}) => {
    return {
      label: i18n.t('EAP type'),
      text: i18n.t('Select the EAP type of your SSID. Leave empty for no EAP.'),
      cols: [
        {
          namespace: 'eap_type',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'eap_type'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'eap_type', i18n.t('Type'))
        }
      ]
    }
  },
  host: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Host'),
      cols: [
        {
          namespace: 'host',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'host'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'host', i18n.t('Host'))
        }
      ]
    }
  },
  ios_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('IOS download URI'),
      cols: [
        {
          namespace: 'ios_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'ios_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'ios_download_uri', 'URI')
        }
      ]
    }
  },
  ios_agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('IOS agent download URI'),
      cols: [
        {
          namespace: 'ios_agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'ios_agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'ios_agent_download_uri', 'URI')
        }
      ]
    }
  },
  mac_osx_agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Mac OSX agent download URI'),
      cols: [
        {
          namespace: 'mac_osx_agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'mac_osx_agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'mac_osx_agent_download_uri', 'URI')
        }
      ]
    }
  },
  non_compliance_security_event: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Non compliance security event'),
      text: i18n.t('Which security event should be raised when non compliance is detected.'),
      cols: [
        {
          namespace: 'non_compliance_security_event',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'non_compliance_security_event'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'non_compliance_security_event', i18n.t('Event'))
        }
      ]
    }
  },
  oses: (form = {}, meta = {}) => {
    return {
      label: 'OS',
      text: i18n.t('Nodes with the selected OS will be affected.'),
      cols: [
        {
          namespace: 'oses',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'oses'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'oses', 'OS')
        }
      ]
    }
  },
  passcode: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Wifi Key'),
      cols: [
        {
          namespace: 'passcode',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'passcode'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'passcode', i18n.t('Key'))
        }
      ]
    }
  },
  password: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Client Secret'),
      cols: [
        {
          namespace: 'password',
          component: pfFormPassword,
          attrs: pfConfigurationAttributesFromMeta(meta, 'password'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'password', i18n.t('Secret'))
        }
      ]
    }
  },
  pki_provider: (form = {}, meta = {}) => {
    return {
      label: i18n.t('PKI Provider'),
      cols: [
        {
          namespace: 'pki_provider',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'pki_provider'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'pki_provider', i18n.t('Provider'))
        }
      ]
    }
  },
  port: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Port'),
      cols: [
        {
          namespace: 'port',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'port'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'port', i18n.t('Port'))
        }
      ]
    }
  },
  private_key: (form = {}, meta = {}) => {
    return {
      label: i18n.t('The private key for signing profiles'),
      text: i18n.t('The private key for signing in PEM format.'),
      cols: [
        {
          namespace: 'private_key',
          component: pfFormTextarea,
          attrs: {
            ...pfConfigurationAttributesFromMeta(meta, 'private_key'),
            ...{
              rows: 5
            }
          },
          validators: pfConfigurationValidatorsFromMeta(meta, 'private_key', i18n.t('Key'))
        }
      ]
    }
  },
  protocol: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Protocol'),
      cols: [
        {
          namespace: 'protocol',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'protocol'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'protocol', i18n.t('Protocol'))
        }
      ]
    }
  },
  psk_size: (form = {}, meta = {}) => {
    return {
      label: i18n.t('PSK length'),
      text: i18n.t('This is the length of the PSK key you want to generate. The minimum length is eight characters.'),
      cols: [
        {
          namespace: 'psk_size',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'psk_size'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'psk_size', i18n.t('Length'))
        }
      ]
    }
  },
  query_computers: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Query JAMF computers inventory'),
      cols: [
        {
          namespace: 'query_computers',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  query_mobiledevices: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Query JAMF mobile devices inventory'),
      cols: [
        {
          namespace: 'query_mobiledevices',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  refresh_token: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Refresh token'),
      cols: [
        {
          namespace: 'refresh_token',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'refresh_token'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'refresh_token', i18n.t('Token'))
        }
      ]
    }
  },
  security_type: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Security type'),
      text: i18n.t('Select the type of security applied for your SSID.'),
      cols: [
        {
          namespace: 'security_type',
          component: pfFormChosen,
          attrs: pfConfigurationAttributesFromMeta(meta, 'security_type'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'security_type', i18n.t('Type'))
        }
      ]
    }
  },
  server_certificate_path: (form = {}, meta = {}) => {
    return {
      label: i18n.t('RADIUS server certificate path'),
      text: i18n.t('The path to the RADIUS server certificate.'),
      cols: [
        {
          namespace: 'server_certificate_path',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'server_certificate_path'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'server_certificate_path', i18n.t('Path'))
        }
      ]
    }
  },
  ssid: (form = {}, meta = {}) => {
    return {
      label: 'SSID',
      cols: [
        {
          namespace: 'ssid',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'ssid'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'ssid', 'SSID')
        }
      ]
    }
  },
  table_for_agent: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Agent table name'),
      cols: [
        {
          namespace: 'table_for_agent',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'table_for_agent'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'table_for_agent', i18n.t('Agent table name'))
        }
      ]
    }
  },
  table_for_mac: (form = {}, meta = {}) => {
    return {
      label: i18n.t('MAC table name'),
      cols: [
        {
          namespace: 'table_for_mac',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'table_for_mac'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'table_for_mac', i18n.t('Mac table name'))
        }
      ]
    }
  },
  username: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Username'),
      cols: [
        {
          namespace: 'username',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'username'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'username', i18n.t('Username'))
        }
      ]
    }
  },
  win_agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Windows agent download URI'),
      cols: [
        {
          namespace: 'win_agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'win_agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'win_agent_download_uri', 'URI')
        }
      ]
    }
  },
  windows_agent_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Windows agent download URI'),
      cols: [
        {
          namespace: 'windows_agent_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'windows_agent_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'windows_agent_download_uri', 'URI')
        }
      ]
    }
  },
  windows_phone_download_uri: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Windows phone download URI'),
      cols: [
        {
          namespace: 'windows_phone_download_uri',
          component: pfFormInput,
          attrs: pfConfigurationAttributesFromMeta(meta, 'windows_phone_download_uri'),
          validators: pfConfigurationValidatorsFromMeta(meta, 'windows_phone_download_uri', 'URI')
        }
      ]
    }
  }
}

export const view = (form = {}, meta = {}) => {
  const {
    eap_type = null,
    security_type = null
  } = form
  const {
    provisioningType = null
  } = meta
  switch (provisioningType) {
    case 'accept':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta)
          ]
        }
      ]
    case 'android':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            ...[
              viewFields.id(form, meta),
              viewFields.description(form, meta),
              viewFields.category(form, meta),
              viewFields.ssid(form, meta),
              viewFields.broadcast(form, meta),
              viewFields.security_type(form, meta)
            ],
            ...((security_type === 'WPA2')
              ? [viewFields.eap_type(form, meta)]
              : [] // ignore
            ),
            ...((['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
              ? [
                viewFields.dpsk(form, meta),
                viewFields.passcode(form, meta)
              ]
              : [] // ignore
            ),
            ...((security_type === 'WPA2' && ~~eap_type === 25 /* PEAP */)
              ? [viewFields.server_certificate_path(form, meta)]
              : [] // ignore
            ),
            ...((security_type === 'WPA2' && ~~eap_type === 13 /* EAP-TLS */)
              ? [viewFields.pki_provider(form, meta)]
              : [] // ignore
            )
          ]
        }
      ]
    case 'deny':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta)
          ]
        }
      ]
    case 'dpsk':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.ssid(form, meta),
            viewFields.oses(form, meta),
            viewFields.psk_size(form, meta)
          ]
        }
      ]
    case 'ibm':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.username(form, meta),
            viewFields.password(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.api_uri(form, meta),
            viewFields.oses(form, meta),
            viewFields.agent_download_uri(form, meta)
          ]
        }
      ]
    case 'jamf':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.api_username(form, meta),
            viewFields.api_password(form, meta),
            viewFields.device_type_detection(form, meta),
            viewFields.query_computers(form, meta),
            viewFields.query_mobiledevices(form, meta)
          ]
        }
      ]
    case 'mobileconfig':
      return [
        {
          tab: i18n.t('Settings'),
          rows: [
            ...[
              viewFields.id(form, meta),
              viewFields.description(form, meta),
              viewFields.category(form, meta),
              viewFields.ssid(form, meta),
              viewFields.broadcast(form, meta),
              viewFields.security_type(form, meta)
            ],
            ...((security_type === 'WPA2')
              ? [viewFields.eap_type(form, meta)]
              : [] // ignore
            ),
            ...((['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
              ? [
                viewFields.dpsk(form, meta),
                viewFields.passcode(form, meta)
              ]
              : [] // ignore
            ),
            ...((security_type === 'WPA2' && ~~eap_type === 25 /* PEAP */)
              ? [viewFields.server_certificate_path(form, meta)]
              : [] // ignore
            ),
            ...((security_type === 'WPA2' && ~~eap_type === 13 /* EAP-TLS */)
              ? [viewFields.pki_provider(form, meta)]
              : [] // ignore
            )
          ]
        },
        {
          tab: i18n.t('Signing'),
          rows: [
            viewFields.can_sign_profile(form, meta),
            viewFields.certificate(form, meta),
            viewFields.private_key(form, meta),
            viewFields.cert_chain(form, meta)
          ]
        }
      ]
    case 'mobileiron':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.username(form, meta),
            viewFields.password(form, meta),
            viewFields.host(form, meta),
            viewFields.android_download_uri(form, meta),
            viewFields.ios_download_uri(form, meta),
            viewFields.windows_phone_download_uri(form, meta),
            viewFields.boarding_host(form, meta),
            viewFields.boarding_port(form, meta)
          ]
        }
      ]
    case 'opswat':
      return [
        {
          tab: i18n.t('Settings'),
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.client_id(form, meta),
            viewFields.client_secret(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.access_token(form, meta),
            viewFields.refresh_token(form, meta),
            viewFields.agent_download_uri(form, meta)
          ]
        },
        {
          tab: i18n.t('Compliance'),
          rows: [
            viewFields.non_compliance_security_event(form, meta),
            viewFields.critical_issues_threshold(form, meta)
          ]
        }
      ]
    case 'sentinelone':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.api_username(form, meta),
            viewFields.api_password(form, meta),
            viewFields.win_agent_download_uri(form, meta),
            viewFields.mac_osx_agent_download_uri(form, meta)
          ]
        }
      ]
    case 'sepm':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.client_id(form, meta),
            viewFields.client_secret(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.access_token(form, meta),
            viewFields.refresh_token(form, meta),
            viewFields.agent_download_uri(form, meta),
            viewFields.alt_agent_download_uri(form, meta)
          ]
        }
      ]
    case 'symantec':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.username(form, meta),
            viewFields.password(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.api_uri(form, meta),
            viewFields.agent_download_uri(form, meta)
          ]
        }
      ]
    case 'servicenow':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.username(form, meta),
            viewFields.password(form, meta),
            viewFields.host(form, meta),
            viewFields.protocol(form, meta),
            viewFields.table_for_mac(form, meta),
            viewFields.table_for_agent(form, meta)
          ]
        }
      ]
    case 'windows':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            ...[
              viewFields.id(form, meta),
              viewFields.description(form, meta),
              viewFields.category(form, meta),
              viewFields.ssid(form, meta),
              viewFields.broadcast(form, meta),
              viewFields.security_type(form, meta)
            ],
            ...((security_type === 'WPA2')
              ? [viewFields.eap_type(form, meta)]
              : [] // ignore
            ),
            ...((['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
              ? [
                viewFields.dpsk(form, meta),
                viewFields.passcode(form, meta)
              ]
              : [] // ignore
            ),
            ...((security_type === 'WPA2' && ~~eap_type === 25 /* PEAP */)
              ? [viewFields.server_certificate_path(form, meta)]
              : [] // ignore
            ),
            ...((security_type === 'WPA2' && ~~eap_type === 13 /* EAP-TLS */)
              ? [viewFields.pki_provider(form, meta)]
              : [] // ignore
            )
          ]
        }
      ]
    case 'intune':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.applicationID(form, meta),
            viewFields.applicationSecret(form, meta),
            viewFields.tenantID(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.loginUrl(form, meta),
            viewFields.android_agent_download_uri(form, meta),
            viewFields.ios_agent_download_uri(form, meta),
            viewFields.windows_agent_download_uri(form, meta),
            viewFields.mac_osx_agent_download_uri(form, meta),
            viewFields.domains(form, meta)
          ]
        }
      ]
    default:
      return [
        {
          tab: null, // ignore tabs
          rows: []
        }
      ]
  }
}

export const validatorFields = {
  id: (form = {}, meta = {}) => {
    const {
      isNew = false,
      isClone = false
    } = meta
    return {
      id: {
        ...pfConfigurationValidatorsFromMeta(meta, 'id', 'ID'),
        ...{
          [i18n.t('ID exists.')]: not(and(required, conditional(isNew || isClone), hasProvisionings, provisioningExists))
        }
      }
    }
  },
  access_token: (form = {}, meta = {}) => {
    return { access_token: pfConfigurationValidatorsFromMeta(meta, 'access_token', i18n.t('Token')) }
  },
  agent_download_uri: (form = {}, meta = {}) => {
    return { agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'agent_download_uri', 'URI') }
  },
  alt_agent_download_uri: (form = {}, meta = {}) => {
    return { alt_agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'alt_agent_download_uri', 'URI') }
  },
  android_download_uri: (form = {}, meta = {}) => {
    return { android_download_uri: pfConfigurationValidatorsFromMeta(meta, 'android_download_uri', 'URI') }
  },
  android_agent_download_uri: (form = {}, meta = {}) => {
    return { android_agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'android_agent_download_uri', 'URI') }
  },
  api_password: (form = {}, meta = {}) => {
    return { api_password: pfConfigurationValidatorsFromMeta(meta, 'api_password', i18n.t('Password')) }
  },
  api_username: (form = {}, meta = {}) => {
    return { api_username: pfConfigurationValidatorsFromMeta(meta, 'api_username', i18n.t('Username')) }
  },
  api_uri: (form = {}, meta = {}) => {
    return { api_uri: pfConfigurationValidatorsFromMeta(meta, 'api_uri', 'URI') }
  },
  boarding_host: (form = {}, meta = {}) => {
    return { boarding_host: pfConfigurationValidatorsFromMeta(meta, 'boarding_host', i18n.t('Host')) }
  },
  boarding_port: (form = {}, meta = {}) => {
    return { boarding_port: pfConfigurationValidatorsFromMeta(meta, 'boarding_port', i18n.t('Port')) }
  },
  broadcast: (form = {}, meta = {}) => {},
  can_sign_profile: (form = {}, meta = {}) => {},
  category: (form = {}, meta = {}) => {
    return { category: pfConfigurationValidatorsFromMeta(meta, 'category', i18n.t('Roles')) }
  },
  cert_chain: (form = {}, meta = {}) => {
    return { cert_chain: pfConfigurationValidatorsFromMeta(meta, 'cert_chain', i18n.t('Chain')) }
  },
  certificate: (form = {}, meta = {}) => {
    return { certificate: pfConfigurationValidatorsFromMeta(meta, 'certificate', i18n.t('Certificate')) }
  },
  client_id: (form = {}, meta = {}) => {
    return { client_id: pfConfigurationValidatorsFromMeta(meta, 'client_id', i18n.t('Key')) }
  },
  client_secret: (form = {}, meta = {}) => {
    return { client_secret: pfConfigurationValidatorsFromMeta(meta, 'client_secret', i18n.t('Secret')) }
  },
  applicationID: (form = {}, meta = {}) => {
    return { applicationID: pfConfigurationValidatorsFromMeta(meta, 'applicationID', i18n.t('Application ID')) }
  },
  applicationSecret: (form = {}, meta = {}) => {
    return { applicationSecret: pfConfigurationValidatorsFromMeta(meta, 'applicationSecret', i18n.t('Application Secret')) }
  },
  tenantID: (form = {}, meta = {}) => {
    return { tenantID: pfConfigurationValidatorsFromMeta(meta, 'tenantID', i18n.t('Tenant ID')) }
  },
  loginUrl: (form = {}, meta = {}) => {
    return { loginUrl: pfConfigurationValidatorsFromMeta(meta, 'loginUrl', i18n.t('Login Url')) }
  },
  critical_issues_threshold: (form = {}, meta = {}) => {
    return { critical_issues_threshold: pfConfigurationValidatorsFromMeta(meta, 'critical_issues_threshold', i18n.t('Threshold')) }
  },
  description: (form = {}, meta = {}) => {
    return { description: pfConfigurationValidatorsFromMeta(meta, 'description', i18n.t('Description')) }
  },
  device_type_detection: (form = {}, meta = {}) => {},
  domains: (form = {}, meta = {}) => {
    return { domains: pfConfigurationValidatorsFromMeta(meta, 'domains', i18n.t('Domains')) }
  },
  dpsk: (form = {}, meta = {}) => {},
  eap_type: (form = {}, meta = {}) => {
    return { eap_type: pfConfigurationValidatorsFromMeta(meta, 'eap_type', i18n.t('Type')) }
  },
  host: (form = {}, meta = {}) => {
    return { host: pfConfigurationValidatorsFromMeta(meta, 'host', i18n.t('Host')) }
  },
  ios_download_uri: (form = {}, meta = {}) => {
    return { ios_download_uri: pfConfigurationValidatorsFromMeta(meta, 'ios_download_uri', 'URI') }
  },
  ios_agent_download_uri: (form = {}, meta = {}) => {
    return { ios_agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'ios_agent_download_uri', 'URI') }
  },
  mac_osx_agent_download_uri: (form = {}, meta = {}) => {
    return { mac_osx_agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'mac_osx_agent_download_uri', 'URI') }
  },
  non_compliance_security_event: (form = {}, meta = {}) => {
    return { non_compliance_security_event: pfConfigurationValidatorsFromMeta(meta, 'non_compliance_security_event', i18n.t('Event')) }
  },
  oses: (form = {}, meta = {}) => {
    return { oses: pfConfigurationValidatorsFromMeta(meta, 'oses', 'OS') }
  },
  passcode: (form = {}, meta = {}) => {
    return { passcode: pfConfigurationValidatorsFromMeta(meta, 'passcode', i18n.t('Key')) }
  },
  password: (form = {}, meta = {}) => {
    return { password: pfConfigurationValidatorsFromMeta(meta, 'password', i18n.t('Secret')) }
  },
  pki_provider: (form = {}, meta = {}) => {
    return { pki_provider: pfConfigurationValidatorsFromMeta(meta, 'pki_provider', i18n.t('Provider')) }
  },
  port: (form = {}, meta = {}) => {
    return { port: pfConfigurationValidatorsFromMeta(meta, 'port', i18n.t('Port')) }
  },
  private_key: (form = {}, meta = {}) => {
    return { private_key: pfConfigurationValidatorsFromMeta(meta, 'private_key', i18n.t('Key')) }
  },
  protocol: (form = {}, meta = {}) => {
    return { protocol: pfConfigurationValidatorsFromMeta(meta, 'protocol', i18n.t('Protocol')) }
  },
  psk_size: (form = {}, meta = {}) => {
    return { psk_size: pfConfigurationValidatorsFromMeta(meta, 'psk_size', i18n.t('Length')) }
  },
  query_computers: (form = {}, meta = {}) => {},
  query_mobiledevices: (form = {}, meta = {}) => {},
  refresh_token: (form = {}, meta = {}) => {
    return { refresh_token: pfConfigurationValidatorsFromMeta(meta, 'refresh_token', i18n.t('Token')) }
  },
  security_type: (form = {}, meta = {}) => {
    return { security_type: pfConfigurationValidatorsFromMeta(meta, 'security_type', i18n.t('Type')) }
  },
  server_certificate_path: (form = {}, meta = {}) => {
    return { server_certificate_path: pfConfigurationValidatorsFromMeta(meta, 'server_certificate_path', i18n.t('Path')) }
  },
  ssid: (form = {}, meta = {}) => {
    return { ssid: pfConfigurationValidatorsFromMeta(meta, 'ssid', 'SSID') }
  },
  table_for_agent: (form = {}, meta = {}) => {
    return { table_for_agent: pfConfigurationValidatorsFromMeta(meta, 'table_for_agent', i18n.t('Agent table name')) }
  },
  table_for_mac: (form = {}, meta = {}) => {
    return { table_for_mac: pfConfigurationValidatorsFromMeta(meta, 'table_for_mac', i18n.t('Mac table name')) }
  },
  username: (form = {}, meta = {}) => {
    return { username: pfConfigurationValidatorsFromMeta(meta, 'username', i18n.t('Username')) }
  },
  win_agent_download_uri: (form = {}, meta = {}) => {
    return { win_agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'win_agent_download_uri', 'URI') }
  },
  windows_agent_download_uri: (form = {}, meta = {}) => {
    return { windows_agent_download_uri: pfConfigurationValidatorsFromMeta(meta, 'windows_agent_download_uri', 'URI') }
  },
  windows_phone_download_uri: (form = {}, meta = {}) => {
    return { windows_phone_download_uri: pfConfigurationValidatorsFromMeta(meta, 'windows_phone_download_uri', 'URI') }
  }
}

export const validators = (form = {}, meta = {}) => {
  const {
    eap_type = null,
    security_type = null
  } = form
  const {
    provisioningType = null
  } = meta
  switch (provisioningType) {
    case 'accept':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta)
      }
    case 'android':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.ssid(form, meta),
        ...validatorFields.broadcast(form, meta),
        ...validatorFields.security_type(form, meta),
        ...((security_type === 'WPA2')
          ? validatorFields.eap_type(form, meta)
          : {} // ignore
        ),
        ...((['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
          ? {
            ...validatorFields.dpsk(form, meta),
            ...validatorFields.passcode(form, meta)
          }
          : {} // ignore
        ),
        ...((security_type === 'WPA2' && ~~eap_type === 25 /* PEAP */)
          ? validatorFields.server_certificate_path(form, meta)
          : {} // ignore
        ),
        ...((security_type === 'WPA2' && ~~eap_type === 13 /* EAP-TLS */)
          ? validatorFields.pki_provider(form, meta)
          : {} // ignore
        )
      }
    case 'deny':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta)
      }
    case 'dpsk':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.ssid(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.psk_size(form, meta)
      }
    case 'ibm':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.username(form, meta),
        ...validatorFields.password(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.api_uri(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.agent_download_uri(form, meta)
      }
    case 'jamf':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.api_username(form, meta),
        ...validatorFields.api_password(form, meta),
        ...validatorFields.device_type_detection(form, meta),
        ...validatorFields.query_computers(form, meta),
        ...validatorFields.query_mobiledevices(form, meta)
      }
    case 'mobileconfig':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.ssid(form, meta),
        ...validatorFields.broadcast(form, meta),
        ...validatorFields.security_type(form, meta),
        ...((security_type === 'WPA2')
          ? validatorFields.eap_type(form, meta)
          : {} // ignore
        ),
        ...((['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
          ? {
            ...validatorFields.dpsk(form, meta),
            ...validatorFields.passcode(form, meta)
          }
          : {} // ignore
        ),
        ...((security_type === 'WPA2' && ~~eap_type === 25 /* PEAP */)
          ? validatorFields.server_certificate_path(form, meta)
          : {} // ignore
        ),
        ...((security_type === 'WPA2' && ~~eap_type === 13 /* EAP-TLS */)
          ? validatorFields.pki_provider(form, meta)
          : {} // ignore
        ),
        ...validatorFields.can_sign_profile(form, meta),
        ...validatorFields.certificate(form, meta),
        ...validatorFields.private_key(form, meta),
        ...validatorFields.cert_chain(form, meta)
      }
    case 'mobileiron':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.username(form, meta),
        ...validatorFields.password(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.android_download_uri(form, meta),
        ...validatorFields.ios_download_uri(form, meta),
        ...validatorFields.windows_phone_download_uri(form, meta),
        ...validatorFields.boarding_host(form, meta),
        ...validatorFields.boarding_port(form, meta)
      }
    case 'opswat':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.client_id(form, meta),
        ...validatorFields.client_secret(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.access_token(form, meta),
        ...validatorFields.refresh_token(form, meta),
        ...validatorFields.agent_download_uri(form, meta),
        ...validatorFields.non_compliance_security_event(form, meta),
        ...validatorFields.critical_issues_threshold(form, meta)
      }
    case 'sentinelone':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.api_username(form, meta),
        ...validatorFields.api_password(form, meta),
        ...validatorFields.win_agent_download_uri(form, meta),
        ...validatorFields.mac_osx_agent_download_uri(form, meta)
      }
    case 'sepm':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.client_id(form, meta),
        ...validatorFields.client_secret(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.access_token(form, meta),
        ...validatorFields.refresh_token(form, meta),
        ...validatorFields.agent_download_uri(form, meta),
        ...validatorFields.alt_agent_download_uri(form, meta)
      }
    case 'symantec':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.username(form, meta),
        ...validatorFields.password(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.api_uri(form, meta),
        ...validatorFields.agent_download_uri(form, meta)
      }
    case 'servicenow':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.username(form, meta),
        ...validatorFields.password(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.table_for_mac(form, meta),
        ...validatorFields.table_for_agent(form, meta)
      }
    case 'windows':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.ssid(form, meta),
        ...validatorFields.broadcast(form, meta),
        ...validatorFields.security_type(form, meta),
        ...((security_type === 'WPA2')
          ? validatorFields.eap_type(form, meta)
          : {} // ignore
        ),
        ...((['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
          ? {
            ...validatorFields.dpsk(form, meta),
            ...validatorFields.passcode(form, meta)
          }
          : {} // ignore
        ),
        ...((security_type === 'WPA2' && ~~eap_type === 25 /* PEAP */)
          ? validatorFields.server_certificate_path(form, meta)
          : {} // ignore
        ),
        ...((security_type === 'WPA2' && ~~eap_type === 13 /* EAP-TLS */)
          ? validatorFields.pki_provider(form, meta)
          : {} // ignore
        )
      }
    case 'intune':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.applicationID(form, meta),
        ...validatorFields.applicationSecret(form, meta),
        ...validatorFields.tenantID(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.loginUrl(form, meta),
        ...validatorFields.android_agent_download_uri(form, meta),
        ...validatorFields.ios_agent_download_uri(form, meta),
        ...validatorFields.windows_agent_download_uri(form, meta),
        ...validatorFields.mac_osx_agent_download_uri(form, meta),
        ...validatorFields.domains(form, meta)
      }
    default:
      return {}
  }
}
