import i18n from '@/utils/locale'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormPassword from '@/components/pfFormPassword'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationAttributesFromMeta,
  pfConfigurationValidatorsFromMeta
} from '@/globals/configuration/pfConfiguration'

export const pfConfigurationActiveActiveViewFields = (context = {}) => {
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
          label: i18n.t('Shared KEY'),
          text: i18n.t('Shared KEY for VRRP protocol (must be the same on all members).'),
          fields: [
            {
              key: 'password',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'password'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'password', i18n.t('Password'))
            }
          ]
        },
        {
          label: i18n.t('Virtual Router ID'),
          text: i18n.t('The virtual router id for keepalive. Leave untouched unless you have another keepalive cluster in this network. Must be between 1 and 255.'),
          fields: [
            {
              key: 'virtual_router_id',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'virtual_router_id'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'virtual_router_id', 'ID')
            }
          ]
        },
        {
          label: i18n.t('VRRP Unicast'),
          text: i18n.t('Enable keepalived in unicast mode instead of multicast.'),
          fields: [
            {
              key: 'vrrp_unicast',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('pfdns on VIP only'),
          text: i18n.t('Set the name server option in DHCP replies to point only to the VIP in cluster mode rather than to all servers in the cluster.'),
          fields: [
            {
              key: 'dns_on_vip_only',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Centralized access reevaluation'),
          text: i18n.t('Centralize the deauthentication to the management node of the cluster.'),
          fields: [
            {
              key: 'centralized_deauth',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('RADIUS authentication on management'),
          text: i18n.t('Process RADIUS authentication requests on the management server (the current load balancer). Disabling it will make the management server only proxy requests to other servers. Useful if your load balancer cannot handle both tasks. Changing this requires to restart radiusd.'),
          fields: [
            {
              key: 'auth_on_management',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Conflict resolution threshold'),
          text: i18n.t('Defines the amount of seconds after which pfmon attempts to resolve a configuration version conflict between cluster members. For example, if this is set to 5 minutes, then a resolution will be attempted when the members will be detected running a different version for more than 5 minutes.'),
          fields: [
            {
              key: 'conflict_resolution_threshold.interval',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'conflict_resolution_threshold.interval'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'conflict_resolution_threshold.interval', i18n.t('Interval'))
            },
            {
              key: 'conflict_resolution_threshold.unit',
              component: pfFormChosen,
              attrs: pfConfigurationAttributesFromMeta(meta, 'conflict_resolution_threshold.unit'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'conflict_resolution_threshold.unit', i18n.t('Unit'))
            }
          ]
        },
        {
          label: i18n.t('Galera replication'),
          text: i18n.t('Whether or not to activate galera cluster when using a cluster.'),
          fields: [
            {
              key: 'galera_replication',
              component: pfFormRangeToggle,
              attrs: {
                values: { checked: 'enabled', unchecked: 'disabled' }
              }
            }
          ]
        },
        {
          label: i18n.t('Galera replication username'),
          text: i18n.t('Defines the replication username to be used for the MariaDB Galera cluster replication.'),
          fields: [
            {
              key: 'galera_replication_username',
              component: pfFormInput,
              attrs: pfConfigurationAttributesFromMeta(meta, 'galera_replication_username'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'galera_replication_username', i18n.t('Username'))
            }
          ]
        },
        {
          label: i18n.t('Galera replication password'),
          text: i18n.t('Defines the replication password to be used for the MariaDB Galera cluster replication.'),
          fields: [
            {
              key: 'galera_replication_password',
              component: pfFormPassword,
              attrs: pfConfigurationAttributesFromMeta(meta, 'galera_replication_password'),
              validators: pfConfigurationValidatorsFromMeta(meta, 'galera_replication_password', i18n.t('Password'))
            }
          ]
        }
      ]
    }
  ]
}
