<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>
    <live-log-tabs />
    <b-card-body>
      <b-row>
        <b-col sm="3">
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
                    <icon name="pause" class="mx-1"></icon>
                    {{ $i18n.t('Pause') }}
                  </b-button>
                  <b-button v-if="isRunning && isPaused"
                    variant="primary" class="mb-1" size="sm" @click="onUnpauseSession">
                    <icon name="play" class="mx-1"></icon>
                    {{ $i18n.t('Unpause') }}
                  </b-button>
                  <b-button v-if="isRunning"
                    :disabled="isStopping"
                    variant="danger" class="float-right mb-1" size="sm" @click="onStopSession">
                    <icon v-if="isStopping" name="circle-notch" class="mr-2" spin></icon>
                    <icon v-else name="stop" class="mx-1"></icon>
                    {{ $i18n.t('Stop') }}
                  </b-button>
                  <b-button v-if="!isRunning"
                    :disabled="isStarting || !isValid"
                    variant="success" class="float-right mb-1" size="sm" @click="onStartSession">
                    <icon v-if="isStarting" name="circle-notch" class="mr-2" spin></icon>
                    <icon v-else name="play" class="mx-1"></icon>
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
                    <b-list-group-item :key="`${key}-${count}-${filter}`"
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
          sm="9" class="pl-0" :class="`direction-${options.order}`">
          <b-row align-v="center" :class="(options.order === 'forward') ? 'pt-3 border-top' : 'pb-3 border-bottom'">
            <b-col cols="auto" class="mr-auto d-inline">
              <b-button v-if="isRunning && !isPaused"
                variant="primary" class="ml-3" size="sm" @click="onPauseSession">
                <icon name="pause" class="mx-1"></icon>
                {{ $i18n.t('Pause') }}
              </b-button>
              <b-button v-if="isRunning && isPaused"
                variant="primary" class="ml-3" size="sm" @click="onUnpauseSession">
                <icon name="play" class="mx-1"></icon>
                {{ $i18n.t('Unpause') }}
              </b-button>
              <b-button-group class="mx-1 ml-3" size="sm" :disabled="!events || !events.length">
                <b-button @click="onCopyEvents" variant="outline-primary">{{ $t('Copy') }}</b-button>
                <b-button @click="onSaveEvents" variant="outline-primary">{{ $t('Save') }}</b-button>
                <b-button @click="onClearEvents" variant="outline-danger">{{ $t('Clear') }}</b-button>
              </b-button-group>
              <b-button-group class="mx-1 ml-3" size="sm" :title="$i18n.t('Choose background')" v-b-tooltip.hover.top.d300>
                <b-button @click="options.background = 'white'" :active="options.background === 'white'" variant="outline-dark">
                  <icon name="sun" class="text-dark" />
                </b-button>
                <b-button @click="options.background = 'black'" :active="options.background === 'black'" variant="dark">
                  <icon name="moon" class="text-white" />
                </b-button>
              </b-button-group>
              <b-button-group class="mx-1 ml-3" size="sm" :title="$i18n.t('Choose size')" v-b-tooltip.hover.top.d300>
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
              <small class="btn-group mx-1 ml-3">
              <base-input-toggle v-model="options.output"
                :options="[
                  { value: 'color', label: $i18n.t('Color'), color: 'var(--primary)' },
                  { value: 'raw', label: $i18n.t('Raw'), color: 'var(--secondary)' }
                ]" />
              </small>
            </b-col>
            <b-col cols="auto text-right">
              <b-button-group class="mx-1 mr-3" size="sm" :title="$i18n.t('Choose order')" v-b-tooltip.hover.top.d300>
                <b-button @click="options.order = 'reverse'" :active="options.order === 'reverse'" :variant="(options.order === 'reverse') ? 'secondary' : 'outline-secondary'">
                  <icon name="sort-numeric-up-alt" />
                </b-button>
                <b-button @click="options.order = 'forward'" :active="options.order === 'forward'" :variant="(options.order === 'forward') ? 'secondary' : 'outline-secondary'">
                  <icon name="sort-numeric-down" />
                </b-button>
              </b-button-group>
            </b-col>
          </b-row>
          <div editable="true" readonly="true" class="log" :class="{
            'scroll-forward': options.order === 'forward',
            'scroll-reverse': options.order === 'reverse',
            'background-white': options.background === 'white',
            'background-black': options.background === 'black',
            'size-small': options.size === 'small',
            'size-normal': options.size === 'normal',
            'size-large': options.size === 'large'
          }">
            <div class="scroll-only-child">
              <div v-if="events && options.output === 'raw'"
                class="text-raw px-3 py-1" v-html="events.map(event => event.data.raw).join('<br/>')" />
              <div v-else-if="events && options.output === 'color'" class="text-raw px-2 py-1">
                <div v-for="event in events" :key="event.data.raw">
                  <span class="log-timestamp" v-if="event.data.meta.timestamp"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.timestamp }}</span>
                  <span class="log-hostname" v-if="event.data.meta.hostname"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.hostname }}</span>
                  <span class="log-syslog" v-if="event.data.meta.syslog_name"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.syslog_name }}</span>
                  <span class="log-process" v-if="event.data.meta.process"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.process }}</span>
                  <span class="log-level" v-if="event.data.meta.log_level"
                  :class="`text-line log-level-${(event.data.meta.log_level) ? event.data.meta.log_level : 'none'}`">{{ event.data.meta.log_level }}</span>
                  {{ event.data.meta.log_without_prefix }}
                </div>
              </div>
            </div>
          </div>
        </b-col>
      </b-row>
    </b-card-body>
  </b-card>
