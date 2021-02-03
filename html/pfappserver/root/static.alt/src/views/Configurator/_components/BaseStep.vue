<template>
  <b-container fluid>
    <b-row>
      <b-col cols="12" md="4" xl="3" class="pf-sidebar">
        <h6 class="mt-3 px-4 text-muted text-uppercase text-left">{{ $t('Configuration Wizard') }}</h6>
        <sidebar
          :step="step"
          :next-route-name="nextRoute"
          :previous-route-name="previousRoute"
          :name="name"
          :icon="icon"
          :invalid-step="invalidStep"
          :is-loading="isLoading"/>
      </b-col>
      <b-col cols="12" md="8" xl="9" class="mt-3 mb-3">
        <b-row>
          <b-col cols="auto" class="mr-auto px-3">
            <h6 class="text-muted text-uppercase">{{ $t('Step {nb}', { nb: step + 1 }) }}</h6>
          </b-col>
          <b-col class="text-right px-3">
            <h6 class="text-muted">{{ version }}</h6>
          </b-col>
        </b-row>
        <slot></slot>
        <b-container class="p-3" fluid>
          <b-row align-v="center" v-if="!disableNavigation">
            <b-col cols="auto">
              <b-link v-if="previousRoute"
                :to="previousRoute"><icon class="mr-1" name="chevron-left"></icon> {{ $t('Previous') }}</b-link>
            </b-col>
            <b-col cols="auto" class="ml-auto text-right">
              <slot name="button-next">
                <base-button-save :disabled="invalidStep" :isLoading="isLoading" variant="primary" @click="next">
                  {{ $t('Next Step') }} <icon class="ml-1" name="chevron-right"></icon>
                </base-button-save>
              </slot>
              <div class="d-block invalid-feedback" v-if="invalidFeedback && !isLoading" v-text="invalidFeedback"></div>
            </b-col>
          </b-row>
          <slot name="footer"></slot>
        </b-container>
      </b-col>
    </b-row>
  </b-container>
</template>

<script>
import { BaseButtonSave } from '@/components/new/'
import Sidebar from './Sidebar'

const components = {
  BaseButtonSave,
  Sidebar
}

const props = {
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
  }
}

import { ref } from '@vue/composition-api'
import router from '../_router'

const setup = (props, context) => {

  const { root: { $route, $store } = {}, emit } = context

  const step = ref(0)
  const previousRoute = ref(undefined)
  const nextRoute = ref(undefined)

  const version = ref(null)
  $store.dispatch('system/getSummary').then(({ version: _version }) => {
    version.value = _version
  })

  // Find current route to identify next and previous steps
  let steps = router.children
  steps.find((route, index) => {
    let { children = [] } = route
    let match = false
    if (route.name == $route.name) {
      match = true
    } else {
      match = children.find(route => {
        return route.name == $route.name
      })
    }
    if (match) {
      // Route found
      step.value = index
      if (index > 0) {
        previousRoute.value = steps[index - 1]
      }
      if (index + 1 < steps.length) {
        nextRoute.value = steps[index + 1]
      }
      return true
    }
    return false
  })

  const next = () => {
    emit('next', nextRoute.value)
  }

  return {
    // state
    nextRoute,
    previousRoute,
    step,
    version,

    // methods
    next
  }
}

// @vue/component
export default {
  name: 'base-step',
  components,
  props,
  setup
}
</script>
