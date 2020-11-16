<template>
  <b-container class="my-5 py-5">
    <b-row class="justify-content-md-center text-secondary">
      <b-col cols="12" md="auto">
        <b-media>
          <template v-slot:aside>
            <icon v-bind="iconProps" />
          </template>
          <h4>{{ title }}</h4>
          <p class="font-weight-light" v-if="text">{{ text }}</p>
        </b-media>
      </b-col>
    </b-row>
  </b-container>
</template>
<script>
import i18n from '@/utils/locale'

const props = {
  title: {
    type: String,
    default: i18n.t('Loading')
  },
  text: {
    type: String,
    default: i18n.t('Please wait a moment...')
  },
  icon: {
    type: String,
    default: 'circle-notch'
  },
  spin: {
    Boolean,
    default: undefined
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props) => {

  const {
    icon,
    spin
  } = toRefs(props)

  const iconProps = computed(() => ((spin.value !== undefined)
    ? { name: icon.value, scale: 2, spin: true }
    : { name: icon.value, scale: 2 }
  ))

  return {
    iconProps
  }
}

// @vue/component
export default {
  name: 'base-container-loading',
  inheritAttrs: false,
  props,
  setup
}
</script>
,
    default: true
