import i18n from '@/utils/locale'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  attributesFromMeta,
  validatorsFromMeta
} from '../'

export const view = (_, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Record accounting in SQL tables'),
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
          label: i18n.t('Use RADIUS filters in packetfence authorize'),
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
          label: i18n.t('Use RADIUS filters in packetfence pre_proxy'),
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
          label: i18n.t('Use RADIUS filters in packetfence post_proxy'),
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
          label: i18n.t('Use RADIUS filters in packetfence preacct'),
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
          label: i18n.t('Use RADIUS filters in packetfence accounting'),
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
          label: i18n.t('Use RADIUS filters in packetfence-tunnel authorize'),
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
          label: i18n.t('Use RADIUS filters in eduroam authorize'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.authorize section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_eduroam_authorize',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in eduroam pre_proxy'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.pre_proxy section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_eduroam_pre_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in eduroam post_proxy'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.post_proxy section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_eduroam_post_proxy',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Use RADIUS filters in eduroam preacct'),
          text: i18n.t('Send the RADIUS request in the RADIUS filter from the RADIUS eduroam.preacct section. Requires a restart of radiusd to be effective.'),
          cols: [
            {
              namespace: 'filter_in_eduroam_preacct',
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
          label: i18n.t('RADIUS attributes'),
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
          label: i18n.t('RADIUS machine auth with username'),
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
          label: i18n.t('Username attributes'),
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
    }
  ]
}

export const validators = (_, meta = {}) => {
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
