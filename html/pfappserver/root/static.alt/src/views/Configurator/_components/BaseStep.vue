<template>
  <b-container fluid>
    <b-row>
      <b-col cols="12" md="4" xl="3" class="pf-sidebar">
        <h6 class="mt-3 px-4 text-muted text-uppercase text-left">{{ $t('Configuration Wizard') }}</h6>
        <sidebar
          :step="step"
          :next-route-name="nextRouteName"
          :previous-route-name="previousRouteName"
          :name="name"
          :icon="icon"
          :invalid-step="invalidStep"
          :is-loading="isLoading"/>
      </b-col>
      <b-col cols="12" md="8" xl="9" class="mt-3 mb-3">
        <h6 class="text-muted text-uppercase">{{ $t('Step {nb}', { nb: step + 1 }) }}</h6>
        <slot></slot>
        <b-container class="p-3" fluid>
          <b-row align-v="center" v-if="!disableNavigation">
            <b-col v-if="previousRouteName">
              <b-link :to="{ name: previousRouteName }"><icon class="mr-1" name="chevron-left"></icon> {{ $t('Previous') }}</b-link>
            </b-col>
            <b-col class="text-right">
              <slot name="button-next">
                <b-button v-if="nextRouteName" :disabled="invalidStep || isLoading" variant="primary" @click="next">
                  {{ $t('Next Step') }} <icon class="ml-1" name="chevron-right"></icon>
                </b-button>
              </slot>
              <div class="d-block invalid-feedback" v-if="invalidFeedback" v-text="invalidFeedback"></div>
            </b-col>
          </b-row>
          <slot name="footer"></slot>
        </b-container>
      </b-col>
    </b-row>
  </b-container>
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
    },
    disableNavigation: {
      type: Boolean,
      default: false
    },
    invalidStep: {
      type: Boolean,
      default: false
    },
    invalidFeedback: {
      type: String
    },
    isLoading: {
      type: Boolean,
      default: false
    },
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
    },
    next () {
      this.$emit('next', this.nextRouteName)
    }
  },
  created () {
    this.init()
  }
}
</script>