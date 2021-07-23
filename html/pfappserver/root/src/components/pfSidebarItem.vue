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
          <text-highlight :queries="[filter]">{{ item.name }}</text-highlight>
          <text-highlight class="figure-caption text-nowrap" v-if="item.caption" :queries="[filter]">{{ item.caption }}</text-highlight>
        </div>
        <icon class="mx-1" :name="item.icon" v-if="item.icon" />
        <slot/>
      </div>
    </b-nav-item>
    <b-nav class="pf-sidenav mb-2" v-if="showSavedSearches && savedBasicSearches.length > 0" vertical>
      <div class="pf-sidenav-group small py-0" v-t="'Basic Searches'" />
      <b-nav-item
        exact-active-class="active"
        v-for="search in savedBasicSearches"
        :key="search.name"
        class="saved-search"
        @click="goToBasicSearch(search)"
      >
        <div class="pf-sidebar-item pl-3">
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
          <icon class="mx-1" name="trash-alt" @click.stop.prevent="deleteBasicSavedSearch(search)" />
        </div>
      </b-nav-item>
    </b-nav>
    <b-nav class="pf-sidenav mb-2" v-if="showSavedSearches && savedAdvancedSearches.length > 0" vertical>
      <div class="pf-sidenav-group small py-0" v-t="'Advanced Searches'" />
      <b-nav-item
        exact-active-class="active"
        v-for="search in savedAdvancedSearches"
        :key="search.name"
        class="saved-search"
        @click="goToAdvancedSearch(search)"
      >
        <div class="pf-sidebar-item pl-3">
          <text-highlight :queries="[filter]">{{ search.name }}</text-highlight>
          <icon class="mx-1" name="trash-alt" @click.stop.prevent="deleteAdvancedSavedSearch(search)" />
        </div>
      </b-nav-item>
    </b-nav>
  </div>
</template>

<script>
import TextHighlight from 'vue-text-highlight'

export default {
  name: 'pf-sidebar-item',
  components: {
    TextHighlight
  },
  props: {
    item: {
      default: { name: 'undefined', path: '/' }
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
      },
    }
  },
  computed: {
    showSavedSearches () {
      const { item: { saveSearchNamespace } = {} } = this
      return this.visible && saveSearchNamespace
    },
    saveSearchNamespace () {
      const { item: { saveSearchNamespace } = {} } = this
      return saveSearchNamespace
    },
    savedAdvancedSearches () {
      const { values = {} } = this.$store.state.preferences.cache[`${this.saveSearchNamespace}::advancedSearch`] || {}
      return Object.keys(values).map(name => ({ name, ...values[name] }))
    },
    savedBasicSearches () {
      const { values = {} } = this.$store.state.preferences.cache[`${this.saveSearchNamespace}::basicSearch`] || {}
      return Object.keys(values).map(name => ({ name, ...values[name] }))
    }
  },
  methods: {
    deleteAdvancedSavedSearch (search) {
      const id = `${this.saveSearchNamespace}::advancedSearch`
      const { values = {} } = this.$store.state.preferences.cache[id] || {}
      delete values[search.name]
      this.$store.dispatch('preferences/set', {
        id,
        value: { values }
      })
    },
    deleteBasicSavedSearch (search) {
      const id = `${this.saveSearchNamespace}::basicSearch`
      const { values = {} } = this.$store.state.preferences.cache[id] || {}
      delete values[search.name]
      this.$store.dispatch('preferences/set', {
        id,
        value: { values }
      })
    },
    goToAdvancedSearch (search) {
      const { name, query, ...rest } = search
      const { path } = this.item
      this.$store.dispatch('preferences/set', {
        id: `${this.saveSearchNamespace}::defaultSearch`,
        value: { ...rest, conditionAdvanced: query }
      }).then(() => {
        if (path === this.$router.currentRoute.path)
          this.$router.go() // hard reset
        else
          this.$router.push({ path })
      })
    },
    goToBasicSearch (search) {
      const { name, query, ...rest } = search
      const { path } = this.item
      this.$store.dispatch('preferences/set', {
        id: `${this.saveSearchNamespace}::defaultSearch`,
        value: { ...rest, conditionBasic: query }
      }).then(() => {
        if (path === this.$router.currentRoute.path)
          this.$router.go() // hard reset
        else
          this.$router.push({ path })
      })
    }
  },
  mounted () {
    if ('can' in this.item) {
      this.visible = this.$can.apply(null, this.item.can.split(' '))
    }
    if (this.saveSearchNamespace) {
      this.$store.dispatch('preferences/get', `${this.saveSearchNamespace}::advancedSearch`)
        .then(value => {
          if (Object.keys(value).length === 0) { // declare reactive placeholder
            this.$store.dispatch('preferences/set', { id: `${this.saveSearchNamespace}::advancedSearch` })
          }
        })
      this.$store.dispatch('preferences/get', `${this.saveSearchNamespace}::basicSearch`)
        .then(value => {
          if (Object.keys(value).length === 0) { // declare reactive placeholder
            this.$store.dispatch('preferences/set', { id: `${this.saveSearchNamespace}::basicSearch` })
          }
        })
    }
  }
}
</script>

<style lang="scss">
@import '../styles/variables';

.saved-search {
  svg.fa-icon {
    visibility: hidden;
  }
}
.saved-search .pf-sidebar-item:hover {
  svg.fa-icon {
    visibility: visible !important;
  }
}
</style>
