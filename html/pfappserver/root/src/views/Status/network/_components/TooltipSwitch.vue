<template>
  <b-card no-body class="tooltip-switch">
    <b-card-header>
      <h5 class="mb-0 text-nowrap">{{ $t('Switch') }}</h5>
      <p class="mb-0"><mac>{{ id }}</mac></p>
    </b-card-header>
    <div class="card-body" v-if="isLoading || (!isError && Object.keys(switche).length > 0)">
      <b-container class="my-3 px-0" v-if="isLoading">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto" class="w-100 text-center">
            <icon name="circle-notch" scale="2" spin></icon>
          </b-col>
        </b-row>
      </b-container>
      <b-container class="container px-0" v-else-if="!isError">
        <b-row v-if="switche.description">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Decription'"></p>
            <p class="mb-2" v-text="switche.description"></p>
          </b-col>
        </b-row>
        <b-row v-if="switche.type">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Type'"></p>
            <p class="mb-2" v-text="switche.type"></p>
          </b-col>
        </b-row>
      </b-container>
    </div>
  </b-card>
</template>

<script>
const props = {
  id: {
    type: String
  },
  properties: {
    type: Object,
    default: () => ({})
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'
import apiCall from '@/utils/api'

const setup = props => {

  const {
    id,
    properties
  } = toRefs(props)

  const switche = ref(false)
  const isLoading = ref(false)
  const isError = ref(false)

  watch([id, properties], () => {
    if (id.value !== 'unknown') {
      this.isLoading = true
      apiCall.getQuiet(`config/switch/${id.value}`)
        .then(response => {
          switche.value = response.data.item
        })
        .catch(err => {
          if (Object.keys(properties.value).length > 0)
            switche.value = properties.value // inherit properties from node
          else
            isError.value = err
        })
        .finally(() => {
          isLoading.value = false
        })
    } else {
      // id 'unknown'
      switche.value = properties.value // inherit properties from node
    }
  }, { immediate: true })

  return {
    switche,
    isLoading,
    isError
  }
}

// @vue/component
export default {
  name: 'tooltip-switch',
  props,
  setup
}
</script>

<style lang="scss">
@keyframes expandheight {
  from { overflow-y: hidden; max-height: 0px; }
  to   { overflow-y: initial; max-height: 500px; }
}

.tooltip-switch {
  .container {
    animation: expandheight 300ms;
    overflow-x: initial;
  }
}
</style>
