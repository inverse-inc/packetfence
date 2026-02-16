<template>
  <b-card no-body>
    <b-card-header class="pl-4">
      <h4 class="d-inline mb-0">{{ isSaas ? 'PacketFence Cloud' : 'PacketFence' }} {{ version }}</h4>
    </b-card-header>
    <div class="card-body">
      <!-- Quick Links -->
      <h5 class="mb-3" v-t="'Quick Links'"></h5>
      <b-row class="mb-4">
        <b-col cols="6" md="4" lg="2" v-for="section in sections" :key="section.path" class="mb-3">
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

      <!-- Help -->
      <h5 class="mb-3" v-t="'Help'"></h5>
      <b-row>
        <!-- Support Inquiry -->
        <b-col cols="6" md="4" lg="2" class="mb-3">
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
            <b-card class="about-card h-100 text-center d-flex align-items-center justify-content-center cursor-pointer" @click="openGuideFullscreen(doc.name)">
              <icon name="book" scale="2" class="mb-2" />
              <div class="small">{{ doc.text }}</div>
            </b-card>
            <a :href="`/static/doc/${doc.name}`" target="_blank" class="about-card-doc-external" @click.stop>
              <icon name="external-link-alt" scale="1.2" />
            </a>
          </div>
        </b-col>
      </b-row>
    </div>
  </b-card>
</template>

<script>
import { computed, onMounted, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'

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
          { name: i18n.t('Admin API Logs'), path: '/auditing/admin_api_audit_logs/search' },
          { name: i18n.t('Live Logs'), path: '/auditing/live' }
        ]
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
      },
      {
        name: i18n.t('Configuration'),
        path: '/configuration',
        icon: 'cogs',
        items: [
          { name: i18n.t('Policies and Access Control'), path: '/configuration/policies_access_control' },
          { name: i18n.t('Compliance'), path: '/configuration/compliance' },
          { name: i18n.t('Integration'), path: '/configuration/integration' },
          { name: i18n.t('Advanced Access Configuration'), path: '/configuration/advanced_access_configuration' },
          { name: i18n.t('Network Configuration'), path: '/configuration/network_configuration' },
          { name: i18n.t('System Configuration'), path: '/configuration/system_configuration' }
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

  return {
    version,
    isSaas,
    guides,
    openGuideFullscreen,
    sections
  }
}

// @vue/component
export default {
  name: 'the-view',
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

.about-card-doc-wrapper {
  position: relative;
  height: 100%;

  &:hover {
    .about-card {
      color: var(--primary);
      border-color: var(--primary);
    }

    .about-card-doc-external {
      opacity: 1;
    }
  }
}

.about-card-doc-external {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  opacity: 0.3;
  color: var(--secondary);
  transition: opacity 0.15s ease-in-out, color 0.15s ease-in-out;
  z-index: 1;

  &:hover {
    opacity: 1;
    color: var(--primary);
  }
}

.about-card-support-link {
  text-decoration: none;
  display: block;
  height: 100%;
}
</style>
