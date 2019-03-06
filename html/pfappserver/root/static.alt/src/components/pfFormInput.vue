<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-input" :class="{ 'mb-0': !columnLabel }">
    <b-input-group>
      <b-form-input
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :state="isValid()"
        :disabled="disabled"
        :readonly="readonly"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
      />
      <b-input-group-append v-if="readonly || disabled">
        <b-button class="input-group-text" tabindex="-1" disabled><icon name="lock"></icon></b-button>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-input',
  mixins: [
    pfMixinValidation
  ],
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
    disabled: {
      type: Boolean,
      default: false
    },
    readonly: {
      type: Boolean,
      default: false
    },
    formatter: {
      type: Function,
      default: null
    }
  },
  computed: {
    inputValue: {
      get () {
        return (this.formatter) ? this.formatter(this.value) : this.value
      },
      set (newValue) {
        this.$emit('input', newValue)
      }
    }
  }
}
</script>
