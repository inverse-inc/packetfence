<template>
    <div>
        <div class="icon-counter" :class="variant" v-if="notEmpty">
          <slot>{{ count }}</slot>
        </div>
        <icon :name="name" v-bind="$attrs"></icon>
    </div>
</template>

<script>
export default {
  name: 'icon-counter',
  inheritAttrs: false,
  props: {
    name: {
      type: String,
      required: true
    },
    variant: {
      type: String,
      default: 'danger'
    },
    value: {
      type: Number,
      default: 0,
      required: true
    }
  },
  computed: {
    count () {
      return (this.value > 99) ? '!!' : this.value
    },
    notEmpty () {
      return this.value > 0
    }
  }
}
</script>

<style lang="scss">
/* See styles/_icon-counter.scss */
</style>
