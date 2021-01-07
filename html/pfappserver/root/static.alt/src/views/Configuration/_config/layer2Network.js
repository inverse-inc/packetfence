import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormHtml from '@/components/pfFormHtml'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import {
  and,
  not,
  conditional,
  hasLayer2Networks,
  layer2NetworkExists,
  isFQDN
} from '@/globals/pfValidators'
import {
  required,
  ipAddress
} from 'vuelidate/lib/validators'

export const htmlNote = `<div class="alert alert-warning">
  <strong>${i18n.t('Note')}</strong>
  ${i18n.t('Adding or modifying a network requires a restart of the pfdhcp and pfdns services for the changes to take place.')}
</div>`

export const columns = [
  {
    key: 'id',
    label: 'Network', // i18n defer
    sortable: true,
    visible: true,
    required: true
  },
  {
    key: 'algorithm',
    label: 'Algorithm', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'pool_backend',
    label: 'Backend', // i18n defer
    sortable: true,
    visible: true,
  },
  {
    key: 'dhcp_start',
    label: 'Starting IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_end',
    label: 'Ending IP Address', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_default_lease_time',
    label: 'Default Lease Time', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'dhcp_max_lease_time',
    label: 'Max Lease Time', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'portal_fqdn',
    label: 'Portal FQDN', // i18n defer
    sortable: true,
    visible: true
  },
  {
    key: 'netflow_accounting_enabled',
    label: 'Netflow Accounting Enabled', // i18n defer
    sortable: true,
    visible: true
  },
]

export const view = (form = {}, meta = {}) => {
  const {
    fake_mac_enabled,
    type
  } = form
  const {
    isNew = false
  } = meta
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Layer2 Network'),
          cols: [
            {
              namespace: 'id',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'id'),
                ...{
                  disabled: (!isNew)
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Algorithm'),
          cols: [
            {
              namespace: 'algorithm',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'algorithm'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: i18n.t('DHCP Pool Backend Type'),
          cols: [
            {
              namespace: 'pool_backend',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'pool_backend'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Starting IP Address'),
          cols: [
            {
              namespace: 'dhcp_start',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Ending IP Address'),
          cols: [
            {
              namespace: 'dhcp_end',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_start'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Default Lease Time'),
          cols: [
            {
              namespace: 'dhcp_default_lease_time',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_default_lease_time'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Max Lease Time'),
          cols: [
            {
              namespace: 'dhcp_max_lease_time',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'dhcp_max_lease_time'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          label: i18n.t('IP Addresses reserved'),
          text: i18n.t('Range like 192.168.0.1-192.168.0.20 and or IP like 192.168.0.22,192.168.0.24 will be excluded from the DHCP pool.'),
          cols: [
            {
              namespace: 'ip_reserved',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'ip_reserved'),
                ...{
                  disabled: (fake_mac_enabled === '1'),
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: i18n.t('IP Addresses assigned'),
          text: i18n.t('List like 00:11:22:33:44:55:192.168.0.12,11:22:33:44:55:66:192.168.0.13.'),
          cols: [
            {
              namespace: 'ip_assigned',
              component: pfFormTextarea,
              attrs: {
                ...attributesFromMeta(meta, 'ip_assigned'),
                ...{
                  disabled: (fake_mac_enabled === '1'),
                  rows: 5
                }
              }
            }
          ]
        },
        {
          label: i18n.t('Portal FQDN'),
          text: i18n.t('Define the FQDN of the portal for this network. Leaving empty will use the FQDN of the PacketFence server.'),
          cols: [
            {
              namespace: 'portal_fqdn',
              component: pfFormInput,
              attrs: {
                ...attributesFromMeta(meta, 'portal_fqdn'),
                ...{
                  disabled: (fake_mac_enabled === '1')
                }
              }
            }
          ]
        },
        {
          if: type === 'inlinel2',
          label: i18n.t('Netflow Accounting Enabled'),
          text: i18n.t('Enable Netflow on this network to enable accounting.'),
          cols: [
            {
              namespace: 'netflow_accounting_enabled',
              component: pfFormRangeToggle,
              attrs: {
                ...attributesFromMeta(meta, 'netflow_accounting_enabled'),
                ...{
                  values: { checked: 'enabled', unchecked: 'disabled' }
                }
              }
            }
          ]
        },
        {
          label: null, /* no label */
          cols: [
            {
              component: pfFormHtml,
              attrs: {
                html: htmlNote
              }
            }
          ]
        }
      ]
    }
  ]
}
export const validators = (_, meta = {}) => {
  const {
    isNew = false
  } = meta
  return {
    id: {
      ...validatorsFromMeta(meta, 'id', 'ID'),
      ...{
        [i18n.t('Network exists.')]: not(and(required, conditional(isNew), hasLayer2Networks, layer2NetworkExists)),
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    algorithm: validatorsFromMeta(meta, 'algorithm', i18n.t('Algorithm')),
    pool_backend: validatorsFromMeta(meta, 'pool_backend', i18n.t('DHCP Pool Backend Type')),
    dhcp_start: {
      ...validatorsFromMeta(meta, 'dhcp_start', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    dhcp_end: {
      ...validatorsFromMeta(meta, 'dhcp_end', 'IP'),
      ...{
        [i18n.t('Invalid IP Address.')]: ipAddress
      }
    },
    dhcp_default_lease_time: validatorsFromMeta(meta, 'dhcp_default_lease_time', i18n.t('Time')),
    dhcp_max_lease_time: validatorsFromMeta(meta, 'dhcp_max_lease_time', i18n.t('Time')),
    ip_reserved: validatorsFromMeta(meta, 'ip_reserved', i18n.t('Addresses')),
    ip_assigned: validatorsFromMeta(meta, 'ip_assigned', i18n.t('Addresses')),
    portal_fqdn: {
      ...validatorsFromMeta(meta, 'portal_fqdn', 'FQDN'),
      ...{
        [i18n.t('Invalid FQDN.')]: isFQDN
      }
    }
  }
}