</template>

<script>
import {
  BaseForm,
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputChosenOne,
  BaseInputToggle,
  BaseInputToggleFalseTrue
} from '@/components/new/'
import LiveLogTabs from './LiveLogTabs'


const components = {
  BaseForm,
  BaseInput,
  BaseInputChosenMultiple,
  BaseInputChosenOne,
  BaseInputToggle,
  BaseInputToggleFalseTrue,
  LiveLogTabs
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

import { computed, customRef, ref, toRefs } from '@vue/composition-api'
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
  
  // const form = session
  const formRef = ref(null)  
  const files = ref([])
  const isStarting = ref(false)
  
  const session = customRef((track, trigger) => ({
    get() {
      track()
      return $store.getters[`$_live_logs/${id.value}/session`]
    },
    set(newValue) {
      $store.dispatch(`$_live_logs/${id.value}/setSession`, newValue)
        .finally(() => trigger())
    }
  }))
  
  const options = customRef((track, trigger) => ({
    get() {
      track()
      return $store.getters[`$_live_logs/${id.value}/options`]
    },
    set(newValue) {
      $store.dispatch(`$_live_logs/${id.value}/setOptions`, newValue)
        .finally(() => trigger())
    }
  }))
  
  const events = computed(() => (options.value.order === 'reverse')
    ? $store.getters[`$_live_logs/${id.value}/eventsFiltered`].slice().reverse()
    : $store.getters[`$_live_logs/${id.value}/eventsFiltered`]
  )
  
  const scopes = computed(() => $store.getters[`$_live_logs/${id.value}/scopes`])
  
  const lines = computed(() => $store.getters[`$_live_logs/${id.value}/lines`])
  
  const size = customRef((track, trigger) => ({
    get() {
      track()
      return $store.getters[`$_live_logs/${id.value}/size`]
    },
    set(newValue) {
      $store.dispatch(`$_live_logs/${id.value}/setSize`, newValue)
        .finally(() => trigger())
    }
  }))
  
  const isLoading = computed(() => $store.getters[`$_live_logs/${id.value}/isLoading`])
  const isStopping = computed(() => $store.getters[`$_live_logs/${id.value}/isStopping`])
  const isRunning = computed(() => $store.getters[`$_live_logs/${id.value}/isRunning`])
  const isPaused = computed(() => $store.getters[`$_live_logs/${id.value}/isPaused`])
  const isValid = useDebouncedWatchHandler([session], () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))  

  const onToggleFilter = (scope, key) => $store.dispatch(`$_live_logs/${id.value}/toggleFilter`, { scope, key })
  const onStopSession = () => $store.dispatch(`$_live_logs/${id.value}/stopSession`)
  const onStartSession = () => {
    isStarting.value = true
    const { session_id, ...form } = session.value
    $store.dispatch(`$_live_logs/createSession`, form).then(response => {
      const { session_id } = response
      if (session_id) {
        $store.dispatch(`$_live_logs/${session_id}/setSize`, size.value)
        $store.dispatch('$_live_logs/destroySession', id.value)        
        $router.push({ name: 'live_log', params: { id: session_id } })          
      }
    }).finally(() => {
      isStarting.value = false
    })
  }
  const onPauseSession = () => $store.dispatch(`$_live_logs/${id.value}/pauseSession`)
  const onUnpauseSession = () => $store.dispatch(`$_live_logs/${id.value}/unpauseSession`)
  const onClearEvents = () => $store.dispatch(`$_live_logs/${id.value}/clearEvents`)
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
    onSaveEvents
  }
}

// @vue/component
export default {
  name: 'live-log-view',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style lang="scss">
.log, .scopes {
  height: 65vh;
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
.direction-forward {
  display: flex;
  flex-direction: column-reverse;
}

/*
  placeholder, only immediate children are reversed
*/
.scroll-only-child {
  width: 100%
}
</style>
