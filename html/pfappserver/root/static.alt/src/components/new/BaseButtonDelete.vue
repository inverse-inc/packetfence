<template>
  <b-button-group
    class="d-inline-flex" :class="{ 'flex-row-reverse': reverse }" :size="size"
    @mouseleave="stopInterrupt($event)"
  >
    <b-button v-if="!interrupt"
      type="button"
      :variant="variant"
      :disabled="disabled"
      @click="startInterrupt($event)"
    >
      <slot>{{ $t('Delete') }}</slot>
    </b-button>
    <b-button v-if="interrupt"
      type="button"
      class="text-nowrap" variant="outline-danger"
      disabled
    >
      {{ confirm }}
    </b-button>
    <b-button v-if="interrupt"
      type="button"
      variant="danger"
      @click="onDelete($event)"
      @mousemove="startInterrupt($event)"
      @mouseover="startInterrupt($event)"
    >
      <slot>{{ $t('Delete') }}</slot>
    </b-button>
  </b-button-group>
</template>
<script>
import { onBeforeUnmount, ref, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

const props = {
  confirm: {
    type: String,
    default: i18n.t('Are you sure?')
  },
  disabled: {
    type: Boolean
  },
  reverse: {
    type: Boolean
  },
  size: {
    type: String,
    default: 'md',
    validator: value => ['sm', 'md', 'lg'].includes(value)
  },
  timeoutDelay: {
    type: Number,
    default: 3000
  },
  variant: {
    type: String,
    default: 'danger'
  },
}

const setup = (props, { emit }) => {

  const {
    timeoutDelay
  } = toRefs(props)

  const interrupt = ref(false)
  let timeout

  const startInterrupt = () => {
    if (timeout)
      clearTimeout(timeout)
    interrupt.value = true
    timeout = setTimeout(stopInterrupt, timeoutDelay.value)
  }

  const stopInterrupt = () => {
    if (timeout)
      clearTimeout(timeout)
    interrupt.value = false
  }

  const onDelete = e => {
    interrupt.value = false
    emit('delete', e)
  }

  onBeforeUnmount(() => {
    if (timeout)
      clearTimeout(timeout)
  })

  return {
    interrupt,
    startInterrupt,
    stopInterrupt,
    onDelete
  }
}

// @vue/component
export default {
  name: 'base-button-delete',
  inheritAttrs: false,
  props,
  setup
}
</script>
<style lang="scss">
.btn-group.flex-row-reverse {
  > .btn {
    &:not(:last-child):not(.dropdown-toggle) {
      border-top-left-radius: 0;
      border-bottom-left-radius: 0;
      border-top-right-radius: $btn-border-radius;
      border-bottom-right-radius: $btn-border-radius;
    }
    &:not(:first-child):not(.dropdown-toggle) {
      border-top-left-radius: $btn-border-radius;
      border-bottom-left-radius: $btn-border-radius;
      border-top-right-radius: 0;
      border-bottom-right-radius: 0;
    }
  }
}
</style>
