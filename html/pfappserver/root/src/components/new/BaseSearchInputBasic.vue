<template>
  <b-form @submit.prevent="onSearch" @reset.prevent="onReset">
    <div class="input-group">
      <div class="input-group-prepend">
        <div class="input-group-text"><icon name="search"></icon></div>
      </div>
      <b-form-input :value="value" @input="onInput" type="text" :disabled="disabled" :placeholder="placeholder"></b-form-input>
      <b-button class="ml-1" type="reset" variant="secondary" :disabled="disabled">{{ $t('Clear') }}</b-button>
      <!-- saved search button -->
      <base-button-save-search v-if="saveSearchNamespace"
        :value="value" @input="onInput" class="ml-1"
        :disabled="disabled"
        :save-search-namespace="saveSearchNamespace" 
        @search="onSearch"
      />
      <!-- normal button -->
      <b-button v-else
        class="ml-1" type="submit" variant="primary" :disabled="disabled">{{ $t('Search') }}</b-button>
    </div>
  </b-form>
</template>
<script>
import BaseButtonSaveSearch from './BaseButtonSaveSearch'

const components = {
  BaseButtonSaveSearch
}

import i18n from '@/utils/locale'

const props = {
  value: {
    type: String
  },
  placeholder: {
    type: String,
    default: i18n.t('Enter search criteria')
  },
  disabled: {
    type: Boolean
  },
  saveSearchNamespace: {
    type: String
  }
}

import { toRefs } from '@vue/composition-api'

const setup = (props, context) => {
  const {
    value
  } = toRefs(props)

  const { emit } = context

  const onInput = value => emit('input', value)
  const onReset = () => emit('reset', true)
  const onSearch = () => emit('search', value.value)

  return { 
    onInput,
    onReset,
    onSearch 
  }
}

// @vue/component
export default {
  name: 'base-search-input-basic',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
