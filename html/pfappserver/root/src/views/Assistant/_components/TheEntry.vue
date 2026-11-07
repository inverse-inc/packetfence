<template>
  <div class="the-entry mb-3" :class="`the-entry-${entry.type}`">

    <div v-if="entry.type === 'user'" class="d-flex flex-column align-items-end">
      <small class="text-muted text-uppercase" v-t="'you'" />
      <div class="the-entry-user px-3 py-2 rounded bg-light border">{{ entry.content }}</div>
    </div>

    <div v-else-if="entry.type === 'bot'">
      <small class="text-muted text-uppercase">{{ entry.label || $t('assistant') }}</small>
      <div class="the-entry-bot pl-3" v-html="html" />
      <div v-if="entry.files && entry.files.length" class="mt-1">
        <b-button v-for="file in entry.files" :key="file.id" size="sm" variant="outline-primary" class="mr-1 mb-1"
          @click="onDownload(file)">
          <icon name="download" class="mr-1" /> {{ file.name }} <small class="text-muted">{{ size(file.size_bytes) }}</small>
        </b-button>
      </div>
      <div class="the-entry-actions mt-1" v-if="entry.id || entry.label">
        <b-button size="sm" variant="link" class="p-0 mr-2 text-muted" @click="onCopy"
          v-b-tooltip.hover.bottom.d300 :title="$t('Copy')"><icon name="copy" /></b-button>
        <template v-if="entry.id">
          <b-button size="sm" variant="link" class="p-0 mr-2" :class="(entry.feedback === 1) ? 'text-success' : 'text-muted'"
            @click="onFeedback(1)" v-b-tooltip.hover.bottom.d300 :title="$t('Good response')"><icon name="thumbs-up" /></b-button>
          <b-button size="sm" variant="link" class="p-0 mr-2" :class="(entry.feedback === -1) ? 'text-danger' : 'text-muted'"
            @click="onFeedback(-1)" v-b-tooltip.hover.bottom.d300 :title="$t('Not good')"><icon name="thumbs-down" /></b-button>
          <small class="text-muted" v-if="entry.feedback === 1" v-t="'Thanks, the assistant will keep this style.'" />
          <small class="text-muted" v-else-if="entry.feedback === -1" v-t="'Noted.'" />
        </template>
      </div>
    </div>

    <div v-else-if="entry.type === 'trace'" class="the-entry-trace pl-2 small text-monospace text-muted">
      <div v-for="(row, index) in rows" :key="index" class="d-flex" :class="{ 'text-black-50': row.debug }">
        <span class="mr-1">&rsaquo;</span>
        <span class="text-break">{{ row.text }}</span>
        <b-button v-if="row.curl" size="sm" variant="link" class="p-0 ml-2 text-muted"
          @click="copy(row.curl, $t('curl command copied to clipboard'))"><icon name="copy" /></b-button>
      </div>
    </div>

    <b-alert v-else-if="entry.type === 'error'" show variant="danger" class="mb-0 small">{{ entry.message }}</b-alert>

    <b-card v-else-if="entry.type === 'confirm'" border-variant="warning" class="the-entry-confirm">
      <h6 v-t="'Confirm this action'" />
      <p class="mb-2">
        {{ $t('Run') }} <strong class="text-monospace">{{ entry.confirm.method }} {{ entry.confirm.path }}</strong>
        <template v-if="entry.confirm.summary"> &mdash; {{ entry.confirm.summary }}</template>?
      </p>
      <template v-if="!entry.state">
        <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="!canWrite" @click="onConfirm(false)">{{ $t('Cancel') }}</b-button>
        <b-button size="sm" variant="warning" :disabled="!canWrite" @click="onConfirm(true)">{{ $t('Confirm') }}</b-button>
        <small v-if="!canWrite" class="d-block text-danger mt-1" v-t="'Your admin role grants read-only access to the assistant.'" />
      </template>
      <small v-else-if="entry.state === 'running'" class="text-muted"><icon name="circle-notch" spin class="mr-1" />{{ $t('running') }}</small>
      <small v-else :class="{ 'text-success': entry.state === 'done', 'text-danger': entry.state === 'failed', 'text-muted': entry.state === 'cancelled' }">
        <icon v-if="entry.state === 'done'" name="check" class="mr-1" />{{ entry.message }}
      </small>
      <pre v-if="entry.response" class="mt-2 mb-0 p-2 bg-light border small the-entry-response">{{ entry.response }}</pre>
    </b-card>

    <div v-else-if="entry.type === 'node_actions'">
      <b-button size="sm" variant="link" class="p-0" :pressed.sync="showNodeActions">
        <icon :name="showNodeActions ? 'chevron-down' : 'chevron-right'" class="mr-1" />
        {{ $t('Actions for') }} <span class="text-monospace">{{ entry.node.mac }}</span>
        <b-badge v-if="entry.node.status" class="ml-1" variant="light">{{ entry.node.status }}</b-badge>
      </b-button>
      <div v-if="showNodeActions" class="mt-1 pl-3">
        <b-button v-if="nodeStatus !== 'registered'" size="sm" variant="outline-primary" pill class="mr-1 mb-1" :disabled="!canWrite" @click="onStage('register')">{{ $t('Register node') }}</b-button>
        <b-button v-if="nodeStatus !== 'unregistered'" size="sm" variant="outline-danger" pill class="mr-1 mb-1" :disabled="!canWrite" @click="onStage('deregister')">{{ $t('Deregister node') }}</b-button>
        <b-button size="sm" variant="outline-primary" pill class="mr-1 mb-1" :disabled="!canWrite" @click="onStage('reevaluate')">{{ $t('Reevaluate access') }}</b-button>
        <b-button size="sm" variant="outline-secondary" pill class="mr-1 mb-1" @click="$emit('send', `Diagnose ${entry.node.mac}`)">{{ $t('Diagnose again') }}</b-button>
        <b-button size="sm" variant="outline-secondary" pill class="mr-1 mb-1" @click="$emit('inspect')">{{ $t('Open inspector') }}</b-button>
      </div>
    </div>

  </div>
