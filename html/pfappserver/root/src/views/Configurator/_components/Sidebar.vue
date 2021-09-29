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
const props = {
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
}

import { ref, toRefs } from '@vue/composition-api'
import route from '../_router'
const setup = props => {

  const {
    step,
    invalidStep
  } = toRefs(props)

  const routes = ref(route.children)
  const stepsCount = ref(routes.value.length)

  const isCurrentStep = i => i === step.value
  const isInvalidStep = i => invalidStep.value && i >= step.value
  const classForStep = i => {
    if (i === step.value) {
      return invalidStep.value ? 'bg-warning' : 'btn-outline-primary'
    } else if (i < step.value) {
      return 'bg-primary text-white'
    } else {
      return 'btn-outline-faded'
    }
  }
  const lineClassForStep = i => {
    if (i > 0 && i < stepsCount.value) {
      if (i > step.value) {
        return 'wizard-line-inactive'
      } else {
        return 'wizard-line-active'
      }
    }
  }

  return {
    routes,
    stepsCount,
    isCurrentStep,
    isInvalidStep,
    classForStep,
    lineClassForStep
  }
}

// @vue/component
export default {
  name: 'sidebar',
  props,
  setup
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