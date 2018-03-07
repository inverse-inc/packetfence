<template>
        <b-row>
            <b-col cols="12" md="3" xl="2" class="bd-sidebar">
                <div class="bd-search d-flex align-items-center">
                    <b-form-input type="text" placeholder="Search..."></b-form-input>
                    <b-btn class="bd-search-docs-toggle d-md-none p-0 ml-3" aria-controls="bd-docs-nav">=</b-btn>
                </div>
                <b-collapse is-nav class="bd-links" id="bd-docs-nav">
                    <div class="bd-toc-item active">
                        <b-nav vertical class="bd-sidenav">
                            <div class="bd-toc-link">{{ $t('Status') }}</div>
                            <b-nav-item to="/status/dashboard" replace>{{ $t('Dashboard') }}</b-nav-item>
                            <b-nav-item v-can:access="'services'" to="/status/services" replace>{{ $t('Services') }}</b-nav-item>
                            <b-nav-item v-can:access="'reports'" to="/status/reports" replace>{{ $t('Reports') }}</b-nav-item>
                        </b-nav>
                    </div>
                </b-collapse>
            </b-col>
            <b-col cols="12" md="9" xl="10">
                <router-view></router-view>
            </b-col>
        </b-row>
</template>

<script>
import store from './_store'

export default {
  name: 'Status',
  props: {
  },
  data () {
    return {
    }
  },
  computed: {
  },
  created () {
    // Register store module only once
    if (!this.$store.state.$_status) {
      this.$store.registerModule('$_status', store)
    }
  },
  mounted () {
  }
}
</script>
