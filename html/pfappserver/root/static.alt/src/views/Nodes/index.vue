<template>
        <b-row>
            <b-col cols="12" md="3" xl="2" class="bd-sidebar">
                <div class="bd-search d-flex align-items-center">
                    <b-form-input type="text" :placeholder="$t('Filter')"></b-form-input>
                    <b-btn class="bd-search-docs-toggle d-md-none p-0 ml-3" aria-controls="bd-docs-nav">=</b-btn>
                </div>
                <b-collapse is-nav class="bd-links" id="bd-docs-nav">
                    <div class="bd-toc-item active">
                        <b-nav vertical class="bd-sidenav">
                            <div class="bd-toc-link" v-t="'Nodes'"></div>
                            <b-nav-item to="/nodes/search" replace>{{ $t('Search') }}</b-nav-item>
                            <b-nav-item to="/nodes/create" replace>{{ $t('Create') }}</b-nav-item>
                            <div class="bd-toc-link" v-t="'Standard Searches'"></div>
                            <b-nav-item to="search/openviolations">Open Violations</b-nav-item>
                            <b-nav-item to="search/closedviolations">Closed Violations</b-nav-item>
                            <div class="bd-toc-link" v-t="'Saved Searches'"></div>
                            <b-nav-item v-for="search in savedSearches" :key="search.name" :to="routeSavedSearch(search)" replace>
                              {{search.name}}
                              <icon class="float-right mt-1" name="trash-alt" @click.native.stop.prevent="deleteSavedSearch(search)"></icon>
                            </b-nav-item>
                        </b-nav>
                    </div>
                </b-collapse>
            </b-col>
            <b-col cols="12" md="9" xl="10" class="mt-3 mb-3">
                <transition name="slide-bottom">
                    <router-view></router-view>
                </transition>
            </b-col>
        </b-row>
</template>

<script>
export default {
  name: 'Nodes',
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
