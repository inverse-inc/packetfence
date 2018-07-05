<template>
  <b-nav vertical class="bd-sidenav" v-if="savedSearches && savedSearches.length > 0">
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
  props: {
    storeName: {
      type: String,
      default: null,
      required: true
    },
    routeName: {
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    savedSearches () {
      return this.$store.state['$_' + this.storeName].savedSearches
    }
  },
  methods: {
    deleteSavedSearch (search) {
      this.$store.dispatch(`$_${this.storeName}/deleteSavedSearch`, search)
    },
    routeSavedSearch (search) {
      return { name: this.routeName, query: { query: JSON.stringify(search.query) } }
    }
  }
}
</script>
