<template>
  <b-tab :active="active" class="p-0">
    <template v-slot:title>
      <icon scale=".5" :class="isCertKeyMatch ? 'text-success' : 'text-danger'" name="circle"></icon>
      <icon scale=".5" :class="isChainValid ? 'text-success' : 'text-danger'" name="circle" class="fa-overlap mr-1" ></icon>
      {{ id.toUpperCase() }}
    </template>
    <the-form
      :id="id"
      @chain-valid="onChainValid"
      @cert-key-match="onCertKeyMatch"
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

import { computed, ref, toRefs, watch } from '@vue/composition-api'

const setup = (props) => {

  const isCertKeyMatch = ref(false)
  const isChainValid = ref(false)

  const onCertKeyMatch = match => {
    isCertKeyMatch.value = match
  }
  const onChainValid = valid => {
    isChainValid.value = valid
  }

  return {
    isCertKeyMatch,
    isChainValid,
    onCertKeyMatch,
    onChainValid
  }
}
export default {
  name: 'the-tab',
  components,
  props,
  setup
}
</script>
