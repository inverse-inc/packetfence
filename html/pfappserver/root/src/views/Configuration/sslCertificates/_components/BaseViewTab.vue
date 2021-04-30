<template>
  <b-tab :active="active" class="p-0">
    <template v-slot:title>
      <icon scale=".5" :class="isCertKeyMatch ? 'text-success' : 'text-danger'" name="circle"></icon>
      <icon scale=".5" :class="isChainValid ? 'text-success' : 'text-danger'" name="circle" class="fa-overlap mr-1" ></icon>
      {{ id.toUpperCase() }}
    </template>
    <b-form @submit.prevent="doSave" ref="rootRef">
      <the-form
        :form="form"
        :isLoading="isLoading"
        :id="id"
      />
    </b-form>
  </b-tab>
</template>
<script>
import {
  TheForm
} from './'

const components = {
  TheForm
}

import { useTab } from '../_composables/useTab'

export const props = {
  active: {
    type: Boolean
  },
  id: {
    type: String
  }
}

const setup = (props, context) => useTab(props, context)

export default {
  name: 'base-view-tab',
  components,
  props,
  setup
}
</script>
