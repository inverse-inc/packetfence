<template>
  <b-modal v-model="show" :title="$t('NACBot Service Logs')" size="xl" hide-footer
    @show="onShow" @hide="onHide">
    <div class="d-flex justify-content-between align-items-center mb-2">
      <small class="text-muted">
        <icon name="circle" :class="paused ? 'text-warning' : 'text-success'" scale="0.6" class="mr-1" />
        {{ paused ? $t('Paused') : $t('Live — updates every 2s') }}
        <span v-if="lines.length" class="ml-2">
          {{ lines.length }} {{ $t('lines') }}
          <span class="text-muted"> · last 24h</span>
        </span>
      </small>
      <b-button-group size="sm">
        <b-button variant="outline-secondary" @click="togglePause">
          <icon :name="paused ? 'play' : 'pause'" class="mr-1" />
          {{ paused ? $t('Resume') : $t('Pause') }}
        </b-button>
        <b-button variant="outline-danger" @click="clearLocal">
          <icon name="trash-alt" class="mr-1" />
          {{ $t('Clear') }}
        </b-button>
        <b-button variant="outline-secondary" @click="scrollToBottom" v-b-tooltip.hover :title="$t('Jump to bottom')">
          <icon name="arrow-down" />
        </b-button>
      </b-button-group>
    </div>
    <b-alert :show="!!loadError" variant="danger" class="mb-2">{{ loadError }}</b-alert>
    <div ref="logContainer"
      class="log-container p-2 rounded"
      style="height:65vh; overflow-y:auto; font-family:monospace; font-size:0.78rem; white-space:pre-wrap; background:#1e1e1e; color:#d4d4d4;">
      <div v-if="isLoading && !lines.length" class="text-muted text-center pt-4">
        <icon name="circle-notch" spin class="mr-1" />{{ $t('Loading 24h of logs…') }}
      </div>
      <div v-else-if="!lines.length" class="text-muted text-center pt-4">
        {{ $t('No log entries in the last 24 hours.') }}
      </div>
      <div v-for="(line, i) in lines" :key="i" :class="lineClass(line)">{{ line }}</div>
    </div>
  </b-modal>
</template>

<script>
import { customRef, ref, nextTick } from '@vue/composition-api'
import api from '../_api'

const props = {
  value: { type: Boolean }
}

const setup = (props, context) => {
  const { emit, refs } = context

  const show = customRef((track, trigger) => ({
    get() { track(); return props.value },
    set(v) { emit('input', v); trigger() }
  }))

  const lines = ref([])
  const isLoading = ref(false)
  const loadError = ref('')
  const paused = ref(false)
  let timer = null
  let lastTs = ''       // last timestamp seen — used for incremental polling
  let cleared = false   // user cleared display; keep polling but don't restore old lines

  // Initial load: fetch full 24h history (no `since` param)
  const loadHistory = () => {
    isLoading.value = true
    api.logs(5000, '').then(r => {
      lines.value = r.lines || []
      lastTs = r.last_ts || ''
      loadError.value = ''
      nextTick(scrollToBottom)
    }).catch(err => {
      const { response: { data: { error, message } = {} } = {} } = err || {}
      loadError.value = error || message || 'Could not load logs'
    }).finally(() => { isLoading.value = false })
  }

  // Incremental poll: only fetch lines newer than lastTs
  const pollNew = () => {
    if (paused.value) return
    api.logs(2000, lastTs).then(r => {
      const newLines = r.lines || []
      if (newLines.length) {
        if (!cleared) {
          lines.value = [...lines.value, ...newLines]
          nextTick(scrollToBottom)
        } else {
          // After clear, start fresh with just the new lines
          lines.value = newLines
          cleared = false
          nextTick(scrollToBottom)
        }
      }
      if (r.last_ts) lastTs = r.last_ts
      loadError.value = ''
    }).catch(err => {
      const { response: { data: { error, message } = {} } = {} } = err || {}
      loadError.value = error || message || 'Could not load logs'
    })
  }

  const onShow = () => {
    isLoading.value = true
    paused.value = false
    cleared = false
    lastTs = ''
    lines.value = []
    loadHistory()
    timer = setInterval(pollNew, 2000)
  }

  const onHide = () => {
    clearInterval(timer)
    timer = null
    lastTs = ''
  }

  const scrollToBottom = () => {
    const el = refs.logContainer
    if (el) el.scrollTop = el.scrollHeight
  }

  const togglePause = () => { paused.value = !paused.value }

  const clearLocal = () => {
    lines.value = []
    cleared = true
  }

  const lineClass = line => {
    const l = line.toLowerCase()
    if (/traceback|critical/.test(l)) return 'text-danger'
    if (/\berror\b/.test(l) && !/['\]?error[']?\s*:\s*(none|null|false)/.test(l)) return 'text-danger'
    if (/\bexception\b/.test(l) && !/exception.*none/.test(l)) return 'text-danger'
    if (/\bwarning\b|\bwarn\b/.test(l)) return 'text-warning'
    if (/\b(get|post|put|delete|patch)\b.*\b(200|201|204)\b/.test(l)) return 'text-secondary'
    return ''
  }

  return { show, lines, isLoading, loadError, paused, onShow, onHide, scrollToBottom, togglePause, clearLocal, lineClass }
}

export default {
  name: 'the-journal-logs',
  props,
  setup
}
</script>
