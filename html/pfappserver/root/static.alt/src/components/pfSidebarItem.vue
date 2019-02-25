<!--

<pf-sidebar-item :item="section" :filter="filter" indent>

-->
<template>
  <b-nav-item
    v-if="visible" v-bind="$attrs" :to="item.path"
    :key="item.name" :exact="isQuery" :exact-active-class="isQuery ? 'secondary' : null" :active="isActive">
    <div class="pf-sidebar-item" :class="{ 'ml-3': indent }">
      <div>
        <text-highlight :queries="[filter]">{{ $t(item.name) }}</text-highlight>
        <text-highlight class="figure-caption text-nowrap" v-if="item.caption" :queries="[filter]">{{ $t(item.caption) }}</text-highlight>
      </div>
      <icon class="mx-1" :name="item.icon" v-if="item.icon"></icon>
      <slot/>
    </div>
  </b-nav-item>
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
      }
    }
  },
  computed: {
    isQuery () {
      return this.item.path instanceof Object && 'query' in this.item.path
    },
    isActive () {
      return ((this.item.path instanceof Object && 'name' in this.item.path && this.item.path.name === this.$route.name) ||
        (this.item.path.constructor === String && this.$route.path.indexOf(this.item.path.slice(0, -1)) === 0))
    }
  },
  mounted () {
    if ('can' in this.item) {
      this.visible = this.$can.apply(null, this.item.can.split(' '))
    }
  }
}
</script>
