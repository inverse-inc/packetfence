<template>
  <component :is="component"
    :namespace="field.key"
    :column-label="field.label || field.key"
    :text="field.text"
    :disabled="isDisabled"
    v-bind="componentProps"
  />
</template>
<script>
import {
  BaseFormGroupChosenMultiple,
  BaseFormGroupChosenOne,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
  BaseFormGroupInputPassword,
  BaseFormGroupSwitch,
  BaseFormGroupTextarea,
  BaseFormGroupTextareaUpload
} from '@/components/new/'
import BaseFormGroupStringArray from './BaseFormGroupStringArray'

// pairs of values rendered as a switch: [enabled, disabled]
const togglePairs = [
  ['enabled', 'disabled'],
  ['yes', 'no'],
  ['Y', 'N'],
  ['true', 'false'],
  ['on', 'off'],
  ['1', '0']
]

const widgets = {
  input: BaseFormGroupInput,
  password: BaseFormGroupInputPassword,
  number: BaseFormGroupInputNumber,
  textarea: BaseFormGroupTextarea,
  upload: BaseFormGroupTextareaUpload,
  toggle: BaseFormGroupSwitch,
  chosen: BaseFormGroupChosenOne,
  multiple: BaseFormGroupChosenMultiple,
  array: BaseFormGroupStringArray
}

const props = {
  field: {
    type: Object,
    required: true
  },
  meta: {
    type: Object,
    default: () => ({})
  },
  isNew: {
    type: Boolean
  },
  isClone: {
    type: Boolean
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = props => {

  const {
    field,
    meta,
    isNew,
    isClone
  } = toRefs(props)

  const fieldMeta = computed(() => meta.value[field.value.key] || {})

  const togglePair = computed(() => {
    const { allowed } = fieldMeta.value
    if (!Array.isArray(allowed) || allowed.length !== 2)
      return undefined
    const values = allowed.map(({ value }) => `${value}`)
    return togglePairs.find(pair => pair.every(value => values.includes(value)))
  })

  const widget = computed(() => {
    const { widget } = field.value
    if (widget && widget in widgets)
      return widget
    const { type, allowed, allowed_lookup, item: { allowed: itemAllowed, allowed_lookup: itemAllowedLookup } = {} } = fieldMeta.value
    switch (true) {
      case !!togglePair.value:
        return 'toggle'
      case type === 'array' && !!(itemAllowed || itemAllowedLookup):
        return 'multiple'
      case type === 'array':
        return 'array'
      case !!(allowed || allowed_lookup):
        return 'chosen'
      case type === 'integer':
        return 'number'
      default:
        return 'input'
    }
  })

  const component = computed(() => widgets[widget.value])

  const componentProps = computed(() => {
    const { props: extraProps = {} } = field.value
    switch (widget.value) {
      case 'toggle': {
        const [enabledValue, disabledValue] = (field.value.values || togglePair.value || ['enabled', 'disabled'])
        return { enabledValue, disabledValue, ...extraProps }
      }
      case 'textarea':
      case 'upload':
        return { rows: 3, autoFit: true, ...extraProps }
      case 'array':
        return { buttonLabel: field.value.button_label, ...extraProps }
      default:
        return extraProps
    }
  })

  // the identifier can only be set on creation
  const isDisabled = computed(() => {
    const { readonly, identifier } = field.value
    return !!readonly || (!!identifier && !isNew.value && !isClone.value)
  })

  return {
    component,
    componentProps,
    isDisabled
  }
}

// @vue/component
export default {
  name: 'form-field',
  inheritAttrs: false,
  props,
  setup
}
</script>
