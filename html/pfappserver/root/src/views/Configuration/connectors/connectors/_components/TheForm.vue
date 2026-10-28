<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs card nav-wrapper-class="mb-3" v-model="tabIndex">
      <template v-if="isLive">
        <tab-overview :id="id" />
        <tab-networking :id="id" />
        <tab-devices />
        <tab-cache :id="id" />
        <tab-troubleshooting :id="id" />
      </template>

      <base-form-tab :title="$i18n.t('Settings')">
        <b-tabs v-model="settingsTabIndex" nav-wrapper-class="mb-3">
          <base-form-tab :title="$i18n.t('Connector')">
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

            <template v-if="!isNew && !isClone">
              <b-card class="mt-3" bg-variant="light" no-body>
                <b-card-body>
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
                </b-card-body>
              </b-card>

              <b-card v-if="isLive" class="mt-3" bg-variant="light" no-body>
                <b-card-body>
                  <b-row align-v="center">
                    <b-col>
                      <h6 class="mb-0">{{ $i18n.t('Version') }}</h6>
                      <small v-if="system" class="text-muted">
                        {{ $i18n.t('PacketFence is {central}; this connector runs {version}.', { central: (status && status.central_version) || '-', version: system.version }) }}
                      </small>
                      <small v-else class="text-muted">{{ $i18n.t('The version is reported while the tunnel is connected.') }}</small>
                    </b-col>
                    <b-col cols="auto" v-if="canUpdate && status && status.upgrade_available">
                      <b-button variant="primary" :disabled="!isConnected || isUpgrading" @click="showUpgradeModal = true">
                        <icon name="arrow-circle-up" class="mr-1" />{{ $i18n.t('Update to {version}', { version: status.central_version }) }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-card-body>
              </b-card>
            </template>
          </base-form-tab>

          <base-form-tab :title="$i18n.t('Fingerbank')">
            <form-group-fingerbank-environment namespace="fingerbank_environment"
              :column-label="$i18n.t('Environment')"
            />
          </base-form-tab>

          <base-form-tab :title="$i18n.t('Site networking')">
            <b-alert show variant="info">
              {{ $i18n.t('The connector creates these interfaces and routes on its host and keeps them applied; the interface carrying the tunnel is never reconfigured.') }}
              <base-doc-link anchor="pfconnector-site-networking" />
            </b-alert>
            <the-host-interfaces v-if="isLive" :interfaces="hostInterfaces" class="mb-3" />
            <form-group-interfaces namespace="interfaces"
              :column-label="$i18n.t('Interfaces')"
              :text="$i18n.t('A VLAN on top of an interface of the host, or a secondary interface without VLAN ID, with its address and prefix length (e.g. 10.10.100.1/24). DHCP serves the network from PacketFence, DNS answers every query with the interface address (captive portal).')"
            />
            <form-group-routes namespace="routes"
              :column-label="$i18n.t('Static Routes')"
              :text="$i18n.t('Optional static routes installed on the connector host. A route needs a gateway, an interface, or both. The default route cannot be managed from here.')"
            />

            <b-alert show variant="info" class="mt-3">
              {{ $i18n.t('High availability: install the connector on two or more hosts with the same ID and secret, and set the virtual IP they share here (empty for a single host).') }}
              <b-link v-if="isLive && form && form.ha_vip" class="text-nowrap" @click="goToTab('overview')">{{ $i18n.t('See the hosts') }}</b-link>
              <base-doc-link anchor="pfconnector-high-availability" class="ml-1" />
            </b-alert>
            <form-group-ha-vip namespace="ha_vip"
              :column-label="$i18n.t('Virtual IP')"
              :text="$i18n.t('IPv4 address with prefix length, on the network the connector hosts share (e.g. 192.0.2.250/24). The interface addresses above move with it.')"
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

          <base-form-tab :title="$i18n.t('DNS')">
            <b-alert show variant="info">
              {{ $i18n.t('DNS servers of the site reachable through this connector, with the domains each one is authoritative for. PacketFence forwards the queries for those domains to the server through the tunnel, and uses them to route hostnames under those domains (LDAP sources, Active Directory servers) to this connector. A domain can be served through one connector only; several DNS servers of this connector may serve the same domain, PacketFence then fails over between them. The tunnel port is allocated automatically.') }}
            </b-alert>
            <form-group-dns-servers namespace="dns_servers"
              :column-label="$i18n.t('DNS Servers')"
              :text="$i18n.t('One row per DNS server: its IP address on the remote site, its port (53 by default), the domains it serves (type a name and press enter) and, optionally, a fixed tunnel port in the 30000-30999 range.')"
            />
            <the-dns-test v-if="isLive" :id="id" :form="form" class="mt-3" />
          </base-form-tab>
        </b-tabs>
      </base-form-tab>
    </b-tabs>

    <b-modal v-model="showInstallModal"
      size="lg"
      :title="$i18n.t('Install Remote Connector')"
      centered
    >
      <p class="mb-2">{{ $i18n.t('Run the following command on the target host to install and configure the remote connector:') }}</p>
      <b-form-textarea
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

    <template v-if="isLive">
      <b-modal v-model="showTerminalModal"
        :title="$i18n.t('Open Remote Terminal')"
        centered
      >
        <p>{{ $i18n.t('Enter the 6-digit code from the authenticator enrolled on this connector. The code is validated by the remote connector itself.') }}</p>
        <b-form @submit.prevent="authorizeTerminal">
          <b-form-input v-model="terminalCode" class="text-monospace"
            autofocus autocomplete="one-time-code" inputmode="numeric" maxlength="6" placeholder="123456" />
        </b-form>
        <template #modal-footer="{ hide }">
          <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
          <b-button variant="primary" :disabled="isTerminalLoading || terminalCode.length !== 6" @click="authorizeTerminal">
            {{ $i18n.t('Open Terminal') }}
          </b-button>
        </template>
      </b-modal>

      <b-modal v-model="showUpgradeModal"
        :title="$i18n.t('Upgrade Remote Connector')"
        centered
      >
        <p>{{ $i18n.t('The remote connector will point its PacketFence package repository at version {version}, upgrade its packetfence-pfconnector-remote package and restart. Network activity through this connector will be interrupted for a short period. Continue?', { version: status ? status.central_version : '' }) }}</p>
        <template #modal-footer="{ hide }">
          <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
          <b-button variant="warning" :disabled="isUpgrading" @click="onUpgrade">{{ $i18n.t('Upgrade') }}</b-button>
        </template>
      </b-modal>

      <b-modal v-model="showNtlmInstallModal"
        :title="$i18n.t('Install NTLM Authentication Services')"
        centered
      >
        <p>{{ $i18n.t('The connector host will install the packetfence-ntlm-auth-join-remote and packetfence-ntlm-auth-api-remote packages from the PacketFence repository of its own version (signature-verified). The connector itself is not restarted. Continue?') }}</p>
        <template #modal-footer="{ hide }">
          <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
          <b-button variant="primary" :disabled="isInstalling" @click="onInstallNtlm">{{ $i18n.t('Install') }}</b-button>
        </template>
      </b-modal>

      <b-modal v-model="showSwitchModal"
        :title="$i18n.t('Make Another Host Active')"
        centered
      >
        <p>{{ $i18n.t('The virtual IP and the tunnel will move to {host} ({address}). This is a controlled failover: RADIUS is answered in degraded mode for a few seconds while the new host connects. Continue?', { host: switchTarget ? switchTarget.hostname : '', address: switchTarget ? switchTarget.address : '' }) }}</p>
        <template #modal-footer="{ hide }">
          <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
          <b-button variant="primary" :disabled="isSwitching" @click="onSwitchActive">{{ $i18n.t('Make active') }}</b-button>
        </template>
      </b-modal>

      <b-modal v-model="showRestartModal"
        :title="$i18n.t('Restart Remote Connector')"
        centered
        @show="restartConfirm = ''"
      >
        <p>{{ $i18n.t('The whole remote connector will be restarted (RADIUS, Fingerbank collector and tunnel included). Network activity through this connector will be interrupted for a short period. Continue?') }}</p>
        <p class="mb-1" v-html="$i18n.t('Type <code>{word}</code> to continue.', { word: restartWord })" />
        <b-form @submit.prevent="onConfirmRestart">
          <b-form-input v-model="restartConfirm" class="text-monospace" autocomplete="off" />
        </b-form>
        <template #modal-footer="{ hide }">
          <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
          <b-button variant="danger" :disabled="isRestarting || restartConfirm !== restartWord" @click="onConfirmRestart">{{ $i18n.t('Restart') }}</b-button>
        </template>
      </b-modal>
    </template>
  </base-form>
</template>
<script>
import { computed, inject, provide, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
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
  FormGroupDnsServers,
  TabCache,
  TabDevices,
  TabNetworking,
  TabOverview,
  TabTroubleshooting,
  TheDnsTest,
  TheHostInterfaces
} from './'
import BaseDocLink from './BaseDocLink'

const components = {
  BaseForm,
  BaseFormTab,
  BaseDocLink,

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
  FormGroupDnsServers,
  TabCache,
  TabDevices,
  TabNetworking,
  TabOverview,
  TabTroubleshooting,
  TheDnsTest,
  TheHostInterfaces
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

const restartWord = 'RESTART'

export const setup = (props, context) => {
  const schema = computed(() => schemaFn(props))

  const { root: { $store } = {} } = context

  const remote = inject('connectorRemote')
  const { tabIndex, tabs, settingsTabIndex, goToTab } = inject('connectorTabs')
  const { onRestart } = remote

  const isLive = computed(() => tabs.value.length > 1)

  // Network interfaces of the connector host, as reported by the connector
  // (system info host_interfaces): choices of the Networking settings, empty
  // while the connector is disconnected, new or predates the feature.
  const hostInterfaces = computed(() => {
    const { host_interfaces: interfaces } = remote.system.value || {}
    return Array.isArray(interfaces) ? interfaces : []
  })
  provide('connectorHostInterfaces', hostInterfaces)
  // Choices for the interface carrying the HA virtual IP: the host's
  // non-VLAN interfaces, main (default route) one first.
  const haInterfaceOptions = computed(() => hostInterfaces.value
    .filter(({ name }) => name && !name.includes('.'))
    .map(({ name, main }) => ({ text: main ? `${name} (${i18n.t('main')})` : name, value: name }))
  )

  const showInstallModal = ref(false)

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

  const restartConfirm = ref('')
  const onConfirmRestart = () => {
    if (restartConfirm.value === restartWord)
      onRestart()
  }

  // not spread: remote.isLoading would shadow the isLoading prop
  const {
    status,
    system,
    isConnected,
    canUpdate,
    isUpgrading,
    isRestarting,
    isTerminalLoading,
    showTerminalModal,
    showUpgradeModal,
    showRestartModal,
    terminalCode,
    authorizeTerminal,
    onUpgrade,
    isInstalling,
    showNtlmInstallModal,
    onInstallNtlm,
    isSwitching,
    showSwitchModal,
    switchTarget,
    onSwitchActive
  } = remote

  return {
    status,
    system,
    isConnected,
    canUpdate,
    isUpgrading,
    isRestarting,
    isTerminalLoading,
    showTerminalModal,
    showUpgradeModal,
    showRestartModal,
    terminalCode,
    authorizeTerminal,
    onUpgrade,
    isInstalling,
    showNtlmInstallModal,
    onInstallNtlm,
    isSwitching,
    showSwitchModal,
    switchTarget,
    onSwitchActive,
    schema,
    tabIndex,
    settingsTabIndex,
    goToTab,
    isLive,
    hostInterfaces,
    haInterfaceOptions,
    showInstallModal,
    installCommand,
    onCopyInstallCommand,
    restartWord,
    restartConfirm,
    onConfirmRestart
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
