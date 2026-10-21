<!--

<section-sidebar-item :item="section" :filter="filter" indent>

-->
<template>
  <div :class="item.class">
    <b-nav-item
      exact-active-class="active"
      v-if="visible"
      v-bind="$attrs"
      :to="item.path"
      :key="item.name"
      >
      <div class="section-sidebar-item d-flex" :class="{ 'ml-3': indent }">
        <div>
          <text-highlight :queries="[filter]">{{ item.name }}</text-highlight>
          <text-highlight class="figure-caption text-nowrap" v-if="item.caption" :queries="[filter]">{{ item.caption }}</text-highlight>
        </div>
        <icon v-if="item.icon"
          class="mx-1" :name="item.icon" />
        <icon v-else-if="item.icons" v-for="(icon, i) in item.icons" :key="`icon-${icon}`"
          class="mx-1" :class="{ 'ml-auto': i === 0 }" :name="icon" />
        <span v-if="countSavedSearches > 0"
          class="saved-search-toggle text-nowrap" :class="(item.icon || item.icons) ? 'ml-1' : 'ml-auto'"
          role="button" :aria-expanded="expanded ? 'true' : 'false'"
          v-b-tooltip.hover.right.d300 :title="(expanded) ? $t('Hide saved searches') : $t('Show saved searches')"
          @click.stop.prevent="toggleSavedSearches">
          <small class="text-muted">{{ countSavedSearches }}</small>
          <icon class="saved-search-chevron ml-1" :class="{ 'is-collapsed': !expanded }" name="chevron-down" scale="0.75" />
        </span>
        <slot/>
      </div>
    </b-nav-item>
    <b-nav class="section-sidenav mb-2" v-if="standardSearches && standardSearches.length > 0" vertical>
      <div class="section-sidenav-group small py-0" :class="{ 'ml-3': indent }" v-t="'Standard Searches'" />
      <b-nav-item
        exact exact-active-class="active"
        v-for="search in standardSearches"
        :key="search.name"
        class="saved-search"
        :to="routeFromItemSearch(item, search)"
      >
        <div class="section-sidebar-item pl-3" :class="{ 'ml-3': indent }">
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
        </div>
      </b-nav-item>
    </b-nav>
    <b-nav class="section-sidenav mb-2" v-if="showSavedSearches && expanded && savedBasicSearches.length > 0" vertical>
      <div class="section-sidenav-group small py-0" :class="{ 'ml-3': indent }" v-t="'Basic Searches'" />
      <b-nav-item
        exact exact-active-class="active"
        v-for="search in savedBasicSearches"
        :key="search.name"
        class="saved-search"
        :to="routeFromItemSearch(item, search)"
      >
        <div class="section-sidebar-item pl-3" :class="{ 'ml-3': indent }">
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
          <icon class="mx-1" name="trash-alt" @click.stop.prevent="deleteBasicSavedSearch(search)" />
        </div>
      </b-nav-item>
    </b-nav>
    <b-nav class="section-sidenav mb-2" v-if="showSavedSearches && expanded && savedAdvancedSearches.length > 0" vertical>
      <div class="section-sidenav-group small py-0" :class="{ 'ml-3': indent }" v-t="'Advanced Searches'" />
      <b-nav-item
        exact exact-active-class="active"
        v-for="search in savedAdvancedSearches"
        :key="search.name"
        class="saved-search"
        :to="routeFromItemSearch(item, search)"
      >
        <div class="section-sidebar-item pl-3" :class="{ 'ml-3': indent }">
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
          <icon class="mx-1" name="trash-alt" @click.stop.prevent="deleteAdvancedSavedSearch(search)" />
        </div>
      </b-nav-item>
    </b-nav>
  </div>
</template>

<script>
import TextHighlight from 'vue-text-highlight'
const components = {
  TextHighlight
}

const props = {
  item: {
    type: Object,
    default: () => ({ name: 'undefined', path: '/' })
  },
  filter: {
    type: String,
    default: ''
  },
  indent: {
    type: Boolean
  }
}

