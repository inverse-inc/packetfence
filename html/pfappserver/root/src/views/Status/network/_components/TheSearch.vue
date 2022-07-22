<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">
        {{ $t('Network') }}
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" @basic="onTouch" @advanced="onTouch" @reset="onTouch">
        <b-form inline>
          <b-input-group class="mr-3">
            <b-input-group-prepend is-text>
              <base-input-toggle-false-true v-model="live.enabled"
                :disabled="isLoading || !live.allowed" :label-right="false" class="inline" />
            </b-input-group-prepend>
            <b-dropdown variant="light" :text="$t('Live View')" :disabled="isLoading || !live.allowed">
              <b-dropdown-item
                :active="!live.enabled"
                @click="live.enabled = false">{{ $t('Disable') }}</b-dropdown-item>
              <b-dropdown-item v-for="timeout in live.options" :key="timeout"
                :active="live.enabled === true && live.timeout === timeout"
                @click="live.enabled = true; live.timeout = timeout"
              >{{ $t('{duration} seconds', { duration: timeout / 1E3 }) }}</b-dropdown-item>
            </b-dropdown>
          </b-input-group>
          <b-input-group class="mb-0 mr-3" :prepend="$t('Sort')">
            <b-form-select v-model="options.sort" :options="fields" :disabled="isLoading" />
            <b-form-select v-model="options.order" :options="['ASC', 'DESC']" :disabled="isLoading" />
          </b-input-group>
        </b-form>
      </base-search>
      <b-container fluid>
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
import {
  BaseInputToggleFalseTrue,
  BaseSearch
} from '@/components/new/'
import TheGraph from '@/views/Nodes/network/_components/TheGraph'

const components = {
  BaseInputToggleFalseTrue,
  BaseSearch,
  TheGraph
}

import { toRefs } from '@vue/composition-api'
import { useSearch } from '@/views/Nodes/network/_search'
import useGraph from '@/views/Nodes/network/_composables/useGraph'

const setup = (props, context) => {

  const { refs } = context

  const search = useSearch()

  const graph = useGraph(search, refs)

  return {
    useSearch,
    ...toRefs(search),
    ...toRefs(graph),
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  setup
}
</script>
