<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
    <the-status v-if="!isNew && !isClone && id"
      :id="id"
    />

    <the-equipment v-if="!isNew && !isClone && id"
      :id="id"
    />

    <div v-if="!isNew && !isClone" class="card mx-3 bg-light">
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

    <b-tabs card nav-wrapper-class="mb-3">
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
          :text="$i18n.t('One 802.1Q VLAN interface per row, created on top of the parent interface of the connector host and named &quot;parent.vlan&quot; (e.g. eth0.100). The IP address is written with its prefix length (e.g. 10.10.100.1/24).')"
        />
        <form-group-routes namespace="routes"
          :column-label="$i18n.t('Static Routes')"
          :text="$i18n.t('Optional static routes installed on the connector host. A route needs a gateway, an interface, or both. The default route cannot be managed from here.')"
        />
      </base-form-tab>
    </b-tabs>
  </base-form>
</template>
<script>
import { computed, ref } from '@vue/composition-api'
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
