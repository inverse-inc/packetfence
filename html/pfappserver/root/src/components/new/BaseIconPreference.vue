<template>
  <icon name="save" v-bind="$atrrs"
    id="icon-preference" :class="(isReading || isWriting) ? 'active' : 'inactive'"
    v-b-tooltip.hover.right.d300 :title="$t(`User preference (${id}) stored in database.`)"
    />
</template>

<script>

const props = {
  id: {
    type: String
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const isReading = computed(() => $store.getters['preferences/isReadingId'](id.value))
  const isWriting = computed(() => $store.getters['preferences/isWritingId'](id.value))

  return {
    isReading,
    isWriting
  }
}

// @vue/component
export default {
  name: 'base-icon-preference',
  props,
  setup
}
</script>

<style lang="scss">
@keyframes active {
  from { color: rgb(248, 249, 250); }
  to { color: rgb(0, 123, 255); }
}
@keyframes inactive {
  from { color: rgb(0, 123, 255); }
  to { color: rgb(248, 249, 250); }
}

#icon-preference {
  &.active {
    color: rgb(0, 123, 255);
    animation-name: active;
    animation-duration: 3s;
  }
  &.inactive {
    color: rgb(248, 249, 250);
    animation-name: inactive;
    animation-duration: 3s;
  }
}
</style>