<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <b-tabs card nav-wrapper-class="mb-3" v-model="tabIndex">
      <template v-if="isLive">
        <tab-overview />
        <tab-networking />
        <tab-devices />
        <tab-troubleshooting :id="id" />
      </template>

      <base-form-tab :title="$i18n.t('Settings')">
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

        <form-group-fingerbank-environment namespace="fingerbank_environment"
          :column-label="$i18n.t('Fingerbank Environment')"
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
import { computed, inject, ref } from '@vue/composition-api'
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
  TabDevices,
  TabNetworking,
  TabOverview,
  TabTroubleshooting
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupNetworks,
  FormGroupSecret,
  FormGroupFingerbankEnvironment,
  TabDevices,
  TabNetworking,
  TabOverview,
  TabTroubleshooting
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
  const { tabIndex, tabs } = inject('connectorTabs')
  const { onRestart } = remote

  const isLive = computed(() => tabs.value.length > 1)

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
    onUpgrade
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
    schema,
    tabIndex,
    isLive,
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
