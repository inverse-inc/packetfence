<template>
  <b-tab :active="active" class="p-0">
    <template v-slot:title>
      <icon scale=".5" :class="isCertKeyMatch ? 'text-success' : 'text-danger'" name="circle"></icon>
      <icon scale=".5" :class="isChainValid ? 'text-success' : 'text-danger'" name="circle" class="fa-overlap mr-1" ></icon>
      {{ id.toUpperCase() }}
    </template>
    <the-form
      :id="id"
    />
  </b-tab>
</template>
<script>
import {
  TheForm
} from './'

const components = {
  TheForm
}

export const props = {
  active: {
    type: Boolean
  },
  id: {
    type: String
  }
}

export default {
  name: 'the-tab',
  components,
  props
}
</script>
