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
                            <div class="bd-toc-link" v-t="'Users'"></div>
                            <b-nav-item to="/users/search" replace>{{ $t('Search') }}</b-nav-item>
                            <b-nav-item to="/users/create" replace>{{ $t('Create') }}</b-nav-item>
                            <div class="bd-toc-link" v-t="'Standard Searches'"></div>
                            <b-nav-item to="search/openviolations">Open Violations</b-nav-item>
                            <b-nav-item to="search/closedviolations">Closed Violations</b-nav-item>
                            <div class="bd-toc-link" v-t="'Saved Searches'"></div>
                        </b-nav>
                    </div>
                </b-collapse>            </b-col>
            <b-col cols="12" md="9" xl="10">
                <router-view></router-view>
            </b-col>
        </b-row>
</template>

<script>
import store from './_store'

export default {
  name: 'Users',
  props: {
  },
  data () {
    return {
    }
  },
  created () {
    // Register store module only once
    if (!this.$store.state.$_users) {
      this.$store.registerModule('$_users', store)
    }
  },
  mounted () {
  }
}
</script>

