<!--

<pf-sidebar v-model="sections">

-->
<template>
    <b-col cols="12" md="3" xl="2" class="pf-sidebar">
      <!-- filter -->
      <div class="pf-sidebar-filter d-flex align-items-center">
        <b-input-group :can="true">
          <b-form-input v-model="filter" type="text" :placeholder="$t('Filter')"></b-form-input>
          <b-input-group-append v-if="filter">
            <b-btn @click="filter = ''"><icon name="times-circle"></icon></b-btn>
          </b-input-group-append>
        </b-input-group>
        <b-btn class="pf-sidebar-filter-toggle d-md-none p-0 ml-3" variant="link" v-b-toggle.pf-sidebar-links>
          <icon name="bars"></icon>
        </b-btn>
      </div>
      <!-- navigation -->
      <b-collapse id="pf-sidebar-links" class="pf-sidebar-links" visible is-nav>
        <b-nav class="pf-sidenav" vertical>
          <template v-for="section in filteredSections">
            <!-- collapsable (root level) -->
            <template v-if="section.collapsable">
              <div class="pf-sidenav-group" :key="section.name" v-b-toggle="section.name">
                <icon class="position-absolute mx-3" :name="section.icon" scale="1.25" v-if="section.icon"></icon>
                <text-highlight class="ml-5" :queries="[filter]">{{ $t(section.name) }}</text-highlight>
                <icon class="mx-1 mt-1" name="chevron-down"></icon>
              </div>
              <b-collapse :id="section.name" :ref="section.name" :key="section.name" visible is-nav>
                <template v-for="item in section.items">
                  <!-- single link -->
                  <pf-sidebar-item v-if="item.path" :key="item.name" :item="item" :filter="filter"></pf-sidebar-item>
                  <!-- collapsable (2nd level) -->
                  <template v-else-if="item.collapsable">
                    <div class="pf-sidenav-group" :key="item.name" v-b-toggle="`${section.name}_${item.name}`">
                      <text-highlight class="ml-5" :queries="[filter]">{{ $t(item.name) }}</text-highlight>
                      <icon class="mx-1 mt-1" name="chevron-down"></icon>
                    </div>
                    <b-collapse :id="`${section.name}_${item.name}`" :key="item.name" visible is-nav>
                      <pf-sidebar-item v-for="subitem in item.items" :key="subitem.name" :item="subitem" :filter="filter" indent></pf-sidebar-item>
                    </b-collapse>
                  </template>
                  <!-- non-collapsable section with items (2nd level) -->
                  <b-nav class="pf-sidenav n0pf-sidenav-group" v-else :key="item.name" vertical>
                      <div class="pf-sidenav-group">
                        <text-highlight :queries="[filter]">{{ $t(item.name) }}</text-highlight>
                      </div>
                      <pf-sidebar-item v-for="subitem in item.items" :key="subitem.name" :item="subitem" :filter="filter" indent></pf-sidebar-item>
                  </b-nav>
                </template>
              </b-collapse>
            </template>
            <!-- non-collapsable section with items -->
            <b-nav v-else-if="section.items" class="pf-sidenav n0pf-sidenav-group" :key="section.name" vertical>
              <div class="pf-sidenav-group">
                <text-highlight :queries="[filter]">{{ $t(section.name) }}</text-highlight>
              </div>
              <pf-sidebar-item v-for="item in section.items" :key="item.name" :item="item" :filter="filter" indent></pf-sidebar-item>
            </b-nav>
            <!-- single link -->
            <pf-sidebar-item v-else :key="section.name" :item="section" :filter="filter"></pf-sidebar-item>
          </template>
          <slot />
        </b-nav>
      </b-collapse>
    </b-col>
</template>

<script>
import pfSidebarItem from './pfSidebarItem'
import TextHighlight from 'vue-text-highlight'

export default {
  name: 'pf-sidebar',
  components: {
    pfSidebarItem,
    TextHighlight
  },
  props: {
    value: {
      default: []
    }
  },
  data () {
    return {
      filter: ''
    }
  },
  computed: {
    filteredSections () {
      if (!this.filter.length) {
        return this.value
      }
      const _filterSection = (section) => {
        const re = new RegExp(this.filter, 'i')
        const keys = ['name', 'caption']
        if (keys.find((key) => {
          return section[key] && (re.test(section[key]) || re.test(this.$i18n.t(section[key])))
        })) {
          return section
        }
        if ('items' in section) {
          let filteredItems = section.items.map(item => {
            return _filterSection(item)
          }).filter(section => section !== undefined)
          if (filteredItems.length > 0) {
            return Object.assign({}, section, { items: filteredItems })
          }
        }
        return undefined
      }
      let filteredSections = this.value.map(section => {
        return _filterSection(section)
      })
      return filteredSections.filter(section => section !== undefined)
    }
  }
}
</script>
