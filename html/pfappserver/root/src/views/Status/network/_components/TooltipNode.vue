<template>
  <b-card no-body class="tooltip-node">
    <b-card-header class="p-2">
      <h5 class="mb-0 text-nowrap">{{ $t('Node') }}</h5>
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
      <b-container class="px-0" v-else-if="!isError">
        <b-row v-if="node.device_class">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Class'"></p>
            <p class="mb-2" v-text="node.device_class"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_manufacturer">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Manufacturer'"></p>
            <p class="mb-2" v-text="node.device_manufacturer"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_type">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Type'"></p>
            <p class="mb-2" v-text="node.device_type"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.device_version">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Device Version'"></p>
            <p class="mb-2" v-text="node.device_version"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.computername">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Computer Name'"></p>
            <p class="mb-2" v-text="node.computername"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.machine_account">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Machine Account'"></p>
            <p class="mb-2" v-text="node.machine_account"></p>
          </b-col>
        </b-row>
        <b-row v-if="node.pid">
          <b-col cols="auto">
            <p class="py-0 col-form-label text-left text-nowrap" v-text="'Owner'"></p>
            <p class="mb-2" v-text="node.pid"></p>
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

  const node = ref(false)
  const isLoading = ref(false)
  const isError = ref(false)

  watch(id, () => {
    isLoading.value = true
    apiCall.getQuiet(`node/${id.value}`)
      .then(response => {
        node.value = response.data.item
      })
      .catch(err => {
        isError.value = err
      })
      .finally(() => {
        isLoading.value = false
      })
  }, { immediate: true })

  return {
    node,
    isLoading,
    isError
  }
}

// @vue/component
export default {
  name: 'tooltip-node',
  props,
  setup
}
</script>
<style lang="scss">
@keyframes expandheight {
  from { overflow-y: hidden;  max-height: 0px; }
  to   { overflow-y: initial; max-height: 500px; }
}

.tooltip-node {
  .container {
    animation: expandheight 300ms;
    overflow-x: initial;
  }
}
</style>
