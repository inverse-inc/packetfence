<template>
    <b-container>
        <b-row class="text-center my-3">
            <b-col :cols="Math.floor(12/stepsCount)" v-for="i in stepsCount" :key="i">
                <b-button size="sm" pill :variant="isCurrentStep(i - 1)? 'outline-primary' : 'outline-secondary'">{{ i }}</b-button>
            </b-col>
        </b-row>
        <b-col class="text-center">
            <icon class="text-primary my-4" :name="icon" scale="3"></icon>
            <h1 class="m-3">{{ name }}</h1>
        </b-col>
    </b-container>
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
    }
  },
  methods: {
    isCurrentStep (i) {
        return i === this.step
    }
  },
  created () {
    this.stepsCount = route.children.length
  }
}
</script>
