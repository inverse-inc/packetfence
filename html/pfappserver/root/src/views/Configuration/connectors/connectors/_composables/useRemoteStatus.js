import { computed, onBeforeUnmount, ref, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
import api from '../_api'
import { dnsServersOf } from './useDnsTopology'
import { connectorHealth, siteNetworkIssues, siteNetworkVariant } from './useConnectorHealth'

export { siteNetworkVariant }

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

export const formatDate = value => {
  if (!value)
    return '-'
  const date = new Date(value)
  return isNaN(date.getTime()) ? '-' : date.toLocaleString()
}

// badge of a site networking interface or route state

// Notifications render HTML: text coming from the remote must be escaped
const escapeHtml = text => String(text).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]))
const errorDetail = error => {
  const { response: { data } = {} } = error || {}
  const message = (data && typeof data === 'object') ? data.message : data
  return (typeof message === 'string' && message.trim()) ? ` (${escapeHtml(message.trim())})` : ''
}

// Live state of one connector-remote, shared by the header and the tabs of
// the connector view (provided as 'connectorRemote').
export const useRemoteStatus = (props, context) => {
  const { root: { $store } = {} } = context

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

  const isLive = computed(() => !!props.id && !props.isNew && !props.isClone)

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
      // the DNS servers as saved on the connector (Settings > DNS)
      api.item(props.id).then(item => dnsServersOf([{ ...item, id: props.id }]).servers).catch(() => [])
    ]).then(([response, dns]) => {
      if (mySeq !== seq)
        return
      equipment.value = response.equipment || {}
      networks.value = response.networks || []
      dnsConnectors.value = dns
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

  // follow-up polls of an action (install, HA switch), cleared with the view
  const followTimers = new Set()
  const clearFollowTimers = () => {
    followTimers.forEach(timer => clearInterval(timer))
    followTimers.clear()
  }
  // refreshes the status every interval ms, count times or until done()
  const follow = (interval, count, done = () => false, onEnd = () => {}) => {
    let polls = 0
    const timer = setInterval(() => {
      refreshStatus()
      if (++polls >= count || done()) {
        clearInterval(timer)
        followTimers.delete(timer)
        onEnd()
      }
    }, interval)
    followTimers.add(timer)
  }

  const restart = () => {
    seq++
    if (timer)
      clearTimeout(timer)
    timer = null
    clearFollowTimers()
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

  watch(() => [props.id, props.isNew, props.isClone], restart, { immediate: true })

  onBeforeUnmount(() => {
    seq++
    if (timer)
      clearTimeout(timer)
    timer = null
    clearFollowTimers()
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

  // The remote advertises recorded terminal sessions in its system info
  // (terminal_recordings); older connectors omit the field.
  const recordingsAvailable = computed(() => !!(system.value && system.value.terminal_recordings === true))

  // Result of the connector's last VLAN interface / static route reconcile
  // pass (site_network), its DHCP relays and captive DNS responders. Absent
  // on connectors predating the feature or before the first pass ran.
  const siteNetwork = computed(() => (system.value && system.value.site_network) || null)
  const dhcpRelay = computed(() => {
    const { dhcp_relay: relay } = system.value || {}
    return Array.isArray(relay) ? relay : []
  })
  const captiveDns = computed(() => {
    const { dns_server: servers } = system.value || {}
    return Array.isArray(servers) ? servers : []
  })
  const siteNetworkErrors = computed(() => siteNetworkIssues(system.value))
  // tunnel and site services rolled up (useConnectorHealth)
  const health = computed(() => connectorHealth(isConnected.value ? 'up' : (status.value ? 'down' : 'unknown'), status.value))

  // Listeners the connector opened on its host (local_binds).
  const localBinds = computed(() => {
    const { local_binds: binds } = system.value || {}
    return Array.isArray(binds) ? binds : []
  })

  // NTLM authentication services on the connector host (host_packages;
  // installed through the host's trigger file, asynchronously).
  const hostPackages = computed(() => {
    const { host_packages: hp } = system.value || {}
    return (hp && hp.packages) ? hp : null
  })
  const ntlmInstalled = computed(() => {
    const hp = hostPackages.value
    return !!hp && hp.available && hp.packages.length > 0 && hp.packages.every(pkg => pkg.installed)
  })
  const installInProgress = computed(() => /^(requested|installing)/.test((hostPackages.value || {}).install_state || ''))
  const isInstalling = ref(false)
  const showNtlmInstallModal = ref(false)
  const onInstallNtlm = () => {
    showNtlmInstallModal.value = false
    isInstalling.value = true
    api.remoteInstall(props.id, ['packetfence-ntlm-auth-join-remote']).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Install started on the connector host. The package state updates as it progresses (details in the "install" log).') })
      // follow the install more closely than the regular refresh for a while
      follow(10000, 30, () => ntlmInstalled.value)
    }).catch(error => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to trigger the install on the connector host.') + errorDetail(error) })
    }).finally(() => {
      isInstalling.value = false
      setTimeout(refreshStatus, 3000)
    })
  }

  // NTLM authentication units of the connector host (host_services, written
  // by the host). An action goes to the host through its trigger file and
  // the state follows on the next polls.
  const hostServices = computed(() => {
    const { host_services: hs } = system.value || {}
    return (hs && hs.available && Array.isArray(hs.services)) ? hs : null
  })
  const actingService = ref(null) // { service, action } while a request is relayed and followed
  const onServiceAction = (service, action) => {
    actingService.value = { service, action }
    api.remoteService(props.id, action, service).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('{action} of {service} requested on the connector host. Its state updates within a few seconds.', { action, service }) })
      follow(3000, 5, () => false, () => { actingService.value = null })
    }).catch(error => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to {action} {service} on the connector host.', { action, service }) + errorDetail(error) })
      actingService.value = null
    })
  }

  // HA state reported by the master (the only host with a tunnel); peers are
  // the backups heard through their LAN heartbeats.
  const ha = computed(() => {
    const { ha: state } = system.value || {}
    return (state && state.enabled) ? state : null
  })
  const haPeersAlive = computed(() => ((ha.value && ha.value.peers) || []).filter(peer => peer.alive))

  // Hand the VIP over to another host of the group (controlled failover).
  const isSwitching = ref(false)
  const showSwitchModal = ref(false)
  const switchTarget = ref(null)
  const askSwitch = peer => {
    switchTarget.value = peer
    showSwitchModal.value = true
  }
  const onSwitchActive = () => {
    showSwitchModal.value = false
    if (!switchTarget.value)
      return
    isSwitching.value = true
    const target = switchTarget.value.address
    api.remoteHaSwitch(props.id, target).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Switch started: {address} is taking the virtual IP. The status updates once its tunnel is up.', { address: target }) })
    }).catch(error => {
      $store.dispatch('notification/danger', { message: i18n.t('Unable to switch the active host.') + errorDetail(error) })
    }).finally(() => {
      // the old master's tunnel drops within a second, the new one is up a
      // few seconds later
      follow(5000, 6, () => false, () => { isSwitching.value = false })
    })
  }

  const attentionCount = computed(() => {
    const { upgrade_available: upgradeAvailable = false } = status.value || {}
    const haAlone = (ha.value && !haPeersAlive.value.length) ? 1 : 0
    return errors.value.length + (upgradeAvailable ? 1 : 0) + unboundStaticConnections.value.length + haAlone + siteNetworkErrors.value.length
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
      $store.dispatch('notification/danger', { message: i18n.t('Unable to open a terminal on the remote connector.') + errorDetail(error) })
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
    recordingsAvailable,
    siteNetwork,
    dhcpRelay,
    captiveDns,
    siteNetworkErrors,
    health,
    localBinds,
    hostPackages,
    ntlmInstalled,
    installInProgress,
    isInstalling,
    showNtlmInstallModal,
    onInstallNtlm,
    hostServices,
    actingService,
    onServiceAction,
    ha,
    haPeersAlive,
    isSwitching,
    showSwitchModal,
    switchTarget,
    askSwitch,
    onSwitchActive,
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
