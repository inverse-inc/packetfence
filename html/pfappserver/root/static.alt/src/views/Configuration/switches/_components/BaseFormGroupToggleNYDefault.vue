<template>
  <base-form-group-toggle v-bind="bind"/>
</template>
<script>
import { BaseFormGroupToggle, BaseFormGroupToggleProps as props } from '@/components/new/'

const components = {
  BaseFormGroupToggle
}

import { computed, toRefs } from '@vue/composition-api'
import { useInput } from '@/composables/useInput'
import { useInputMeta } from '@/composables/useMeta'
import { useInputValue } from '@/composables/useInputValue'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const metaProps = useInputMeta(props, context)

  const {
    placeholder
  } = useInput(metaProps, context)

  const {
    value
  } = useInputValue(metaProps, context)

  const bind = computed(() => {

    let options = [
      { value: 'N', label: i18n.t('No') },
      { value: 'Y', label: i18n.t('Yes'), color: 'var(--primary)' }
    ]
    let hints = []

    if (placeholder.value) {
      let defaultColor
      let defaultLabel
      switch (placeholder.value) {
        case 'Y':
          defaultColor = 'var(--primary)'
          defaultLabel = i18n.t('Yes')
          break
        case 'N':
        default:
          defaultLabel = i18n.t('No')
          break
      }
      options = [ // recompose
        options[0],
        { value: null, label: i18n.t(`Default ({default})`, { default: defaultLabel }), color: defaultColor },
        options[1]
      ]

      switch (true) {
        case placeholder.value === 'N' && [options[0].value, options[1].value].includes(value.value):
          hints = [/*0, 1,*/[0, 1]]
          break

        case placeholder.value === 'Y' && [options[1].value, options[2].value].includes(value.value):
          hints = [/*1, 2,*/[1, 2]]
          break
      }
    }

    return {
      ...props,

      // overload `options` and `hints`, includes placeholder if defined
      options,
      hints,

      // always show right label
      labelRight: true
    }
  })

  return {
    bind
  }
}

export default {
  name: 'base-form-group-toggle-n-y-default',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
