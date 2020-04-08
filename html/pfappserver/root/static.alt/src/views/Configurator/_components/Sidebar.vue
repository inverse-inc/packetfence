<template>
    <div class="wizard-sidebar">
        <b-row class="text-center my-3" no-gutters>
            <b-col :cols="Math.floor(12/stepsCount)" v-for="i in stepsCount" :key="i">
                <div class="wizard-line" :class="lineClassForStep(i - 1)"></div>
                <div class="btn btn-sm rounded-circle" :class="classForStep(i - 1)">{{ i }}</div>
                <div class="wizard-line" :class="lineClassForStep(i)"></div>
            </b-col>
        </b-row>
        <b-col class="text-center">
            <icon class="text-primary my-4" :name="icon" scale="3"></icon>
            <h1 class="m-3">{{ name }}</h1>
        </b-col>
    </div>
</template>

<script>
import route from '../_router'

export default {
  name: 'sidebar',
  data () {
    return {
      stepsCount: 0
    }
  },
  props: {
    name: {
      type: String
    },
    icon: {
      type: String
    },
    step: {
      type: Number,
      default: 0
    },
    invalidStep: {
      type: Boolean,
      default: false
    }
  },
  computed: {
    routes () {
      return route.children
    }
  },
  methods: {
    isCurrentStep (i) {
      return i === this.step
    },
    isInvalidStep (i) {
      return this.invalidStep && i >= this.step
    },
    classForStep (i) {
      if (i === this.step) {
        return this.invalidStep ? 'bg-warning' : 'btn-outline-primary'
      } else if (i < this.step) {
        return 'bg-primary text-white'
      } else {
        return 'btn-outline-faded'
      }
    },
    lineClassForStep (i) {
      if (i > 0 && i < this.stepsCount) {
        if (i > this.step) {
          return 'wizard-line-inactive'
        } else {
          return 'wizard-line-active'
        }
      }
    }
  },
  created () {
    this.stepsCount = this.routes.length
  }
}
</script>

<style lang="scss">
$faded-color: $gray-300;
.wizard-sidebar {
  .btn {
    position: relative;
    z-index: 2;
    background-color: $body-bg;
    cursor: default;
    &.btn-outline-faded {
      border-color: $faded-color;
      color: $faded-color;
    }
  }
  .wizard-line {
    position: absolute;
    top: 0;
    width: 50%;
    height: 50%;
    &-active {
      border-bottom: 1px solid $primary;
    }
    &-inactive {
      border-bottom: 1px solid $faded-color;
    }
    &:last-child {
      right: 0;
    }
  }
}
</style>