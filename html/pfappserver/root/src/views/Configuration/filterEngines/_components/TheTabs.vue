<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('Filter Engines') }}
      </h4>
    </b-card-header>
    <div class="card-body" v-if="isLoading">
      <b-container class="my-5">
          <b-row class="justify-content-md-center text-secondary">
              <b-col cols="12" md="auto">
                <b-media>
                  <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
                  <h4>{{ $t('Loading Filter Engines') }}</h4>
                </b-media>
              </b-col>
          </b-row>
      </b-container>
    </div>
    <b-tabs v-else
      ref="tabs" :value="tabIndex" :key="tabIndex"
      card lazy
    >
      <b-tab v-for="(collection, index) in collections" :key="index"
        :title="(collection && collection.name) ? collection.name : '...'"
        @click="tabIndex = index"
      >
        <the-search :collection="collection" />
      </b-tab>
    </b-tabs>
  </b-card>
</template>
<script>
import TheSearch from './TheSearch'

const components = {
  TheSearch
}

const props = {
  collection: {
    type: String
  }
}

import { computed, customRef, ref, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    collection
  } = toRefs(props)

  const { root: { $router, $store } = {} } = context

  const isLoading = computed(() => $store.getters['$_filter_engines/isLoadingCollections'])
  const collections = ref([])
  $store.dispatch('$_filter_engines/getCollections').then(_collections => {
    collections.value = _collections.sort((a, b) => a.name.localeCompare(b.name)) // sort by name
  })

  const tabIndex = customRef((track, trigger) => ({
    get() {
      track()
        const found = collections.value.findIndex(c => (c && c.collection === collection.value))
        return (found > -1) ? found : 0
    },
    set(newTabIndex) {
      const { [newTabIndex]: { collection } = {} } = collections.value
      if (collection)
        $router.push({ name: 'filterEnginesCollection', params: { collection } })
      trigger()
    }
  }))

  return {
    isLoading,
    collections,
    tabIndex
  }
}

// @vue/component
export default {
  name: 'the-tabs',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
