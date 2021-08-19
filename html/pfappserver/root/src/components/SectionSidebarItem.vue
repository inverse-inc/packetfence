<!--

<section-sidebar-item :item="section" :filter="filter" indent>

-->
<template>
  <div>
    <b-nav-item
      exact-active-class="active"
      v-if="visible"
      v-bind="$attrs"
      :to="item.path"
      :key="item.name"
      >
      <div class="section-sidebar-item" :class="{ 'ml-3': indent }">
        <div>
          <text-highlight :queries="[filter]">{{ item.name }}</text-highlight>
          <text-highlight class="figure-caption text-nowrap" v-if="item.caption" :queries="[filter]">{{ item.caption }}</text-highlight>
        </div>
        <icon class="mx-1" :name="item.icon" v-if="item.icon" />
        <slot/>
      </div>
    </b-nav-item>
    <b-nav class="section-sidenav mb-2" v-if="showSavedSearches && savedBasicSearches.length > 0" vertical>
      <div class="section-sidenav-group small py-0" v-t="'Basic Searches'" />
      <b-nav-item
        exact-active-class="active"
        v-for="search in savedBasicSearches"
        :key="search.name"
        class="saved-search"
        @click="goToBasicSearch(search)"
      >
        <div class="section-sidebar-item pl-3">
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
          <icon class="mx-1" name="trash-alt" @click.stop.prevent="deleteBasicSavedSearch(search)" />
        </div>
      </b-nav-item>
    </b-nav>
    <b-nav class="section-sidenav mb-2" v-if="showSavedSearches && savedAdvancedSearches.length > 0" vertical>
      <div class="section-sidenav-group small py-0" v-t="'Advanced Searches'" />
      <b-nav-item
        exact-active-class="active"
        v-for="search in savedAdvancedSearches"
        :key="search.name"
        class="saved-search"
        @click="goToAdvancedSearch(search)"
      >
        <div class="section-sidebar-item pl-3">
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

import { computed, onMounted, ref, toRefs } from '@vue/composition-api'
import acl from '@/utils/acl'
const setup = (props, context) => {

  const {
    item
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const visible = ref(true)

  const saveSearchNamespace = computed(() => {
    const { saveSearchNamespace } = item.value
    return saveSearchNamespace
  })
  const showSavedSearches = computed(() => visible.value && saveSearchNamespace.value)
  const savedAdvancedSearches = computed(() => {
    const { values = {} } = $store.state.preferences.cache[`${saveSearchNamespace.value}::advancedSearch`] || {}
    return Object.keys(values).map(name => ({ name, ...values[name] }))
  })
  const savedBasicSearches = computed(() => {
    const { values = {} } = $store.state.preferences.cache[`${saveSearchNamespace.value}::basicSearch`] || {}
    return Object.keys(values).map(name => ({ name, ...values[name] }))
  })

  const deleteAdvancedSavedSearch = search => {
    const id = `${saveSearchNamespace.value}::advancedSearch`
    const { values = {} } = $store.state.preferences.cache[id] || {}
    delete values[search.name]
    $store.dispatch('preferences/set', { id, value: { values } })
  }
  const deleteBasicSavedSearch = search => {
    const id = `${saveSearchNamespace.value}::basicSearch`
    const { values = {} } = $store.state.preferences.cache[id] || {}
    delete values[search.name]
    $store.dispatch('preferences/set', { id, value: { values } })
  }
  const goToAdvancedSearch = search => {
    const { name, query, ...rest } = search
    const { path } = item.value
    $store.dispatch('preferences/set', {
      id: `${saveSearchNamespace.value}::defaultSearch`,
      value: { ...rest, conditionAdvanced: query }
    }).then(() => {
      if (path === $router.currentRoute.path)
        $router.go() // hard reset
      else
        $router.push({ path })
    })
  }
  const goToBasicSearch = search => {
    const { name, query, ...rest } = search
    const { path } = item.value
    $store.dispatch('preferences/set', {
      id: `${saveSearchNamespace.value}::defaultSearch`,
      value: { ...rest, conditionBasic: query }
    }).then(() => {
      if (path === $router.currentRoute.path)
        $router.go() // hard reset
      else
        $router.push({ path })
    })
  }

  onMounted(() => {
    if ('can' in item.value)
      visible.value = acl.$can.apply(null, item.value.can.split(' '))
    if (saveSearchNamespace.value) {
      $store.dispatch('preferences/get', `${saveSearchNamespace.value}::advancedSearch`)
        .then(value => {
          if (Object.keys(value).length === 0) { // declare reactive placeholder
            $store.dispatch('preferences/set', { id: `${saveSearchNamespace.value}::advancedSearch` })
          }
        })
      $store.dispatch('preferences/get', `${saveSearchNamespace.value}::basicSearch`)
        .then(value => {
          if (Object.keys(value).length === 0) { // declare reactive placeholder
            $store.dispatch('preferences/set', { id: `${saveSearchNamespace.value}::basicSearch` })
          }
        })
    }
  })

  return {
    visible,

    saveSearchNamespace,
    showSavedSearches,

    savedAdvancedSearches,
    deleteAdvancedSavedSearch,
    goToAdvancedSearch,

    savedBasicSearches,
    deleteBasicSavedSearch,
    goToBasicSearch
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
.saved-search .section-sidebar-item:hover {
  svg.fa-icon {
    visibility: visible !important;
  }
}
</style>
