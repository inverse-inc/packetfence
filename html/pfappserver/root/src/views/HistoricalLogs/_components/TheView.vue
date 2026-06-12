<template>
  <div class="historical-logs-page">
    <div class="historical-logs-header px-3 py-2 border-bottom d-flex align-items-center">
      <b-button variant="outline-secondary" size="sm" class="mr-3" :to="{ name: 'historical_logs' }">
        <icon name="arrow-left" class="mr-1" />{{ $t('Edit query') }}
      </b-button>
      <h4 class="mb-0" v-t="'Historical Logs'" />
      <span class="ml-3 text-muted small">{{ session && session.name }}</span>
      <span class="ml-auto small text-muted">{{ $t('Lines loaded: {n}', { n: lines }) }}</span>
    </div>
    <b-card no-body class="historical-logs-body border-top-0 rounded-0">
      <b-row class="no-gutters flex-grow-1 min-h-0">
        <b-col sm="3" class="d-flex flex-column min-h-0 pl-3 pr-0 bg-light border-right">
          <div class="scopes pr-3 py-3">
            <b-button-group class="btn-block mb-3">
              <b-button variant="primary" size="sm" :disabled="isLoading || exhausted" @click="onLoadMore">
                <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
                <icon v-else name="arrow-down" class="mr-1" />
                {{ exhausted ? $t('No more data') : $t('Load more') }}
              </b-button>
              <b-button variant="outline-danger" size="sm" @click="onClearEvents">
                <icon name="eraser" class="mr-1" />{{ $t('Clear') }}
              </b-button>
            </b-button-group>
            <template v-if="lines > 0">
              <template v-for="(children, scope) in scopes">
                <small class="ml-1" :key="`small-${children.label}`">{{ children.label }}</small>
                <b-list-group :key="`group-${children.label}`" class="mt-1 mb-3">
                  <template v-for="({ count, filter }, key) in children.values">
                    <!-- Stable key: keying on count/filter recreates the
                         element mid-click and drops the click. -->
                    <b-list-group-item :key="key"
                      href="#" class="cursor-pointer"
                      :active="filter"
                      :variant="filter ? 'primary' : 'light'"
                      @click="onToggleFilter(scope, key)">
                      <template v-if="key">{{ key }}</template>
                      <template v-else><em>{{ $t('blank') }}</em></template>
                      <b-badge variant="secondary" pill class="float-right">{{ count }}</b-badge>
                    </b-list-group-item>
                  </template>
                </b-list-group>
              </template>
            </template>
          </div>
        </b-col>
        <b-col sm="9" class="d-flex flex-column min-h-0 px-0">
          <div class="historical-logs-toolbar d-flex align-items-center flex-nowrap px-2 py-1 border-bottom">
            <b-input-group class="mx-1 log-search flex-grow-1" size="sm">
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
            <b-button-group class="mx-1 flex-shrink-0" size="sm" :title="$t('Toggle log level highlighting')" v-b-tooltip.hover.top.d300>
              <b-button @click="options.levelHighlight = !options.levelHighlight"
                :active="options.levelHighlight"
                :variant="options.levelHighlight ? 'secondary' : 'outline-secondary'">
                <icon name="palette" />
              </b-button>
            </b-button-group>
          </div>
          <b-alert variant="warning" class="m-2" :show="!!message">{{ message }}</b-alert>
          <div ref="logRef" class="log size-normal background-white scroll-forward"
            :class="{ 'level-highlight-off': !options.levelHighlight }">
            <div class="scroll-only-child">
              <base-table-empty v-if="!events || !events.length" icon="scroll" :text="$t('No events in this window.')" class="flex-fill">
                {{ $t('No events') }}
              </base-table-empty>
              <!-- Same chip rendering as the LiveLogs color view: colored
                   source tag, neutral timestamp, one colored level chip
                   (_log-events.scss). -->
              <div v-else class="text-raw px-2 py-1">
                <div v-for="(event, idx) in events" :key="idx"
                  :class="{ 'search-match': isSearchMatch(idx), 'search-current': isSearchCurrent(idx) }">
                  <span v-if="event.data.meta.hostname"
                    :class="['log-source-tag', `log-source-tag-${hostColorIndex(event.data.meta.hostname)}`]"
                    v-b-tooltip.hover.left :title="$t('Node / log file')">
                    {{ event.data.meta.hostname }}<template v-if="event.data.meta.filename">&nbsp;/&nbsp;{{ basename(event.data.meta.filename) }}</template>
                  </span>
                  <!-- Neutral timestamp + a single colored level chip — same
                       compact line shape as the live view. -->
                  <span class="log-timestamp text-line log-level-none" v-if="event.data.meta.timestamp">{{ event.data.meta.timestamp }}</span>
                  <span v-if="event.data.meta.log_level"
                  :class="`log-level text-line log-level-${event.data.meta.log_level}`">{{ event.data.meta.log_level }}</span>
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
import { BaseTableEmpty } from '@/components/new/'
import { computed, ref, toRefs, watch, nextTick } from '@vue/composition-api'
import { basename, hostColorIndex } from '@/utils/logEvents'

