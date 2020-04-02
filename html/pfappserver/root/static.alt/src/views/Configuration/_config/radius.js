import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: i18n.t('General'),
      rows: [
        {
          label: 'EAP Auth Types', // i18n defer
          text: i18n.t('Supported EAP Authentication Methods.'),
          cols: [
            {
              namespace: 'eap_authentication_types',
              component: pfFormChosen,
              attrs: attributesFromMeta(meta, 'eap_authentication_types')
            }
          ]
        },
        {
          label: 'EAP FAST Key', // i18n defer
          text: i18n.t('EAP-FAST Opaque Key (32 randomized bytes).'),
          cols: [
            {
              namespace: 'eap_fast_opaque_key',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'eap_fast_opaque_key')
            }
          ]
        },
        {
          label: 'EAP FAST Authority Identity', // i18n defer
          text: i18n.t('EAP-FAST authority ID.'),
          cols: [
            {
              namespace: 'eap_fast_authority_identity',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'eap_fast_authority_identity')
            }
          ]
        },
        {
          label: 'Record accounting in SQL tables', // i18n defer
          text: i18n.t('Record the accounting data in the SQL tables. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'record_accounting_in_sql',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Use RADIUS filters in packetfence authorize', // i18n defer
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.authorize section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_packetfence_authorize',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Use RADIUS filters in packetfence pre_proxy', // i18n defer
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.pre_proxy section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_packetfence_pre_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Use RADIUS filters in packetfence post_proxy', // i18n defer
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.post_proxy section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_packetfence_post_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Use RADIUS filters in packetfence preacct', // i18n defer
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.preacct section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_packetfence_preacct',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Use RADIUS filters in packetfence accounting', // i18n defer
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.accounting section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_packetfence_accounting',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Use RADIUS filters in packetfence-tunnel authorize', // i18n defer
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence-tunnel.authorize section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_packetfence-tunnel_authorize',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'NTLM Redis cache', // i18n defer
          text: i18n.t('Enables a Redis driven cache for NTLM authentication.In order for this to work, you need to setup proper NT hash syncronization between your PacketFence server and your AD. Refer to the Administration guide for more details. Applying this requires a restart of radiusd.'),
          cols: [
            {
              namespace: 'ntlm_redis_cache',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'RADIUS attributes', // i18n defer
          text: i18n.t('List of RADIUS attributes that can be used in the sources configuration.'),
          cols: [
            {
              namespace: 'radius_attributes',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'radius_attributes'),
                ...{
                  placeholderHtml: true,
                  labelHtml: i18n.t('Built-in RADIUS Attributes'),
                  rows: 3
                }
              }
            }
          ]
        },
        {
          label: 'RADIUS machine auth with username', // i18n defer
          text: i18n.t('Use the RADIUS username instead of the TLS certificate common name when doing machine authentication.'),
          cols: [
            {
              namespace: 'normalize_radius_machine_auth_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: 'Username attributes', // i18n defer
          text: i18n.t('Which attributes to use to get the username from a RADIUS request. The order of the attributes are listed in this configuration parameter is followed while performing the lookup.'),
          cols: [
            {
              namespace: 'username_attributes',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'username_attributes'),
                ...{
                  rows: 5
                }
              }
            }
          ]
        }
      ]
    },
    {
      tab: 'OCSP',
      rows: [
        {
          label: 'Enable', // i18n defer
          text: i18n.t('Enable OCSP checking.'),
          cols: [
            {
              namespace: 'ocsp_enable',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          label: 'Override Responder URL', // i18n defer
          text: i18n.t('Override the OCSP Responder URL from the certificate.'),
          cols: [
            {
              namespace: 'ocsp_override_cert_url',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          if: form.ocsp_override_cert_url === 'yes',
          label: 'Responder URL', // i18n defer
          text: i18n.t('The overridden OCSP Responder URL.'),
          cols: [
            {
              namespace: 'ocsp_url',
              component: pfFormInput,
              attrs: attributesFromMeta(meta, 'ocsp_url')
            }
          ]
        },
        {
          label: 'Use nonce', // i18n defer
          text: i18n.t('If the OCSP Responder can not cope with nonce in the request, then it can be disabled here.'),
          cols: [
            {
              namespace: 'ocsp_use_nonce',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          label: 'Response timeout', // i18n defer
          text: i18n.t('Number of seconds to wait for the OCSP response. 0 uses system default.'),
          cols: [
            {
              namespace: 'ocsp_timeout',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'ocsp_timeout'),
                ...{
                  type: 'number',
                  step: 1
                }
              }
            }
          ]
        },
        {
          label: 'Response softfail', // i18n defer
          text: i18n.t(`Treat OCSP response errors as 'soft' failures and still accept the certificate.`),
          cols: [
            {
              namespace: 'ocsp_softfail',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  return {
    eap_authentication_types: validatorsFromMeta(meta, 'eap_authentication_types', i18n.t('Types')),
    eap_fast_opaque_key: validatorsFromMeta(meta, 'eap_fast_opaque_key', i18n.t('Key')),
    eap_fast_authority_identity: validatorsFromMeta(meta, 'eap_fast_authority_identity', i18n.t('Identity')),
    radius_attributes: validatorsFromMeta(meta, 'radius_attributes', i18n.t('Attributes')),
    username_attributes: validatorsFromMeta(meta, 'username_attributes', i18n.t('Attributes')),
    ocsp_url: validatorsFromMeta(meta, 'ocsp_url', i18n.t('URL')),
    ocsp_timeout: validatorsFromMeta(meta, 'ocsp_timeout', i18n.t('Timeout'))
  }
}
