<template>
  <b-row class="the-assistant">
    <b-col cols="12" md="3" xl="2" class="mb-3">
      <the-threads />
    </b-col>
    <b-col cols="12" :md="sidePane ? 6 : 9" :xl="sidePane ? 7 : 10">
      <b-card no-body class="the-assistant-card">
        <b-card-header class="d-flex align-items-center">
          <div>
            <h4 class="mb-0 the-assistant-title d-flex align-items-center">
              <span v-t="'NACBot'" />
              <span class="the-assistant-status ml-2" :class="statusClass" role="img"
                :aria-label="statusTitle" v-b-tooltip.hover.bottom.d300 :title="statusTitle" />
            </h4>
            <small class="text-muted">
              <template v-if="pfVersion">PacketFence {{ pfVersion }}</template>
              <template v-if="settings.provider"> &middot; <span v-b-tooltip.hover.bottom.d300 :title="settings.provider">{{ settings.model || $t('provider default') }}</span></template>
              <template v-else-if="isAvailable">
                &middot; {{ $t("No LLM provider configured.") }}
                <b-link v-if="canConfigure" to="/configuration/pfchatbot">{{ $t("Configure") }}</b-link>
              </template>
            </small>
          </div>
          <div class="ml-auto d-flex align-items-center">
            <div class="the-assistant-tools d-flex" role="group" :aria-label="$t('NACBot tools')">
              <b-button variant="link" class="the-assistant-tool" :class="{ active: sidePane === 'files' }"
                :aria-pressed="sidePane === 'files' ? 'true' : 'false'" @click="toggleSidePane('files')"
                v-b-tooltip.hover.bottom.d300 :title="$t('Files in this conversation')">
                <icon name="book-open" />
              </b-button>
              <b-button variant="link" class="the-assistant-tool" :class="{ active: showUsage }" @click="showUsage = true"
                v-b-tooltip.hover.bottom.d300 :title="$t('Token usage')">
                <icon name="chart-bar" />
              </b-button>
              <b-button variant="link" class="the-assistant-tool" :class="{ active: showTestTools }" @click="openTestTools()"
                v-b-tooltip.hover.bottom.d300 :title="$t('Test tools (802.1X / RADIUS)')">
                <icon name="wrench" />
              </b-button>
              <b-button variant="link" class="the-assistant-tool" :class="{ active: showLogs }" @click="showLogs = true"
                v-b-tooltip.hover.bottom.d300 :title="$t('Service logs')">
                <icon name="file-code" />
              </b-button>
            </div>
            <b-button variant="link" class="the-assistant-tool the-assistant-tool-solo ml-2" to="/configuration/pfchatbot" v-if="canConfigure"
              v-b-tooltip.hover.bottom.d300 :title="$t('Provider settings')">
              <icon name="cog" />
            </b-button>
          </div>
          <!-- the header slider (AppAssistant) adds its close/fullscreen controls here -->
          <slot name="header-actions" />
        </b-card-header>
        <div class="the-assistant-log p-3" ref="logRef" @click="onLogClick">
          <b-alert :show="isAvailable === false" variant="danger">
            <strong>{{ $t('The NACBot service is not reachable.') }}</strong> {{ availabilityError }}
            <div class="small mt-1">{{ $t('Check that the packetfence-chatbot service is running and that /api/v1/pfchatbot is routed by the admin API.') }}</div>
          </b-alert>
          <the-entry v-if="isNew && isAvailable !== false" :entry="greeting" />
          <the-entry v-for="entry in entries" :key="entry.key" :entry="entry"
            @send="send" @inspect="sidePane = 'node'" />
          <div v-if="isSending" class="small text-muted text-monospace">
            <icon name="circle-notch" spin class="mr-1" />
            {{ isStopping ? $t('stopping after the current step') : $t('working') }} {{ elapsed }}s
          </div>
        </div>
        <b-card-footer>
          <the-composer @send="send" @capture="openTestTools" />
        </b-card-footer>
      </b-card>
    </b-col>
    <b-col cols="12" md="3" v-if="sidePane">
      <the-node-inspector v-if="sidePane === 'node'" @send="send" @close="sidePane = null" />
      <the-files v-if="sidePane === 'files'" @close="sidePane = null" />
    </b-col>
    <the-journal-logs v-model="showLogs" />
    <the-usage v-model="showUsage" />
    <the-test-tools v-model="showTestTools" :prepare="testToolsPrepare" @send="send" />
  </b-row>
</template>

