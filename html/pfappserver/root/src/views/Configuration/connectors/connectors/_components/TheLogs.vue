<template>
  <div class="border-top">
    <div class="card-body d-flex flex-column">
      <b-row align-v="center" class="mb-2 flex-shrink-0">
        <b-col>
          <h6 class="mb-0">
            {{ $i18n.t('Live Logs') }}
            <b-badge v-if="isRunning" variant="success" class="ml-2">{{ $i18n.t('Streaming') }}</b-badge>
            <b-badge v-else-if="wsError" variant="danger" class="ml-2">{{ wsError }}</b-badge>
          </h6>
        </b-col>
        <b-col cols="auto" class="d-flex align-items-center">
          <b-form-select v-model="selectedFile" :options="fileOptions" size="sm" class="mr-1 w-auto"
            :disabled="isRunning || isConnecting" />
          <b-input-group size="sm" class="mr-1 connector-logs-lines" :title="$i18n.t('Number of past lines to load before following')" v-b-tooltip.hover.top.d300>
            <b-input-group-prepend is-text>{{ $i18n.t('Lines') }}</b-input-group-prepend>
            <b-form-input v-model.number="backfill" type="number" min="0" max="1000"
              :disabled="isRunning || isConnecting" />
          </b-input-group>
          <b-button v-if="!isRunning" size="sm" variant="success" class="mr-1"
            :disabled="!selectedFile || isConnecting" @click="start">
            <icon v-if="isConnecting" name="circle-notch" spin class="mr-1" />
            <icon v-else name="play" class="mr-1" />{{ $i18n.t('Start') }}
          </b-button>
          <b-button v-else size="sm" variant="danger" class="mr-1" @click="stop">
            <icon name="stop" class="mr-1" />{{ $i18n.t('Stop') }}
          </b-button>
        </b-col>
      </b-row>

      <div class="d-flex align-items-center flex-nowrap mb-2 flex-shrink-0">
        <b-input-group class="mr-1 log-search flex-grow-1" size="sm">
          <b-form-input v-model="searchInput" :placeholder="$t('Find...')"
            :class="{ 'is-invalid': searchError }"
            @keydown.enter.exact.prevent="onSearchNext"
            @keydown.enter.shift.prevent="onSearchPrev" />
          <b-input-group-append>
            <b-button :variant="searchIsRegex ? 'secondary' : 'outline-secondary'" @click="searchIsRegex = !searchIsRegex"
              :title="$i18n.t('Regular Expression')" v-b-tooltip.hover.top.d300>.*</b-button>
            <b-button variant="outline-secondary" @click="onSearchPrev" :disabled="searchMatchCount === 0">
              <icon name="chevron-up" />
            </b-button>
            <b-button variant="outline-secondary" @click="onSearchNext" :disabled="searchMatchCount === 0">
              <icon name="chevron-down" />
            </b-button>
            <b-button variant="outline-secondary" @click="onSearchClear" :disabled="!searchInput">
              <icon name="times" />
            </b-button>
          </b-input-group-append>
        </b-input-group>
        <small v-if="searchInput && !searchError" class="mx-1 text-nowrap text-muted">{{ searchCurrentDisplay }} / {{ searchMatchCount }}</small>
        <b-button-group class="mx-1" size="sm">
          <b-button @click="onCopyEvents" variant="outline-primary" :disabled="!events.length">{{ $t('Copy') }}</b-button>
          <b-button @click="onSaveEvents" variant="outline-primary" :disabled="!events.length">{{ $t('Save') }}</b-button>
          <b-button @click="onClearEvents" variant="outline-danger" :disabled="!events.length">{{ $t('Clear') }}</b-button>
        </b-button-group>
        <b-button-group class="ml-1" size="sm" :title="$i18n.t('Choose background')" v-b-tooltip.hover.top.d300>
          <b-button @click="background = 'white'" :active="background === 'white'" variant="outline-dark">
            <icon name="sun" class="text-dark" />
          </b-button>
          <b-button @click="background = 'black'" :active="background === 'black'" variant="dark">
            <icon name="moon" class="text-white" />
          </b-button>
        </b-button-group>
      </div>

      <div class="connector-logs-stream d-flex flex-column">
        <div ref="logRef" class="log scroll-forward size-small level-highlight-off"
          :class="{ 'background-white': background === 'white', 'background-black': background === 'black' }">
          <div class="scroll-only-child">
            <div class="text-raw px-3 py-1">
              <div v-for="(event, idx) in events" :key="idx" class="log-line"
                :class="{ 'search-match': isSearchMatch(idx), 'search-current': isSearchCurrent(idx) }">
                <span v-html="highlightEscaped(event.data.raw, idx)" />
              </div>
              <div v-if="!events.length" class="text-muted px-1 py-2">
                {{ isRunning ? $i18n.t('Waiting for log lines...') : $i18n.t('Select a log file and press Start to stream it live from the remote connector.') }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { computed, onBeforeUnmount, ref, watch } from '@vue/composition-api'
import { useLogSearch } from '@/composables/useLogSearch'
import i18n from '@/utils/locale'

// Hard cap on the client-side ring buffer: enough scrollback to be useful,
// small enough that the connector edit page stays responsive.
const BUFFER_SIZE = 3000
// New websocket lines are batched and flushed to the reactive buffer on a
// short interval so a chatty log doesn't trigger a render per line.
const FLUSH_INTERVAL = 200

export const props = {
  id: {
    type: String
  },
  files: {
    type: Array,
    default: () => []
  }
}

export const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const selectedFile = ref(null)
  const backfill = ref(100)
  const events = ref([])
  const isConnecting = ref(false)
  const isRunning = ref(false)
  const wsError = ref(null)
  const background = ref('black')

  const fileOptions = computed(() => props.files.map(file => ({ text: file, value: file })))
  // Preselect the first advertised file so Start works out of the box.
  watch(() => props.files, files => {
    if (!selectedFile.value && files && files.length)
      selectedFile.value = files[0]
  }, { immediate: true })

  let ws = null
  let pending = []
  let flushTimer = null

  const flush = () => {
    flushTimer = null
    if (!pending.length)
      return
    const merged = events.value.concat(pending)
    pending = []
    events.value = (merged.length > BUFFER_SIZE) ? merged.slice(-BUFFER_SIZE) : merged
  }

  const stop = () => {
    if (ws) {
      // Neutralize the handlers first: a stop requested by the user must not
      // surface the resulting close event as an error badge.
      ws.onmessage = ws.onclose = ws.onerror = null
      ws.close()
      ws = null
    }
    if (flushTimer) {
      clearTimeout(flushTimer)
      flush()
    }
    isConnecting.value = false
    isRunning.value = false
  }

  const start = () => {
    if (!props.id || !selectedFile.value)
      return
    stop()
    wsError.value = null
    isConnecting.value = true
    const lines = Math.min(Math.max(backfill.value || 0, 0), 1000)
    const proto = window.location.protocol === 'https:' ? 'wss://' : 'ws://'
    const url = `${proto}${window.location.host}/api/v1/pfconnector-remotes/${props.id}/logs/${selectedFile.value}?lines=${lines}`
    try {
      ws = new WebSocket(url)
    } catch (e) {
      isConnecting.value = false
      wsError.value = i18n.t('Unable to open the log stream.')
      return
    }
    ws.onopen = () => {
      isConnecting.value = false
      isRunning.value = true
    }
    ws.onmessage = message => {
      let data
      try {
        data = JSON.parse(message.data)
      } catch (e) {
        return
      }
      pending.push({ data })
      if (!flushTimer)
        flushTimer = setTimeout(flush, FLUSH_INTERVAL)
    }
    ws.onclose = event => {
      ws = null
      isConnecting.value = false
      isRunning.value = false
      wsError.value = (event && event.reason)
        ? i18n.t('Stream closed: {reason}', { reason: event.reason })
        : i18n.t('Stream disconnected.')
    }
    ws.onerror = () => {
      // onclose follows and sets the badge; nothing else to do here.
    }
  }

  // Switching files mid-stream restarts the stream on the new file.
  watch(selectedFile, () => {
    if (isRunning.value || isConnecting.value)
      start()
  })

  onBeforeUnmount(stop)

  const onClearEvents = () => {
    pending = []
    events.value = []
  }
  const onCopyEvents = () => {
    try {
      navigator.clipboard.writeText(events.value.map(event => event.data.raw).join('\n')).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Logs copied to clipboard.') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy logs to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }
  const onSaveEvents = () => {
    const blob = new Blob([events.value.map(event => event.data.raw).join('\r\n')], { type: 'text/plain' })
    const filename = `${props.id}-${selectedFile.value || 'connector'}.log`
    const elem = window.document.createElement('a')
    elem.href = window.URL.createObjectURL(blob)
    elem.download = filename
    document.body.appendChild(elem)
    elem.click()
    document.body.removeChild(elem)
  }

  const logRef = ref(null)
  const searchQuery = ref('')
  const searchIsRegex = ref(false)
  const {
    searchInput, searchError, searchMatchCount, searchCurrentDisplay,
    onSearchNext, onSearchPrev, onSearchClear,
    highlightEscaped, isSearchMatch, isSearchCurrent
  } = useLogSearch({
    events, searchQuery, searchIsRegex, logRef,
    matchText: event => event.data.raw
  })

  return {
    selectedFile,
    fileOptions,
    backfill,
    events,
    isConnecting,
    isRunning,
    wsError,
    background,
    start,
    stop,
    onClearEvents,
    onCopyEvents,
    onSaveEvents,

    logRef,
    searchInput,
    searchIsRegex,
    searchError,
    searchMatchCount,
    searchCurrentDisplay,
    onSearchNext,
    onSearchPrev,
    onSearchClear,
    highlightEscaped,
    isSearchMatch,
    isSearchCurrent
  }
}

// @vue/component
export default {
  name: 'the-logs',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
// The shared stream rendering (.log, .log-line, search marks, backgrounds)
// comes from src/styles/_log-events.scss, loaded globally. .log is built to
// fill a flex column, so give it a bounded flex parent here.
.connector-logs-stream {
  height: 50vh;
  min-height: 20rem;
}
.connector-logs-lines {
  width: 9rem;
}
</style>
