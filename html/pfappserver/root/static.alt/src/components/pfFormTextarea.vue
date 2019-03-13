<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="{ 'mb-0': !columnLabel }">
    <b-form-textarea
      ref="input"
      v-model="inputValue"
      v-bind="$attrs"
      :state="isValid()"
      @input.native="validate()"
      @keyup.native="onChange($event)"
      @change.native="onChange($event)"
    ></b-form-textarea>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-textarea',
  mixins: [
    pfMixinValidation
  ],
  props: {
    value: {
      default: null
    },
    columnLabel: {
      type: String,
      default: null
    },
    labelCols: {
      type: Number,
      default: 3
    },
    text: {
      type: String,
      default: null
    }
  },
  computed: {
    inputValue: {
      get () {
        return this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    }
  }
}
</script>
