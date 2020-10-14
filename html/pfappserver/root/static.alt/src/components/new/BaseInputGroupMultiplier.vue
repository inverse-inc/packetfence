<template>
  <base-input-group
    :state="inputState"
    :invalid-feedback="inputInvalidFeedback"
    :valid-feedback="inputValidFeedback"
    :text="inputText"
    :isFocus="isFocus"
    :isLocked="isLocked"
  >
    <b-form-input ref="input"
      class="base-input"
      :disabled="isLocked"
      :readonly="inputReadonly"
      :placeholder="inputPlaceholder"
      :tabIndex="inputTabIndex"
      :type="inputType"
      :value="inputValue"
      @input="onChange"
      @change="onChange"
      @focus="onFocus"
      @blur="onBlur"
    />
    <template v-slot:append>
      <b-dropdown size="sm" v-if="prefixesInRange.length > 0" variant="light" class="base-input-dropdown">
        <template v-slot:button-content>
          <span class="mr-1">{{ prefix.label  + units.label }}</span>
        </template>
        <template v-for="(p, i) in prefixesInRange">
          <b-dropdown-item-button :key="i" :active="p.label === prefix.label" @click="onChangePrefix(p)">{{ p.label + units.label }} - {{ p.name + units.name }}</b-dropdown-item-button>
        </template>
      </b-dropdown>
    </template>
  </base-input-group>
</template>
<script>
import BaseInputGroup from './BaseInputGroup'

const components = {
  BaseInputGroup
}

import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps,

  max: {
    type: Number,
    default: 16 * Math.pow(1024, 6) // 16XB
  },
  prefixes: {
    type: Array,
    default: () => ([
      { label: '',   name: '',      multiplier: Math.pow(1024, 0) },
      { label: 'k',  name: 'kilo',  multiplier: Math.pow(1024, 1) },
      { label: 'M',  name: 'mega',  multiplier: Math.pow(1024, 2) },
      { label: 'G',  name: 'giga',  multiplier: Math.pow(1024, 3) },
      { label: 'T',  name: 'tera',  multiplier: Math.pow(1024, 4) },
      { label: 'P',  name: 'peta',  multiplier: Math.pow(1024, 5) },
      { label: 'X',  name: 'exa',   multiplier: Math.pow(1024, 6) },
      { label: 'Z',  name: 'zetta', multiplier: Math.pow(1024, 7) },
      { label: 'Y',  name: 'yotta', multiplier: Math.pow(1024, 8) },
      { label: 'X',  name: 'xona',  multiplier: Math.pow(1024, 9) },
      { label: 'W',  name: 'weka',  multiplier: Math.pow(1024, 10) },
      { label: 'V',  name: 'vunda', multiplier: Math.pow(1024, 11) },
      { label: 'U',  name: 'uda',   multiplier: Math.pow(1024, 12) },
      { label: 'TD', name: 'treda', multiplier: Math.pow(1024, 13) },
      { label: 'S',  name: 'sorta', multiplier: Math.pow(1024, 14) },
      { label: 'R',  name: 'rinta', multiplier: Math.pow(1024, 15) },
      { label: 'Q',  name: 'quexa', multiplier: Math.pow(1024, 16) },
      { label: 'PP', name: 'pepta', multiplier: Math.pow(1024, 17) },
      { label: 'O',  name: 'ocha',  multiplier: Math.pow(1024, 18) },
      { label: 'N',  name: 'nena',  multiplier: Math.pow(1024, 19) },
      { label: 'MI', name: 'minga', multiplier: Math.pow(1024, 20) },
      { label: 'L',  name: 'luma',  multiplier: Math.pow(1024, 21) }
    ])
  },
  type: {
    type: String,
    default: 'number'
  },
  units: {
    type: Object,
    default: () => ({
      label: 'B',
      name: 'bytes'
    })
  }
}

export const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)
  const {
    max,
    prefixes
  } = toRefs(metaProps)

  const {
    placeholder,
    readonly,
    tabIndex,
    text,
    type,
    isFocus,
    isLocked,
    onFocus,
    onBlur,
    doFocus
  } = useInput(metaProps, context)

  const {
    value,
    onChange
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    validFeedback
  } = useInputValidator(metaProps, value)

  const prefixesInRange = computed(() => unref(prefixes).filter(prefix => prefix.multiplier <= unref(max)))

  const prefix = ref(unref(prefixes)[0])

  const scaledValue = ref(null)

  watch(value, value => {
    if (+value) {
      // sort prefixes descending using multiplier to order iteration
      const _prefixes = JSON.parse(JSON.stringify(unref(prefixesInRange)))
        .sort((a, b) => a.multiplier === b.multiplier ? 0 : a.multiplier < b.multiplier ? 1 : -1)
      // find LCD for `value`
      for (let i = 0; i < _prefixes.length; i++) {
        let quotient = +value / _prefixes[i].multiplier
        if (Math.abs(quotient) >= 1 && quotient === Math.round(quotient)) {
          prefix.value = _prefixes[i]
          scaledValue.value = (isNaN(quotient)) ? undefined : quotient
          return
        }
      }
    }
    // !value or fell through
    if (+value)
      prefix.value = unref(prefixesInRange)[0]
    scaledValue.value = (isNaN(value)) ? undefined : value
  }, { immediate: true })

  const onChangeInput = (newValue) => onChange(newValue && +newValue * unref(prefix).multiplier)

  const onChangePrefix = (newPrefix) => {
    const oldPrefix = unref(prefix)
    prefix.value = newPrefix
    const _value = unref(value)
    if (_value)
      onChange(+_value / oldPrefix.multiplier * newPrefix.multiplier)
  }

  return {
    // useInput
    inputPlaceholder: placeholder,
    inputReadonly: readonly,
    inputTabIndex: tabIndex,
    inputText: text,
    inputType: type,
    isFocus,
    isLocked,
    onFocus,
    onBlur,
    doFocus,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputValidFeedback: validFeedback,

    inputValue: scaledValue,
    onChange: onChangeInput,
    onChangePrefix,
    prefixesInRange,
    prefix
  }
}

// @vue/component
export default {
  name: 'base-input-group-multiplier',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
