<template>
  <b-row>
    <b-col cols="12" md="4" xl="3" class="pf-sidebar d-print-none">
      <sidebar :step="step" :name="name" :icon="icon"/>
    </b-col>
    <b-col cols="12" md="8" xl="9" class="mt-3 mb-3">
      <slot></slot>
      <b-container class="p-3">
        <b-row align-v="center">
          <b-col v-if="previousRouteName">
            <b-link :to="{ name: previousRouteName }"><icon class="mr-1" name="chevron-left"></icon> {{ $t('Previous') }}</b-link>
          </b-col>
          <b-col class="text-right" v-if="nextRouteName">
            <b-button variant="primary" :to="{ name: nextRouteName }">{{ $t('Next Step') }} <icon class="ml-1" name="chevron-right"></icon></b-button>
          </b-col>
          <slot name="footer"></slot>
        </b-row>
      </b-container>
    </b-col>
  </b-row>
</template>

<script>
import route from '../_router'
import Sidebar from './Sidebar'

export default {
  name: 'base-step',
  components: {
    Sidebar
  },
  data () {
    return {
      step: 0,
      previousRouteName: null,
      nextRouteName: null
    }
  },
  props: {
    name: {
      type: String
    },
    icon: {
      type: String
    }
  },
  methods: {
    init () {
      // Find current route to identify next and previous steps
      let steps = route.children
      steps.find((route, index) => {
        let { children = [] } = route
        let match = false
        if (route.name == this.$route.name) {
          match = true
        } else {
          match = children.find(route => {
            return route.name == this.$route.name
          })
        }
        if (match) {
          // Route found
          this.step = index
          if (index > 0) {
            this.previousRouteName = steps[index - 1].name;
          }
          if (index + 1 < steps.length) {
            this.nextRouteName = steps[index + 1].name
          }
          return true
        }
        return false
      })
    }
  },
  created () {
    this.init()
  }
}
</script>