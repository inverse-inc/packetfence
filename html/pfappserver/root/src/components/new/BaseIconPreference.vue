<template>
  <icon name="save" v-bind="$attrs"
    id="icon-preference" :class="className"
    v-b-tooltip.hover.right.d300 :title="$t(`User preference (${id}) stored in database.`)"
    />
</template>

<script>

const props = {
  id: {
    type: String
  }
}

import { computed, ref, toRefs, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const isReading = computed(() => $store.getters['preferences/isReadingId'](id.value))
  const isWriting = computed(() => $store.getters['preferences/isWritingId'](id.value))
  const className = ref('is-inactive')


  watch(isReading, () => {
    if (isReading.value)
      className.value = 'is-reading'
    else
      className.value = 'was-reading'
  })

  watch(isWriting, () => {
    if (isWriting.value)
      className.value = 'is-writing'
    else
      className.value = 'was-writing'
  })

  return {
    className
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
$color_active_r: rgb(40, 167, 69);
$color_active_w: rgb(220, 53, 69);
$color_inactive: rgb(216, 216, 216);

@keyframes is-reading {
  0% { color: $color_inactive; transform: scale(1); }
  100% { color: $color_active_r; transform: scale(1.5); }
}
@keyframes was-reading {
  0% { color: $color_inactive; transform: scale(1); }
  25% { color: $color_active_r; transform: scale(1.5); }
  75% { color: $color_active_r; transform: scale(1.5); }
  100% { color: $color_inactive; transform: scale(1); }
}
@keyframes is-writing {
  0% { color: $color_inactive; transform: scale(1); }
  100% { color: $color_active_w; transform: scale(1.5); }
}
@keyframes was-writing {
  0% { color: $color_inactive; transform: scale(1); }
  25% { color: $color_active_w; transform: scale(1.5); }
  75% { color: $color_active_w; transform: scale(1.5); }
  100% { color: $color_inactive; transform: scale(1); }
}

#icon-preference {
  color: $color_inactive;
  &.is-reading {
    color: $color_active_r;
    animation: is-reading 1000ms;
  }
  &.was-reading {
    animation: was-reading 3000ms;
  }
  &.is-writing {
    color: $color_active_w;
    animation: is-writing 1000ms;
  }
  &.was-writing {
    animation: was-writing 3000ms;
  }
}
</style>