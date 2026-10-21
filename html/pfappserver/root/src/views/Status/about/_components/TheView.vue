<template>
  <b-card no-body>
    <b-card-header class="pl-4">
      <h4 class="d-inline mb-0">{{ isSaas ? 'PacketFence Cloud' : 'PacketFence' }} {{ version }}</h4>
    </b-card-header>
    <div class="card-body">
      <!-- Filter -->
      <div class="section-sidebar-filter px-0 mb-4">
        <b-input-group>
          <b-input-group-prepend>
            <icon class="h-auto" name="search" scale=".75" />
          </b-input-group-prepend>
          <b-form-input v-model="filter" v-focus
            class="border-0" type="text" :placeholder="$t('Filter')" />
          <b-input-group-append v-if="filter">
            <b-btn @click="filter = ''"><icon name="times-circle" /></b-btn>
          </b-input-group-append>
        </b-input-group>
      </div>

      <!-- Quick Links -->
      <template v-if="filteredSections.length">
        <h5 class="mb-3" v-t="'Quick Links'"></h5>
        <b-row class="mb-4">
          <b-col cols="6" md="4" lg="2" v-for="section in filteredSections" :key="section.path" class="mb-3">
          <div class="about-card-wrapper">
            <b-card class="about-card h-100 text-center" :to="section.path" tag="router-link">
              <icon :name="section.icon" scale="2" class="mb-2" />
              <div class="small">{{ section.name }}</div>
            </b-card>
            <div class="about-card-dropdown" v-if="section.items && section.items.length">
              <!-- Wrap each item group in a div for proper Vue tracking -->
              <div v-for="item in section.items" :key="item.path" class="about-card-dropdown-group">
                <router-link :to="item.path" class="about-card-dropdown-item">
                  {{ item.name }}
                </router-link>
                <!-- Saved searches for this specific item -->
                <router-link
                  v-for="search in item.savedSearches"
                  :key="`saved-${item.path}-${search.name}`"
                  :to="search.route"
                  class="about-card-dropdown-item about-card-dropdown-item-nested"
                >
                  <icon name="search" scale="0.8" class="mr-1" />
                  {{ search.name }}
                </router-link>
              </div>
            </div>
          </div>
        </b-col>
        </b-row>
      </template>

      <!-- Configuration -->
      <template v-if="filteredConfigSections.length">
        <h5 class="mb-3" v-t="'Configuration'"></h5>
        <b-row class="mb-4">
          <b-col cols="6" md="4" lg="2" v-for="section in filteredConfigSections" :key="section.path" class="mb-3">
          <div class="about-card-wrapper">
            <b-card class="about-card h-100 text-center" :to="section.path" tag="router-link">
              <icon :name="section.icon" scale="2" class="mb-2" />
              <div class="small">{{ section.name }}</div>
            </b-card>
            <div class="about-card-dropdown" v-if="section.items && section.items.length">
              <div v-for="item in section.items" :key="item.path || item.name" class="about-card-dropdown-group">
                <template v-if="item.path">
                  <router-link :to="item.path" class="about-card-dropdown-item">
                    {{ item.name }}
                  </router-link>
                </template>
                <template v-else-if="item.items">
                  <div class="about-card-dropdown-header">{{ item.name }}</div>
                  <router-link
                    v-for="subitem in item.items"
                    :key="subitem.path"
                    :to="subitem.path"
                    class="about-card-dropdown-item about-card-dropdown-item-nested"
                  >
                    {{ subitem.name }}
                  </router-link>
                </template>
              </div>
            </div>
          </div>
          </b-col>
        </b-row>
      </template>

      <!-- Help -->
      <template v-if="isSaas || guides.length">
        <h5 class="mb-3" v-t="'Help'"></h5>
        <b-row>
          <!-- Support Inquiry -->
          <b-col v-if="isSaas" cols="6" md="4" lg="2" class="mb-3">
            <div class="about-card-doc-wrapper">
              <a href="https://www.packetfence.com/docs/" target="_blank" class="about-card-support-link">
                <b-card class="about-card h-100 text-center d-flex align-items-center justify-content-center">
                  <icon name="question-circle" scale="2" class="mb-2" />
                  <div class="small">{{ $t('Support Inquiry') }}</div>
                </b-card>
              </a>
            </div>
          </b-col>
          <b-col cols="6" md="4" lg="2" v-for="doc in guides" :key="doc.name" class="mb-3">
            <div class="about-card-doc-wrapper">
              <b-card no-body class="about-card h-100 text-center d-flex flex-column">
                <div class="d-flex flex-column align-items-center justify-content-center flex-grow-1 p-3">
                  <icon name="book" scale="2" class="mb-2" />
                  <div class="small">{{ doc.text }}</div>
                </div>
                <hr class="m-0">
                <div class="d-flex about-card-doc-actions">
                  <a href="#" class="about-card-doc-link" @click.prevent="openGuideFullscreen(doc.name)">
                    HTML <small class="text-muted">({{ formatFileSize(doc.size) }})</small>
                  </a>
                  <a v-if="doc.pdf_size" :href="`/static/doc/${doc.name.replace('.html', '.pdf')}`" target="_blank"
                    class="about-card-doc-link">
                    PDF <small class="text-muted">({{ formatFileSize(doc.pdf_size) }})</small>
                  </a>
                </div>
              </b-card>
            </div>
          </b-col>
        </b-row>
      </template>
    </div>
  </b-card>
