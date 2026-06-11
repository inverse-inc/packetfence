<template>
  <div class="historical-logs-page">
    <div class="historical-logs-header px-3 py-2 border-bottom d-flex align-items-center">
      <h4 class="mb-0" v-t="'Historical Logs'" />
      <small v-if="isCluster" class="ml-3 text-muted">
        <icon name="cubes" class="mr-1" />{{ $t('Queries all {n} cluster nodes.', { n: nodeCount }) }}
      </small>
    </div>
    <div class="px-3 py-3 border-bottom bg-light">
      <b-form @submit.prevent="onSubmit">
        <b-row>
          <b-col md="6" class="pr-2">
            <label class="small mb-1">{{ $t('Log Files') }}</label>
            <multiselect v-model="selectedFiles"
              :options="fileOptions" :multiple="true" :close-on-select="false"
              track-by="value" label="text"
              :placeholder="$t('Choose log file(s)...')" />
          </b-col>
          <b-col md="6">
            <label class="small mb-1">{{ $t('Time range (your local timezone)') }}</label>
            <b-row no-gutters>
              <b-col cols="6" class="pr-2">
                <b-input-group>
                  <template #prepend>
                    <b-input-group-text>{{ $t('From') }}</b-input-group-text>
                  </template>
                  <b-form-input type="datetime-local" v-model="startLocal" :max="endLocal || nowLocal" />
                </b-input-group>
              </b-col>
              <b-col cols="6">
                <b-input-group>
                  <template #prepend>
                    <b-input-group-text>{{ $t('To') }}</b-input-group-text>
                  </template>
                  <b-form-input type="datetime-local" v-model="endLocal" :min="startLocal" :max="nowLocal" />
                </b-input-group>
              </b-col>
            </b-row>
            <div class="mt-2">
              <small class="text-muted mr-2">{{ $t('Quick:') }}</small>
              <b-button-group size="sm">
                <b-button variant="outline-secondary" @click="setRange(1)">{{ $t('Last 1h') }}</b-button>
                <b-button variant="outline-secondary" @click="setRange(6)">{{ $t('Last 6h') }}</b-button>
                <b-button variant="outline-secondary" @click="setRange(24)">{{ $t('Last 24h') }}</b-button>
                <b-button variant="outline-secondary" @click="setRange(24*7)">{{ $t('Last 7d') }}</b-button>
                <b-button variant="outline-secondary" @click="setRange(0)">{{ $t('Clear') }}</b-button>
              </b-button-group>
            </div>
          </b-col>
        </b-row>
        <b-row class="mt-3">
          <b-col md="9" class="pr-2">
            <label class="small mb-1">{{ $t('Text filter (optional)') }}</label>
            <b-input-group>
              <b-form-input v-model="filter" :placeholder="$t('Substring or regex...')" />
              <template #append>
                <b-input-group-text>
                  <b-form-checkbox v-model="filterIsRegexp" class="mb-0">{{ $t('Regex') }}</b-form-checkbox>
                </b-input-group-text>
              </template>
            </b-input-group>
          </b-col>
          <b-col md="3" class="d-flex align-items-end">
            <b-button type="submit" variant="primary" size="lg" class="ml-auto"
              :disabled="isLoading || !selectedFiles.length">
              <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />
              <icon v-else name="search" class="mr-1" />
              {{ $t('Load') }}
            </b-button>
          </b-col>
        </b-row>
      </b-form>
    </div>
  </div>
</template>

<script>
import { computed, ref, onMounted } from '@vue/composition-api'
import Multiselect from 'vue-multiselect'
import i18n from '@/utils/locale'

const components = { Multiselect }

// Convert a local "YYYY-MM-DDTHH:MM" datetime-local value to an ISO-8601
// UTC string with seconds. Empty input -> null (= "no bound").
const localToIso = (s) => {
  if (!s) return null
  const d = new Date(s)
  if (isNaN(d)) return null
  return d.toISOString().replace(/\.\d+Z$/, 'Z')
}

// Inverse of localToIso for prefilling the datetime-local inputs.
const isoToLocal = (s) => {
  if (!s) return ''
  const d = new Date(s)
  if (isNaN(d)) return ''
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const setup = (props, context) => {
  const { root: { $router, $store } = {} } = context

  const fileOptions = ref([])
  const selectedFiles = ref([])
  const startLocal = ref('')
  const endLocal = ref('')
  const filter = ref('')
  const filterIsRegexp = ref(false)

  const nowLocal = computed(() => {
    // Format Date() to "YYYY-MM-DDTHH:MM" in local timezone for <input type="datetime-local" max>.
    const d = new Date()
    const pad = n => String(n).padStart(2, '0')
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
  })

  const isLoading = computed(() => $store.getters['$_historical_logs/isLoading'])
  const isSaas = computed(() => $store.getters['system/isSaas'])
  const isCluster = computed(() => !isSaas.value && $store.getters['cluster/isCluster'])
  const nodeCount = computed(() => {
    const servers = $store.state.cluster && $store.state.cluster.servers
    return servers ? Object.keys(servers).length : 0
  })

  onMounted(() => {
    // "Edit query" returns here from the results view: prefill from the
    // previous session instead of starting blank.
    const lastId = $store.state.$_historical_logs && $store.state.$_historical_logs._lastSessionId
    const lastSession = (lastId && $store.getters[`$_historical_logs/${lastId}/session`]) || null

    $store.dispatch('$_historical_logs/optionsSession').then(response => {
      const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
      if (allowed) {
        fileOptions.value = allowed
          .map(({ text, value }) => ({ text, value }))
          .sort((a, b) => a.value.localeCompare(b.value))
        if (lastSession && lastSession.files) {
          selectedFiles.value = fileOptions.value.filter(o => lastSession.files.includes(o.value))
        }
      }
    })
    if (lastSession) {
      filter.value = lastSession.filter || ''
      filterIsRegexp.value = !!lastSession.filter_is_regexp
      startLocal.value = isoToLocal(lastSession.start)
      endLocal.value = isoToLocal(lastSession.end)
    } else {
      // Default to "last 1h" so the form is immediately useful.
      setRange(1)
    }
  })

  // Hours back from now; 0 clears both bounds.
  const setRange = hours => {
    if (hours === 0) {
      startLocal.value = ''
      endLocal.value = ''
      return
    }
    const pad = n => String(n).padStart(2, '0')
    const fmt = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
    const now = new Date()
    const then = new Date(now.getTime() - hours * 60 * 60 * 1000)
    startLocal.value = fmt(then)
    endLocal.value = fmt(now)
  }

  const onSubmit = () => {
    const form = {
      name: i18n.t('Historical query'),
      files: selectedFiles.value.map(o => o.value),
      filter: filter.value || null,
      filter_is_regexp: !!filterIsRegexp.value,
      start: localToIso(startLocal.value),
      end: localToIso(endLocal.value)
    }
    $store.dispatch('$_historical_logs/createSession', form).then(response => {
      const { session_id } = response
      if (session_id) {
        $router.push({ name: 'historical_log', params: { id: session_id } })
      }
    })
  }

  return {
    fileOptions, selectedFiles,
    startLocal, endLocal, nowLocal,
    filter, filterIsRegexp,
    isLoading, isCluster, nodeCount,
    setRange, onSubmit
  }
}

export default {
  name: 'the-form',
  inheritAttrs: false,
  components,
  setup
}
</script>