import { computed, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import acl from '@/utils/acl'
const setup = (props, context) => {

  const {
    item
  } = toRefs(props)

  const { root: { $route, $store } = {} } = context

  const visible = ref(true)

  const standardSearches = computed(() => {
    const { standardSearches } = item.value
    return standardSearches
  })

  const saveSearchNamespace = computed(() => {
    const { saveSearchNamespace } = item.value
    return saveSearchNamespace
  })
  const showSavedSearches = computed(() => visible.value && saveSearchNamespace.value)

  // Use a ref to track cache changes for reactivity
  const preferencesCache = ref($store.state.preferences.cache)
  watch(
    () => $store.state.preferences.cache,
    (newCache) => { preferencesCache.value = { ...newCache } },
    { deep: true }
  )

  const savedAdvancedSearches = computed(() => {
    const cache = preferencesCache.value
    const { values = {} } = cache[`${saveSearchNamespace.value}::advancedSearch`] || {}
    return Object.keys(values).map(name => {
      const { query: conditionAdvanced, ...rest } = values[name]
      return { name, conditionAdvanced, ...rest }
    })
  })
  const deleteAdvancedSavedSearch = search => {
    const id = `${saveSearchNamespace.value}::advancedSearch`
    const { values = {} } = $store.state.preferences.cache[id] || {}
    const { [search.name]: _, ...newValues } = values
    $store.dispatch('preferences/set', { id, value: { values: newValues } })
  }

  const savedBasicSearches = computed(() => {
    const cache = preferencesCache.value
    const { values = {} } = cache[`${saveSearchNamespace.value}::basicSearch`] || {}
    return Object.keys(values).map(name => {
      const { query: conditionBasic, ...rest } = values[name]
      return { name, conditionBasic, ...rest }
    })
  })
  const deleteBasicSavedSearch = search => {
    const id = `${saveSearchNamespace.value}::basicSearch`
    const { values = {} } = $store.state.preferences.cache[id] || {}
    const { [search.name]: _, ...newValues } = values
    $store.dispatch('preferences/set', { id, value: { values: newValues } })
  }

  const countSavedSearches = computed(() => {
    if (!showSavedSearches.value)
      return 0
    return savedBasicSearches.value.length + savedAdvancedSearches.value.length
  })

  // expand/collapse saved searches, remembered per namespace in this browser
  const expanded = ref(false)
  const expandedStorageKey = () => `sidebar::savedSearches::${saveSearchNamespace.value}`
  const toggleSavedSearches = () => {
    expanded.value = !expanded.value
    try {
      localStorage.setItem(expandedStorageKey(), (expanded.value) ? '1' : '0')
    } catch (e) {
      // storage unavailable, keep in-memory state
    }
  }

  onMounted(() => {
    if ('can' in item.value)
      visible.value = acl.$can.apply(null, item.value.can.split(' '))
    if (saveSearchNamespace.value) {
      // get declares a reactive placeholder when the preference does not exist
      $store.dispatch('preferences/get', `${saveSearchNamespace.value}::advancedSearch`)
      $store.dispatch('preferences/get', `${saveSearchNamespace.value}::basicSearch`)
      try {
        expanded.value = localStorage.getItem(expandedStorageKey()) === '1'
      } catch (e) {
        // storage unavailable, default collapsed
      }
      // always show the saved search that is currently loaded
      const { path, query: { _savedSearch } = {} } = $route || {}
      if (_savedSearch && path === item.value.path)
        expanded.value = true
    }
  })

  const routeFromItemSearch = (item, search) => {
    const { path } = item
    const { name, ...rest } = search // strip name from spread, but include as identifier
    const query = Object.keys(rest).reduce((query, param) => {
      query[param] = JSON.stringify(rest[param])
      return query
    }, {})
    // Include saved search name as unique identifier to differentiate routes
    if (name) {
      query._savedSearch = JSON.stringify(name)
    }
    return { path, query }
  }

  return {
    visible,
    standardSearches,
    saveSearchNamespace,
    showSavedSearches,
    savedAdvancedSearches,
    deleteAdvancedSavedSearch,
    savedBasicSearches,
    deleteBasicSavedSearch,
    countSavedSearches,
    expanded,
    toggleSavedSearches,
    routeFromItemSearch
  }
}

// @vue/component
export default {
  name: 'section-sidebar-item',
  components,
  props,
  setup
}
</script>

<style lang="scss">
@import '../styles/variables';

.saved-search {
  svg.fa-icon {
    visibility: hidden;
  }
}
.saved-search-toggle .saved-search-chevron {
  transition: transform 300ms ease;
  &.is-collapsed {
    transform: rotate(-90deg);
  }
}
.saved-search .section-sidebar-item:hover {
  svg.fa-icon {
    visibility: visible !important;
  }
}
</style>