</template>

<script>
import { computed, onMounted, ref, watch } from '@vue/composition-api'
import bytes from '@/utils/bytes'
import { focus } from '@/directives'
import i18n from '@/utils/locale'
import { useSections as useConfigSections } from '@/views/Configuration/_composables/useSections'

const directives = {
  focus
}

const setup = (props, context) => {
  const { root: { $store, $router } = {} } = context

  // Helper to get saveSearchNamespace from router meta by path
  const getNamespaceFromRouter = (path) => {
    const routes = $router.options.routes || []
    // Recursively search for the route
    const findRoute = (routes, targetPath) => {
      for (const route of routes) {
        const fullPath = route.path
        if (fullPath === targetPath || `/${route.path}` === targetPath) {
          return route.meta?.saveSearchNamespace
        }
        if (route.children) {
          // Build child path
          for (const child of route.children) {
            const childPath = child.path.startsWith('/')
              ? child.path
              : `${fullPath}/${child.path}`.replace(/\/+/g, '/')
            if (childPath === targetPath) {
              return child.meta?.saveSearchNamespace
            }
          }
        }
      }
      return null
    }
    return findRoute(routes, path)
  }

  // System info from store
  const version = computed(() => $store.getters['system/version'])
  const isSaas = computed(() => $store.getters['system/isSaas'])

  // Documentation guides
  onMounted(() => $store.dispatch('documentation/getIndex'))
  const guides = computed(() => {
    const index = $store.getters['documentation/index'] || []
    return [...index].sort((a, b) => a.text.localeCompare(b.text))
  })

  const formatFileSize = (value) => {
    return bytes.toHuman(value, 2, true) + 'B'
  }

  const openGuideFullscreen = (filename) => {
    $store.dispatch('documentation/setPath', filename)
    $store.dispatch('documentation/openViewer')
    $store.commit('documentation/FULLSCREEN_ON')
  }

  // Initialize preferences and load saved searches
  onMounted(() => {
    $store.dispatch('preferences/init')
  })

  // Reactive preferences cache (same pattern as SectionSidebarItem)
  const preferencesCache = ref({})
  watch(
    () => $store.state.preferences.cache,
    (newCache) => {
      preferencesCache.value = { ...newCache }
    },
    { deep: true, immediate: true }
  )

  // Helper to get saved searches for a namespace (used inside computed)
  const getSavedSearches = (cache, saveSearchNamespace, path) => {
    if (!saveSearchNamespace) return []

    const searches = []

    // Advanced searches
    const advancedKey = `${saveSearchNamespace}::advancedSearch`
    const { values: advancedValues = {} } = cache[advancedKey] || {}
    Object.keys(advancedValues).forEach(name => {
      const { query: conditionAdvanced } = advancedValues[name]
      if (conditionAdvanced) {
        searches.push({
          name,
          route: { path, query: { conditionAdvanced: JSON.stringify(conditionAdvanced) } }
        })
      }
    })

    // Basic searches
    const basicKey = `${saveSearchNamespace}::basicSearch`
    const { values: basicValues = {} } = cache[basicKey] || {}
    Object.keys(basicValues).forEach(name => {
      const { query: conditionBasic } = basicValues[name]
      if (conditionBasic) {
        searches.push({
          name,
          route: { path, query: { conditionBasic: JSON.stringify(conditionBasic) } }
        })
      }
    })

    return searches
  }

  // Quick link sections - savedSearches computed inline for reactivity
  const sections = computed(() => {
    const cache = preferencesCache.value

    // Raw section definitions
    const rawSections = [
      {
        name: i18n.t('Status'),
        path: '/status',
        icon: 'tachometer-alt',
        items: [
          { name: i18n.t('Dashboard'), path: isSaas.value ? '/status/dashboard_saas' : '/status/dashboard' },
          { name: i18n.t('Assets'), path: '/status/assets' },
          { name: i18n.t('Network Threats'), path: '/status/network_threats' },
          { name: i18n.t('Network Communication'), path: '/status/network_communication' },
          { name: i18n.t('Services'), path: isSaas.value ? '/status/services_saas' : '/status/services' },
          { name: i18n.t('Queue'), path: '/status/queue' }
        ]
      },
      {
        name: i18n.t('Reports'),
        path: '/reports',
        icon: 'chart-pie',
        items: []
      },
      {
        name: i18n.t('Auditing'),
        path: '/auditing',
        icon: 'clipboard-list',
        items: [
          { name: i18n.t('RADIUS Logs'), path: '/auditing/radiuslogs/search' },
          { name: i18n.t('DHCP Option 82'), path: '/auditing/dhcpoption82s/search' },
          { name: i18n.t('DNS Logs'), path: '/auditing/dnslogs/search' },
          { name: i18n.t('Admin API Logs'), path: '/auditing/admin_api_audit_logs/search' }
        ]
      },
      {
        name: i18n.t('Live Logs'),
        path: '/live-logs',
        icon: 'scroll',
        items: []
      },
      {
        name: i18n.t('Nodes'),
        path: '/nodes',
        icon: 'desktop',
        items: [
          { name: i18n.t('Search'), path: '/nodes/search' },
          { name: i18n.t('Create'), path: '/nodes/create' },
          { name: i18n.t('Import'), path: '/nodes/import' }
        ]
      },
      {
        name: i18n.t('Users'),
        path: '/users',
        icon: 'user',
        items: [
          { name: i18n.t('Search'), path: '/users/search' },
          { name: i18n.t('Create'), path: '/users/create' },
          { name: i18n.t('Import'), path: '/users/import' }
        ]
      }
    ]

    // Attach savedSearches to each item within the computed
    // Look up namespace from router meta
    return rawSections.map(section => ({
      ...section,
      items: (section.items || []).map(item => {
        const namespace = getNamespaceFromRouter(item.path)
        return {
          ...item,
          savedSearches: getSavedSearches(cache, namespace, item.path)
        }
      })
    }))
  })

  const { sections: configSections } = useConfigSections()

  // Keyword filter (persisted in Vuex store)
  const filter = computed({
    get: () => $store.state.$_status.aboutFilter,
    set: val => $store.commit('$_status/ABOUT_FILTER_UPDATED', val)
  })

  const matchesFilter = (text, keyword) => {
    return text.toLowerCase().includes(keyword)
  }

  // Filter items within a section, keeping only those that match.
  // Handles flat items (with path), grouped items (with nested items),
  // and saved searches.
  const filterItems = (items, keyword) => {
    return items.reduce((acc, item) => {
      // Flat item with path
      if (item.path) {
        if (matchesFilter(item.name, keyword)) {
          acc.push(item)
        } else {
          // Check saved searches
          const matchingSearches = (item.savedSearches || []).filter(s => matchesFilter(s.name, keyword))
          if (matchingSearches.length) {
            acc.push({ ...item, savedSearches: matchingSearches })
          }
        }
      }
      // Grouped item with nested sub-items (no path)
      else if (item.items) {
        if (matchesFilter(item.name, keyword)) {
          acc.push(item) // group header matches, keep all sub-items
        } else {
          const filteredSubs = item.items.filter(sub => matchesFilter(sub.name, keyword))
          if (filteredSubs.length) {
            acc.push({ ...item, items: filteredSubs })
          }
        }
      }
      return acc
    }, [])
  }

  // Filter sections, pruning dropdown items to only those matching.
  // If the section name itself matches, keep all its items.
  const filterSections = (allSections, keyword) => {
    return allSections.reduce((acc, section) => {
      if (matchesFilter(section.name, keyword)) {
        acc.push(section)
      } else {
        const items = filterItems(section.items || [], keyword)
        if (items.length) {
          acc.push({ ...section, items })
        }
      }
      return acc
    }, [])
  }

  const filteredSections = computed(() => {
    const keyword = filter.value.trim().toLowerCase()
    if (!keyword) return sections.value
    return filterSections(sections.value, keyword)
  })

  const filterSaas = (sections) => {
    if (!isSaas.value) return sections
    return sections.reduce((acc, section) => {
      if (section.class === 'no-saas') return acc
      const items = (section.items || []).reduce((itemAcc, item) => {
        if (item.class === 'no-saas') return itemAcc
        if (item.items) {
          const subItems = item.items.filter(sub => sub.class !== 'no-saas')
          if (subItems.length) {
            itemAcc.push({ ...item, items: subItems })
          }
        } else {
          itemAcc.push(item)
        }
        return itemAcc
      }, [])
      if (items.length || !section.items?.length) {
        acc.push({ ...section, items })
      }
      return acc
    }, [])
  }

  const filteredConfigSections = computed(() => {
    const sections = filterSaas(configSections.value)
    const keyword = filter.value.trim().toLowerCase()
    if (!keyword) return sections
    return filterSections(sections, keyword)
  })


  return {
    version,
    isSaas,
    filter,
    filteredSections,
    filteredConfigSections,
    formatFileSize,
    guides,
    openGuideFullscreen,
    sections,
    configSections
  }
}

