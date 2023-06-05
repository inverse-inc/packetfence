<template>
  <div class="base-input-chosen-container">
    <multiselect
                 class="base-input-chosen"
                 :class="{
                    'is-invalid': state === false,
                    'is-focus': isFocused,
                    'size-sm': size === 'sm',
                    'size-md': size === 'md',
                    'size-lg': size === 'lg'
                 }"

                 :show-no-results="true"

                 :options="options"
                 :track-by="trackBy"
                 :label="label"

                 :options-limit="optionsLimit"
                 :placeholder="placeholder"
                 :name="name"
                 :select-label="selectLabel"
                 :select-group-label="selectGroupLabel"
                 :selected-label="selectedLabel"
                 :deselect-label="deselectLabel"
                 :deselect-group-label="deselectGroupLabel"
                 :show-labels="showLabels"
                 :limit="limit"
                 :limit-text="limitText"
                 :open-direction="openDirection"
                 :show-pointer="showPointer"
                 :disabled="isDisabled"
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
      <template v-slot:beforeList>
        <li v-if="!internalSearch" class="multiselect__element">
          <div class="col-form-label py-1 px-2 text-dark text-left bg-light border-bottom">
            {{ $t('Type to search') }}
          </div>
        </li>
      </template>
      <template v-slot:noOptions>
        <b-media class="text-secondary" md="auto">
          <template v-slot:aside>
            <icon name="search" scale="1.5" class="mt-2 ml-2"></icon>
          </template>
          <strong>{{ $t('Search') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('Type to search results.') }}</b-form-text>
        </b-media>
      </template>
      <template v-slot:noResult>
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
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  toRefs,
  unref
} from '@vue/composition-api'
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'

const components = {
  Multiselect
}

import useEventFnWrapper from '@/composables/useEventFnWrapper'
import {useInput, useInputProps} from '@/composables/useInput'
import {useInputMeta, useInputMetaProps} from '@/composables/useMeta'
import {useOptionsPromise, useOptionsValue} from '@/composables/useInputMultiselect'
import {useInputValidator, useInputValidatorProps} from '@/composables/useInputValidator'
import {useInputValue, useInputValueProps} from '@/composables/useInputValue'
import {useInputMultiselectProps} from '@/composables/useInputMultiselect'

export const props = {
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },

  onSearch: {
    type: Function,
    default: () => {
    }
  },

  onSelect: {
    type: Function,
    default: () => {
    }
  },

  onOpen: {
    type: Function,
    default: () => {
    }
  },

  onClose: {
    type: Function,
    default: () => {
    }
  },

  onRemove: {
    type: Function,
    default: () => {
    }
  },

  isFocused: {
    type: Boolean,
    default: false
  },

  isDisabled: {
    type: Boolean,
    default: false
  },

  singleLabel: {
    type: String,
    default: ''
  },

  loading: {
    type: Boolean,
    default: false
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

export const setup = (props, context) => {
}

// @vue/component
export default {
  name: 'search-input',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
@import '~@/styles/multiselect.scss';
</style>
