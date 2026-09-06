<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs card nav-wrapper-class="mb-3">
      <b-tab v-if="!isNew && !isClone && id" :title="$i18n.t('Status')">
        <the-status :id="id" />
        <div class="card mx-3 bg-light">
          <div class="card-body">
            <b-row align-v="center">
              <b-col>
                <h6 class="mb-0">{{ $i18n.t('Remote Connector Installation') }}</h6>
                <small class="text-muted">{{ $i18n.t('Use this command to install and configure the remote connector on a target host.') }}</small>
              </b-col>
              <b-col cols="auto">
                <b-button variant="outline-primary" @click="showInstallModal = true">
                  {{ $i18n.t('Show Install Command') }}
                </b-button>
              </b-col>
            </b-row>
          </div>
        </div>

        <b-modal v-model="showInstallModal"
          size="lg"
          :title="$i18n.t('Install Remote Connector')"
          centered
        >
          <p class="mb-2">{{ $i18n.t('Run the following command on the target host to install and configure the remote connector:') }}</p>
          <b-form-textarea
            ref="commandRef"
            :value="installCommand"
            rows="3"
            readonly
            class="text-monospace bg-dark text-light"
            no-resize
          />
          <template #modal-footer="{ hide }">
            <b-button variant="secondary" @click="hide()">{{ $i18n.t('Close') }}</b-button>
            <b-button variant="primary" @click="onCopyInstallCommand">{{ $i18n.t('Copy to Clipboard') }}</b-button>
          </template>
        </b-modal>
      </b-tab>
      <b-tab v-if="!isNew && !isClone && id" :title="$i18n.t('Equipment')">
        <the-equipment :id="id" />
      </b-tab>
      <base-form-tab :title="$i18n.t('Configuration')">
        <b-tabs pills nav-wrapper-class="mb-3 mx-3">
          <base-form-tab :title="$i18n.t('Connector')" active>
            <form-group-identifier namespace="id"
              :column-label="$i18n.t('Connector ID')"
              :disabled="!isNew && !isClone"
            />

            <form-group-description namespace="description"
              :column-label="$i18n.t('Description')"
            />

            <form-group-secret namespace="secret"
              :column-label="$i18n.t('Secret')"
            />

            <form-group-networks namespace="networks"
              :column-label="$i18n.t('Networks')"
              :text="$i18n.t('Outbound networks for which this connector should be used. When a network matches multiple connectors, a top-down match is performed based on their order in the configuration. This filtering only applies when PacketFence performs outbound traffic to a server or equipment via the connector, not when receiving inbound traffic.')"
            />
          </base-form-tab>
          <base-form-tab :title="$i18n.t('Fingerbank')">
            <form-group-fingerbank-environment namespace="fingerbank_environment"
              :column-label="$i18n.t('Environment')"
            />
          </base-form-tab>
          <base-form-tab :title="$i18n.t('Networking')">
            <b-alert show variant="info" class="mx-3">
              {{ $i18n.t('The remote connector creates these VLAN interfaces on its host, assigns them the given IP address and installs the static routes. Changes are applied within a few seconds and re-applied every time the connector starts.') }}
            </b-alert>
            <form-group-interfaces namespace="interfaces"
              :column-label="$i18n.t('VLAN Interfaces')"
              :text="$i18n.t('One 802.1Q VLAN interface per row, created on top of the parent interface of the connector host and named &quot;parent.vlan&quot; (e.g. eth0.100). The IP address is written with its prefix length (e.g. 10.10.100.1/24). Enable DHCP to serve addresses on that VLAN: the connector relays the requests to the PacketFence DHCP server through its tunnel, and the server hands out the range configured here (the network is the one of the interface address). Enable DNS to make the connector answer every DNS query received on that VLAN with the interface address (captive-portal DNS).')"
            />
            <form-group-routes namespace="routes"
              :column-label="$i18n.t('Static Routes')"
              :text="$i18n.t('Optional static routes installed on the connector host. A route needs a gateway, an interface, or both. The default route cannot be managed from here.')"
            />

            <b-alert show variant="info" class="mx-3 mt-3">
              {{ $i18n.t('High availability: install this connector on two or more hosts with the same ID and secret and set a virtual IP here. The hosts form a VRRP group; the one holding the virtual IP runs the tunnel and the others stand by, mirror its credential cache and take over within seconds. Configure switches, portal redirection and DHCP relays with the virtual IP. Leave it empty for a single host.') }}
            </b-alert>
            <form-group-ha-vip namespace="ha_vip"
              :column-label="$i18n.t('Virtual IP')"
              :text="$i18n.t('IPv4 address with prefix length, on the network the connector hosts share (e.g. 10.0.0.250/24). The VLAN interface addresses above move with it.')"
            />
            <form-group-ha-vrid namespace="ha_vrid"
              :column-label="$i18n.t('VRRP virtual router id')"
              :min="1" :max="255"
              :text="$i18n.t('1 to 255, default 51. Change it only when another VRRP group uses the same id on that network.')"
            />
            <form-group-ha-interface namespace="ha_interface"
              :column-label="$i18n.t('Interface')"
              :options="haInterfaceOptions"
              :taggable="true"
              :tag-placeholder="$i18n.t('Use this interface name')"
              :placeholder="$i18n.t('Default: the interface of the default route')"
              :text="$i18n.t('Interface carrying the virtual IP and the VRRP advertisements on the connector hosts.')"
            />
          </base-form-tab>
        </b-tabs>
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed, onMounted, provide, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'
import {
  BaseForm,
  BaseFormTab
} from '@/components/new/'
import schemaFn from '../schema'
import { connectorInstallCommand } from '../_composables/useInstallCommand'
import {
  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupNetworks,
  FormGroupSecret,
  FormGroupFingerbankEnvironment,
  FormGroupInterfaces,
  FormGroupRoutes,
  FormGroupHaVip,
  FormGroupHaVrid,
  FormGroupHaInterface,
  TheStatus,
  TheEquipment,
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupNetworks,
  FormGroupSecret,
  FormGroupFingerbankEnvironment,
  FormGroupInterfaces,
  FormGroupRoutes,
  FormGroupHaVip,
  FormGroupHaVrid,
  FormGroupHaInterface,
  TheStatus,
  TheEquipment,
}

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

