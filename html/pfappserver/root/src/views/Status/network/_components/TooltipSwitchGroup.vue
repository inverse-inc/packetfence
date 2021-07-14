<template>
  <b-card no-body class="tooltip-switch-group">
    <b-card-header class="p-2">
      <h5 class="mb-0 text-nowrap">{{ $t('Switch Group') }}</h5>
      <p class="mb-0"><mac>{{ id }}</mac></p>
    </b-card-header>
    <div class="card-body p-2" v-if="isLoading || !isError">
      <b-container class="my-3 px-0" v-if="isLoading">
        <b-row class="justify-content-md-center text-secondary">
          <b-col cols="12" md="auto" class="w-100 text-center">
            <icon name="circle-notch" scale="2" spin></icon>
          </b-col>
        </b-row>
      </b-container>
      <b-container class="container px-0" v-else-if="!isError">
        <b-row v-if="switchGroup.description">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Decription'"></p>
            <p class="mb-2" v-text="switchGroup.description"></p>
          </b-col>
        </b-row>
        <b-row v-if="switchGroup.type">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Type'"></p>
            <p class="mb-2" v-text="switchGroup.type"></p>
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
  }
}

import { ref, toRefs, watch } from '@vue/composition-api'
import apiCall from '@/utils/api'

export const setup = props => {

  const {
    id
  } = toRefs(props)

  const switchGroup = ref(false)
  const isLoading = ref(false)
  const isError = ref(false)

  watch(id, () => {
    isLoading.value = true
    apiCall.getQuiet(`config/switch_group/${id.value}`)
      .then(response => {
        switchGroup.value = response.data.item
      })
      .catch(err => {
        isError.value = err
      })
      .finally(() => {
        isLoading.value = false
      })
  }, { immediate: true })

  return {
    switchGroup,
    isLoading,
    isError
  }
}

// @vue/component
export default {
  name: 'tooltip-switch-group',
  props,
  setup
}
</script>
<style lang="scss">
@keyframes expandheight {
  from { overflow-y: hidden; max-height: 0px; }
  to   { overflow-y: initial; max-height: 500px; }
}

.tooltip-switch-group {
  .container {
    animation: expandheight 300ms;
    overflow-x: initial;
  }
}
</style>
