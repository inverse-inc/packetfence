import Vue from 'vue'
import i18n from '@/utils/locale'

// Shared scope/filter helpers for the LiveLogs and HistoricalLogs session
// stores. timestamp/log_without_prefix/syslog_name are excluded from the
// countable scopes (per-line, or syslog_name duplicates process).

export const defaultScopes = () => ({
  hostname: { label: i18n.t('Hostname'), values: {} },
  filename: { label: i18n.t('Log Name'), values: {} },
  log_level: { label: i18n.t('Log Level'), values: {} },
  process: { label: i18n.t('Process Name'), values: {} }
})

// Count an event's meta values into the scopes; new values are inserted in
// sorted order so the sidebar lists stay stable while streaming.
export const addMeta = (scopes, event) => {
  const { data: { meta: { timestamp, log_without_prefix, syslog_name, ...meta } = {} } = {} } = event // eslint-disable-line no-unused-vars
  for (const key of Object.keys(meta)) {
    if (!(key in scopes)) {
      Vue.set(scopes, key, { label: key, values: { [meta[key]]: { count: 1 } } })
    }
    else if (!(meta[key] in scopes[key].values)) {
      Vue.set(scopes[key], 'values', Object.entries({
        ...scopes[key].values,
        [meta[key]]: { count: 1 }
      }).sort(([a], [b]) => {
        if (!a) return -1
        if (!b) return 1
        return +a - +b
      }).reduce((r, [k, v]) => {
        return { ...r, [k]: v }
      }, {}))
    }
    else {
      Vue.set(scopes[key].values[meta[key]], 'count', scopes[key].values[meta[key]].count + 1)
    }
  }
}

export const delMeta = (scopes, event) => {
  const { data: { meta: { timestamp, log_without_prefix, syslog_name, ...meta } = {} } = {} } = event // eslint-disable-line no-unused-vars
  for (const key of Object.keys(meta)) {
    Vue.set(scopes[key].values[meta[key]], 'count', scopes[key].values[meta[key]].count - 1)
  }
}

// Set a value's filter flag, creating the scope/value entry if this module
// has not seen it yet: in the merged cluster view a user can click a value
// only another peer produced (e.g. a different node's hostname); count
// stays 0 until addMeta sees it here.
export const setScopeFilter = (scopes, scope, key, filter) => {
  if (!(scope in scopes)) {
    Vue.set(scopes, scope, { label: scope, values: {} })
  }
  if (!(key in scopes[scope].values)) {
    Vue.set(scopes[scope].values, key, { count: 0 })
  }
  Vue.set(scopes[scope].values[key], 'filter', filter)
}

// Getter bodies shared by both session stores.
export const isFilteredGetter = state => (scope, key) => {
  const { scopes: { [scope]: { values: { [key]: { filter = false } = {} } = {} } = {} } = {} } = state
  return filter
}

export const eventsFilteredGetter = state => {
  const fk = Object.keys(state.filters)
  if (fk.length === 0) {
    return state.events
  }
  return state.events.filter(event => {
    const { data: { meta: { timestamp, log_without_prefix, ...meta } = {} } = {} } = event // eslint-disable-line no-unused-vars
    for (const k of fk) {
      if (!state.filters[k].includes(meta[k])) {
        return false
      }
    }
    return event
  })
}

// Basename: the live tailer reports a full path, the history endpoint already
// a basename — splitting on both separators is idempotent for either.
export const basename = (path) => String(path || '').split(/[\\/]/).pop()

// Strip the hostname token (already shown in the source tag) from a raw syslog
// line. Only when it sits in the expected slot — right after the timestamp —
// so continuation/stack-trace and legacy lines are left intact.
export const stripHostnameToken = (raw, hostname) => {
  if (!raw || !hostname) return raw
  const escaped = hostname.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return raw.replace(new RegExp('^(\\S+\\s+)' + escaped + '\\s+'), '$1')
}

// Stable per-hostname colour, memoized: hash into 6 buckets matching the
// .log-source-tag-0..5 classes.
const hostColorCache = new Map()
export const hostColorIndex = (hostname) => {
  if (!hostname) return 0
  const cached = hostColorCache.get(hostname)
  if (cached !== undefined) return cached
  let h = 0
  for (let i = 0; i < hostname.length; i++) {
    h = (h * 31 + hostname.charCodeAt(i)) | 0
  }
  const idx = Math.abs(h) % 6
  hostColorCache.set(hostname, idx)
  return idx
}

// Rebuild the active-filters map from the scope flags (UPDATE_FILTERS body).
export const computeFilters = scopes => {
  const filters = {}
  for (const [scope, { values = {} }] of Object.entries(scopes)) {
    const active = Object.entries(values).filter(([, v]) => v.filter).map(([k]) => k)
    if (active.length) filters[scope] = active
  }
  return filters
}