</template>

<script>
import { computed, ref } from '@vue/composition-api'
import bytes from '@/utils/bytes'
import i18n from '@/utils/locale'
import { useDownload } from '@/composables/useDownload'
import api from '../_api'
import markdown from '../markdown'

const props = {
  entry: {
    type: Object
  }
}

const setup = (props, context) => {
  const { root: { $can, $store } = {} } = context

  const html = computed(() => markdown(props.entry.content))
  const canWrite = computed(() => $can('write', 'chatbot'))

  // "· ..." rows are verbose-trace detail; "curl [200]:: curl ..." rows copy
  const rows = computed(() => (props.entry.rows || []).map(raw => {
    const s = String(raw)
    const debug = s.startsWith('·')
    const text = debug ? s.slice(1).trim() : s
    const curl = text.match(/^curl \[([^\]]*)\]:: ([\s\S]+)$/)
    if (curl)
      return { debug: true, text: 'curl ' + curl[2].replace(/^curl\s+/, ''), curl: curl[2] }
    return { debug, text }
  }))

  const copy = (text, message) => navigator.clipboard.writeText(text)
    .then(() => $store.dispatch('notification/info', { message }))
  const onCopy = () => copy(props.entry.content, i18n.t('Reply copied to clipboard'))
  const onFeedback = rating => $store.dispatch('$_assistant/feedback', { entry: props.entry, rating: (props.entry.feedback === rating) ? 0 : rating })
  const onConfirm = approved => $store.dispatch('$_assistant/confirm', { entry: props.entry, approved })
  const onDownload = file => api.downloadFile(file.id).then(response => useDownload(file.name, response.data, file.mime))
  const size = n => bytes.toHuman(n, 1, true) + 'B'

  // collapsed by default, as in the conversation it reads like a footnote
  const showNodeActions = ref(false)
  const nodeStatus = computed(() => ((props.entry.node && props.entry.node.status) || '').toLowerCase())
  const onStage = action => $store.dispatch('$_assistant/stageNode', { mac: props.entry.node.mac, action }).catch(() => {})

  return { html, canWrite, rows, copy, onCopy, onFeedback, onConfirm, onDownload, size, showNodeActions, nodeStatus, onStage }
}

// @vue/component
export default {
  name: 'the-entry',
  props,
  setup
}
</script>

<style lang="scss">
.the-entry {
  .the-entry-user {
    max-width: 85%;
    white-space: pre-wrap;
  }
  .the-entry-bot {
    max-width: 80ch;
    border-left: 2px solid $gray-300;
    p { margin: .35em 0; }
    pre {
      padding: .5rem .75rem;
      background-color: $gray-100;
      border: 1px solid $gray-300;
      border-radius: $border-radius;
    }
    code.mac { cursor: pointer; }
    .navlink {
      font-weight: 600;
      border-bottom: 1px dotted;
      &:hover { text-decoration: none; border-bottom-style: solid; }
    }
    .navsep { opacity: .55; }
    .uilabel { font-weight: 600; }
  }
  .the-entry-trace {
    border-left: 2px solid $primary;
  }
  .the-entry-response {
    max-height: 16rem;
    overflow: auto;
    white-space: pre-wrap;
  }
}
</style>
