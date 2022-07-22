<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline" v-t="'Assets/Inventory'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-row>
        <b-col cols="12">
          <b-tabs small class="fixed">
            <b-tab class="border-1 border-right border-bottom border-left p-3">
              <template #title>
                {{ $i18n.t('Search') }}
              </template>
              <the-search />
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
import TheSearch from './TheSearch'
import {
  BaseIconPreference,
  BaseSearchInputLimit,
  BaseSearchInputPage
 } from '@/components/new/'
import TheGraph from '@/views/Nodes/network/_components/TheGraph'
const components = {
  BaseIconPreference,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  TheGraph,
  TheSearch,
}

import { toRefs } from '@vue/composition-api'
import { useSearch } from '../_search'
import useGraph from '@/views/Nodes/network/_composables/useGraph'

const setup = (props, context) => {

  const { refs } = context

  const search = useSearch()
  const graph = useGraph(search, refs)

  return {
    ...toRefs(search),
    ...graph,
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