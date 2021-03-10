<template>
  <b-form-group ref="form-group"
    class="base-form-group"
    :class="{
      'mb-0': !columnLabel
    }"
    :labelCols="labelCols"
    :label="columnLabel"
  >
    <b-input-group class="text-nowrap">

      <base-input-chosen-one :namespace="namespace"/>

      <b-button v-if="switchTemplateId"
        variant="outline-primary" class="ml-2"
        :to="{ name: 'switchTemplate', params: { id: switchTemplateId } }"
      >{{ $i18n.t('View Switch Template') }}</b-button>

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

import { computed, ref } from '@vue/composition-api'
import { useFormGroupProps } from '@/composables/useFormGroup'
import { useInputMetaProps, useInputMeta } from '@/composables/useMeta'
import { useInputProps } from '@/composables/useInput'
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
    value,
    text
  } = useInputValue(metaProps, context)

  const { root: { $store } = {} } = context

  const switchTemplates = ref([])
  $store.dispatch('$_switches/optionsBySwitchGroup').then(switchGroupOptions => {
    const { meta: { type: { allowed: switchGroups = [] } = {} } = {} } = switchGroupOptions
    switchGroups.map(switchGroup => {
      const { options: switchGroupMembers } = switchGroup
      switchGroupMembers.map(switchGroupMember => {
        const { is_template, value } = switchGroupMember
        if (is_template)
          switchTemplates.value.push(value)
      })
    })
  })

  const switchTemplateId = computed(() => {
    if (switchTemplates.value.includes(value.value))
      return value.value
    return undefined
  })

  return {
    inputText: text,
    switchTemplateId
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


