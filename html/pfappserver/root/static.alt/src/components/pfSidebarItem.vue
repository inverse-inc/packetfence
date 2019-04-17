<!--

<pf-sidebar-item :item="section" :filter="filter" indent>

-->
<template>
  <div>
    <b-nav-item
      exact-active-class="active"
      v-if="visible"
      v-bind="$attrs"
      :to="item.path"
      :key="item.name"
      >
      <div class="pf-sidebar-item" :class="{ 'ml-3': indent }">
        <div>
          <text-highlight :queries="[filter]">{{ $t(item.name) }}</text-highlight>
          <text-highlight class="figure-caption text-nowrap" v-if="item.caption" :queries="[filter]">{{ $t(item.caption) }}</text-highlight>
        </div>
        <icon class="mx-1" :name="item.icon" v-if="item.icon"></icon>
        <slot/>
      </div>
    </b-nav-item>
    <b-nav class="pf-sidenav my-2" v-if="showSavedSearch" vertical>
      <div class="pf-sidenav-group" v-t="'Saved Searches'"></div>
      <b-nav-item
        exact-active-class="active"
        v-for="search in savedSearches"
        :key="search.name"
        :to="toSavedSearch(search)"
        >
          <icon class="mx-1" name="trash-alt" role="button" @click.native.stop.prevent="deleteSavedSearch(search)"></icon>
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
        </b-nav-item>
    </template>
  </b-nav>
</template>

<script>
import TextHighlight from 'vue-text-highlight'

export default {
  name: 'pfSidebarItem',
  components: {
    TextHighlight
  },
  props: {
    item: {
      default: { name: 'undefined', path: '/', savedSearch: false }
    },
    filter: {
      default: ''
    },
    indent: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      visible: {
        type: Boolean,
        default: true
      }
    }
  },
  computed: {
    storeName () {
      const { item: { savedSearch: { storeName = null } = {} } = {} } = this
      return storeName
    },
    routeName () {
      const { item: { savedSearch: { routeName = null } = {} } = {} } = this
      return routeName
    },
    showSavedSearch () {
      return this.visible && this.item.savedSearch && this.savedSearches.length > 0
    },
    savedSearches () {
      return this.$store.state[this.storeName].savedSearches
    }
  },
  methods: {
    toSavedSearch (search) {
      return { name: this.routeName, query: { query: JSON.stringify(search.query) } }
    },
    deleteSavedSearch (search) {
      this.$store.dispatch(`${this.storeName}/deleteSavedSearch`, search)
    }
  },
  mounted () {
    if ('can' in this.item) {
      this.visible = this.$can.apply(null, this.item.can.split(' '))
    }
  }
}
</script>

<style lang="scss">
.pf-sidebar-item {
  .pf-sidenav {
    .pf-sidenav-group,
    pf-sidebar-item {
      padding-left: 0;
    }
  }
}
</style>
