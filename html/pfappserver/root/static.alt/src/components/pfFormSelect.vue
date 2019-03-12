<template>
  <b-form-group :horizontal="columnLabel" :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-select" :class="{ 'mb-0': !columnLabel }">
    <b-input-group>
      <b-form-select
        v-model="inputValue"
        v-bind="$attrs"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
      >
        <!-- BEGIN SLOTS -->
        <!-- Forward default slot -->
        <slot/>
        <!-- Forward named slots -->
        <slot name="first" slot="first"/>
        <!-- END SLOTS -->
      </b-form-select>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-select',
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