<script>
import 'vue-awesome/icons/book-open'
import 'vue-awesome/icons/wrench'
import { computed, nextTick, onBeforeUnmount, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import TheComposer from './TheComposer'
import TheEntry from './TheEntry'
import TheFiles from './TheFiles'
import TheNodeInspector from './TheNodeInspector'
import TheTestTools from './TheTestTools'
import TheThreads from './TheThreads'
import TheJournalLogs from './TheJournalLogs'
import TheUsage from './TheUsage'

const components = {
  TheComposer,
  TheEntry,
  TheFiles,
  TheNodeInspector,
  TheJournalLogs,
  TheTestTools,
  TheThreads,
  TheUsage
}

const greeting = {
  type: 'bot',
  content: i18n.t('NACBot ready. Ask about live data, the documentation, or pick a shortcut below.')
}

const setup = (props, context) => {
  const { refs, root: { $can, $store } = {} } = context

  $store.dispatch('$_assistant/init')

  const entries = computed(() => $store.state.$_assistant.entries)
  const isNew = computed(() => $store.getters['$_assistant/isNew'])
  const isSending = computed(() => $store.getters['$_assistant/isSending'])
  const isStopping = computed(() => $store.getters['$_assistant/isStopping'])
  const settings = computed(() => $store.state.$_assistant.settings)
  const pfVersion = computed(() => $store.state.$_assistant.pfVersion)
  const isAvailable = computed(() => $store.state.$_assistant.isAvailable)
  const availabilityError = computed(() => $store.state.$_assistant.availabilityError)
  const nodeActions = computed(() => $store.state.$_assistant.nodeActions)
  const canConfigure = computed(() => $can('update', 'configuration_main'))
  // header dot: green when the service answers, red when it does not, grey until known
  const statusClass = computed(() => ({ true: 'is-up', false: 'is-down' })[String(isAvailable.value)] || 'is-unknown')
  const statusTitle = computed(() => ({
    'is-up': i18n.t('NACBot service is reachable'),
    'is-down': i18n.t('NACBot service is not reachable')
  })[statusClass.value] || i18n.t('Checking the NACBot service'))

  const sidePane = ref(null)
  const toggleSidePane = pane => {
    sidePane.value = (sidePane.value === pane) ? null : pane
  }
  // a single-node lookup docks the inspector
  watch(nodeActions, node => {
    if (node)
      sidePane.value = 'node'
    else if (sidePane.value === 'node')
      sidePane.value = null
  })

  const scrollDown = () => nextTick(() => {
    const { logRef } = refs
    if (logRef)
      logRef.scrollTop = logRef.scrollHeight
  })
  watch(() => entries.value.length, scrollDown)

  const elapsed = ref(0)
  let timer = null
  watch(isSending, sending => {
    clearInterval(timer)
    elapsed.value = 0
    if (sending) {
      const t0 = Date.now()
      timer = setInterval(() => { elapsed.value = Math.round((Date.now() - t0) / 1000) }, 1000)
    }
    scrollDown()
  })
  onBeforeUnmount(() => clearInterval(timer))

  const send = message => $store.dispatch('$_assistant/send', { message, debug: $store.state.$_assistant.debug })
    .then((response = {}) => {
      const { prepare_test, prepare_capture } = response
      if (prepare_test)
        openTestTools({ ...prepare_test })
      else if (prepare_capture)
        openTestTools({ tool: 'tcpdump', fields: prepare_capture })
    })

  const showLogs = ref(false)
  const showUsage = ref(false)
  const showTestTools = ref(false)
  const testToolsPrepare = ref(null)
  const openTestTools = (prepare = null) => {
    testToolsPrepare.value = prepare
    showTestTools.value = true
  }

  // MACs in replies copy on click
  const onLogClick = event => {
    const { target } = event
    if (target && target.tagName === 'CODE' && target.classList.contains('mac')) {
      navigator.clipboard.writeText(target.textContent).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('{mac} copied to clipboard', { mac: target.textContent }) })
      })
    }
  }

  return {
    greeting,
    entries,
    isNew,
    isSending,
    isStopping,
    elapsed,
    settings,
    pfVersion,
    isAvailable,
    availabilityError,
    canConfigure,
    statusClass,
    statusTitle,
    sidePane,
    toggleSidePane,
    send,
    showLogs,
    showUsage,
    showTestTools,
    testToolsPrepare,
    openTestTools,
    onLogClick
  }
}

// @vue/component
export default {
  name: 'the-view',
  components,
  setup
}
</script>

<style lang="scss">
.the-assistant {
  .the-assistant-card {
    height: calc(100vh - 7rem);
  }
  .the-assistant-log {
    flex: 1;
    overflow-y: auto;
  }
  .the-assistant-title { font-weight: 700; }
  .the-assistant-status {
    display: inline-block;
    width: .55rem;
    height: .55rem;
    border-radius: 50%;
    &.is-up      { background-color: $success; }
    &.is-down    { background-color: $danger; }
    &.is-unknown { background-color: $gray-400; }
  }
  .the-assistant-tools {
    padding: .25rem;
    background-color: $gray-100;
    border-radius: .65rem;
  }
  .the-assistant-tool {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-width: 2.5rem;
    height: 2.5rem;
    padding: 0 .65rem;
    color: $gray-800;
    border: 0;
    border-radius: .5rem;
    &:hover, &:focus {
      color: $primary;
      text-decoration: none;
      background-color: lighten($primary, 46%);
    }
    &.active {
      color: $gray-900;
      background-color: $white;
      box-shadow: 0 1px 2px rgba($black, .1);
    }
    + .the-assistant-tool { margin-left: .15rem; }
  }
  .the-assistant-tool-solo {
    height: 3rem;
    min-width: 3rem;
    background-color: $white;
    border: 1px solid $gray-300;
    border-radius: .65rem;
  }
}
</style>
