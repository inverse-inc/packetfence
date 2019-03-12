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
    }
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('EAP Auth Types'),
          text: i18n.t('Supported EAP Authentication Methods.'),
          fields: [
            {
              key: 'eap_authentication_types',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'eap_authentication_types'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'eap_authentication_types', 'Types')
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
              validators: pfConfigurationValidatorsFromMeta(meta, 'eap_fast_opaque_key', 'Key')
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
              validators: pfConfigurationValidatorsFromMeta(meta, 'eap_fast_authority_identity', 'Identity')
            }
          ]
        },
        {
          label: i18n.t('Record accounting in SQL tables'),
          text: i18n.t('Record the accounting data in the SQL tables.Requires a restart of radiusd to be effective.'),
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
          label: i18n.t('Use radius filters in packetfence authorize'),
          text: i18n.t('Send the radius request in the radius filter from the radius packetfence.authorize section.Requires a restart of radiusd to be effective.'),
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
          label: i18n.t('Use radius filters in packetfence pre_proxy'),
          text: i18n.t('Send the radius request in the radius filter from the radius packetfence.pre_proxy section.Requires a restart of radiusd to be effective.'),
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
          label: i18n.t('Use radius filters in packetfence post_proxy'),
          text: i18n.t('Send the radius request in the radius filter from the radius packetfence.post_proxy section.Requires a restart of radiusd to be effective.'),
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
          label: i18n.t('Use radius filters in packetfence preacct'),
          text: i18n.t('Send the radius request in the radius filter from the radius packetfence.preacct section.Requires a restart of radiusd to be effective.'),
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
          label: i18n.t('Use radius filters in packetfence accounting'),
          text: i18n.t('Send the radius request in the radius filter from the radius packetfence.accounting section.Requires a restart of radiusd to be effective.'),
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
          label: i18n.t('Use radius filters in packetfence-tunnel authorize'),
          text: i18n.t('Send the radius request in the radius filter from the radius packetfence-tunnel.authorize section.Requires a restart of radiusd to be effective.'),
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
          text: i18n.t('Enables a Redis driven cache for NTLM authentication.In order for this to work, you need to setup proper NT hash syncronization between your PacketFence server and your AD.Refer to the Administration guide for more details.Applying this requires a restart of radiusd.'),
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
              validators: pfConfigurationValidatorsFromMeta(meta, 'radius_attributes', 'Attributes')
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
          text: i18n.t('Which attributes to use to get the username from a RADIUS requestThe order of the attributes are listed in this configuration parameter is followed while performing the lookup.'),
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
              validators: pfConfigurationValidatorsFromMeta(meta, 'username_attributes', 'Attributes')
            }
          ]
        }
      ]
    }
  ]
}
