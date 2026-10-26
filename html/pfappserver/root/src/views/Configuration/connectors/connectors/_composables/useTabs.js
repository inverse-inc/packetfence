import { computed, ref } from '@vue/composition-api'

const LIVE_TABS = ['overview', 'networking', 'devices', 'troubleshooting']

// sub-tabs of the Settings tab, kept in ?section=
const SETTINGS_SECTIONS = ['connector', 'fingerbank', 'networking', 'dns']

// sub-views of the Networking tab, kept in ?view=
const NETWORKING_VIEWS = ['tunnel', 'dns', 'site']

// the query of a tab: the parameters of the other tabs' sub-tabs are dropped,
// so that a copied link opens the sub-tab shown
const tabQuery = (query, tab, extra = {}) => {
  const { section, view, ...rest } = query || {} // eslint-disable-line no-unused-vars
  return {
    ...rest,
    tab,
    ...((tab === 'settings' && section) ? { section } : {}),
    ...((tab === 'networking' && view) ? { view } : {}),
    ...extra
  }
}

// The selected tab of the connector view, kept in ?tab= (not a route prop:
// a prop change would re-init the form and drop unsaved changes).
export const useTabs = (props, context) => {
  const { root } = context

  const tabs = computed(() => {
    if (props.isNew || props.isClone)
      return ['settings']
    return [...LIVE_TABS, 'settings']
  })

  const tab = computed({
    get: () => {
      const { query: { tab: queryTab } = {} } = root.$route || {}
      return tabs.value.includes(queryTab) ? queryTab : tabs.value[0]
    },
    set: value => {
      if (value === tab.value)
        return
      const { query } = root.$route
      root.$router.replace({ query: tabQuery(query, value) })
        .catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
    }
  })

  const tabIndex = computed({
    get: () => tabs.value.indexOf(tab.value),
    set: index => {
      if (index in tabs.value)
        tab.value = tabs.value[index]
    }
  })

  const isSettings = computed(() => tab.value === 'settings')

  const goToTab = value => { tab.value = value }

  const settingsTabIndex = computed({
    get: () => {
      const { query: { section } = {} } = root.$route || {}
      return Math.max(SETTINGS_SECTIONS.indexOf(section), 0)
    },
    set: index => {
      const section = SETTINGS_SECTIONS[index]
      const { query } = root.$route
      if (!section || query.section === section || (!query.section && index === 0))
        return
      root.$router.replace({ query: { ...query, section } })
        .catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
    }
  })

  // a section of the Settings tab, as a link target (deep link) or a jump
  const settingsLocation = section => {
    const { query } = root.$route
    return { query: tabQuery(query, 'settings', { section }) }
  }
  const goToSettings = section => {
    root.$router.replace(settingsLocation(section))
      .catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
  }

  // sub-view of the Networking tab: 'tunnel', 'dns' or 'site'
  const networkingView = computed({
    get: () => {
      const { query: { view } = {} } = root.$route || {}
      return NETWORKING_VIEWS.includes(view) ? view : NETWORKING_VIEWS[0]
    },
    set: view => {
      const { query } = root.$route
      if (query.view === view || (!query.view && view === NETWORKING_VIEWS[0]))
        return
      root.$router.replace({ query: { ...query, view } })
        .catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
    }
  })
  const goToNetworking = view => {
    const { query } = root.$route
    root.$router.replace({ query: tabQuery(query, 'networking', { view }) })
      .catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
  }
  const goToDns = () => goToNetworking('dns')
  const goToSiteNetwork = () => goToNetworking('site')

  // log file the Live Logs of the Troubleshooting tab open and stream, from
  // a time (RFC 3339) or its last lines (null)
  const logFile = ref(null)
  const logSince = ref(null)
  const goToLogs = (file, since = null) => {
    logFile.value = file
    logSince.value = since
    goToTab('troubleshooting')
  }

  return {
    tabs,
    tab,
    tabIndex,
    isSettings,
    goToTab,
    settingsTabIndex,
    settingsLocation,
    goToSettings,
    networkingView,
    goToDns,
    goToSiteNetwork,
    logFile,
    logSince,
    goToLogs
  }
}
