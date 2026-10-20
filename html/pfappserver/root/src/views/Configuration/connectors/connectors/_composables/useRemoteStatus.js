import { computed, onBeforeUnmount, ref, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import api from '../_api'
import dnsApi from '../../dns/_api'

const POLL_INTERVAL = 30000
const UPGRADE_POLL_INTERVAL = 10000
const UPGRADE_FOLLOW_DURATION = 5 * 60 * 1000

export const formatBytes = bytes => {
  if (!bytes && bytes !== 0)
    return '-'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let value = bytes
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit++
  }
  return `${value.toFixed(1)} ${units[unit]}`
}

export const formatPercent = value => {
  if (!value && value !== 0)
    return '-'
  return `${value.toFixed(1)}%`
}

export const formatLoad = value => {
  if (!value && value !== 0)
    return '-'
  return value.toFixed(2)
}

export const formatUptime = seconds => {
  if (!seconds && seconds !== 0)
    return '-'
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  return `${days}d ${hours}h ${minutes}m`
}

// Live state of one connector-remote, shared by the header and the tabs of
// the connector view (provided as 'connectorRemote').
export const useRemoteStatus = (props, context) => {
  const { root: { $store } = {} } = context

  const canRead = computed(() => acl.$can('read', 'connectors'))
  const canUpdate = computed(() => acl.$can('update', 'connectors'))

  const status = ref(null)
  const errors = ref([])
  const isLoading = ref(false)
  const lastRefresh = ref(null)

  const equipment = ref(null)
  const networks = ref([])
  const dnsConnectors = ref([])
  const equipmentError = ref(null)
  const isEquipmentLoading = ref(false)

  const isRestarting = ref(false)
  const isUpgrading = ref(false)
  const isTerminalLoading = ref(false)
  const showTerminalModal = ref(false)
  const showUpgradeModal = ref(false)
  const showRestartModal = ref(false)
  const terminalCode = ref('')
  const upgradeFollowUntil = ref(null) // Date while following an upgrade

  const isLive = computed(() => !!props.id && !props.isNew && !props.isClone && canRead.value)

  let timer = null
  let seq = 0 // drops responses for a previous connector

  const schedule = () => {
    if (timer)
      clearTimeout(timer)
    const following = upgradeFollowUntil.value && Date.now() < upgradeFollowUntil.value.getTime()
    timer = setTimeout(refreshStatus, following ? UPGRADE_POLL_INTERVAL : POLL_INTERVAL)
  }

  const refreshStatus = () => {
    if (!isLive.value)
      return Promise.resolve()
    const mySeq = seq
    isLoading.value = true
    return api.remoteStatusQuiet(props.id).then(response => {
      if (mySeq !== seq)
        return
      status.value = response
      errors.value = response.errors || []
      if (upgradeFollowUntil.value && response.upgrade_available === false && response.system) {
        upgradeFollowUntil.value = null
        $store.dispatch('notification/info', { message: i18n.t('The remote connector now runs version {version}.', { version: response.system.version }) })
      }
    }).catch(error => {
      if (mySeq !== seq)
        return
      const { response: { data } = {} } = error || {}
      const detail = (typeof data === 'string' && data.trim()) ? ` (${data.trim()})` : ''
      errors.value = [i18n.t('Unable to fetch the remote connector status.') + detail]
    }).finally(() => {
      if (mySeq !== seq)
        return
      isLoading.value = false
      lastRefresh.value = new Date()
      if (upgradeFollowUntil.value && Date.now() >= upgradeFollowUntil.value.getTime()) {
        upgradeFollowUntil.value = null
        $store.dispatch('notification/warning', { message: i18n.t('No new version was reported by the remote connector. Check its upgrade log.') })
      }
      schedule()
    })
  }

  const refreshEquipment = () => {
    if (!isLive.value)
      return Promise.resolve()
    const mySeq = seq
    isEquipmentLoading.value = true
    return Promise.all([
      api.equipment(props.id),
      dnsApi.list({ limit: 1000 }).then(({ items = [] }) => items).catch(() => [])
    ]).then(([response, dns]) => {
      if (mySeq !== seq)
        return
      equipment.value = response.equipment || {}
      networks.value = response.networks || []
      const ids = (equipment.value.dns_connectors || []).map(item => item.id)
      dnsConnectors.value = dns.filter(item => ids.includes(item.id))
      equipmentError.value = null
    }).catch(() => {
      if (mySeq !== seq)
        return
      equipmentError.value = i18n.t('Unable to fetch the equipment located behind this connector.')
    }).finally(() => {
      if (mySeq !== seq)
        return
      isEquipmentLoading.value = false
    })
  }

  const refresh = () => Promise.all([refreshStatus(), refreshEquipment()])

  const restart = () => {
    seq++
    if (timer)
      clearTimeout(timer)
    timer = null
    status.value = null
    errors.value = []
    lastRefresh.value = null
    equipment.value = null
    networks.value = []
    dnsConnectors.value = []
    equipmentError.value = null
    isLoading.value = false
    isEquipmentLoading.value = false
    upgradeFollowUntil.value = null
    if (isLive.value)
      refresh()
  }

  watch(() => [props.id, props.isNew, props.isClone, canRead.value], restart, { immediate: true })

  onBeforeUnmount(() => {
    seq++
    if (timer)
      clearTimeout(timer)
    timer = null
  })

  const isConnected = computed(() => !!(status.value && status.value.connected))
  const system = computed(() => (status.value && status.value.system) || null)
  const logFiles = computed(() => {
    const { log_files: files } = system.value || {}
    return Array.isArray(files) ? files : []
  })
  // Only when the remote says so: a remote that doesn't report it can't
  // enforce the terminal session
  const isTerminalEnabled = computed(() => !!(system.value && system.value.terminal_enabled === true))
  const unboundStaticConnections = computed(() => {
    if (!isConnected.value)
      return []
    const { static_connections: connections = [] } = status.value || {}
    return connections.filter(connection => !connection.bound)
  })
  const attentionCount = computed(() => {
    const { upgrade_available: upgradeAvailable = false } = status.value || {}
    return errors.value.length + (upgradeAvailable ? 1 : 0) + unboundStaticConnections.value.length
  })

  const onRestart = () => {
    showRestartModal.value = false
    isRestarting.value = true
    api.remoteRestart(props.id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Restart requested. The remote connector will reconnect shortly.') })
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to restart the remote connector.') })
    }).finally(() => {
      isRestarting.value = false
      setTimeout(refreshStatus, 5000)
    })
  }

  const onUpgrade = () => {
    showUpgradeModal.value = false
    isUpgrading.value = true
    api.remoteUpgrade(props.id).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Upgrade started. The remote connector will restart and report its new version once done (see conf/upgrade.log on the connector host for details).') })
      upgradeFollowUntil.value = new Date(Date.now() + UPGRADE_FOLLOW_DURATION)
      schedule()
    }).catch(() => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to trigger the upgrade of the remote connector.') })
    }).finally(() => {
      isUpgrading.value = false
    })
  }

  // Called from a click handler: the tab is opened right away, while the
  // browser still sees the user's click, and only pointed at the terminal
  // once the session is authorized. Opening it after the API calls would get
  // it blocked as a popup, after the session and the TOTP code were used.
  const requestTerminal = code => {
    if (isTerminalLoading.value)
      return
    const terminalWindow = window.open('', '_blank')
    if (!terminalWindow) {
      $store.dispatch('notification/danger', { message: i18n.t('The terminal tab was blocked by the browser. Allow popups for this site and try again.') })
      return
    }
    terminalWindow.document.title = i18n.t('Opening terminal...')
    terminalWindow.document.body.textContent = i18n.t('Opening terminal...')
    isTerminalLoading.value = true
    api.terminalSession(props.id).then(session => {
      return api.terminalAuthorize(props.id, session.uuid, code).then(() => {
        showTerminalModal.value = false
        terminalWindow.location.href = `/api/v1/terminal/${encodeURIComponent(props.id)}/`
      })
    }).catch(error => {
      terminalWindow.close()
      const { response: { data } = {} } = error || {}
      const detail = (typeof data === 'string' && data.trim()) ? ` (${data.trim()})` : ''
      $store.dispatch('notification/danger', { message: i18n.t('Unable to open a terminal on the remote connector.') + detail })
    }).finally(() => {
      isTerminalLoading.value = false
    })
  }

  const openTerminal = () => {
    const { terminal_totp: totpRequired } = system.value || {}
    if (totpRequired === false) {
      // The remote reports TOTP disabled (PFCONNECTOR_TERMINAL_TOTP=false):
      // no code to prompt for. Enforcement stays on the remote either way.
      requestTerminal()
      return
    }
    terminalCode.value = ''
    showTerminalModal.value = true
  }

  const authorizeTerminal = () => {
    if (terminalCode.value.length !== 6)
      return
    requestTerminal(terminalCode.value)
  }

  return {
    canRead,
    canUpdate,
    status,
    errors,
    isLoading,
    lastRefresh,
    isConnected,
    system,
    logFiles,
    isTerminalEnabled,
    unboundStaticConnections,
    attentionCount,
    equipment,
    networks,
    dnsConnectors,
    equipmentError,
    isEquipmentLoading,
    isRestarting,
    isUpgrading,
    isTerminalLoading,
    showTerminalModal,
    showUpgradeModal,
    showRestartModal,
    terminalCode,
    upgradeFollowUntil,
    refresh,
    refreshStatus,
    refreshEquipment,
    onRestart,
    onUpgrade,
    openTerminal,
    authorizeTerminal
  }
}
