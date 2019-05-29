import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationRadiusViewFields = (context = {}) => {
  const {
    options: {
      meta = {}
    },
    form = {}
  } = context
  return [
    {
      tab: i18n.t('General'),
      fields: [
        {
          label: i18n.t('EAP Auth Types'),
          text: i18n.t('Supported EAP Authentication Methods.'),
          fields: [
            {
              key: 'eap_authentication_types',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'eap_authentication_types'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'eap_authentication_types', i18n.t('Types'))
            }
          ]
        },
        {
          label: i18n.t('EAP FAST Key'),
          text: i18n.t('EAP-FAST Opaque Key (32 randomized bytes).'),
          fields: [
            {
              key: 'eap_fast_opaque_key',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'eap_fast_opaque_key'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'eap_fast_opaque_key', i18n.t('Key'))
            }
          ]
        },
        {
          label: i18n.t('EAP FAST Authority Identity'),
          text: i18n.t('EAP-FAST authority ID.'),
          fields: [
            {
              key: 'eap_fast_authority_identity',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'eap_fast_authority_identity'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'eap_fast_authority_identity', i18n.t('Identity'))
            }
          ]
        },
        {
          label: i18n.t('Record accounting in SQL tables'),
          text: i18n.t('Record the accounting data in the SQL tables. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'record_accounting_in_sql',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in packetfence authorize'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.authorize section. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'filter_in_packetfence_authorize',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in packetfence pre_proxy'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.pre_proxy section. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'filter_in_packetfence_pre_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in packetfence post_proxy'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.post_proxy section. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'filter_in_packetfence_post_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in packetfence preacct'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.preacct section. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'filter_in_packetfence_preacct',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in packetfence accounting'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence.accounting section. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'filter_in_packetfence_accounting',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in packetfence-tunnel authorize'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS packetfence-tunnel.authorize section. Requires a restart of radiusd to be effective.'),
          fields: [
            {
              key: 'filter_in_packetfence-tunnel_authorize',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('NTLM Redis cache'),
          text: i18n.t('Enables a Redis driven cache for NTLM authentication.In order for this to work, you need to setup proper NT hash syncronization between your PacketFence server and your AD. Refer to the Administration guide for more details. Applying this requires a restart of radiusd.'),
          fields: [
            {
              key: 'ntlm_redis_cache',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('RADIUS attributes'),
          text: i18n.t('List of RADIUS attributes that can be used in the sources configuration.'),
          fields: [
            {
              key: 'radius_attributes',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'radius_attributes'),
                ...{
                  placeholderHtml: true,
                  labelHtml: i18n.t('Built-in RADIUS Attributes'),
                  rows: 3
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'radius_attributes', i18n.t('Attributes'))
            }
          ]
        },
        {
          label: i18n.t('RADIUS machine auth with username'),
          text: i18n.t('Use the RADIUS username instead of the TLS certificate common name when doing machine authentication.'),
          fields: [
            {
              key: 'normalize_radius_machine_auth_username',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Username attributes'),
          text: i18n.t('Which attributes to use to get the username from a RADIUS request. The order of the attributes are listed in this configuration parameter is followed while performing the lookup.'),
          fields: [
            {
              key: 'username_attributes',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'username_attributes'),
                ...{
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'username_attributes', i18n.t('Attributes'))
            }
          ]
        }
      ]
    },
    {
      tab: 'OCSP',
      fields: [
        {
          label: i18n.t('Enable'),
          text: i18n.t('Enable OCSP checking.'),
          fields: [
            {
              key: 'ocsp_enable',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          label: i18n.t('Override Responder URL'),
          text: i18n.t('Override the OCSP Responder URL from the certificate.'),
          fields: [
            {
              key: 'ocsp_override_cert_url',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          if: form.ocsp_override_cert_url === 'yes',
          label: i18n.t('Responder URL'),
          text: i18n.t('The overridden OCSP Responder URL.'),
          fields: [
            {
              key: 'ocsp_url',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'ocsp_url'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'ocsp_url', i18n.t('URL'))
            }
          ]
        },
        {
          label: i18n.t('Use nonce'),
          text: i18n.t('If the OCSP Responder can not cope with nonce in the request, then it can be disabled here.'),
          fields: [
            {
              key: 'ocsp_use_nonce',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'yes', unchecked: 'no' }
              }
            }
          ]
        },
        {
          label: i18n.t('Response timeout'),
          text: i18n.t('Number of seconds to wait for the OCSP response. 0 uses system default.'),
          fields: [
            {
              key: 'ocsp_timeout',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'ocsp_timeout'),
                ...{
                  type: 'number',
                  step: 1
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'ocsp_timeout', i18n.t('Timeout'))
            }
          ]
        },
        {
          label: i18n.t('Response softfail'),
          text: i18n.t(`Treat OCSP response errors as 'soft' failures and still accept the certificate.`),
          fields: [
            {
              key: 'ocsp_softfail',
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
