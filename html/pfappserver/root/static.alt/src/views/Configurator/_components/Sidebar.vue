<template>
    <div>
        <b-row class="text-center my-3">
            <b-col :cols="Math.floor(12/stepsCount)" v-for="i in stepsCount" :key="i">
                <b-button
                  class="rounded-circle"
                  size="sm" pill
                  :to="{ name: routes[i - 1].name }"
                  :disabled="isInvalidStep(i - 1)"
                  :variant="isCurrentStep(i - 1)? ( isInvalidStep(i - 1) ? 'warning' : 'primary' ) : 'outline-secondary'">{{ i }}</b-button>
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
    }
  },
  created () {
    this.stepsCount = this.routes.length
  }
}
</script>