const components = { BaseTableEmpty }
const props = { id: { type: String } }

const setup = (props, context) => {
  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const session = computed(() => $store.getters[`$_historical_logs/${id.value}/session`])
  const options = computed(() => $store.getters[`$_historical_logs/${id.value}/options`])
  const events = computed(() => $store.getters[`$_historical_logs/${id.value}/eventsFiltered`])
  const scopes = computed(() => $store.getters[`$_historical_logs/${id.value}/scopes`])
  const lines = computed(() => $store.getters[`$_historical_logs/${id.value}/lines`])
  const isLoading = computed(() => $store.getters[`$_historical_logs/${id.value}/isLoading`])
  const exhausted = computed(() => $store.getters[`$_historical_logs/${id.value}/exhausted`])
  const message = computed(() => $store.getters[`$_historical_logs/${id.value}/message`])

  const onLoadMore = () => $store.dispatch(`$_historical_logs/${id.value}/loadMore`)
  const onClearEvents = () => $store.dispatch(`$_historical_logs/${id.value}/clearEvents`)
  const onToggleFilter = (scope, key) => $store.dispatch(`$_historical_logs/${id.value}/toggleFilter`, { scope, key })

  // In-results text search — same machinery as the LiveLogs view, backed
  // by the searchQuery/searchIsRegex state this store already carries.
  const logRef = ref(null)
  const searchQuery = computed({
    get: () => $store.getters[`$_historical_logs/${id.value}/searchQuery`],
    set: val => $store.commit(`$_historical_logs/${id.value}/SET_SEARCH_QUERY`, val)
  })
  const searchIsRegex = computed({
    get: () => $store.getters[`$_historical_logs/${id.value}/searchIsRegex`],
    set: val => $store.commit(`$_historical_logs/${id.value}/SET_SEARCH_IS_REGEX`, val)
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

  // escapeHtml BEFORE highlight: the log line is untrusted content, only
  // our own <mark> wrapper may carry markup into v-html.
  const escapeHtml = (text) => String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

  const highlightEscaped = (text) => {
    const escaped = escapeHtml(text)
    const re = searchRegex.value
    if (!re) return escaped
    re.lastIndex = 0
    return escaped.replace(re, match => `<mark>${match}</mark>`)
  }

  const isSearchMatch = (idx) => searchMatchIndices.value.includes(idx)
  const isSearchCurrent = (idx) => searchMatchIndices.value[searchCurrentIdx.value] === idx

  return {
    session, options, events, scopes, lines, isLoading, exhausted, message,
    onLoadMore, onClearEvents, onToggleFilter,
    logRef, searchQuery, searchIsRegex, searchError,
    searchMatchCount, searchCurrentDisplay,
    onSearchNext, onSearchPrev, onSearchClear,
    highlightEscaped, isSearchMatch, isSearchCurrent,
    basename, hostColorIndex
  }
}

export default {
  name: 'the-view',
  components,
  props,
  setup
}
</script>

<style lang="scss">
.historical-logs-page {
  margin-left: -15px;
  margin-right: -15px;
  display: flex;
  flex-direction: column;
  height: calc(100vh - 4rem);
  background: var(--white);
}
.historical-logs-header { background: var(--light); flex-shrink: 0; }
.historical-logs-body {
  display: flex !important; flex-direction: column; flex: 1 1 0; min-height: 0;
}
.historical-logs-toolbar {
  background: var(--light);
  flex-shrink: 0;
}
// Stream rendering (.log, chips, source tags, scroll, search) is shared
// with LiveLogs: src/styles/_log-events.scss (loaded globally).
</style>
