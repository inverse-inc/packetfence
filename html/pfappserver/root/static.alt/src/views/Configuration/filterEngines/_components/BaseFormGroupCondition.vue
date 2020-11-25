<template>
  <base-form-group
    class="base-form-group-condition"
    :label-cols="labelCols"
    :column-label="columnLabel"
    :text="text"
    :disabled="isLocked"
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :is-focus="isFocus"
  >

    <div class="w-100">
        <base-input-toggle-advanced-mode
          v-model="advancedMode"
          :disabled="isLoading"
          label-right
        />
    </div>

    <base-input-group-textarea v-if="advancedMode"
      v-model="advancedCondition"
      class="flex-grow-1" rows="10"
      :state="advancedState"
      :invalid-feedback="advancedError"
    />

    <base-condition-operator v-else
      :namespace="namespace"
      v-model="inputValue"
    />

  </base-form-group>
</template>
<script>
import {
  BaseFormGroup,

  BaseInputGroupTextarea,
  BaseInputToggleAdvancedMode
} from '@/components/new'
import BaseConditionOperator from './BaseConditionOperator'

const components = {
  BaseConditionOperator,
  BaseFormGroup,
  BaseInputGroupTextarea,
  BaseInputToggleAdvancedMode
}

const highlightError = (error, offset, length = 15) => {
  let start = Math.max(0, offset - Math.floor(length / 2) - 1)
  let end = Math.min(start + length, error.length)
  start -= Math.max(0, length + start - end)
  let chr = ''
  let string = ''
  for (let i = start; i < end; i++) {
    if (i >= 0 && i < error.length) {
      chr = (error[i] === ' ') ? '\u00a0' : error[i]
      string += (i === offset)
        ? `<span class="bg-danger text-white">${chr}</span>`
        : error[i]
    }
  }
  return `${(start > 0) ? '...' : ''}${string}${(end < error.length) ? '...' : ''}`
}

import { computed, ref } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const { root: { $store } = {} } = context

  const metaProps = useInputMeta(props, context)

  const {
    placeholder,
    tabIndex,
    text,
    isFocus,
    isLocked,
    onFocus,
    onBlur
  } = useInput(metaProps, context)

  const {
    value,
    onChange,
    onInput
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const advancedMode = ref(false)
  const advancedCondition = ref(undefined)
  const advancedError = ref(undefined)
  const advancedState = computed(() => {
    return !advancedError.value
  })
  const isLoading = ref(false)

  useDebouncedWatchHandler([advancedMode, value], () => {
    if (advancedMode.value === false && value.value) {
      isLoading.value = true
      $store.dispatch('config/stringifyCondition', value.value).then(condition => {
        advancedCondition.value = condition
        advancedError.value = undefined
      }).finally(() => {
        isLoading.value = false
      })
    }
  })

  useDebouncedWatchHandler([advancedMode, advancedCondition], () => {
    if (advancedMode.value === true && advancedCondition.value) {
      isLoading.value = true
      $store.dispatch('config/parseCondition', advancedCondition.value).then(condition => {
        onChange(condition)
        advancedError.value = undefined
      }).catch(err => {
        const { response: { data: { errors: { 0: { highlighted_error, offset } = {} } = {} } = {} } = {} } = err
        const { 0: error = '' } = highlighted_error.split('\n')
        if (error)
          advancedError.value = `${error}: <code class="text-secondary font-weight-bold">\u00a0${highlightError(advancedCondition, offset)}\u00a0</code>`
        else
          advancedError.value = undefined
      }).finally(() => {
        isLoading.value = false
      })
    }
  })

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputTabIndex: tabIndex,
    inputText: text,
    isFocus,
    isLocked,
    onFocus,
    onBlur,

    // useInputValue
    inputValue: value,
    onChange,
    onInput,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    advancedMode,
    advancedCondition,
    advancedError,
    advancedState,
    isLoading
  }
}

