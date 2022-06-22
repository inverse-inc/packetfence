<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Assets/Inventory'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="12">
          <b-tabs small class="fixed">
            <b-tab class="border-1 border-right border-bottom border-left pb-1">
              <template #title>
                {{ $i18n.t('Categories') }} <b-badge v-if="selectedCategories.length" pill variant="primary" class="ml-1">{{ selectedCategories.length }}</b-badge>
              </template>
              <base-filter-categories v-model="selectedCategories" />
            </b-tab>
          </b-tabs>
        </b-col>
      </b-row>
      <b-container fluid class="mt-3">
        <b-row align-v="center">
          <b-form inline class="mb-3">
            <b-button-group class="mr-3" size="sm">
              <b-button disabled variant="outline-primary"><icon name="window-maximize" class="mx-1"/></b-button>
              <b-button @click="dimensions.fit = 'min'" :variant="(dimensions.fit === 'min') ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ $t('Minimize') }}</b-button>
              <b-button @click="dimensions.fit = 'max'" :variant="(dimensions.fit === 'max') ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ $t('Maximize') }}</b-button>
            </b-button-group>
          </b-form>
          <b-form inline class="mb-3">
            <b-button-group class="mr-3" size="sm">
              <b-button disabled variant="outline-primary"><icon name="project-diagram" class="mx-1"/></b-button>
              <b-button v-for="layout in layouts" :key="layout" @click="options.layout = layout" :variant="(options.layout === layout) ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ layout }}</b-button>
            </b-button-group>
          </b-form>
          <b-form inline class="mb-3">
            <b-button-group class="mr-3" size="sm">
              <b-button disabled variant="outline-primary"><icon name="palette" class="mx-1"/></b-button>
              <b-button v-for="palette in Object.keys(palettes)" :key="palette" @click="options.palette = palette" :variant="(options.palette === palette) ? 'primary' : 'outline-primary'" :disabled="isLoading">{{ palette }}</b-button>
            </b-button-group>
          </b-form>
          <b-col cols="auto" class="d-flex ml-auto">
            <base-search-input-limit
              :value="limit" @input="setLimit"
              size="md"
              :limits="limits"
              :disabled="isLoading"
            />
            <base-search-input-page
              :value="page" @input="setPage"
              class="ml-3"
              :limit="limit"
              :total-rows="totalRows"
              :disabled="isLoading"
            />
          </b-col>
        </b-row>
      </b-container>
      <the-graph ref="graphRef"
        :dimensions="dimensions"
        :nodes="nodes"
        :links="links"
        :options="options"
        :palettes="palettes"
        :disabled="!live.enabled && isLoading"
        :is-loading="!live.enabled && isLoading"
        @layouts="layouts = $event"
      />
    </div>
  </b-card>
</template>

<script>
import BaseFilterCategories from './BaseFilterCategories'
import {
  BaseSearchInputLimit,
  BaseSearchInputPage
 } from '@/components/new/'
import TheGraph from '@/views/Nodes/network/_components/TheGraph'
const components = {
  BaseFilterCategories,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  TheGraph,
}

import { onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { useSearch } from '../_search'
import useGraph from '@/views/Nodes/network/_composables/useGraph'
import usePreference from '@/composables/usePreference'

const setup = (props, context) => {

  const { refs, root: { $store } = {} } = context

  const search = useSearch()
  const {
    doReset,
    doSearch,
    setPage
  } = search

  const graph = useGraph(search, refs)

  const deviceClassMap = ref({})
  onMounted(() => {
    $store.dispatch('$_fingerbank/getClasses').then(items => {
      deviceClassMap.value = items.reduce((assoc, item) => {
        return { ...assoc, [item.id]: item.name }
      }, {})
    })
  })

  const selectedCategories = usePreference('vizsec::filters', 'categories', [])

  watch([selectedCategories, deviceClassMap], () => {
    setPage(1)
    if (selectedCategories.value.length) {
      doSearch({
        op: 'and',
        values: [
          { op: 'or', values: selectedCategories.value.map(value => { return { field: 'device_class', op: 'equals', value: deviceClassMap.value[value] || null }}) }
        ]
      })
    }
    else {
      doReset()
    }
  }, { deep: true, immediate: true })

  return {
    selectedCategories,
    ...toRefs(search),
    ...toRefs(graph),
  }
}

// @vue/component
export default {
  name: 'the-view',
  inheritAttrs: false,
  components,
  setup
}
</script>

<style lang="scss" scoped>
.tabs.fixed {
  div[role="tabpanel"] {
    height: 50vh;
    overflow-y: auto;
    overflow-x: hidden;
    .card {
      border: 0px !important;
      box-shadow: 0px 0px 0px 0px !important;
    }
  }
}
</style>