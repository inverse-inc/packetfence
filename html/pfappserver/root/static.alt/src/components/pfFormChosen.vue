<template>
  <b-form-group horizontal :label-cols="(columnLabel) ? labelCols : 0" :label="$t(columnLabel)"
    :state="isValid()" :invalid-feedback="getInvalidFeedback()"
    class="pf-form-chosen" :class="{ 'mb-0': !columnLabel, 'is-focus': focus }">
    <b-input-group>
      <multiselect
        v-model="inputValue"
        v-bind="$attrs"
        v-on="forwardListeners"
        ref="input"
        :showLabels="false"
        :id="id"
        :multiple="multiple"
        :options="options"
        :trackBy="trackBy"
        :state="isValid()"
        @input.native="validate()"
        @keyup.native.stop.prevent="onChange($event)"
        @change.native="onChange($event)"
        @open="focus = true"
        @close="focus = false"
      >
        <b-media slot="noResult" class="text-secondary" md="auto">
          <icon name="search" scale="2" slot="aside" class="ml-2"></icon>
          <strong>{{ $t('No results') }}</strong>
          <b-form-text class="font-weight-light">{{ $t('Please refine your search.') }}</b-form-text>
        </b-media>
      </multiselect>
    </b-input-group>
    <b-form-text v-if="text" v-t="text"></b-form-text>
  </b-form-group>
</template>

<script>
import Multiselect from 'vue-multiselect'
import 'vue-multiselect/dist/vue-multiselect.min.css'
import pfMixinValidation from '@/components/pfMixinValidation'

export default {
  name: 'pf-form-chosen',
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
      default: []
    },
    multiple: {
      type: Boolean,
      default: false
    },
    id: {
      type: String
    },
    trackBy: {
      type: String,
      default: 'value'
    },
    // Add a proxy on our inputValue to modify set/get for simple external models.
    // https://github.com/shentao/vue-multiselect/issues/385#issuecomment-418881148
    collapseObject: {
      type: Boolean,
      default: false
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
        const currentValue = this.value || ((this.multiple) ? [] : null)
        if (this.collapseObject) {
          return (this.multiple)
            ? [...new Set(currentValue.map(value => this.options.find(option => option[this.trackBy] === value)))]
            : (this.options)
              ? this.options.find(option => option[this.trackBy] === currentValue)
              : null
        }
        return currentValue
      },
      set (newValue) {
        if (this.collapseObject) {
          newValue = (this.multiple)
            ? [...new Set(newValue.map(value => value[this.trackBy]))]
            : (newValue && newValue[this.trackBy])
        }
        this.$emit('input', newValue)
      }
    },
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    }
  }
}
</script>

<style lang="scss">
@import "../../node_modules/bootstrap/scss/functions";
@import "../../node_modules/bootstrap/scss/mixins/border-radius";
@import "../../node_modules/bootstrap/scss/mixins/box-shadow";
@import "../../node_modules/bootstrap/scss/mixins/transition";
@import "../styles/variables";

/**
 * Adjust is-invalid and is-focus borders
 */
.pf-form-chosen {
  .multiselect {
      border-width: 1px;
      font-size: $font-size-base;
      min-height: auto;
  }
  .multiselect__tags {
    background-color: $input-focus-bg;
    border: 1px solid $input-focus-bg;
    @include border-radius($border-radius);
    @include transition($custom-forms-transition);
    padding: $input-padding-y $input-padding-x;
    min-height: auto;
    outline: 0;
    span > span.multiselect__single { /* placeholder */
      color: $input-placeholder-color;
      // Override Firefox's unusual default opacity; see https://github.com/twbs/bootstrap/pull/11526.
      opacity: 1;
    }
    .multiselect__tag {
      margin-bottom: 0px;
    }
  }
  .multiselect__input,
  .multiselect__single {
    background-color: $input-focus-bg;
    font-size: $font-size-base;
    line-height: $input-line-height;
    color: $input-color;
    padding: 0px;
    margin: 0px;
    &::placeholder {
      color: $input-placeholder-color;
    }
  }
  .multiselect__placeholder {
    color: $input-placeholder-color;
    font-size: $font-size-base;
    line-height: $input-line-height;
    margin-bottom: 0px;
    padding-top: 0px;
  }
  .multiselect__content-wrapper {
      border: $dropdown-border-width solid $dropdown-border-color;
      @include border-radius($dropdown-border-radius);
      @include box-shadow($dropdown-box-shadow);
      z-index: $zindex-dropdown;
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
    .multiselect__content-wrapper {
      border-bottom-width: 0px;
      border-bottom-left-radius: 0 !important;
      border-bottom-right-radius: 0 !important;
    }
  }
  .multiselect__option--highlight {
    color: $dropdown-link-active-color;
    background-color: $dropdown-link-active-bg;
  }
  &.is-focus {
    .multiselect__tags {
      border-color: $input-focus-border-color;
    }
  }
  &.is-invalid {
    .multiselect__tags {
      border-color: $form-feedback-invalid-color;
    }
  }
}
</style>
