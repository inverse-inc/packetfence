import { computed, onBeforeUnmount, onMounted, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

const POLL_INTERVAL = 60000

export const uptimeWindows = [
  { value: '1h', text: '1h', minutes: 60 },
  { value: '24h', text: '24h', minutes: 24 * 60 },
  { value: '30d', text: '30d', minutes: 30 * 24 * 60 }
]

// Uptime history of a connector (pfconnector-remotes/{id}/uptime): the
// tunnel, and the hosts of an HA connector, over the selected window. Shared
// by the cards of the overview so that they show the same window.
export const useUptime = id => {
  const uptimeWindow = ref('24h')
  const history = ref(null)
  const error = ref(null)

  const refresh = () => {
    if (!id.value)
      return
    const requested = uptimeWindow.value
    api.remoteUptime(id.value, requested).then(data => {
      if (requested !== uptimeWindow.value)
        return
      history.value = data
      error.value = null
    }).catch(() => {
      error.value = i18n.t('Uptime history unavailable.')
    })
  }

  let interval = null
  onMounted(() => {
    refresh()
    interval = setInterval(refresh, POLL_INTERVAL)
  })
  onBeforeUnmount(() => {
    if (interval)
      clearInterval(interval)
  })
  watch(uptimeWindow, refresh)

  const windowMinutes = computed(() => uptimeWindows.find(w => w.value === uptimeWindow.value).minutes)

  return { uptimeWindow, windowMinutes, history, error, refresh }
}

// a date of a bucket, with the day for the 30 days window
export const formatBucketTime = (value, window) => {
  const date = new Date(value)
  if (window === '30d')
    return date.toLocaleString(i18n.locale, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  return date.toLocaleTimeString(i18n.locale, { hour: '2-digit', minute: '2-digit' })
}

// minutes as min, h or d
export const formatDuration = minutes => {
  if (minutes < 120)
    return i18n.t('{n} min', { n: Math.round(minutes) })
  if (minutes < 48 * 60)
    return i18n.t('{n} h', { n: Math.round(minutes / 6) / 10 })
  return i18n.t('{n} d', { n: Math.round(minutes / 144) / 10 })
}
