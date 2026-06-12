<template>
  <div class="live-logs-page">
    <div class="live-logs-header px-3 py-2 border-bottom d-flex align-items-center">
      <b-button variant="outline-secondary" size="sm" class="mr-3" :to="{ name: 'live_logs' }">
        <icon name="arrow-left" class="mr-1" />{{ $i18n.t('New session') }}
      </b-button>
      <h4 class="mb-0" v-t="'Live Logs'" />
      <b-badge v-if="isClusterSession" variant="info" class="ml-3"
        v-b-tooltip.hover.right
        :title="$i18n.t('Tailing log files from every cluster node in parallel.')">
        {{ $i18n.t('Cluster: {n} nodes', { n: peerIds.length }) }}
      </b-badge>
    </div>
    <the-create-bar />
    <the-tabs />
    <b-card no-body class="live-logs-body border-top-0 rounded-0">
      <base-table-empty v-if="!session" icon="scroll" :text="$i18n.t('Start a session using the form above.')" class="flex-fill">{{ $i18n.t('No active sessions') }}</base-table-empty>
      <b-row v-else class="no-gutters flex-grow-1 min-h-0">
        <b-col sm="3" class="d-flex flex-column min-h-0 pl-3 pr-0 bg-light border-right">
          <div class="scopes pr-3">
            <small class="ml-1">{{ $i18n.t('Session Options') }}</small>
            <b-list-group class="mt-1 mb-3">
              <b-list-group-item variant="light">
                <b-form @submit.prevent ref="formRef">
                  <base-form
                    :form="session"
                    :schema="schema"
                    :isLoading="isLoading || isRunning">
                    <small class="ml-1">{{ $i18n.t('Log Files') }}</small>
                    <base-input-chosen-multiple v-if="session && 'files' in session"
                      namespace="files"
                      :placeholder="$t('Choose log file(s)')"
                      :options="files" />
                    <small class="ml-1">{{ $i18n.t('Filter') }}</small>
                    <base-input v-if="session && 'filter' in session"
                      namespace="filter" />
                    <small class="ml-1">{{ $i18n.t('Regular Expression') }}</small>
                    <base-input-toggle-false-true v-if="session && 'filter_is_regexp' in session"
                      namespace="filter_is_regexp" />
                  </base-form>
                </b-form>
                <b-button-group class="mt-3 btn-block">
                  <b-button v-if="isRunning && !isPaused"
                    variant="primary" class="mb-1" size="sm" @click="onPauseSession">
                    <icon name="pause" class="mx-1" />
                    {{ $i18n.t('Pause') }}
                  </b-button>
                  <b-button v-if="isRunning && isPaused"
                    variant="primary" class="mb-1" size="sm" @click="onUnpauseSession">
                    <icon name="play" class="mx-1" />
                    {{ $i18n.t('Unpause') }}
                  </b-button>
                  <b-button v-if="isRunning"
                    :disabled="isStopping"
                    variant="danger" class="float-right mb-1" size="sm" @click="onStopSession">
                    <icon v-if="isStopping" name="circle-notch" class="mr-2" spin />
                    <icon v-else name="stop" class="mx-1" />
                    {{ $i18n.t('Stop') }}
                  </b-button>
                  <b-button v-if="!isRunning"
                    :disabled="isStarting || !isValid"
                    variant="success" class="float-right mb-1" size="sm" @click="onStartSession">
                    <icon v-if="isStarting" name="circle-notch" class="mr-2" spin />
                    <icon v-else name="play" class="mx-1" />
                    {{ $i18n.t('Reset') }}
                  </b-button>
                </b-button-group>
              </b-list-group-item>
            </b-list-group>
            <small class="ml-1">{{ $i18n.t('Buffer Size') }}</small>
            <base-input-chosen-one v-model="size"
              :options="sizes"
              :placeholder="$t('Choose max buffer size')" />
            <template v-if="lines > 0">
              <template v-for="(children, scope) in scopes">
                <small class="ml-1" :key="`small-${children.label}`">{{ children.label }}</small>
                <b-list-group :key="`group-${children.label}`" class="mt-1 mb-3">
                  <template v-for="({ count, filter }, key) in children.values">
                    <!-- Stable key: count changes on every poll; keying on it
                         recreates the element mid-click and drops the click. -->
                    <b-list-group-item :key="key"
                      href="#" class="cursor-pointer"
                      :active="filter"
                      :variant="(filter) ? 'primary' : 'light'"
                      @click="onToggleFilter(scope, key)"
                      :title="(filter) ? $i18n.t('Click to disable filter') : $i18n.t('Click to enable filter')"
                      v-b-tooltip.hover.top.d300>
                      <template v-if="key">
                        {{ key }}
                      </template>
                      <template v-else>
                        <i>{{ $i18n.t('none') }}</i>
                      </template>
                      <b-badge class="float-right border text-secondary bg-light ml-1">{{ count }}</b-badge>
                    </b-list-group-item>
                  </template>
                </b-list-group>
              </template>
            </template>
          </div>
        </b-col>
        <b-col v-if="options"
          sm="9" class="d-flex flex-column min-h-0 pl-0">
          <div class="live-logs-toolbar d-flex align-items-center flex-nowrap px-2 py-1"
            :class="(options.order === 'forward') ? 'border-top order-2' : 'border-bottom order-0'"
          >
            <b-input-group class="mx-1 live-logs-search flex-grow-1" size="sm">
              <b-form-input v-model="searchQuery" :placeholder="$t('Find...')"
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
                <b-button variant="outline-secondary" @click="onSearchClear" :disabled="!searchQuery">
                  <icon name="times" />
                </b-button>
              </b-input-group-append>
            </b-input-group>
            <small v-if="searchQuery && !searchError" class="mx-1 text-nowrap text-muted">{{ searchCurrentDisplay }} / {{ searchMatchCount }}</small>
            <div class="d-flex align-items-center flex-shrink-0">
              <b-button v-if="isRunning && !isPaused"
                variant="primary" class="mx-1" size="sm" @click="onPauseSession">
                <icon name="pause" class="mx-1" />
                {{ $i18n.t('Pause') }}
              </b-button>
              <b-button v-if="isRunning && isPaused"
                variant="primary" class="mx-1" size="sm" @click="onUnpauseSession">
                <icon name="play" class="mx-1" />
                {{ $i18n.t('Unpause') }}
              </b-button>
              <b-button-group class="mx-1" size="sm" :disabled="!events || !events.length">
                <b-button @click="onCopyEvents" variant="outline-primary">{{ $t('Copy') }}</b-button>
                <b-button @click="onSaveEvents" variant="outline-primary">{{ $t('Save') }}</b-button>
                <b-button @click="onClearEvents" variant="outline-danger">{{ $t('Clear') }}</b-button>
              </b-button-group>
              <b-button-group class="mx-1" size="sm" :title="$i18n.t('Choose background')" v-b-tooltip.hover.top.d300>
                <b-button @click="options.background = 'white'" :active="options.background === 'white'" variant="outline-dark">
                  <icon name="sun" class="text-dark" />
                </b-button>
                <b-button @click="options.background = 'black'" :active="options.background === 'black'" variant="dark">
                  <icon name="moon" class="text-white" />
                </b-button>
              </b-button-group>
              <b-button-group class="mx-1" size="sm" :title="$i18n.t('Choose size')" v-b-tooltip.hover.top.d300>
                <b-button @click="options.size = 'small'" :active="options.size === 'small'" :variant="(options.size === 'small') ? 'secondary' : 'outline-secondary'">
                  <icon name="font" scale="0.75" />
                </b-button>
                <b-button @click="options.size = 'normal'" :active="options.size === 'normal'" :variant="(options.size === 'normal') ? 'secondary' : 'outline-secondary'">
                  <icon name="font" scale="1" />
                </b-button>
                <b-button @click="options.size = 'large'" :active="options.size === 'large'" :variant="(options.size === 'large') ? 'secondary' : 'outline-secondary'">
                  <icon name="font" scale="1.25" />
                </b-button>
              </b-button-group>
              <small class="btn-group mx-1">
              <base-input-toggle v-model="options.output"
                :options="[
                  { value: 'color', label: $i18n.t('Color'), color: 'var(--primary)' },
                  { value: 'raw', label: $i18n.t('Raw'), color: 'var(--secondary)' }
                ]"
                :labelRight="true" />
              </small>
              <b-button-group class="mx-1" size="sm" :title="$i18n.t('Choose order')" v-b-tooltip.hover.top.d300>
                <b-button @click="options.order = 'reverse'" :active="options.order === 'reverse'" :variant="(options.order === 'reverse') ? 'secondary' : 'outline-secondary'">
                  <icon name="sort-numeric-up-alt" />
                </b-button>
                <b-button @click="options.order = 'forward'" :active="options.order === 'forward'" :variant="(options.order === 'forward') ? 'secondary' : 'outline-secondary'">
                  <icon name="sort-numeric-down" />
                </b-button>
              </b-button-group>
            </div>
          </div>
          <div ref="logRef" editable="true" readonly="true" class="log" :class="{
            'scroll-forward': options.order === 'forward',
            'scroll-reverse': options.order === 'reverse',
            'background-white': options.background === 'white',
            'background-black': options.background === 'black',
            'size-small': options.size === 'small',
            'size-normal': options.size === 'normal',
            'size-large': options.size === 'large'
          }">
            <div class="scroll-only-child">
              <div v-if="events && options.output === 'raw'" class="text-raw px-3 py-1">
                <div v-for="(event, idx) in events" :key="idx"
                  :class="{ 'search-match': isSearchMatch(idx), 'search-current': isSearchCurrent(idx) }">
                  <span v-if="event.data.meta.hostname"
                    :class="['log-source-tag', `log-source-tag-${hostColorIndex(event.data.meta.hostname)}`]"
                    v-b-tooltip.hover.left :title="$t('Node / log file')">
                    {{ event.data.meta.hostname }}<template v-if="event.data.meta.filename">&nbsp;/&nbsp;{{ event.data.meta.filename }}</template>
                  </span>
                  <span v-html="highlightRaw(event.data.raw)" />
                </div>
              </div>
              <div v-else-if="events && options.output === 'color'" class="text-raw px-2 py-1">
                <div v-for="(event, idx) in events" :key="idx"
                  :class="{ 'search-match': isSearchMatch(idx), 'search-current': isSearchCurrent(idx) }">
                  <span v-if="event.data.meta.hostname"
                    :class="['log-source-tag', `log-source-tag-${hostColorIndex(event.data.meta.hostname)}`]"
                    v-b-tooltip.hover.left :title="$t('Node / log file')">
                    {{ event.data.meta.hostname }}<template v-if="event.data.meta.filename">&nbsp;/&nbsp;{{ event.data.meta.filename }}</template>
                  </span>
                  <span class="log-timestamp" v-if="event.data.meta.timestamp"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.timestamp }}</span>
                  <span class="log-syslog" v-if="event.data.meta.syslog_name"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.syslog_name }}</span>
                  <span class="log-process" v-if="event.data.meta.process"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.process }}</span>
                  <span class="log-level" v-if="event.data.meta.log_level"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.log_level }}</span>
                  <span v-html="highlightEscaped(event.data.meta.log_without_prefix)" />
                </div>
              </div>
            </div>
          </div>
        </b-col>
      </b-row>
    </b-card>
  </div>
