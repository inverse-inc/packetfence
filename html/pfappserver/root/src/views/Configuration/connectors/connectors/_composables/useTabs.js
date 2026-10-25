import { computed, ref } from '@vue/composition-api'

const LIVE_TABS = ['overview', 'networking', 'devices', 'troubleshooting']

// sub-tabs of the Settings tab, kept in ?section=
const SETTINGS_SECTIONS = ['connector', 'fingerbank', 'networking', 'dns']

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
      root.$router.replace({ query: { ...query, tab: value } })
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

  // a section of the Settings tab
  const goToSettings = section => {
    const { query } = root.$route
    root.$router.replace({ query: { ...query, tab: 'settings', section } })
      .catch(e => { if (e.name !== 'NavigationDuplicated') throw e })
  }

  // sub-view of the Networking tab: 'tunnel', 'dns' or 'site'
  const networkingView = ref('tunnel')
  const goToDns = () => {
    networkingView.value = 'dns'
    goToTab('networking')
  }
  const goToSiteNetwork = () => {
    networkingView.value = 'site'
    goToTab('networking')
  }

  return {
    tabs,
    tab,
    tabIndex,
    isSettings,
    goToTab,
    settingsTabIndex,
    goToSettings,
    networkingView,
    goToDns,
    goToSiteNetwork
  }
}
