<template>
  <base-search :use-search="useSearch">
    <slot/>
  </base-search>
</template>
<script>
import {
  BaseSearch
} from '@/components/new/'
const components = {
  BaseSearch
}

const props = {
  meta: {
    type: Object
  }
}

import { toRefs } from '@vue/composition-api'
import { useSearchFactory } from '../_search'

const setup = props => {

  const {
    meta
  } = toRefs(props)

  const useSearch = useSearchFactory(meta)

  return {
    useSearch
  }
}
// @vue/component
export default {
  name: 'the-search',
  components,
  props,
  setup
}
</script>