</template>

<script>
import {
  BaseForm,
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputChosenOne,
  BaseInputToggle,
  BaseInputToggleFalseTrue,
  BaseTableEmpty
} from '@/components/new/'
import TheCreateBar from './TheCreateBar'
import TheTabs from './TheTabs'

const components = {
  BaseForm,
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputChosenOne,
  BaseInputToggle,
  BaseInputToggleFalseTrue,
  BaseTableEmpty,
  TheCreateBar,
  TheTabs
}

const props = {
  id: {
    type: String
  }
}

const sizes = [
  { text: '100', value: 100 },
  { text: '250', value: 250 },
  { text: '500', value: 500 },
  { text: '1000', value: 1000 },
  { text: '2500', value: 2500 },
  { text: '5000', value: 5000 }
]

import { computed, customRef, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schema = yup.object({
  files: yup.array().ensure()
    .required(i18n.t('Log file(s) required.'))
    .of(yup.string().nullable())
})

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  // Resolve URL :id to one or more session submodule namespaces.
  // - Standalone / SaaS: peerIds = [id], primary = id (legacy behaviour).
  // - Cluster: id is a synthetic group_id; the value in _groups[id] is an
  //   array of full peer objects {hostname, management_ip, session_id}.
  const peerEntries = computed(() => {
    const groups = $store.state.$_live_logs && $store.state.$_live_logs._groups
    if (groups && groups[id.value]) return groups[id.value]
    return [{ session_id: id.value, management_ip: null }]
  })
  const peerIds = computed(() => peerEntries.value.map(p => p.session_id))
  const primary = computed(() => peerIds.value[0])
  const isClusterSession = computed(() => peerIds.value.length > 1)

  // const form = session
  const formRef = ref(null)
  const files = ref([])
  const isStarting = ref(false)

  const session = customRef((track, trigger) => ({
    get() {
      track()
      return $store.getters[`$_live_logs/${primary.value}/session`]
    },
    set(newValue) {
      // Mirror form updates (files/filter changes) to every peer so the
      // session-options panel stays in sync across the cluster.
      Promise.all(peerIds.value.map(pid =>
        $store.dispatch(`$_live_logs/${pid}/setSession`, newValue)
      )).finally(() => trigger())
    }
  }))

  const options = customRef((track, trigger) => ({
    get() {
      track()
      return $store.getters[`$_live_logs/${primary.value}/options`]
    },
    set(newValue) {
      Promise.all(peerIds.value.map(pid =>
        $store.dispatch(`$_live_logs/${pid}/setOptions`, newValue)
      )).finally(() => trigger())
    }
  }))

  // Merge events across peer submodules and order by timestamp so a
  // single chronological stream is shown even on a 3-node cluster.
  const mergedEvents = computed(() => {
    const all = peerIds.value.flatMap(pid =>
      $store.getters[`$_live_logs/${pid}/eventsFiltered`] || []
    )
    if (peerIds.value.length === 1) return all // preserve insertion order
    return all.slice().sort((a, b) => {
      const ta = a && a.data && a.data.meta && a.data.meta.timestamp || ''
      const tb = b && b.data && b.data.meta && b.data.meta.timestamp || ''
      return ta < tb ? -1 : ta > tb ? 1 : 0
    })
  })

  const events = computed(() => (options.value.order === 'reverse')
    ? mergedEvents.value.slice().reverse()
    : mergedEvents.value
  )

  // Merge scopes (hostname / filename / log_level / process / syslog_name)
  // so the per-host counts add up across the cluster and the user can
  // filter by any of them from a single panel.
  const scopes = computed(() => {
    if (peerIds.value.length === 1) {
      return $store.getters[`$_live_logs/${primary.value}/scopes`]
    }
    const merged = {}
    for (const pid of peerIds.value) {
      const peerScopes = $store.getters[`$_live_logs/${pid}/scopes`] || {}
      for (const [scope, { label, values = {} }] of Object.entries(peerScopes)) {
        if (!merged[scope]) merged[scope] = { label, values: {} }
        for (const [key, val] of Object.entries(values)) {
          const cur = merged[scope].values[key] || { count: 0 }
          merged[scope].values[key] = {
            count: cur.count + (val.count || 0),
            filter: cur.filter || val.filter
          }
        }
      }
    }
    return merged
  })

  const lines = computed(() => peerIds.value.reduce((sum, pid) =>
    sum + ($store.getters[`$_live_logs/${pid}/lines`] || 0), 0))

  const size = customRef((track, trigger) => ({
    get() {
      track()
      return $store.getters[`$_live_logs/${primary.value}/size`]
    },
    set(newValue) {
      Promise.all(peerIds.value.map(pid =>
        $store.dispatch(`$_live_logs/${pid}/setSize`, newValue)
      )).finally(() => trigger())
    }
  }))

  // Any peer being loading/stopping should reflect on the toolbar so the
  // user does not see a stale Stop button while a peer is still tearing down.
  const isLoading = computed(() => peerIds.value.some(pid => $store.getters[`$_live_logs/${pid}/isLoading`]))
  const isStopping = computed(() => peerIds.value.some(pid => $store.getters[`$_live_logs/${pid}/isStopping`]))
  const isRunning = computed(() => peerIds.value.some(pid => $store.getters[`$_live_logs/${pid}/isRunning`]))
  const isPaused = computed(() => $store.getters[`$_live_logs/${primary.value}/isPaused`])
  const isValid = useDebouncedWatchHandler([session], () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))

  // Decide the target state once from the merged scopes (what the user sees)
  // and set it explicitly on every peer module — a per-module toggle would
  // flip peers in opposite directions when their flags diverge.
  const onToggleFilter = (scope, key) => {
    const { [scope]: { values: { [key]: { filter = false } = {} } = {} } = {} } = scopes.value
    return Promise.all(peerIds.value.map(pid =>
      $store.dispatch(`$_live_logs/${pid}/setFilter`, { scope, key, filter: !filter })
    ))
  }
  const onStopSession = () => Promise.all(peerEntries.value.map(peer =>
    $store.dispatch(`$_live_logs/${peer.session_id}/stopSession`, peer)
  ))
  const onStartSession = () => {
    isStarting.value = true
    const { session_id, ...form } = session.value
    $store.dispatch(`$_live_logs/createSession`, form).then(response => {
      const newId = response && (response.group_id || response.session_id)
      if (newId) {
        // Mirror the user's preferred buffer size onto every fresh peer.
        const fresh = response.group_id
          ? (response.peers || []).map(p => p.session_id)
          : [response.session_id]
        fresh.forEach(pid => $store.dispatch(`$_live_logs/${pid}/setSize`, size.value))
        $store.dispatch('$_live_logs/destroySession', id.value)
        $router.push({ name: 'live_log', params: { id: newId } })
      }
    }).finally(() => {
      isStarting.value = false
    })
  }
  const onPauseSession = () => Promise.all(peerIds.value.map(pid =>
    $store.dispatch(`$_live_logs/${pid}/pauseSession`)
  ))
  const onUnpauseSession = () => Promise.all(peerIds.value.map(pid =>
    $store.dispatch(`$_live_logs/${pid}/unpauseSession`)
  ))
  const onClearEvents = () => Promise.all(peerIds.value.map(pid =>
    $store.dispatch(`$_live_logs/${pid}/clearEvents`)
  ))
    .then(() => $store.dispatch('notification/info', { message: i18n.t('Cleared logs.') }))
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
    // window.open(encodeURI(`data:text/csv;charset=utf-8,${csvContentArray.join('\r\n')}`)) // doesn't allow naming
    let blob = new Blob([events.value.map(event => event.data.raw).join('\r\n')], { type: 'text/plain' })
    let filename = session.value.name + ((session.value.name.slice(-4) === '.log') ? '' : '.log')
    if (window.navigator.msSaveOrOpenBlob)
      window.navigator.msSaveBlob(blob, filename)
    else {
      var elem = window.document.createElement('a')
      elem.href = window.URL.createObjectURL(blob)
      elem.download = filename
      document.body.appendChild(elem)
      elem.click()
      document.body.removeChild(elem)
    }
  }

  // search
  const logRef = ref(null)
  const searchQuery = computed({
    get: () => $store.getters[`$_live_logs/${primary.value}/searchQuery`],
    set: val => peerIds.value.forEach(pid => $store.commit(`$_live_logs/${pid}/SET_SEARCH_QUERY`, val))
  })
  const searchIsRegex = computed({
    get: () => $store.getters[`$_live_logs/${primary.value}/searchIsRegex`],
    set: val => peerIds.value.forEach(pid => $store.commit(`$_live_logs/${pid}/SET_SEARCH_IS_REGEX`, val))
  })
  const searchError = ref(false)
  const searchCurrentIdx = ref(0)

  const searchRegex = computed(() => {
    if (!searchQuery.value) return null
    searchError.value = false
    try {
      const pattern = searchIsRegex.value
        ? searchQuery.value
        : searchQuery.value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
      return new RegExp(pattern, 'gi')
    } catch (e) {
      searchError.value = true
      return null
    }
  })

  const searchMatchIndices = computed(() => {
    const re = searchRegex.value
    if (!re || !events.value) return []
    return events.value.reduce((acc, event, idx) => {
      re.lastIndex = 0
      if (re.test(event.data.raw)) acc.push(idx)
      return acc
    }, [])
  })

  const searchMatchCount = computed(() => searchMatchIndices.value.length)
  const searchCurrentDisplay = computed(() => searchMatchCount.value === 0 ? 0 : searchCurrentIdx.value + 1)

  watch(searchMatchIndices, () => {
    searchCurrentIdx.value = 0
  })

  const scrollToCurrentMatch = () => {
    nextTick(() => {
      if (!logRef.value) return
      const el = logRef.value.querySelector('.search-current')
      if (el) el.scrollIntoView({ block: 'center', behavior: 'smooth' })
    })
  }

  const onSearchNext = () => {
    if (searchMatchCount.value === 0) return
    searchCurrentIdx.value = (searchCurrentIdx.value + 1) % searchMatchCount.value
    scrollToCurrentMatch()
  }
  const onSearchPrev = () => {
    if (searchMatchCount.value === 0) return
    searchCurrentIdx.value = (searchCurrentIdx.value - 1 + searchMatchCount.value) % searchMatchCount.value
    scrollToCurrentMatch()
  }
  const onSearchClear = () => {
    searchQuery.value = ''
    searchCurrentIdx.value = 0
  }

  const escapeHtml = (text) => String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

  const applyHighlight = (str) => {
    const re = searchRegex.value
    if (!re) return str
    re.lastIndex = 0
    return str.replace(re, match => `<mark>${match}</mark>`)
  }
  const highlightRaw = (text) => applyHighlight(escapeHtml(text))
  const highlightEscaped = (text) => applyHighlight(escapeHtml(text))

  const isSearchMatch = (idx) => searchMatchIndices.value.includes(idx)
  const isSearchCurrent = (idx) => searchMatchIndices.value[searchCurrentIdx.value] === idx

  // Stable per-hostname colour: hash the string into 6 buckets so the
  // same node always gets the same accent regardless of event order.
  const hostColorIndex = (hostname) => {
    if (!hostname) return 0
    let h = 0
    for (let i = 0; i < hostname.length; i++) {
      h = (h * 31 + hostname.charCodeAt(i)) | 0
    }
    return Math.abs(h) % 6
  }

  // immediate
  $store.dispatch(`$_live_logs/optionsSession`).then(response => {
    const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
    if (allowed) {
      files.value = allowed
        .map(item => {
          const { text, value } = item
          return { text: `${value} - ${text}`, value }
        })
        .sort((a, b) => {
          return a.value.localeCompare(b.value)
        })
    }
  })

  return {
    formRef,
    schema,
    files,
    sizes,
    session,
    options,
    events,
    scopes,
    lines,
    size,
    peerIds,
    isClusterSession,

    isLoading,
    isStarting,
    isStopping,
    isRunning,
    isPaused,
    isValid,

    onToggleFilter,
    onStopSession,
    onStartSession,
    onPauseSession,
    onUnpauseSession,
    onClearEvents,
    onCopyEvents,
    onSaveEvents,

    logRef,
    searchQuery,
    searchIsRegex,
    searchError,
    searchMatchCount,
    searchCurrentDisplay,
    onSearchNext,
    onSearchPrev,
    onSearchClear,
    highlightRaw,
    highlightEscaped,
    isSearchMatch,
    isSearchCurrent,
    hostColorIndex
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style lang="scss">
.live-logs-page {
  margin-left: -15px;
  margin-right: -15px;
  display: flex;
  flex-direction: column;
  height: calc(100vh - 4rem);
  background: var(--white);
}
.live-logs-header {
  background: var(--light);
  flex-shrink: 0;
}
.live-logs-body {
  display: flex !important;
  flex-direction: column;
  flex: 1 1 0;
  min-height: 0;
}
.live-logs-toolbar {
  flex-shrink: 0;
}
.live-logs-search {
  min-width: 10rem;
  .form-control {
    height: auto;
  }
  .input-group-append .btn {
    border-color: #ced4da;
    color: var(--secondary);
  }
}
.search-match {
  background: rgba(255, 235, 59, 0.15);
}
.search-current {
  background: rgba(255, 235, 59, 0.4);
}
.min-h-0 {
  min-height: 0;
}
.log, .scopes {
  flex: 1 1 0;
  min-height: 0;
  overflow-y: scroll;
  overflow-x: auto;
}
.log {
  display: flex;
  align-items: flex-end;

  &.background-black {
    color: rgba(255, 255, 255, 1);
    background: rgba(0, 0, 0, 1);

    .log-timestamp,
    .log-hostname,
    .log-level,
    .log-process,
    .log-syslog {
      color: rgba(0, 0, 0, 1);
    }
  }
  &.background-white {
    color: rgba(0, 0, 0, 1);
    background: rgba(255, 255, 255, 1);

    .log-timestamp,
    .log-hostname,
    .log-level,
    .log-process,
    .log-syslog {
      color: rgba(255, 255, 255, 1);
    }
  }
  &.size-small {
    font-size: 0.75em;
  }
  &.size-normal {
    font-size: 1em;
  }
  &.size-large {
    font-size: 1.5em;
  }

  .text-line {
    line-height: 1.5rem;
    margin: .25rem 0;

    &.log-level-none {
      background: var(--secondary);
    }
    &.log-level-info {
      background: var(--info);
    }
    &.log-level-warn {
      background: var(--warning);
    }
    &.log-level-error {
      background: var(--danger);
    }

    &.log-timestamp,
    &.log-hostname,
    &.log-level,
    &.log-process,
    &.log-syslog {
      white-space: nowrap;
      margin: 0 .25rem 0 0;
      padding: .25rem .5rem;
      border: 1px solid;
      border-radius: .25rem;
    }
  }
}

// Source tag: shows "<hostname> / <filename>" so every line in a
// merged cluster stream is unambiguously attributable.
.log-source-tag {
  display: inline-block;
  font-family: monospace;
  font-size: .8em;
  line-height: 1;
  padding: .15rem .4rem;
  margin: 0 .35rem 0 0;
  border-radius: .25rem;
  color: #fff;
  white-space: nowrap;
  vertical-align: 1px;
}
.log-source-tag-0 { background: #2563eb; }   // blue
.log-source-tag-1 { background: #16a34a; }   // green
.log-source-tag-2 { background: #c026d3; }   // magenta
.log-source-tag-3 { background: #ea580c; }   // orange
.log-source-tag-4 { background: #0891b2; }   // teal
.log-source-tag-5 { background: #ca8a04; }   // amber

/*
 reverse content, pin vertical scrollbar to the bottom,
   reverses content only on immediate children
*/
.scroll-forward {
  flex-direction: column-reverse;
}
.scroll-reverse {
  flex-direction: column;
}
/*
  placeholder, only immediate children are reversed
*/
.scroll-only-child {
  width: 100%
}
</style>
