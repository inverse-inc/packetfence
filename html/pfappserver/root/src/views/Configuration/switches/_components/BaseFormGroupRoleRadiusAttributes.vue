<template>
  <b-form-group ref="form-group"
    class="base-form-group base-form-group-role-radius-attributes"
    :class="{
      'mb-0': !columnLabel
    }"
    :label="columnLabel"
    :label-cols="labelCols"
    :state="inputState"
  >
    <div class="w-100"
      :class="{
        'is-valid': inputState === true,
        'is-invalid': inputState === false
      }"
    >
      <b-row v-for="(row, index) in rows" :key="row.key"
        class="mx-0 mb-1" align-v="center" no-gutters
      >
        <b-col cols="5" class="pr-1">
          <base-input-chosen-one
            :value="row.type"
            :options="attributeOptions"
            :disabled="isLocked"
            :placeholder="$i18n.t('Search RADIUS attributes')"
            @input="onType(index, $event)"
          />
        </b-col>
        <b-col cols="5" class="pr-1">
          <base-input-chosen-one v-if="valueOptions[index]"
            :value="row.value"
            :options="valueOptions[index]"
            :disabled="isLocked || !row.type"
            :placeholder="$i18n.t('Value')"
            @input="onValue(index, $event)"
          />
          <base-input v-else
            :value="row.value"
            :disabled="isLocked || !row.type"
            :placeholder="valuePlaceholder(row)"
            @input="onValue(index, $event)"
          />
        </b-col>
        <b-col cols="2" class="text-nowrap">
          <b-link class="ml-1 text-secondary" :disabled="isLocked" @click="onDelete(index)"
            v-b-tooltip.hover.left.d300 :title="$i18n.t('Delete Row')">
            <icon name="minus-circle" class="cursor-pointer"/>
          </b-link>
          <b-link class="ml-1 text-secondary" :disabled="isLocked" @click="onAdd(index + 1)"
            v-b-tooltip.hover.left.d300 :title="$i18n.t('Add Row')">
            <icon name="plus-circle" class="cursor-pointer"/>
          </b-link>
        </b-col>
      </b-row>
      <b-button v-if="!rows.length"
        :variant="(inputState === false) ? 'outline-danger' : 'outline-secondary'"
        :disabled="isLocked" @click="onAdd(0)">
        {{ $i18n.t('Add RADIUS Attribute') }}
      </b-button>
    </div>
    <template v-slot:description v-if="inheritedText || inputText || inputApiFeedback">
      <div v-if="inputApiFeedback" v-html="inputApiFeedback" class="text-warning"/>
      <div v-if="inheritedText">{{ $i18n.t('Inherited: {attributes}', { attributes: inheritedText }) }}</div>
      <div v-if="inputText" v-html="inputText"/>
    </template>
    <template v-slot:invalid-feedback v-if="inputInvalidFeedback">
      <div v-html="inputInvalidFeedback"/>
    </template>
  </b-form-group>
</template>
<script>
import {
  BaseInput,
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInput,
  BaseInputChosenOne
}

import { computed, inject, ref, watch } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValidator, useInputValidatorProps } from '@/composables/useInputValidator'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

export const props = {
  ...useFormGroupProps,
  ...useInputProps,
  ...useInputMetaProps,
  ...useInputValidatorProps,
  ...useInputValueProps
}

import { parse, serialize } from '../radiusAttributes'

let rowKey = 0

// the options of the dictionary are the same for every role, build them once
let dictionary = { attributes: null, options: [] }
const dictionaryOptions = attributes => {
  if (dictionary.attributes !== attributes)
    dictionary = {
      attributes,
      options: Object.values(attributes).map(({ name, vendor }) => ({ text: (vendor) ? `${name} (${vendor})` : name, value: name }))
    }
  return dictionary.options
}

export const setup = (props, context) => {

  // inject radiusAttributes from ancestor
  const radiusAttributes = inject('radiusAttributes', ref({}))

  const metaProps = useInputMeta(props, context)

  const {
    placeholder,
    text,
    isLocked
  } = useInput(metaProps, context)

  const {
    value,
    onChange
  } = useInputValue(metaProps, context)

  const {
    state,
    invalidFeedback,
    apiFeedback
  } = useInputValidator(metaProps, value)

  const rows = ref([])
  watch(value, newValue => {
    // keep the rows being edited (no attribute chosen yet) when the text is the same
    if (newValue !== serialize(rows.value))
      rows.value = parse(newValue).map(row => ({ ...row, key: ++rowKey }))
  }, { immediate: true })

  // the attributes of the form that are not in the dictionary, joined to compare them
  const missingTypes = computed(() => [...new Set(rows.value
    .filter(({ type }) => type && !(type in radiusAttributes.value))
    .map(({ type }) => type))].join('\n'))

  // the options change only with the attributes that are not in the dictionary, not on each value typed
  const attributeOptions = computed(() => {
    const options = dictionaryOptions(radiusAttributes.value)
    if (!missingTypes.value)
      return options
    return [ ...options, ...missingTypes.value.split('\n').map(type => ({ text: type, value: type })) ]
  })

  const attribute = type => radiusAttributes.value[type] || {}

  // the options of the value of each row, undefined when the attribute has no named values
  const valueOptions = computed(() => rows.value.map(({ type, value: rowValue }) => {
    const { allowed_values } = attribute(type)
    if (!allowed_values || !allowed_values.length)
      return undefined
    const options = allowed_values.map(({ name }) => ({ text: name, value: name }))
    // keep a value of the form that is not named in the dictionary (a number)
    if (rowValue && !options.find(option => option.value === rowValue))
      options.push({ text: rowValue, value: rowValue })
    return options
  }))

  const valuePlaceholder = ({ type }) => attribute(type).placeholder

  const commit = () => onChange(serialize(rows.value))

  const onType = (index, type) => {
    const row = rows.value[index]
    if (row.type !== type) {
      rows.value.splice(index, 1, { ...row, type, value: null })
      commit()
    }
  }

  const onValue = (index, newValue) => {
    rows.value.splice(index, 1, { ...rows.value[index], value: newValue })
    commit()
  }

  const onAdd = index => {
    rows.value.splice(index, 0, { type: null, value: null, key: ++rowKey })
  }

  const onDelete = index => {
    rows.value.splice(index, 1)
    commit()
  }

  // the attributes inherited from the switch group or the default switch
  const inheritedText = computed(() => {
    if (rows.value.length || !placeholder.value)
      return undefined
    return parse(placeholder.value).map(({ type, value }) => `${type} = ${value}`).join(', ')
  })

  return {
    rows,
    attributeOptions,
    valueOptions,
    valuePlaceholder,
    inheritedText,
    onType,
    onValue,
    onAdd,
    onDelete,

    // useInput
    inputText: text,
    isLocked,

    // useInputValidator
    inputState: state,
    inputInvalidFeedback: invalidFeedback,
    inputApiFeedback: apiFeedback
  }
}

// @vue/component
export default {
  name: 'base-form-group-role-radius-attributes',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
