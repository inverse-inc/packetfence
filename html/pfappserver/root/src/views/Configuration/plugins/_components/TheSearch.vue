<template>
  <!-- re-created when switching between plugin collections, the search store depends on it -->
  <the-search-collection :key="`${plugin}/${collection}`"
    :plugin="plugin" :collection="collection" />
</template>
<script>
import TheSearchCollection from './TheSearchCollection'
import { useItemProps as props } from '../_composables/useCollection'

// @vue/component
export default {
  name: 'the-search',
  components: {
    TheSearchCollection
  },
  props
}
</script>
