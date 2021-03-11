<template>
  <b-button ref="buttonComponentRef"
    type="submit"
    :disabled="disabled || isLoading"
    :style="{ minWidth: buttonWidth }"
    :variant="variant"
    v-bind="$attrs"
    v-on="$listeners"
  >
    <icon v-if="isLoading"
      name="circle-notch" spin />
    <slot v-else>{{ $t('Save') }}</slot>
  </b-button>
</template>
<script>
import { ref, toRefs, watch } from '@vue/composition-api'

const props = {
  disabled: {
    type: Boolean
  },
  isLoading: {
    type: Boolean
  },
  variant: {
    type: String,
    default: 'primary'
  }
}

const setup = (props) => {
  const {
    isLoading
  } = toRefs(props)

  const buttonComponentRef = ref(null)
  const buttonWidth = ref(0)

  watch(isLoading, isLoading => {
    if (isLoading)
      buttonWidth.value = `${buttonComponentRef.value.clientWidth + 2}px`
  })

  return {
    buttonComponentRef,
    buttonWidth
  }
}

// @vue/component
export default {
  name: 'base-button-save',
  inheritAttrs: false,
  props,
  setup
}
</script>
