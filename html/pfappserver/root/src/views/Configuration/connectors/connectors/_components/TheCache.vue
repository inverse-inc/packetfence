<template>
  <div class="card mx-3 mb-3 bg-light">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">
            {{ $i18n.t('Connector Cache') }}
            <b-badge v-if="stats" variant="success" class="ml-2">{{ $i18n.t('Running') }}</b-badge>
            <b-badge v-else-if="statsError" variant="danger" class="ml-2">{{ $i18n.t('Unavailable') }}</b-badge>
          </h6>
          <small class="text-muted d-block">
            {{ $i18n.t('The local cache service of the remote connector: RADIUS authorizations and credentials replayed when PacketFence is unreachable, and the RADIUS rate limiter.') }}
          </small>
          <small v-if="lastRefresh" class="text-muted">{{ $i18n.t('Last refreshed') }}: {{ lastRefresh }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="isLoading" @click="refresh">
            <icon name="sync" :spin="isLoading" class="mr-1" />{{ $i18n.t('Refresh') }}
          </b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1"
            :disabled="!stats || isBusy"
            :title="$i18n.t('Delete the cached RADIUS authorizations and credentials older than their expiration, then compact the database file.')"
            @click="showOptimizeModal = true">
            <icon name="compress" class="mr-1" />{{ $i18n.t('Optimize Database') }}
          </b-button>
          <b-button size="sm" variant="outline-danger" class="mr-1"
            :disabled="!stats || isBusy"
            :title="$i18n.t('Delete every cached RADIUS authorization, credential and rate-limit key.')"
            @click="showCleanModal = true">
            <icon name="trash-alt" class="mr-1" />{{ $i18n.t('Wipe Caches') }}
          </b-button>
          <b-button size="sm" variant="outline-warning"
            :disabled="!stats || isBusy"
            :title="$i18n.t('Gracefully restart the cache service (about a millisecond of downtime).')"
            @click="showRestartModal = true">
            <icon name="power-off" class="mr-1" />{{ $i18n.t('Restart Cache Service') }}
          </b-button>
        </b-col>
      </b-row>

      <b-alert v-if="unsupported" show variant="warning" class="mb-2">
        {{ $i18n.t('This remote connector does not expose the cache management API. Upgrade it from the Status tab to manage its cache from here.') }}
      </b-alert>
      <b-alert v-else-if="statsError" show variant="danger" class="mb-2">{{ statsError }}</b-alert>

      <b-row>
        <b-col md="5">
          <h6 class="text-secondary">{{ $i18n.t('Statistics') }}</h6>
          <b-table-simple v-if="stats" small borderless class="mb-0">
            <b-tbody>
              <b-tr>
                <b-td class="text-muted">{{ $i18n.t('Cached RADIUS authorizations') }}</b-td>
                <b-td>{{ stats.devices_in_db }}</b-td>
              </b-tr>
              <b-tr>
                <b-td class="text-muted">{{ $i18n.t('Cached credentials') }}</b-td>
                <b-td>{{ stats.credential_in_db }}</b-td>
              </b-tr>
              <b-tr>
                <b-td class="text-muted">{{ $i18n.t('Active rate-limit keys') }}</b-td>
                <b-td>{{ stats.keys_in_ratelimit }}</b-td>
              </b-tr>
              <b-tr>
                <b-td class="text-muted">{{ $i18n.t('Database size') }}</b-td>
                <b-td>{{ formatBytes(stats.db_size) }}</b-td>
              </b-tr>
              <b-tr>
                <b-td class="text-muted">{{ $i18n.t('Memory') }}</b-td>
                <b-td>{{ formatBytes(stats.mem_alloc) }} <small class="text-muted">{{ $i18n.t('allocated') }}</small> / {{ formatBytes(stats.mem_sys) }} <small class="text-muted">{{ $i18n.t('from the OS') }}</small></b-td>
              </b-tr>
              <b-tr v-if="config && config.server">
                <b-td class="text-muted">{{ $i18n.t('Listening port') }}</b-td>
                <b-td class="text-monospace">127.0.0.1:{{ config.server.port }}</b-td>
              </b-tr>
            </b-tbody>
          </b-table-simple>
          <p v-else class="text-muted mb-0">{{ $i18n.t('Statistics unavailable.') }}</p>
        </b-col>

        <b-col md="7">
          <h6 class="text-secondary">
            {{ $i18n.t('Configuration') }}
            <b-badge v-if="dirtyFields.length" variant="warning" class="ml-2">{{ $i18n.t('{n} unsaved change(s)', { n: dirtyFields.length }) }}</b-badge>
          </h6>
          <template v-if="config">
            <b-alert v-if="configError" show variant="danger" class="py-1 small">{{ configError }}</b-alert>
            <b-alert v-if="restartPending" show variant="info" class="py-1 small">
              {{ $i18n.t('The database options were saved but only apply after a restart of the cache service.') }}
              <b-button size="sm" variant="link" class="p-0 ml-1 align-baseline" :disabled="isBusy" @click="showRestartModal = true">{{ $i18n.t('Restart it now') }}</b-button>
            </b-alert>

            <b-form @submit.prevent="save">
              <b-form-group v-for="field in fields" :key="field.key"
                :label="field.label" :description="field.help"
                label-cols-md="5" label-size="sm" class="mb-2"
                :state="fieldState(field)" :invalid-feedback="fieldFeedback(field)">
                <template v-if="field.type === 'number'">
                  <b-input-group size="sm" :append="field.unit">
                    <b-form-input v-model="form[field.key]" type="number" :min="field.min" :max="field.max" step="1"
                      :state="fieldState(field)" :disabled="isSaving" />
                  </b-input-group>
                </template>
                <template v-else-if="field.type === 'boolean'">
                  <b-form-checkbox v-model="form[field.key]" switch size="sm" class="pt-1" :disabled="isSaving">
                    {{ form[field.key] ? field.trueLabel : field.falseLabel }}
                  </b-form-checkbox>
                </template>
                <template v-else-if="field.type === 'list'">
                  <b-form-textarea v-model="form[field.key]" size="sm" rows="3" max-rows="8" class="text-monospace"
                    :placeholder="$i18n.t('One prefix per line')" :state="fieldState(field)" :disabled="isSaving" />
                </template>
                <small v-if="field.restart" class="text-muted d-block">
                  <icon name="info-circle" class="mr-1" />{{ $i18n.t('Applied at the next restart of the cache service.') }}
                </small>
              </b-form-group>
              <div class="text-right">
                <b-button size="sm" variant="outline-secondary" class="mr-1" :disabled="!dirtyFields.length || isSaving" @click="reset">
                  {{ $i18n.t('Reset') }}
                </b-button>
                <b-button size="sm" variant="primary" type="submit" :disabled="!dirtyFields.length || !isValid || isSaving">
                  <icon v-if="isSaving" name="circle-notch" spin class="mr-1" />
                  <icon v-else name="save" class="mr-1" />{{ $i18n.t('Save') }}
                </b-button>
              </div>
            </b-form>
          </template>
          <b-alert v-else-if="configError" show variant="danger" class="py-1 small mb-0">{{ configError }}</b-alert>
          <p v-else class="text-muted mb-0">{{ $i18n.t('Configuration unavailable.') }}</p>
        </b-col>
      </b-row>
    </div>

    <b-modal v-model="showOptimizeModal" :title="$i18n.t('Optimize Cache Database')" centered>
      <p>{{ $i18n.t('Cached RADIUS authorizations older than {rad} day(s) and credentials older than {cred} day(s) will be deleted, then the database file will be compacted. Requests keep being served during the operation. Continue?', { rad: ttl('app.radius_attribute_ttl'), cred: ttl('app.credential_ttl') }) }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isBusy" @click="optimize">{{ $i18n.t('Optimize') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showCleanModal" :title="$i18n.t('Wipe Connector Caches')" centered>
      <p>{{ $i18n.t('Every cached RADIUS authorization, cached credential and rate-limit key on this connector will be deleted. Until PacketFence has authorized them again, devices cannot be served from the cache while PacketFence is unreachable. Continue?') }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="danger" :disabled="isBusy" @click="clean">{{ $i18n.t('Wipe') }}</b-button>
      </template>
    </b-modal>

    <b-modal v-model="showRestartModal" :title="$i18n.t('Restart Cache Service')" centered>
      <p>{{ $i18n.t('The cache service will be gracefully restarted: its configuration file is reloaded and requests are interrupted for about a millisecond. The rest of the remote connector is not affected. Continue?') }}</p>
      <template #modal-footer="{ hide }">
        <b-button variant="secondary" @click="hide()">{{ $i18n.t('Cancel') }}</b-button>
        <b-button variant="warning" :disabled="isBusy" @click="restart">{{ $i18n.t('Restart') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
import { computed, onBeforeUnmount, onMounted, reactive, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

export const props = {
  id: {
    type: String
  }
}

// The connector-cache options the admin can change, keyed by their
// dot-separated YAML path (the connector-remote refuses anything else).
// Ranges mirror connector-cache's validation tags.
const fields = [
  {
    key: 'app.rate_limit_rate', type: 'number', min: 0, max: 180,
    label: i18n.t('RADIUS rate limit'), unit: i18n.t('req/min'),
    help: i18n.t('Maximum RADIUS requests per minute for a single device before the rate limiter kicks in (0 = unlimited).')
  },
  {
    key: 'app.rate_limit_reject', type: 'boolean',
    label: i18n.t('Above the rate limit'),
    trueLabel: i18n.t('Reject the request'), falseLabel: i18n.t('Answer from the cache'),
    help: i18n.t('What to do with the requests of a device exceeding its rate limit.')
  },
  {
    key: 'app.rate_limit_key_max_age', type: 'number', min: 1, max: 24,
    label: i18n.t('Rate-limit key retention'), unit: i18n.t('hours'),
    help: i18n.t('How long an idle device stays in the rate limiter before its counter is dropped.')
  },
  {
    key: 'app.radius_attribute_ttl', type: 'number', min: 1, max: 365,
    label: i18n.t('RADIUS authorization expiration'), unit: i18n.t('days'),
    help: i18n.t('Cached RADIUS authorizations older than this are no longer replayed and are deleted when the database is optimized.')
  },
  {
    key: 'app.credential_ttl', type: 'number', min: 1, max: 365,
    label: i18n.t('Credential expiration'), unit: i18n.t('days'),
    help: i18n.t('Cached credentials (NT keys) older than this are no longer replayed and are deleted when the database is optimized.')
  },
  {
    key: 'app.radius_attribute_filters', type: 'list',
    label: i18n.t('Excluded RADIUS attributes'),
    help: i18n.t('Attributes whose name starts with one of these prefixes are not cached (one per line). The defaults, control:, MS-MPPE and EAP-Message, are always applied.')
  },
  {
    key: 'database.cache_ram_size', type: 'number', min: 32, max: 4096, restart: true,
    label: i18n.t('Database memory cache'), unit: 'MB',
    help: i18n.t('RAM the SQLite database may use as page cache.')
  },
  {
    key: 'database.startup_clean', type: 'boolean', restart: true,
    label: i18n.t('Optimize at startup'),
    trueLabel: i18n.t('Enabled'), falseLabel: i18n.t('Disabled'),
    help: i18n.t('Delete the expired entries and compact the database each time the cache service starts.')
  }
]

// getPath reads "app.rate_limit_rate" in the nested configuration document.
const getPath = (config, key) => key.split('.').reduce((node, part) => (node && node[part] !== undefined) ? node[part] : undefined, config)

// toForm turns a configuration value into its input representation.
const toForm = (field, value) => {
  switch (field.type) {
    case 'list':
      return Array.isArray(value) ? value.join('\n') : ''
    case 'boolean':
      return !!value
    default:
      return (value === undefined || value === null) ? '' : String(value)
  }
}

// fromForm turns an input value back into the typed value connector-cache
// expects; undefined when the input is not valid.
const fromForm = (field, value) => {
  switch (field.type) {
    case 'list':
      return String(value || '').split('\n').map(line => line.trim()).filter(line => line)
    case 'boolean':
      return !!value
    default: {
      if (String(value).trim() === '' || !/^-?\d+$/.test(String(value).trim()))
        return undefined
      const n = Number(value)
      if (n < field.min || n > field.max)
        return undefined
      return n
    }
  }
}

const sameValue = (a, b) => JSON.stringify(a) === JSON.stringify(b)

export const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const stats = ref(null)
  const statsError = ref(null)
  const config = ref(null)
  const configError = ref(null)
  const unsupported = ref(false)
  const isLoading = ref(false)
  const isSaving = ref(false)
  const isActing = ref(false)
  const lastRefresh = ref(null)
  const restartPending = ref(false)
  const showOptimizeModal = ref(false)
  const showCleanModal = ref(false)
  const showRestartModal = ref(false)

  const form = reactive({})
  const loaded = reactive({})

  const isBusy = computed(() => isSaving.value || isActing.value)

  const errorMessage = (error, fallback) => {
    const { response: { status, data } = {} } = error || {}
    if (status === 404)
      unsupported.value = true
    if (data && typeof data === 'object' && data.message)
      return data.message
    if (typeof data === 'string' && data.trim())
      return data.trim()
    return fallback
  }

  const loadForm = document => {
    fields.forEach(field => {
      const value = toForm(field, getPath(document, field.key))
      loaded[field.key] = value
      form[field.key] = value
    })
  }

  const dirtyFields = computed(() => fields.filter(field => !sameValue(fromForm(field, form[field.key]), fromForm(field, loaded[field.key]))))
  const isValid = computed(() => fields.every(field => fromForm(field, form[field.key]) !== undefined))

  const fieldState = field => {
    if (fromForm(field, form[field.key]) === undefined)
      return false
    return dirtyFields.value.includes(field) ? true : null
  }
  const fieldFeedback = field => {
    if (field.type === 'number')
      return i18n.t('An integer between {min} and {max} is expected.', { min: field.min, max: field.max })
    return i18n.t('Invalid value.')
  }

  const ttl = key => {
    const value = fromForm(fields.find(field => field.key === key), loaded[key])
    return (value === undefined) ? '?' : value
  }

  const refreshStats = () => api.remoteCacheStats(props.id).then(response => {
    stats.value = response
    statsError.value = null
    unsupported.value = false
  }).catch(error => {
    stats.value = null
    statsError.value = errorMessage(error, i18n.t('Unable to fetch the cache statistics from the remote connector.'))
  })

  // The configuration is (re)loaded only while the form has no pending
  // edits: a periodic refresh must not throw the admin's changes away.
  const refreshConfig = (force = false) => {
    if (!force && config.value && dirtyFields.value.length)
      return Promise.resolve()
    return api.remoteCacheConfig(props.id).then(response => {
      config.value = response
      configError.value = null
      loadForm(response)
    }).catch(error => {
      configError.value = errorMessage(error, i18n.t('Unable to fetch the cache configuration from the remote connector.'))
    })
  }

  const refresh = () => {
    if (!props.id)
      return
    isLoading.value = true
    Promise.all([refreshStats(), refreshConfig()]).finally(() => {
      lastRefresh.value = (new Date()).toLocaleTimeString()
      isLoading.value = false
    })
  }

  const reset = () => {
    fields.forEach(field => { form[field.key] = loaded[field.key] })
  }

  const save = () => {
    if (!dirtyFields.value.length || !isValid.value)
      return
    const changed = dirtyFields.value
    const toUpdate = changed.map(field => ({ field: field.key, value: fromForm(field, form[field.key]) }))
    isSaving.value = true
    configError.value = null
    api.remoteCacheConfigUpdate(props.id, toUpdate).then(response => {
      config.value = response
      loadForm(response)
      if (changed.some(field => field.restart))
        restartPending.value = true
      $store.dispatch('notification/info', { message: i18n.t('Cache configuration saved on the remote connector.') })
    }).catch(error => {
      configError.value = errorMessage(error, i18n.t('Unable to save the cache configuration on the remote connector.'))
    }).finally(() => {
      isSaving.value = false
    })
  }

  // Delayed refreshes after an action, cleared on unmount.
  const refreshTimers = new Set()
  const scheduleRefresh = ms => {
    const timer = setTimeout(() => {
      refreshTimers.delete(timer)
      refresh()
    }, ms)
    refreshTimers.add(timer)
  }

  const act = (call, successMessage, failureMessage, refreshAfter = 1000) => {
    isActing.value = true
    return call(props.id).then(response => {
      $store.dispatch('notification/info', { message: (response && response.message) || successMessage })
    }).catch(error => {
      $store.dispatch('notification/danger', { message: errorMessage(error, failureMessage) })
    }).finally(() => {
      isActing.value = false
      scheduleRefresh(refreshAfter)
    })
  }

  const optimize = () => {
    showOptimizeModal.value = false
    act(api.remoteCacheOptimize,
      i18n.t('Expired cache entries deleted and database optimized.'),
      i18n.t('Unable to optimize the cache database.'))
  }
  const clean = () => {
    showCleanModal.value = false
    act(api.remoteCacheClean,
      i18n.t('The connector caches have been wiped.'),
      i18n.t('Unable to wipe the connector caches.'))
  }
  const restart = () => {
    showRestartModal.value = false
    restartPending.value = false
    act(api.remoteCacheRestart,
      i18n.t('Cache service restart requested.'),
      i18n.t('Unable to restart the cache service.'), 3000)
  }

  const formatBytes = bytes => {
    if (!bytes && bytes !== 0)
      return '-'
    const units = ['B', 'KB', 'MB', 'GB', 'TB']
    let value = bytes
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024
      unit++
    }
    return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`
  }

  let refreshInterval = null
  onMounted(() => {
    refresh()
    refreshInterval = setInterval(refresh, 30000)
  })
  onBeforeUnmount(() => {
    if (refreshInterval)
      clearInterval(refreshInterval)
    refreshTimers.forEach(timer => clearTimeout(timer))
    refreshTimers.clear()
  })

  return {
    fields,
    form,
    stats,
    statsError,
    config,
    configError,
    unsupported,
    isLoading,
    isSaving,
    isBusy,
    lastRefresh,
    restartPending,
    dirtyFields,
    isValid,
    fieldState,
    fieldFeedback,
    ttl,
    refresh,
    reset,
    save,
    optimize,
    clean,
    restart,
    showOptimizeModal,
    showCleanModal,
    showRestartModal,
    formatBytes
  }
}

// @vue/component
export default {
  name: 'the-cache',
  inheritAttrs: false,
  props,
  setup
}
</script>
