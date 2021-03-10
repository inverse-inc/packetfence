<template>
  <div>
    <form-group-type
      :namespace="`${namespace}.type`"
      :column-label="$i18n.t('Type')"
      :options="triggerTypeOptions"
      :deselectLabel="$i18n.t('Press enter to disable')"
    />

    <form-group-direction v-show="type === 'bandwidth'"
      :namespace="`${namespace}.direction`"
      :column-label="$i18n.t('Direction')"
      :options="triggerDirectionOptions"
    />

    <form-group-limit v-show="type === 'bandwidth'"
      :namespace="`${namespace}.limit`"
      :column-label="$i18n.t('Limit')"
    />

    <form-group-interval v-show="type === 'bandwidth'"
      :namespace="`${namespace}.interval`"
      :column-label="$i18n.t('Interval')"
      :options="triggerIntervalOptions"
    />
  </div>
</template>
<script>
import {
  BaseFormGroupChosenOne        as FormGroupType,
  BaseFormGroupChosenOne        as FormGroupDirection,
  BaseFormGroupInputMultiplier  as FormGroupLimit,
  BaseFormGroupChosenOne        as FormGroupInterval
} from '@/components/new/'

const components = {
  FormGroupType,
  FormGroupDirection,
  FormGroupLimit,
  FormGroupInterval
}

import { computed } from '@vue/composition-api'
import { useInputMeta, useInputMetaProps } from '@/composables/useMeta'
import { useInputValue, useInputValueProps } from '@/composables/useInputValue'
import {
  triggerDirectionOptions,
  triggerIntervalOptions,
  triggerTypeOptions
} from '../config'

const props = {
  ...useInputMetaProps,
  ...useInputValueProps
}

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    value: inputValue
  } = useInputValue(metaProps, context)

  const type = computed(() => {
    const { type } = inputValue.value || {}
    return type
  })

  return {
    type,

    triggerDirectionOptions,
    triggerIntervalOptions,
    triggerTypeOptions
  }
}

// @vue/component
export default {
  name: 'base-trigger-usage',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

