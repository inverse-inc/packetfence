<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :content-cols="contentCols"
    :content-cols-sm="contentColsSm"
    :content-cols-md="contentColsMd"
    :content-cols-lg="contentColsLg"
    :content-cols-xl="contentColsXl"
    :label="columnLabel"
    :label-cols="labelCols"
    :label-cols-sm="labelColsSm"
    :label-cols-md="labelColsMd"
    :label-cols-lg="labelColsLg"
    :label-cols-xl="labelColsXl"
  >
    <b-input-group class="text-nowrap">

      <base-input-chosen-one group-label="group" group-values="options" :namespace="namespace"/>

      <b-button v-if="switchTemplateId"
        variant="outline-primary" class="ml-2"
        :to="{ name: 'switchTemplate', params: { id: switchTemplateId } }"
      >{{ $i18n.t('View Switch Template') }}</b-button>

      <template v-slot:prepend v-if="isDefault && isEmpty">
        <b-button
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
          v-b-tooltip.hover.left.d300 :title="$t('A default value is provided if this field is not defined.')"
        >
          <icon ref="icon-default"
            name="stamp" scale="0.75"
          />
        </b-button>
      </template>
      <template v-slot:append v-if="isLocked">
        <b-button
          class="input-group-text"
          :disabled="true"
          tabIndex="-1"
        >
          <icon ref="icon-lock"
            name="lock"
          />
        </b-button>
      </template>

    </b-input-group>
    <template v-slot:description v-if="inputText">
      <div v-html="inputText"/>
    </template>
  </b-form-group>
</template>
<script>
import {
  BaseInputChosenOne
} from '@/components/new'

const components = {
  BaseInputChosenOne
}

import { computed, inject, ref } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInputMetaProps, useInputMeta } from '@/composables/useMeta'
import { useInput, useInputProps } from '@/composables/useInput'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'

const props = {
  ...useFormGroupProps,
  ...useInputMetaProps,
  ...useInputProps,
  ...useInputValueProps
}

const setup = (props, context) => {
  const metaProps = useInputMeta(props, context)

  const {
    isDefault,
    isLocked,
    placeholder
  } = useInput(metaProps, context)

  const {
    value,
    text,
    isEmpty
  } = useInputValue(metaProps, context)

  const meta = inject('meta', ref({}))
  const switchTemplates = computed(() => {
    const { type: { allowed: switchGroups = [] } = {} } = meta.value
    let _switchTemplates = []
    switchGroups.map(switchGroup => {
      const { options: switchGroupMembers } = switchGroup
      switchGroupMembers.forEach(switchGroupMember => {
        const { is_template, value } = switchGroupMember
        if (is_template)
          _switchTemplates.push(value)
      })
    })
    return _switchTemplates
  })

  const switchTemplateId = computed(() => {
    if (switchTemplates.value.includes(value.value))
      return value.value
    return undefined
  })

  return {
    inputPlaceholder: placeholder,
    inputText: text,
    switchTemplateId,
    isDefault,
    isEmpty,
    isLocked
  }
}

// @vue/component
export default {
  name: 'base-form-group-type',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>


