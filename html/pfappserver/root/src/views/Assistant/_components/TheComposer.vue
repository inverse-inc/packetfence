<template>
  <div class="the-composer">
    <div v-if="isNew" class="mb-2 text-nowrap overflow-auto">
      <b-button v-for="chip in chips" :key="chip" size="sm" variant="outline-secondary" pill class="mr-1"
        :disabled="isSending || isUnavailable" @click="$emit('send', chip)">{{ chip }}</b-button>
    </div>
    <b-input-group size="sm" class="mb-2">
      <b-input-group-prepend>
        <b-button variant="outline-primary" :pressed.sync="showDiagnose">{{ $t('Diagnose') }}</b-button>
      </b-input-group-prepend>
      <template v-if="showDiagnose">
        <b-form-input v-model="diagnose" class="text-monospace" :placeholder="$t('MAC or username')"
          @keydown.enter.prevent="onDiagnose" autocomplete="off" />
        <b-input-group-append>
          <b-button variant="primary" :disabled="!diagnose.trim() || isSending || isUnavailable" @click="onDiagnose">{{ $t('Go') }}</b-button>
        </b-input-group-append>
      </template>
    </b-input-group>
    <b-input-group>
      <b-input-group-prepend>
        <b-button variant="outline-secondary" :disabled="isUploading || isUnavailable" @click="$refs.fileRef.click()"
          v-b-tooltip.hover.top.d300 :title="$t('Attach a file (not indexed for search)')">
          <icon :name="isUploading ? 'circle-notch' : 'paperclip'" :spin="isUploading" />
        </b-button>
      </b-input-group-prepend>
      <b-form-textarea v-model="message" rows="1" max-rows="6" no-resize
        :placeholder="$t('Ask about nodes, users, configuration, or the documentation')"
        @keydown.enter.exact.prevent="onSend" />
      <b-input-group-append>
        <b-button v-if="!isSending" variant="primary" :disabled="!message.trim() || isUnavailable" @click="onSend"
          v-b-tooltip.hover.top.d300 :title="$t('Send')"><icon name="arrow-circle-right" /></b-button>
        <b-button v-else variant="danger" @click="onStop"
          v-b-tooltip.hover.top.d300 :title="isStopping ? $t('Stopping. Press again to abandon.') : $t('Stop after the current step')">
          <icon name="stop" />
        </b-button>
      </b-input-group-append>
    </b-input-group>
    <input type="file" ref="fileRef" class="d-none" multiple @change="onFiles" />
    <div class="d-flex align-items-center mt-2">
      <small class="text-muted d-none d-md-inline" v-t="'Enter to send, Shift+Enter for a new line, click a MAC to copy.'" />
      <b-dropdown size="sm" variant="outline-secondary" class="ml-auto" right dropup :disabled="!canSetModel"
        @show="onModels" v-b-tooltip.hover.top.d300 :title="canSetModel ? $t('Choose the model') : $t('Changing the model needs the CONFIGURATION_MAIN_UPDATE admin role')">
        <template #button-content>
          {{ $t('model') }}: <strong>{{ settings.model || $t('provider default') }}</strong>
        </template>
        <b-dropdown-header>{{ models.provider || settings.provider }} {{ $t('models') }}</b-dropdown-header>
        <b-dropdown-text v-if="models.loading"><icon name="circle-notch" spin /></b-dropdown-text>
        <b-dropdown-text v-else-if="models.error" class="text-danger small">{{ models.error }}</b-dropdown-text>
        <b-dropdown-item-button v-for="model in models.items" :key="model.id" :active="model.id === models.current" @click="onModel(model.id)">
          {{ model.id }} <b-badge v-if="model.recommended" variant="success" class="ml-1">{{ $t('recommended') }}</b-badge>
        </b-dropdown-item-button>
      </b-dropdown>
      <b-button size="sm" class="ml-1" :variant="debug ? 'primary' : 'outline-secondary'" :pressed="debug" @click="onDebug"
        v-b-tooltip.hover.top.d300 :title="$t('Verbose trace: tool arguments, every API request (LLM and PacketFence), sizes and timing')">
        {{ $t('trace') }}: {{ debug ? $t('verbose') : $t('standard') }}
      </b-button>
    </div>
  </div>
</template>

<script>
import { computed, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'

const chips = [
  i18n.t('show all nodes'),
  i18n.t('what are the minimum hardware requirements?'),
  i18n.t('show node 00:11:22:33:44:55'),
  i18n.t('how do I register a device?')
]

const setup = (props, context) => {
  const { emit, root: { $can, $store } = {} } = context

  const isNew = computed(() => $store.getters['$_assistant/isNew'])
  const isSending = computed(() => $store.getters['$_assistant/isSending'])
  const isStopping = computed(() => $store.getters['$_assistant/isStopping'])
  const settings = computed(() => $store.state.$_assistant.settings)
  const debug = computed(() => $store.state.$_assistant.debug)
  const canSetModel = computed(() => $can('update', 'configuration_main'))
  const isUnavailable = computed(() => $store.state.$_assistant.isAvailable === false)

  const message = ref('')
  const onSend = () => {
    if (isSending.value || isUnavailable.value || !message.value.trim())
      return
    emit('send', message.value)
    message.value = ''
  }
  const onStop = () => $store.dispatch('$_assistant/stop')

  // the agent routes "Diagnose <x>" to pf_diagnose
  const showDiagnose = ref(false)
  const diagnose = ref('')
  const onDiagnose = () => {
    const value = diagnose.value.trim()
    if (!value || isSending.value || isUnavailable.value)
      return
    emit('send', `Diagnose ${value}`)
    diagnose.value = ''
    showDiagnose.value = false
  }

  const isUploading = ref(false)
  const onFiles = event => {
    const files = [...event.target.files]
    event.target.value = ''
    if (!files.length)
      return
    isUploading.value = true
    $store.dispatch('$_assistant/upload', files).finally(() => { isUploading.value = false })
  }

  const models = ref({ items: [] })
  const onModels = () => {
    models.value = { items: [], loading: true }
    $store.dispatch('$_assistant/getModels').then(({ provider, current, models: items = [], error } = {}) => {
      models.value = { provider, current, items, error }
    })
  }
  const onModel = model => $store.dispatch('$_assistant/setModel', model)

  const onDebug = () => $store.commit('$_assistant/DEBUG', !debug.value)

  return {
    chips,
    isNew,
    isSending,
    isStopping,
    settings,
    debug,
    canSetModel,
    isUnavailable,
    message,
    onSend,
    onStop,
    showDiagnose,
    diagnose,
    onDiagnose,
    isUploading,
    onFiles,
    models,
    onModels,
    onModel,
    onDebug
  }
}

// @vue/component
export default {
  name: 'the-composer',
  setup
}
</script>
