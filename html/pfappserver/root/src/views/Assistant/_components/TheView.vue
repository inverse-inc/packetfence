<template>
  <b-row :class="['the-assistant', { 'the-assistant--dark': darkMode }]">
    <b-col cols="12" md="3" xl="2" class="mb-3">
      <the-threads />
    </b-col>
    <b-col cols="12" :md="sidePane ? 6 : 9" :xl="sidePane ? 7 : 10">
      <b-card no-body class="the-assistant-card">
        <b-card-header class="d-flex align-items-center">
          <div>
            <h4 class="mb-0" v-t="'NACBot'" />
            <small class="text-muted">
              <template v-if="pfVersion">PacketFence {{ pfVersion }}</template>
              <template v-if="settings.provider"> &middot; {{ settings.provider }} / {{ settings.model }}</template>
              <template v-else-if="isAvailable">
                &middot; {{ $t("No LLM provider configured.") }}
                <b-link v-if="canConfigure" to="/configuration/pfchatbot">{{ $t("Configure") }}</b-link>
              </template>
            </small>
          </div>
          <b-button-group class="ml-auto">
            <b-button size="sm" variant="outline-secondary" :pressed="sidePane === 'files'" @click="toggleSidePane('files')"
              v-b-tooltip.hover.bottom.d300 :title="$t('Files in this conversation')">
              <icon name="file" />
            </b-button>
            <b-button size="sm" variant="outline-secondary" @click="showUsage = true"
              v-b-tooltip.hover.bottom.d300 :title="$t('Token usage')">
              <icon name="chart-bar" />
            </b-button>
            <b-button size="sm" variant="outline-secondary" @click="openTestTools()"
              v-b-tooltip.hover.bottom.d300 :title="$t('Test tools (802.1X / RADIUS)')">
              <icon name="tools" />
            </b-button>
            <b-button size="sm" variant="outline-secondary" @click="showLogs = true"
              v-b-tooltip.hover.bottom.d300 :title="$t('Service logs')">
              <icon name="file-code" />
            </b-button>
            <b-button size="sm" variant="outline-secondary" to="/configuration/pfchatbot" v-if="canConfigure"
              v-b-tooltip.hover.bottom.d300 :title="$t('Provider settings')">
              <icon name="cog" />
            </b-button>
          </b-button-group>
          <b-button size="sm" variant="outline-secondary" @click="toggleDark"
            v-b-tooltip.hover.bottom.d300 :title="darkMode ? $t('Switch to light theme') : $t('Switch to dark theme')">
            <icon :name="darkMode ? 'sun' : 'moon'" />
          </b-button>
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

  // Dark mode — persisted in localStorage
  const darkMode = ref(localStorage.getItem('nacbot-dark') === '1')
  const toggleDark = () => {
    darkMode.value = !darkMode.value
    localStorage.setItem('nacbot-dark', darkMode.value ? '1' : '0')
  }

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
    sidePane,
    toggleSidePane,
    send,
    darkMode,
    toggleDark,
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
}

/* ── Dark theme ─────────────────────────────────────────────────────────── */
.the-assistant--dark {
  .card, .the-assistant-card {
    background: #1a1b1e;
    border-color: #3a3b40;
    .card-header, .card-footer { background: #141517; border-color: #3a3b40; }
  }
  .the-assistant-log { background: #1a1b1e; }

  // text
  p, li, h3, h4, h5, h6, small, .text-muted { color: #c9cdd4 !important; }
  strong { color: #e2e5ea; }
  h4.mb-0 { color: #ffffff; }

  // user bubble
  .the-entry-user { background: #2d2f35 !important; border-color: #3a3b40 !important; color: #e2e5ea !important; }

  // bot reply border
  .the-entry-bot { border-left-color: #4a4d55; }

  // trace
  .the-entry-trace { border-left-color: #4a90d9; .text-muted, .text-black-50 { color: #7a8290 !important; } }

  // code blocks
  pre { background: #252628 !important; border-color: #3a3b40 !important; color: #cdd6f4; }
  code { background: #2a2c30; color: #cba6f7; }
  code.mac { color: #f38ba8; }

  // tables
  table.pf-table {
    thead th { background: #252628; color: #e2e5ea; border-color: #3a3b40; }
    td        { border-color: #3a3b40; color: #c9cdd4; }
    tbody tr:nth-child(even) { background: #202224; }
    tbody tr:hover            { background: #2d3748; }
  }

  // links
  a:not(.btn):not(.navlink) { color: #89b4fa; }
  .navlink { color: #89b4fa; border-bottom-color: #89b4fa; }

  // alert
  .alert-danger { background: #2d1b1b; border-color: #6b3030; color: #f38ba8; }

  // thread sidebar
  .list-group-item {
    background: #1e1f22;
    border-color: #3a3b40;
    color: #c9cdd4;
    &.active, &:hover { background: #2d2f35; }
  }
  .card { &.border-primary { border-color: #4a90d9 !important; } }

  // form inputs in composer
  textarea, input[type="text"] {
    background: #252628 !important;
    border-color: #3a3b40 !important;
    color: #e2e5ea !important;
    &::placeholder { color: #6b7280 !important; }
  }

  // buttons - keep outline variants readable
  .btn-outline-secondary {
    color: #9ca3af;
    border-color: #4a4d55;
    &:hover { background: #2d2f35; color: #e2e5ea; }
    &.active, &.pressed { background: #2d2f35 !important; color: #e2e5ea; }
  }
  .btn-outline-primary  { color: #89b4fa; border-color: #89b4fa; &:hover { background: #1e3a5f; } }
  .btn-outline-danger   { color: #f38ba8; border-color: #f38ba8; &:hover { background: #3d1a1a; } }

  // badge
  .badge-light { background: #2d2f35; color: #c9cdd4; }

  // confirm card
  .the-entry-confirm { background: #252628; border-color: #b45309 !important; }
  .the-entry-response { background: #1a1b1e !important; border-color: #3a3b40 !important; color: #c9cdd4; }
}
</style>
