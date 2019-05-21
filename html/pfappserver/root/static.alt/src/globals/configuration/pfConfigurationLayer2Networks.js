import i18n from '@/utils/locale'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'
import {
  and,
  not,
  conditional,
  hasLayer2Networks,
  layer2NetworkExists,
  isFQDN
} from '@/globals/pfValidators'

const {
  ipAddress,
  required
} = require('vuelidate/lib/validators')

export const pfConfigurationLayer2NetworkHtmlNote = `<div class="alert alert-warning">
  <strong>${i18n.t('Note')}</strong>
  ${i18n.t('Adding or modifying a network requires a restart of the pfdhcp and pfdns services for the changes to take place.')}
</div>`

export const pfConfigurationLayer2NetworksListColumns = [
  {
    key: 'id',
    label: i18n.t('Network'),
    sortable: false,
    visible: true
  },
  {
    key: 'dhcp_start',
    label: i18n.t('Starting IP Address'),
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_end',
    label: i18n.t('Ending IP Address'),
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_default_lease_time',
    label: i18n.t('Default Lease Time'),
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_max_lease_time',
    label: i18n.t('Max Lease Time'),
    sortable: true,
    visible: true
  },
  {
    key: 'portal_fqdn',
    label: i18n.t('Portal FQDN'),
    sortable: true,
    visible: true
  }
]

export const pfConfigurationLayer2NetworkViewFields = (context = {}) => {
  const {
    isNew = false,
    isClone = false,
    options: {
      meta = {}
    },
    form = {}
  } = context

  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Layer2 Network'),
          fields: [
            {
              key: 'id',
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
                  [i18n.t('Network exists.')]: not(and(required, conditional(isNew || isClone), hasLayer2Networks, layer2NetworkExists)),
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Starting IP Address'),
          fields: [
            {
              key: 'dhcp_start',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (form.fake_mac_enabled === '1')
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'dhcp_start', 'IP'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Ending IP Address'),
          fields: [
            {
              key: 'dhcp_end',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (form.fake_mac_enabled === '1')
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'dhcp_start', 'IP'),
                ...{
                  [i18n.t('Invalid IP Address.')]: ipAddress
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Default Lease Time'),
          fields: [
            {
              key: 'dhcp_default_lease_time',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_default_lease_time'),
                ...{
                  disabled: (form.fake_mac_enabled === '1')
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcp_default_lease_time', i18n.t('Time'))
            }
          ]
        },
        {
          label: i18n.t('Max Lease Time'),
          fields: [
            {
              key: 'dhcp_max_lease_time',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'dhcp_max_lease_time'),
                ...{
                  disabled: (form.fake_mac_enabled === '1')
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'dhcp_max_lease_time', i18n.t('Time'))
            }
          ]
        },
        {
          label: i18n.t('IP Addresses reserved'),
          text: i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.'),
          fields: [
            {
              key: 'ip_reserved',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'ip_reserved'),
                ...{
                  disabled: (form.fake_mac_enabled === '1'),
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'ip_reserved', i18n.t('Addresses'))
            }
          ]
        },
        {
          label: i18n.t('IP Addresses assigned'),
          text: i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.'),
          fields: [
            {
              key: 'ip_assigned',
              component: pfFormTextarea,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'ip_assigned'),
                ...{
                  disabled: (form.fake_mac_enabled === '1'),
                  rows: 5
                }
              },
              validators: pfConfigurationValidatorsFromMeta(meta, 'ip_assigned', i18n.t('Addresses'))
            }
          ]
        },
        {
          label: i18n.t('Portal FQDN'),
          text: i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.'),
          fields: [
            {
              key: 'portal_fqdn',
              component: pfFormInput,
              attrs: {
                ...pfConfigurationAttributesFromMeta(meta, 'portal_fqdn'),
                ...{
                  disabled: (form.fake_mac_enabled === '1')
                }
              },
              validators: {
                ...pfConfigurationValidatorsFromMeta(meta, 'portal_fqdn', 'FQDN'),
                ...{
                  [i18n.t('Invalid FQDN.')]: isFQDN
                }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          fields: [
            {
              component: pfFormHtml,
              attrs: {
                html: pfConfigurationLayer2NetworkHtmlNote
              }
            }
          ]
        }
      ]
    }
  ]
}
