<template>
  <div class="historical-logs-page">
    <div class="historical-logs-header px-3 py-2 border-bottom d-flex align-items-center">
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
                    <b-list-group-item :key="`${key}-${count}-${filter}`"
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
          <div ref="logRef" class="log size-normal background-white scroll-forward">
            <div class="scroll-only-child">
              <base-table-empty v-if="!events.length" icon="scroll" :text="$t('No events in this window.')" class="flex-fill">
                {{ $t('No events') }}
              </base-table-empty>
              <div v-else class="text-raw px-3 py-1">
                <div v-for="(event, idx) in events" :key="idx">
                  <span class="log-timestamp" v-if="event.data.meta.timestamp">{{ event.data.meta.timestamp }}</span>
                  <span class="log-hostname" v-if="event.data.meta.hostname"> {{ event.data.meta.hostname }}</span>
                  <span class="log-process" v-if="event.data.meta.process"> {{ event.data.meta.process }}</span>
                  <span v-if="event.data.meta.log_level" :class="`log-level log-level-${event.data.meta.log_level}`"> {{ event.data.meta.log_level }}</span>
                  <span> {{ event.data.meta.log_without_prefix }}</span>
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
import { computed, toRefs } from '@vue/composition-api'

const components = { BaseTableEmpty }
const props = { id: { type: String } }

const setup = (props, context) => {
  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const session = computed(() => $store.getters[`$_historical_logs/${id.value}/session`])
  const events = computed(() => $store.getters[`$_historical_logs/${id.value}/eventsFiltered`])
  const scopes = computed(() => $store.getters[`$_historical_logs/${id.value}/scopes`])
  const lines = computed(() => $store.getters[`$_historical_logs/${id.value}/lines`])
  const isLoading = computed(() => $store.getters[`$_historical_logs/${id.value}/isLoading`])
  const exhausted = computed(() => $store.getters[`$_historical_logs/${id.value}/exhausted`])

  const onLoadMore = () => $store.dispatch(`$_historical_logs/${id.value}/loadMore`)
  const onClearEvents = () => $store.dispatch(`$_historical_logs/${id.value}/clearEvents`)
  const onToggleFilter = (scope, key) => $store.dispatch(`$_historical_logs/${id.value}/toggleFilter`, { scope, key })

  return { session, events, scopes, lines, isLoading, exhausted, onLoadMore, onClearEvents, onToggleFilter }
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
</style>
