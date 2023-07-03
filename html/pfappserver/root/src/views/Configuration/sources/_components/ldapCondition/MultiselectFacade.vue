<template>
  <div class="base-input-chosen-container">
    <multiselect ref="inputRef"
                 class="base-input-chosen"
                 :class="{
                    'is-invalid': state === false,
                    'is-focus': isFocused,
                    'size-sm': size === 'sm',
                    'size-md': size === 'md',
                    'size-lg': size === 'lg'
                 }"
                 :disabled="isDisabled"
                 :label="label"
                 :limit="limit"
                 :limit-text="limitText"
                 :loading="isLoading"
                 :name="name"
                 :options="selectOptions"
                 :open-direction="openDirection"
                 :options-limit="optionsLimit"
                 :placeholder="placeholder"
                 :show-no-results="true"
                 :select-label="selectLabel"
                 :select-group-label="selectGroupLabel"
                 :selected-label="selectedLabel"
                 :show-labels="showLabels"
                 :show-pointer="showPointer"
                 :track-by="trackBy"
                 :value="value"
                 @search-change="onSearch"
                 @select="onSelect"
                 @open="onOpen"
                 @remove="onRemove"
                 @close="onClose"
    >
      <template v-slot:singleLabel>
        {{ singleLabel }}
      </template>
      <template>
        <span class="multiselect__tag bg-secondary">
          <span v-if="value">{{ value.text }}</span>
          <icon v-else
                name="question-circle" variant="white"/>
          <i aria-hidden="true" tabindex="1" class="multiselect__tag-icon"></i>
        </span>
      </template>
      <template v-if="isConnected" v-slot:beforeList>
        <li v-if="!internalSearch" class="multiselect__element">
          <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">
            {{ $t('Type to search') }}
          </div>
        </li>
      </template>
      <template v-if="!isConnected" v-slot:noOptions>
        <LdapConnectionError/>
      </template>
      <template v-else v-slot:noOptions>
        <b-media class="text-secondary" md="auto">
          <template v-slot:aside>
            <icon name="search" scale="1.5" class="mt-2 ml-2"></icon>
          </template>
          <strong>{{ $t('Search') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('Type to search results.') }}</b-form-text>
        </b-media>
      </template>
      <template v-if="!isLoading" v-slot:noResult>
        <b-media class="text-secondary" md="auto">
          <template v-slot:aside>
            <icon name="search" scale="1.5" class="mt-2 ml-2"></icon>
          </template>
          <strong>{{ $t('No results') }}</strong>
          <b-form-text class="font-weight-light">{{
              $t('Please refine your search.')
            }}
          </b-form-text>
        </b-media>
      </template>
    </multiselect>
    <small v-if="searchQueryInvalidFeedback"
           class="invalid-feedback"
           v-html="searchQueryInvalidFeedback"
    />
  </div>
</template>
<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import {useInputProps} from '@/composables/useInput'
import {useInputMetaProps} from '@/composables/useMeta'
import {useInputMultiselectProps} from '@/composables/useInputMultiselect'
import {useInputValidatorProps} from '@/composables/useInputValidator'
import {useInputValueProps} from '@/composables/useInputValue'
import {computed} from '@vue/composition-api';
import LdapConnectionError
  from '@/views/Configuration/sources/_components/ldapCondition/LdapConnectionError.vue';

const components = {
  Multiselect,
  LdapConnectionError
}

export const props = {
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },


  onSearch: {
    type: Function,
    default: () => {}
  },

  onSelect: {
    type: Function,
    default: () => {}
  },

  onOpen: {
    type: Function,
    default: () => {}
  },

  onClose: {
    type: Function,
    default: () => {}
  },

  onRemove: {
    type: Function,
    default: () => {}
  },

  isConnected: {
    type: Boolean,
    default: true
  },

  isFocused: {
    type: Boolean,
    default: false
  },

  isDisabled: {
    type: Boolean,
    default: false
  },

  isLoading: {
    type: Boolean,
    default: false
  },

  singleLabel: {
    type: String,
    default: ''
  },

  searchQueryInvalidFeedback: {
    type: String,
    default: ''
  },

  state: {
    type: Boolean,
    default: true
  },

  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,
  ...useInputMultiselectProps
}

// eslint-disable-next-line no-unused-vars
function setup(props, context) {
  const selectOptions = computed(() => {
    if (props.noConnection) {
      return []
    } else {
      return props.options
    }
  })
  return {
    selectOptions
  }
}

export default {
  name: 'multiselect-facade',
  inheritAttrs: false,
  components,
  setup,
  props,
}

</script>
<style lang="scss">
@import '~@/styles/multiselect.scss';
</style>