// @vue/component
export default {
  name: 'the-view',
  directives,
  setup
}
</script>

<style lang="scss" scoped>
.about-card-wrapper {
  position: relative;

  &:hover {
    .about-card {
      color: var(--primary);
      border-color: var(--primary);
    }

    .about-card-dropdown {
      display: flex;
    }
  }
}

.about-card {
  color: var(--secondary);
  transition: color 0.15s ease-in-out, border-color 0.15s ease-in-out;
}

.about-card-dropdown {
  display: none;
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  z-index: 10;
  flex-direction: column;
  background: var(--white);
  border: 1px solid var(--primary);
  border-top: none;
  border-radius: 0 0 0.25rem 0.25rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

.about-card-dropdown-group {
  border-bottom: 1px solid var(--light);

  &:last-child {
    border-bottom: none;
  }
}

.about-card-dropdown-item {
  display: block;
  padding: 0.5rem 0.75rem;
  font-size: 0.85rem;
  color: var(--secondary);
  text-decoration: none;

  &:hover {
    background: var(--light);
    color: var(--primary);
  }

  &.about-card-dropdown-item-nested {
    padding-left: 1.5rem;
    font-size: 0.8rem;
    font-style: italic;
    background-color: rgba(0, 0, 0, 0.02);
    border-top: 1px solid var(--light);
  }
}

.about-card-dropdown-header {
  display: block;
  padding: 0.4rem 0.75rem 0.1rem;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--gray);
  text-transform: uppercase;
  letter-spacing: 0.03em;
}

.about-card-doc-wrapper {
  position: relative;
  height: 100%;

  &:hover {
    .about-card {
      color: var(--primary);
      border-color: var(--primary);
    }
  }
}

.about-card-doc-actions {
  display: flex;
}

.about-card-doc-link {
  flex: 1 1 50%;
  padding: 0.5rem 0.25rem;
  font-size: 0.8rem;
  line-height: 1.2;
  text-decoration: none;
  color: var(--secondary);
  transition: color 0.15s ease-in-out, background-color 0.15s ease-in-out;

  & + & {
    border-left: 1px solid rgba(0, 0, 0, 0.125);
  }

  &:hover {
    color: var(--primary);
    background-color: var(--light);
  }
}

.about-card-support-link {
  text-decoration: none;
  display: block;
  height: 100%;
}
</style>
