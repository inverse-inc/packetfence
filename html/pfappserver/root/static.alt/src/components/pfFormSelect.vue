<template>
  <b-form-group :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)" :state="inputState"
    class="pf-form-select" :class="{ 'mb-0': !columnLabel }">
    <template v-slot:invalid-feedback>
      <icon name="circle-notch" spin v-if="!inputInvalidFeedback"></icon> {{ inputInvalidFeedback }}
    </template>
    <b-input-group>
      <b-form-select
        v-model="inputValue"
        v-bind="$attrs"
        :state="inputState"
        :disabled="disabled"
        :readonly="readonly"
        :options="options"
      >
        <template v-slot:first><slot name="first"/></template>
        <slot/>
      </b-form-select>
    </b-input-group>
    <b-form-text v-if="text" v-html="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-select',
  mixins: [
    pfMixinForm
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
    options: {
      type: Array,
      default: () => { return [] }
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    }
  }
}
</script>
