<template>
  <b-nav vertical class="bd-sidenav">
    <div class="bd-toc-link" v-t="'Saved Searches'"></div>
    <b-nav-item v-for="search in savedSearches" :key="search.name" :to="routeSavedSearch(search)" replace>
      {{search.name}}
      <icon class="float-right mt-1" name="trash-alt" @click.native.stop.prevent="deleteSavedSearch(search)"></icon>
    </b-nav-item>
  </b-nav>
</template>

<script>
export default {
  name: 'pfMixinSavedSearch',
  computed: {
    savedSearches () {
      return this.$store.state.$_nodes.savedSearches
    }
  },
  methods: {
    deleteSavedSearch (search) {
      this.$store.dispatch('$_nodes/deleteSavedSearch', search)
    },
    routeSavedSearch (search) {
      return { name: 'nodes', query: { query: JSON.stringify(search.query) } }
    }
  }
}
</script>
