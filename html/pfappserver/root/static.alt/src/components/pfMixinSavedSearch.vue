<template>
  <b-nav vertical class="pf-sidenav" v-if="savedSearches && savedSearches.length > 0">
    <div class="pf-sidenav-group" v-t="'Saved Searches'"></div>
    <pf-sidebar-item v-for="item in savedSearches" :key="item.name" :item="savedSearch(item)" :filter="filter" indent>
      <icon class="mx-1" name="trash-alt" role="button" @click.native.stop.prevent="deleteSavedSearch(item)"></icon>
    </pf-sidebar-item>
  </b-nav>
</template>

<script>
import pfSidebarItem from './pfSidebarItem'

export default {
  name: 'pfMixinSavedSearch',
  components: {
    pfSidebarItem
  },
  props: {
    storeName: { // from router
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
      return this.$store.state[this.storeName].savedSearches
    }
  },
  methods: {
    deleteSavedSearch (search) {
      this.$store.dispatch(`${this.storeName}/deleteSavedSearch`, search)
    },
    savedSearch (item) {
      return Object.assign(item, { path: { name: this.routeName, query: { query: JSON.stringify(item.query) } } } )
    }
  }
}
</script>
