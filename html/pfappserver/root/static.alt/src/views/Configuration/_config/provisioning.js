/* eslint-disable camelcase */
import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
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
    label: 'Identifier', // i18n defer
    required: true,
    sortable: true,
    visible: true
  },
  {
    key: 'description',
    label: 'Description', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'type',
    label: 'Type', // i18n defer
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
            ...attributesFromMeta(meta, 'id'),
            ...{
              disabled: (!isNew && !isClone)
            }
          },
          validators: {
            ...validatorsFromMeta(meta, 'id', 'ID'),
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
          attrs: attributesFromMeta(meta, 'access_token'),
          validators: validatorsFromMeta(meta, 'access_token', i18n.t('Token'))
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
          attrs: attributesFromMeta(meta, 'agent_download_uri'),
          validators: validatorsFromMeta(meta, 'agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'alt_agent_download_uri'),
          validators: validatorsFromMeta(meta, 'alt_agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'android_download_uri'),
          validators: validatorsFromMeta(meta, 'android_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'android_agent_download_uri'),
          validators: validatorsFromMeta(meta, 'android_agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'api_password'),
          validators: validatorsFromMeta(meta, 'api_password', i18n.t('Password'))
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
          attrs: attributesFromMeta(meta, 'api_username'),
          validators: validatorsFromMeta(meta, 'api_username', i18n.t('Username'))
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
          attrs: attributesFromMeta(meta, 'api_uri'),
          validators: validatorsFromMeta(meta, 'api_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'boarding_host'),
          validators: validatorsFromMeta(meta, 'boarding_host', i18n.t('Host'))
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
          attrs: attributesFromMeta(meta, 'boarding_port'),
          validators: validatorsFromMeta(meta, 'boarding_port', i18n.t('Port'))
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
  autoregister: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Auto register'),
      text: i18n.t('Whether or not devices should be automatically registered on the network if they are authorized in the provisioner.'),
      cols: [
        {
          namespace: 'autoregister',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  sync_pid: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Sync PID'),
      text: i18n.t('Whether or not the PID (username) should be synchronized from the provisioner to PacketFence.'),
      cols: [
        {
          namespace: 'sync_pid',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  enforce: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Enforce'),
      text: i18n.t('Whether or not the provisioner should be enforced. This will trigger checks to validate the device is compliant with the provisioner during RADIUS authentication and on the captive portal.'),
      cols: [
        {
          namespace: 'enforce',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  apply_role: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Apply role'),
      text: i18n.t('When enabled, this will apply the configured role to the endpoint if it is authorized in the provisioner.'),
      cols: [
        {
          namespace: 'apply_role',
          component: pfFormRangeToggle,
          attrs: {
            values: { checked: 'enabled', unchecked: 'disabled' }
          }
        }
      ]
    }
  },
  role_to_apply: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Role to apply'),
      text: i18n.t('When "Apply role" is enabled, this defines the role to apply when the device is authorized with the provisioner.'),
      cols: [
        {
          namespace: 'role_to_apply',
          component: pfFormChosen,
          attrs: attributesFromMeta(meta, 'role_to_apply'),
          validators: validatorsFromMeta(meta, 'role_to_apply', i18n.t('Role to apply'))
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
          attrs: attributesFromMeta(meta, 'category'),
          validators: validatorsFromMeta(meta, 'category', i18n.t('Roles'))
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
            ...attributesFromMeta(meta, 'cert_chain'),
            ...{
              rows: 5
            }
          },
          validators: validatorsFromMeta(meta, 'cert_chain', i18n.t('Chain'))
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
            ...attributesFromMeta(meta, 'certificate'),
            ...{
              rows: 5
            }
          },
          validators: validatorsFromMeta(meta, 'certificate', i18n.t('Certificate'))
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
          attrs: attributesFromMeta(meta, 'client_id'),
          validators: validatorsFromMeta(meta, 'client_id', i18n.t('Key'))
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
          attrs: attributesFromMeta(meta, 'client_secret'),
          validators: validatorsFromMeta(meta, 'client_secret', i18n.t('Secret'))
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
          attrs: attributesFromMeta(meta, 'applicationID'),
          validators: validatorsFromMeta(meta, 'applicationID', i18n.t('Application ID'))
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
          attrs: attributesFromMeta(meta, 'applicationSecret'),
          validators: validatorsFromMeta(meta, 'applicationSecret', i18n.t('Application Secret'))
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
          attrs: attributesFromMeta(meta, 'tenantID'),
          validators: validatorsFromMeta(meta, 'tenantID', i18n.t('Tenant ID'))
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
          attrs: attributesFromMeta(meta, 'loginUrl'),
          validators: validatorsFromMeta(meta, 'loginUrl', i18n.t('Login Url'))
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
            ...attributesFromMeta(meta, 'critical_issues_threshold'),
            ...{
              type: 'number',
              step: 1
            }
          },
          validators: validatorsFromMeta(meta, 'critical_issues_threshold', i18n.t('Threshold'))
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
          attrs: attributesFromMeta(meta, 'description'),
          validators: validatorsFromMeta(meta, 'description', i18n.t('Description'))
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
          attrs: attributesFromMeta(meta, 'domains'),
          validators: validatorsFromMeta(meta, 'domains', i18n.t('Domains'))
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
          attrs: attributesFromMeta(meta, 'eap_type'),
          validators: validatorsFromMeta(meta, 'eap_type', i18n.t('Type'))
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
          attrs: attributesFromMeta(meta, 'host'),
          validators: validatorsFromMeta(meta, 'host', i18n.t('Host'))
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
          attrs: attributesFromMeta(meta, 'ios_download_uri'),
          validators: validatorsFromMeta(meta, 'ios_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'ios_agent_download_uri'),
          validators: validatorsFromMeta(meta, 'ios_agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'mac_osx_agent_download_uri'),
          validators: validatorsFromMeta(meta, 'mac_osx_agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'non_compliance_security_event'),
          validators: validatorsFromMeta(meta, 'non_compliance_security_event', i18n.t('Event'))
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
          attrs: attributesFromMeta(meta, 'oses'),
          validators: validatorsFromMeta(meta, 'oses', 'OS')
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
          attrs: attributesFromMeta(meta, 'passcode'),
          validators: validatorsFromMeta(meta, 'passcode', i18n.t('Key'))
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
          attrs: attributesFromMeta(meta, 'password'),
          validators: validatorsFromMeta(meta, 'password', i18n.t('Secret'))
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
          attrs: attributesFromMeta(meta, 'pki_provider'),
          validators: validatorsFromMeta(meta, 'pki_provider', i18n.t('Provider'))
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
          attrs: attributesFromMeta(meta, 'port'),
          validators: validatorsFromMeta(meta, 'port', i18n.t('Port'))
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
            ...attributesFromMeta(meta, 'private_key'),
            ...{
              rows: 5
            }
          },
          validators: validatorsFromMeta(meta, 'private_key', i18n.t('Key'))
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
          attrs: attributesFromMeta(meta, 'protocol'),
          validators: validatorsFromMeta(meta, 'protocol', i18n.t('Protocol'))
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
          attrs: attributesFromMeta(meta, 'psk_size'),
          validators: validatorsFromMeta(meta, 'psk_size', i18n.t('Length'))
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
          attrs: attributesFromMeta(meta, 'refresh_token'),
          validators: validatorsFromMeta(meta, 'refresh_token', i18n.t('Token'))
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
          attrs: attributesFromMeta(meta, 'security_type'),
          validators: validatorsFromMeta(meta, 'security_type', i18n.t('Type'))
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
          attrs: attributesFromMeta(meta, 'server_certificate_path'),
          validators: validatorsFromMeta(meta, 'server_certificate_path', i18n.t('Path'))
        }
      ]
    }
  },
  ca_cert_path: (form = {}, meta = {}) => {
    return {
      label: i18n.t('RADIUS server CA path'),
      text: i18n.t('The path to the RADIUS server CA which signed the RADIUS server certificate.'),
      cols: [
        {
          namespace: 'ca_cert_path',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'ca_cert_path'),
          validators: validatorsFromMeta(meta, 'ca_cert_path', i18n.t('Path'))
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
          attrs: attributesFromMeta(meta, 'ssid'),
          validators: validatorsFromMeta(meta, 'ssid', 'SSID')
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
          attrs: attributesFromMeta(meta, 'table_for_agent'),
          validators: validatorsFromMeta(meta, 'table_for_agent', i18n.t('Agent table name'))
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
          attrs: attributesFromMeta(meta, 'table_for_mac'),
          validators: validatorsFromMeta(meta, 'table_for_mac', i18n.t('Mac table name'))
        }
      ]
    }
  },
  tenant_code: (form = {}, meta = {}) => {
    return {
      label: i18n.t('Tenant code'),
      cols: [
        {
          namespace: 'tenant_code',
          component: pfFormInput,
          attrs: attributesFromMeta(meta, 'tenant_code'),
          validators: validatorsFromMeta(meta, 'tenant_code', i18n.t('Tenant code'))
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
          attrs: attributesFromMeta(meta, 'username'),
          validators: validatorsFromMeta(meta, 'username', i18n.t('Username'))
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
          attrs: attributesFromMeta(meta, 'win_agent_download_uri'),
          validators: validatorsFromMeta(meta, 'win_agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'windows_agent_download_uri'),
          validators: validatorsFromMeta(meta, 'windows_agent_download_uri', 'URI')
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
          attrs: attributesFromMeta(meta, 'windows_phone_download_uri'),
          validators: validatorsFromMeta(meta, 'windows_phone_download_uri', 'URI')
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
              viewFields.enforce(form, meta),
              viewFields.autoregister(form, meta),
              viewFields.apply_role(form, meta),
              viewFields.role_to_apply(form, meta),
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
              ? [
                viewFields.server_certificate_path(form, meta),
                viewFields.ca_cert_path(form, meta)
                ]
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
            viewFields.sync_pid(form, meta),
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
              viewFields.enforce(form, meta),
              viewFields.autoregister(form, meta),
              viewFields.apply_role(form, meta),
              viewFields.role_to_apply(form, meta),
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
              ? [
                viewFields.server_certificate_path(form, meta),
                viewFields.ca_cert_path(form, meta)
                ]
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
              viewFields.enforce(form, meta),
              viewFields.autoregister(form, meta),
              viewFields.apply_role(form, meta),
              viewFields.role_to_apply(form, meta),
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
              ? [
                viewFields.server_certificate_path(form, meta),
                viewFields.ca_cert_path(form, meta)
                ]
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
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
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
    case 'airwatch':
      return [
        {
          tab: null, // ignore tabs
          rows: [
            viewFields.id(form, meta),
            viewFields.description(form, meta),
            viewFields.enforce(form, meta),
            viewFields.autoregister(form, meta),
            viewFields.apply_role(form, meta),
            viewFields.role_to_apply(form, meta),
            viewFields.sync_pid(form, meta),
            viewFields.category(form, meta),
            viewFields.oses(form, meta),
            viewFields.host(form, meta),
            viewFields.port(form, meta),
            viewFields.protocol(form, meta),
            viewFields.api_username(form, meta),
            viewFields.api_password(form, meta),
            viewFields.tenant_code(form, meta)
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
        ...validatorsFromMeta(meta, 'id', 'ID'),
        ...{
          [i18n.t('ID exists.')]: not(and(required, conditional(isNew || isClone), hasProvisionings, provisioningExists))
        }
      }
    }
  },
  access_token: (form = {}, meta = {}) => {
    return { access_token: validatorsFromMeta(meta, 'access_token', i18n.t('Token')) }
  },
  agent_download_uri: (form = {}, meta = {}) => {
    return { agent_download_uri: validatorsFromMeta(meta, 'agent_download_uri', 'URI') }
  },
  alt_agent_download_uri: (form = {}, meta = {}) => {
    return { alt_agent_download_uri: validatorsFromMeta(meta, 'alt_agent_download_uri', 'URI') }
  },
  android_download_uri: (form = {}, meta = {}) => {
    return { android_download_uri: validatorsFromMeta(meta, 'android_download_uri', 'URI') }
  },
  android_agent_download_uri: (form = {}, meta = {}) => {
    return { android_agent_download_uri: validatorsFromMeta(meta, 'android_agent_download_uri', 'URI') }
  },
  api_password: (form = {}, meta = {}) => {
    return { api_password: validatorsFromMeta(meta, 'api_password', i18n.t('Password')) }
  },
  api_username: (form = {}, meta = {}) => {
    return { api_username: validatorsFromMeta(meta, 'api_username', i18n.t('Username')) }
  },
  api_uri: (form = {}, meta = {}) => {
    return { api_uri: validatorsFromMeta(meta, 'api_uri', 'URI') }
  },
  tenant_code: (form = {}, meta = {}) => {
    return { tenant_code: validatorsFromMeta(meta, 'tenant_code', i18n.t('Tenant code')) }
  },
  boarding_host: (form = {}, meta = {}) => {
    return { boarding_host: validatorsFromMeta(meta, 'boarding_host', i18n.t('Host')) }
  },
  boarding_port: (form = {}, meta = {}) => {
    return { boarding_port: validatorsFromMeta(meta, 'boarding_port', i18n.t('Port')) }
  },
  broadcast: (form = {}, meta = {}) => {},
  can_sign_profile: (form = {}, meta = {}) => {},
  sync_pid: (form = {}, meta = {}) => {
    return { sync_pid: validatorsFromMeta(meta, 'sync_pid', i18n.t('Sync PID')) }
  },
  enforce: (form = {}, meta = {}) => {
    return { enforce: validatorsFromMeta(meta, 'enforce', i18n.t('Enforce')) }
  },
  autoregister: (form = {}, meta = {}) => {
    return { autoregister: validatorsFromMeta(meta, 'autoregister', i18n.t('Auto register')) }
  },
  apply_role: (form = {}, meta = {}) => {
    return { apply_role: validatorsFromMeta(meta, 'apply_role', i18n.t('Apply Role')) }
  },
  role_to_apply: (form = {}, meta = {}) => {
    return { role_to_apply: validatorsFromMeta(meta, 'role_to_apply', i18n.t('Role to apply')) }
  },
  category: (form = {}, meta = {}) => {
    return { category: validatorsFromMeta(meta, 'category', i18n.t('Roles')) }
  },
  cert_chain: (form = {}, meta = {}) => {
    return { cert_chain: validatorsFromMeta(meta, 'cert_chain', i18n.t('Chain')) }
  },
  certificate: (form = {}, meta = {}) => {
    return { certificate: validatorsFromMeta(meta, 'certificate', i18n.t('Certificate')) }
  },
  client_id: (form = {}, meta = {}) => {
    return { client_id: validatorsFromMeta(meta, 'client_id', i18n.t('Key')) }
  },
  client_secret: (form = {}, meta = {}) => {
    return { client_secret: validatorsFromMeta(meta, 'client_secret', i18n.t('Secret')) }
  },
  applicationID: (form = {}, meta = {}) => {
    return { applicationID: validatorsFromMeta(meta, 'applicationID', i18n.t('Application ID')) }
  },
  applicationSecret: (form = {}, meta = {}) => {
    return { applicationSecret: validatorsFromMeta(meta, 'applicationSecret', i18n.t('Application Secret')) }
  },
  tenantID: (form = {}, meta = {}) => {
    return { tenantID: validatorsFromMeta(meta, 'tenantID', i18n.t('Tenant ID')) }
  },
  loginUrl: (form = {}, meta = {}) => {
    return { loginUrl: validatorsFromMeta(meta, 'loginUrl', i18n.t('Login Url')) }
  },
  critical_issues_threshold: (form = {}, meta = {}) => {
    return { critical_issues_threshold: validatorsFromMeta(meta, 'critical_issues_threshold', i18n.t('Threshold')) }
  },
  description: (form = {}, meta = {}) => {
    return { description: validatorsFromMeta(meta, 'description', i18n.t('Description')) }
  },
  device_type_detection: (form = {}, meta = {}) => {},
  domains: (form = {}, meta = {}) => {
    return { domains: validatorsFromMeta(meta, 'domains', i18n.t('Domains')) }
  },
  dpsk: (form = {}, meta = {}) => {},
  eap_type: (form = {}, meta = {}) => {
    return { eap_type: validatorsFromMeta(meta, 'eap_type', i18n.t('Type')) }
  },
  host: (form = {}, meta = {}) => {
    return { host: validatorsFromMeta(meta, 'host', i18n.t('Host')) }
  },
  ios_download_uri: (form = {}, meta = {}) => {
    return { ios_download_uri: validatorsFromMeta(meta, 'ios_download_uri', 'URI') }
  },
  ios_agent_download_uri: (form = {}, meta = {}) => {
    return { ios_agent_download_uri: validatorsFromMeta(meta, 'ios_agent_download_uri', 'URI') }
  },
  mac_osx_agent_download_uri: (form = {}, meta = {}) => {
    return { mac_osx_agent_download_uri: validatorsFromMeta(meta, 'mac_osx_agent_download_uri', 'URI') }
  },
  non_compliance_security_event: (form = {}, meta = {}) => {
    return { non_compliance_security_event: validatorsFromMeta(meta, 'non_compliance_security_event', i18n.t('Event')) }
  },
  oses: (form = {}, meta = {}) => {
    return { oses: validatorsFromMeta(meta, 'oses', 'OS') }
  },
  passcode: (form = {}, meta = {}) => {
    return { passcode: validatorsFromMeta(meta, 'passcode', i18n.t('Key')) }
  },
  password: (form = {}, meta = {}) => {
    return { password: validatorsFromMeta(meta, 'password', i18n.t('Secret')) }
  },
  pki_provider: (form = {}, meta = {}) => {
    return { pki_provider: validatorsFromMeta(meta, 'pki_provider', i18n.t('Provider')) }
  },
  port: (form = {}, meta = {}) => {
    return { port: validatorsFromMeta(meta, 'port', i18n.t('Port')) }
  },
  private_key: (form = {}, meta = {}) => {
    return { private_key: validatorsFromMeta(meta, 'private_key', i18n.t('Key')) }
  },
  protocol: (form = {}, meta = {}) => {
    return { protocol: validatorsFromMeta(meta, 'protocol', i18n.t('Protocol')) }
  },
  psk_size: (form = {}, meta = {}) => {
    return { psk_size: validatorsFromMeta(meta, 'psk_size', i18n.t('Length')) }
  },
  query_computers: (form = {}, meta = {}) => {},
  query_mobiledevices: (form = {}, meta = {}) => {},
  refresh_token: (form = {}, meta = {}) => {
    return { refresh_token: validatorsFromMeta(meta, 'refresh_token', i18n.t('Token')) }
  },
  security_type: (form = {}, meta = {}) => {
    return { security_type: validatorsFromMeta(meta, 'security_type', i18n.t('Type')) }
  },
  server_certificate_path: (form = {}, meta = {}) => {
    return { server_certificate_path: validatorsFromMeta(meta, 'server_certificate_path', i18n.t('Path')) }
  },
  ca_cert_path: (form = {}, meta = {}) => {
    return { ca_cert_path: validatorsFromMeta(meta, 'ca_cert_path', i18n.t('Path')) }
  },
  ssid: (form = {}, meta = {}) => {
    return { ssid: validatorsFromMeta(meta, 'ssid', 'SSID') }
  },
  table_for_agent: (form = {}, meta = {}) => {
    return { table_for_agent: validatorsFromMeta(meta, 'table_for_agent', i18n.t('Agent table name')) }
  },
  table_for_mac: (form = {}, meta = {}) => {
    return { table_for_mac: validatorsFromMeta(meta, 'table_for_mac', i18n.t('Mac table name')) }
  },
  username: (form = {}, meta = {}) => {
    return { username: validatorsFromMeta(meta, 'username', i18n.t('Username')) }
  },
  win_agent_download_uri: (form = {}, meta = {}) => {
    return { win_agent_download_uri: validatorsFromMeta(meta, 'win_agent_download_uri', 'URI') }
  },
  windows_agent_download_uri: (form = {}, meta = {}) => {
    return { windows_agent_download_uri: validatorsFromMeta(meta, 'windows_agent_download_uri', 'URI') }
  },
  windows_phone_download_uri: (form = {}, meta = {}) => {
    return { windows_phone_download_uri: validatorsFromMeta(meta, 'windows_phone_download_uri', 'URI') }
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta)
      }
    case 'android':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
          ? {
            ...validatorFields.server_certificate_path(form, meta),
            ...validatorFields.ca_cert_path(form, meta)
          }
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta)
      }
    case 'dpsk':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.ssid(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.psk_size(form, meta)
      }
    case 'ibm':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
        ...validatorFields.sync_pid(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
          ? {
            ...validatorFields.server_certificate_path(form, meta),
            ...validatorFields.ca_cert_path(form, meta)
          }
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
          ? {
            ...validatorFields.server_certificate_path(form, meta),
            ...validatorFields.ca_cert_path(form, meta)
          }
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
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
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
    case 'airwatch':
      return {
        ...validatorFields.id(form, meta),
        ...validatorFields.description(form, meta),
        ...validatorFields.enforce(form, meta),
        ...validatorFields.autoregister(form, meta),
        ...validatorFields.apply_role(form, meta),
        ...validatorFields.role_to_apply(form, meta),
        ...validatorFields.sync_pid(form, meta),
        ...validatorFields.category(form, meta),
        ...validatorFields.oses(form, meta),
        ...validatorFields.host(form, meta),
        ...validatorFields.port(form, meta),
        ...validatorFields.protocol(form, meta),
        ...validatorFields.api_username(form, meta),
        ...validatorFields.api_password(form, meta),
        ...validatorFields.tenant_code(form, meta)
      }
    default:
      return {}
  }
}
