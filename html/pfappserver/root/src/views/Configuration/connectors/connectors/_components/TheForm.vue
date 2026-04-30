<template>
  <base-form
    :form="form"
    :meta="meta"
    :schema="schema"
    :isLoading="isLoading"
  >
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
import {
  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupNetworks,
  FormGroupSecret,
  FormGroupFingerbankEnvironment,
} from './'

const components = {
  BaseForm,
  BaseFormTab,

  FormGroupIdentifier,
  FormGroupDescription,
  FormGroupNetworks,
  FormGroupSecret,
  FormGroupFingerbankEnvironment,
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
    return `curl -sL https://proxy.saas.packetfence.com/connector-remote-install.sh | bash -s -- ${id || ''} ${secret || ''} ${server}`
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
