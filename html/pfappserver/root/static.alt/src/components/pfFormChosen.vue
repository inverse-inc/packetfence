<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()" :class="[{ 'mb-0': !columnLabel }, { 'is-focus': focus}]">
    <b-input-group class="input-group-chosen">
      <multiselect 
        v-model="inputValue"
        v-bind="$attrs"
        :options="options"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
        @open="focus = true"
        @close="focus = false"
      ></multiselect>
    </b-input-group>
    <b-form-text v-if="text" v-t="text">This is an error</b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-input',
  mixins: [
    pfMixinValidation
  ],
  components: {
    Multiselect
  },
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
    options: {
      type: Array,
      default: null
    }
  },
  data () {
    return {
      focus: false
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

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

/* fix underlap with input-group::z-index:2 */
.input-group-prepend .btn, .input-group-append .btn {
  z-index: auto;
}

/**
 * Adjust is-invalid and is-focus borders
 */
.form-group {
  .multiselect {
      border-width: 1px;
  }
  .multiselect__tags {
    background-color: $input-focus-bg;
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    outline: 0;
  }
  .multiselect__input,
  .multiselect__single {
    background-color: $input-focus-bg;
  }
  .multiselect__content-wrapper {
      border-left-width: 1px;
      border-right-width: 1px;
  }
  .multiselect--active:not(.multiselect--above) {
    .multiselect__content-wrapper {
      border-top-width: 0px;
      border-bottom-width: 1px;
      border-top-left-radius: 0 !important;
      border-top-right-radius: 0 !important;
      border-bottom-left-radius: $border-radius !important;
      border-bottom-right-radius: $border-radius !important;
    }
  }
  .multiselect--above {
    .mulitselect__content-wrapper {
      border-top-width: 1px;
      border-bottom-width: 0px;
      border-top-left-radius: $border-radius !important;
      border-top-right-radius: $border-radius !important;
      border-bottom-left-radius: 0 !important;
      border-bottom-right-radius: 0 !important;
    }
  }
  &.is-focus {
    .multiselect__tags {
      border-color: $input-focus-border-color;
    }
    .multiselect__content-wrapper {
      border-color: $input-focus-border-color;
      box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
    }
  }
  &.is-invalid {

    .multiselect__tags {
      border-color: $form-feedback-invalid-color;
    }
    .multiselect__content-wrapper {
      border-color: $form-feedback-invalid-color;
      box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
    }
  }
}
</style>
