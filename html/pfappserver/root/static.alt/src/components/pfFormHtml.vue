<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    class="pf-form-html" :class="{ 'mb-0': !columnLabel }">
    <b-input-group v-html="html"></b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
export default {
  name: 'pf-form-html',
  props: {
    value: {
      default: null
    },
    columnLabel: {
      type: String
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    },
    html: {
      type: String,
      default: null
    }
  }
}
</script>
