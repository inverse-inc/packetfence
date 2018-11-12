<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="password-element" :class="{ 'mb-0': !columnLabel, 'is-focus': focus }">
    <b-input-group class="input-group-password">
      <b-form-input
        v-model="inputValue"
        v-bind="$attrs"
        ref="input"
        :type="type"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native="onChange($event)"
        @change.native="onChange($event)"
        @focus.native="focus = true"
        @blur.native="focus = false"
      >
      </b-form-input>
      <b-input-group-append>
        <b-button-group rel="prefixButtonGroup">
          <b-button class="input-group-text" @mouseover="over()" @mousemove="over()" @mouseout="out()" :disabled="!this.value"><icon name="eye"></icon></b-button>
          <b-button v-if="test" class="input-group-text" @click="test()" :disabled="!this.value">{{ $t('Test') }}</b-button>
        </b-button-group>
      </b-input-group-append>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-password',
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
    type: {
      type: String,
      default: 'password'
    },
    test: {
      type: Function,
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
  },
  methods: {
    over () {
      this.type = 'text'
    },
    out () {
      this.type = 'password'
    }
  }
}
</script>

<style lang="scss" scoped>
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

/**
 * Adjust is-invalid and is-focus borders
 */
.password-element {
  .input-group-password {
    background-color: $input-focus-bg;
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    padding: 1px;
    outline: 0;

    * {
      border: 0px;
    }
    &:not(:first-child):not(:last-child):not(:only-child),
    &.btn-group:first-child {
      border-radius: 0;
    }
    &:first-child {
      border-top-left-radius: $border-radius;
      border-bottom-left-radius: $border-radius;
    }
    &:last-child {
      border-top-right-radius: $border-radius;
      border-bottom-right-radius: $border-radius;
    }
  }
  &.is-focus .input-group-password {
    border: 1px solid $input-focus-border-color;
    box-shadow: 0 0 0 $input-focus-width rgba($input-focus-border-color, .25);
  }
  &.is-invalid .input-group-password {
    border: 1px solid $form-feedback-invalid-color;
    box-shadow: 0 0 0 $input-focus-width rgba($form-feedback-invalid-color, .25);
  }
}

/**
 * Add btn-primary color(s) on hover
 */
.btn-group[rel=prefixButtonGroup] button:hover {
  color: $input-btn-hover-text-color;
  background-color: $input-btn-hover-bg-color;
  border-color: $input-btn-hover-bg-color;
}
</style>