export const setup = (props, context) => {
  const schema = computed(() => schemaFn(props))

  const { root: { $store } = {} } = context

  const showInstallModal = ref(false)

  // Network interfaces of the connector host, as reported by the connector
  // (system info host_interfaces). Offered as choices in the Networking tab;
  // empty while the connector is disconnected, new or predates the feature.
  const hostInterfaces = ref([])
  provide('connectorHostInterfaces', hostInterfaces)
  // Choices for the interface carrying the HA virtual IP: the host's
  // non-VLAN interfaces, main (default route) one first.
  const haInterfaceOptions = computed(() => (hostInterfaces.value || [])
    .filter(({ name }) => name && !name.includes('.'))
    .map(({ name, main }) => ({ text: main ? `${name} (${i18n.t('main')})` : name, value: name }))
  )
  onMounted(() => {
    if (props.isNew || props.isClone || !props.id)
      return
    api.remoteStatus(props.id).then(response => {
      const { system: { host_interfaces: interfaces = [] } = {} } = response || {}
      hostInterfaces.value = interfaces
    }).catch(() => {
      hostInterfaces.value = []
    })
  })

  const installCommand = computed(() => {
    const { id, secret } = props.form || {}
    const server = $store.getters['system/hostname'] || window.location.hostname
    const version = $store.getters['system/version']
    return connectorInstallCommand({ id, secret, server, version })
  })

  const onCopyInstallCommand = () => {
    try {
      navigator.clipboard.writeText(installCommand.value).then(() => {
        showInstallModal.value = false
        $store.dispatch('notification/info', { message: i18n.t('Install command copied to clipboard.') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy install command to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }

  return {
    schema,
    haInterfaceOptions,
    showInstallModal,
    installCommand,
    onCopyInstallCommand
  }
}

// @vue/component
export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