// @vue/component
export default {
  name: 'base-form-group-condition',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
<style lang="scss">
.base-form-group-condition {

  .base-condition {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-start;
    border-radius: .5rem;
    transition: background-color .3s ease-out,
      border-color .3s ease-out;

    .base-condition-operator,
    .base-condition-values {
      /* take full width */
      flex: 0 0 100%;
    }
    .base-condition-operator {
      display: flex;
      flex-wrap: nowrap;
      align-content: center;
    }
    .base-condition-values {
      display: flex;
      /* full width - (margin-left + margin-right) */
      flex: 0 0 calc(100% - 2.25rem);
      flex-wrap: wrap;
      justify-content: flex-start;
      margin-left: 1.75rem;
      margin-right: .5rem;

      /* curly brackets */
      border-color: var(--secondary);
      border-radius: .5rem;
      border-style: solid;
      border-width: 0 .25rem;
      padding: 0 .25rem;

      .base-condition,
      .base-condition-value {
        display: flex;
        flex: 0 0 100%;
        align-content: center;
        align-items: flex-start;
        /* disable user selection on drag */
        user-select: none;
      }
    }
    .drag-handle,
    .dropdown {
      align-self: flex-start;
      display: flex;
      align-items: center;
      min-height: $input-height;
    }
    .drag-handle {
      cursor: grab;
    }
    .drag-placeholder {
      border-color: var(--primary);
      background-color: var(--primary);
      color: var(--light);
      .invalid-feedback,
      .menu .dropdown > .btn {
        color: var(--light);
      }
      .form-control.is-invalid,
      .pf-form-chosen.is-invalid .multiselect__tags,
      .pf-form-boolean-values {
        border-color: var(--light);
      }
    }
    .drag-source {
      opacity: .5;
    }
  }
  .base-condition-operator,
  .base-condition-value {
    & > .dropdown > .btn {
      align-self: center;
      padding: 0!important;
    }
  }
}

.zzz {
  .zzz {

    & > div {
      display: flex;
    }



    &.highlight {
      border-color: var(--primary);
      background-color: var(--primary);
      color: var(--light);
      .invalid-feedback,
      .menu .dropdown > .btn {
        color: var(--light);
      }
      .form-control.is-invalid,
      .pf-form-chosen.is-invalid .multiselect__tags,
      .base-condition-values {
        border-color: var(--light);
      }
    }

    .base-condition-operator,
    .base-condition-values,
    .base-condition-value {
      display: flex;
      align-items: stretch;
      user-select: none; /* disable user selection on drag */
      input, select, textarea {
        user-select: initial; /* override user selection on input elements */
      }
    }

    .base-condition-operator {
      display: flex;
      align-self: center;
      flex-shrink: 0;
      flex-wrap: nowrap;
      margin-right: -8.33333%;
      min-width: 8.33333%;
      padding: 0 .5rem 0 0 !important;
      & > * {
        display: flex;
        align-self: center;
      }
    }

    .base-condition-values {
      flex-wrap: wrap;
      justify-content: flex-start;
      margin-left: 8.33333%;
      margin-right: .25rem;

      /* curly brackets */
      border-color: var(--secondary);
      border-radius: .5rem;
      border-style: solid;
      border-width: 0 .25rem;
      padding: 0 .25rem;
    }

    .base-condition-value {
      display: flex;
      flex-wrap: nowrap;
    }

    /* add/del menu */
    .menu {
      align-self: center;
      cursor: pointer;
      flex-shrink: 0;
      .dropdown > .btn { // menu dropdown
        padding: .375rem 0;
        .fa-icon {
          height: 14px !important;
        }
      }
      & > * {
        margin: 0 0 0 .25rem;
        &:hover {
          color: var(--primary);
        }
      }
    }

    .drag-handle {
      align-self: center;
      cursor: grab;
      flex-shrink: 0;
      margin: 0 .25rem;
    }

    &.drag-source {
      opacity: .5;
    }

    &.drag-target {
      border-color: var(--primary);
      background-color: var(--primary);
      svg {
        visibility: hidden;
      }
      .base-condition-values {
        border-color: var(--light);
      }
    }
  }
}
</style>
