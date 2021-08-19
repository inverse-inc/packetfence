<!--

<section-sidebar v-model="sections">

-->
<template>
    <b-col cols="12" md="3" xl="2" class="section-sidebar d-print-none">
      <!-- filter -->
      <div class="section-sidebar-filter d-flex align-items-center">
        <b-input-group>
          <b-input-group-prepend>
            <icon class="h-auto" name="search" scale=".75" />
          </b-input-group-prepend>
          <b-form-input ref="refFilter" v-model="filter" v-focus
            class="border-0" type="text" :placeholder="$t('Filter')" v-b-tooltip.hover.bottom.d300 title="Alt + Shift + F" />
          <b-input-group-append v-if="filter">
            <b-btn @click="filter = ''"><icon name="times-circle" /></b-btn>
          </b-input-group-append>
        </b-input-group>
        <b-btn class="section-sidebar-filter-toggle d-md-none p-0 ml-3" variant="link" v-b-toggle.section-sidebar-links>
          <icon name="bars" />
        </b-btn>
      </div>
      <!-- navigation -->
      <b-collapse id="section-sidebar-links" class="section-sidebar-links" visible>
        <b-nav class="section-sidenav" vertical>
          <template v-for="section in filteredSections">
            <!-- collapsable (root level) -->
            <template v-if="section.collapsable">
              <template v-if="can(section)">
                <component class="section-sidenav-group" :is="section.path ? 'router-link': 'div'"
                  :key="`${section.name}_btn`" :to="section.path"
                  v-b-toggle="$sanitizedClass(section.name)">
                  <icon class="position-absolute mx-3" :name="section.icon" scale="1.25" v-if="section.icon" />
                  <text-highlight class="ml-5" :queries="[filter]">{{ section.name }}</text-highlight>
                  <icon v-if="section.loading"
                    class="mx-1 mt-1" name="circle-notch" spin />
                  <icon v-else
                    class="mx-1 mt-1" name="chevron-down" />
                </component>
                <b-collapse :id="$sanitizedClass(section.name)" :key="section.name" :accordion="accordion(section.name)" :visible="isActive(section.name)">
                  <template v-for="item in section.items">
                    <!-- single link -->
                    <section-sidebar-item v-if="item.path" :key="item.name" :item="item" :filter="filter" />
                    <!-- collapsable (2nd level) -->
                    <template v-else-if="item.collapsable">
                      <div class="section-sidenav-group" :key="`${item.name}_btn`" v-b-toggle="$sanitizedClass(`${section.name}_${item.name}`)">
                        <text-highlight class="ml-5" :queries="[filter]">{{ item.name }}</text-highlight>
                        <icon class="mx-1" name="angle-double-down" />
                      </div>
                      <b-collapse :id="$sanitizedClass(`${section.name}_${item.name}`)" :key="item.name" :visible="isActive(item.name)">
                        <section-sidebar-item v-for="subitem in item.items" :key="subitem.name" :item="subitem" :filter="filter" indent />
                      </b-collapse>
                    </template>
                    <!-- non-collapsable section with items (2nd level) -->
                    <b-nav class="section-sidenav my-2" v-else :key="item.name" vertical>
                        <div class="section-sidenav-group">
                          <text-highlight :queries="[filter]">{{ $t(item.name) }}</text-highlight>
                        </div>
                        <section-sidebar-item v-for="subitem in item.items" :key="subitem.name" :item="subitem" :filter="filter" indent />
                    </b-nav>
                  </template>
                </b-collapse>
              </template>
            </template>
            <!-- non-collapsable section with items -->
            <b-nav v-else-if="section.items" class="section-sidenav my-2" :key="section.name" vertical>
              <template v-if="can(section)">
                <div class="section-sidenav-group">
                  <text-highlight :queries="[filter]">{{ section.name }}</text-highlight>
                </div>
                <section-sidebar-item v-for="item in section.items" :key="item.name" :item="item" :filter="filter" indent />
              </template>
            </b-nav>
            <!-- single link -->
            <section-sidebar-item v-else :key="section.name" :item="section" :filter="filter" />
          </template>
          <slot />
        </b-nav>
      </b-collapse>
    </b-col>
</template>

<script>
import SectionSidebarItem from './SectionSidebarItem'
import TextHighlight from 'vue-text-highlight'
const components = {
  SectionSidebarItem,
  TextHighlight
}

const props = {
  value: {
    type: Array,
    default: () => ([])
  }
}

import { focus } from '@/directives'
const directives = {
  focus
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import useEvent from '@/composables/useEvent'
import acl from '@/utils/acl'
import i18n from '@/utils/locale'
const setup = (props, context) => {

  const {
    value
  } = toRefs(props)

  const { refs, root: { $router } = {} } = context

  // template ref
  const refFilter = ref(null)

  const filter = ref('')
  const expandedSections = ref([])
  const filteredMode = computed(() => filter.value.length > 0)
  const filteredSections = computed(() => {
    if (!filteredMode.value)
      return value.value
    const _filterSection = section => {
      const re = new RegExp(filter.value, 'i')
      const keys = ['name', 'caption']
      if (keys.find((key) => section[key] && (re.test(section[key]) || re.test(i18n.t(section[key]))))) {
        return section
      }
      if ('items' in section) {
        let filteredItems = section.items.map(item => _filterSection(item))
          .filter(section => section !== undefined)
        if (filteredItems.length > 0)
          return Object.assign({}, section, { items: filteredItems })
      }
      return undefined
    }
    return value.value
      .map(section => _filterSection(section))
      .filter(section => section !== undefined)
  })

  // Set accordion mode when *not* filtering the sidebar items
  const accordion = name => ((filteredMode.value) ? name : 'root')

  // Return true if the current route matches the items.
  // Ignore current route and always return true when filtering the sidebar items so all sections are expanded.
  const isActive = name => filteredMode.value || expandedSections.value.includes(name)

  const findActiveSections = (items, sections) => {
    if (items.constructor === Array) { // ignore Promises
      const { currentRoute: { name: currentName, path: currentPath, query: { query: currentQuery } = {} } = {} } = $router
      items.forEach(({ name: sectionName, path, items }) => {
        if (items) {
          findActiveSections(items, [sectionName, ...sections])
        }
        else if (path && path instanceof Object) {
          const { name: pathName, query: { query: pathQuery } } = path
          if (pathName === currentName && pathQuery === currentQuery) {
            expandedSections.value = sections
          }
        }
        else if (path === currentPath) {
          expandedSections.value = sections
        }
      })
    }
  }

  const focusFilter = () => {
    const { $el } = refs.refFilter
    if ($el) {
      $el.focus()
      nextTick(() => $el.select())
    }
  }

  const can = item => {
    if ('can' in item) {
      return acl.$can.apply(null, item.can.split(' '))
    }
    return true
  }

  watch(value, () => findActiveSections(value.value, []))

  useEvent('keydown', e => {
    const { altKey = false, shiftKey = false, keyCode = false } = e
    if (altKey && shiftKey && keyCode === 70) // ALT+SHIFT+F
      focusFilter()
  })

  return {
    // template ref
    refFilter,

    filter,
    expandedSections,
    filteredMode,
    filteredSections,
    accordion,
    isActive,
    findActiveSections,
    focusFilter,
    can
  }
}

// @vue/component
export default {
  name: 'section-sidebar',
  components,
  directives,
  props,
  setup
}
</script>
