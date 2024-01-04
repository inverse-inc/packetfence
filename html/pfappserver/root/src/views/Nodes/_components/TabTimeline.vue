<template>
  <b-tab title="Timeline">
    <template v-slot:title>
      {{ $i18n.t('Timeline') }}
    </template>
    <b-row>
      <b-col>
        <timeline
          ref="timelineRef"
          :items="visItems"
          :groups="visGroups"
          :options="visOptions"
        ></timeline>
      </b-col>
    </b-row>
  </b-tab>
</template>
<script>
import { DataSet, Timeline } from 'vue2vis'

const components = {
  Timeline
}

const props = {
  id: {
    type: String
  }
}

import { computed, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const { id } = toRefs(props)
  const { root: { $store } = {} } = context

  const timelineRef = ref(null)

  const visGroups = new DataSet()
  const visItems = new DataSet()
  const visOptions = ref({
    editable: false,
    margin: {
      item: 25
    },
    orientation: {
      axis: 'both',
      item: 'bottom'
    },
    selectable: false,
    stack: true,
    tooltip: {
      followMouse: true
    }
  })

  const setupVis = () => {
    const node = $store.state.$_nodes.nodes[id.value]
    if (node) {
      if (node.detect_date && node.detect_date !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-seen`,
          content: i18n.t('Seen')
        })
        addVisItem({
          id: 'detect',
          group: `${id.value}-seen`,
          start: new Date(node.detect_date),
          end: (node.last_seen && node.last_seen !== '0000-00-00 00:00:00' && node.last_seen !== node.detect_date) ? new Date(node.last_seen) : null,
          content: i18n.t('Detected')
        })
      } else if (node.last_seen && node.last_seen !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-seen`,
          content: i18n.t('Seen')
        })
        addVisItem({
          id: 'last_seen',
          group: `${id.value}-seen`,
          start: new Date(node.last_seen),
          content: i18n.t('Last Seen')
        })
      }
      if (node.regdate && node.regdate !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-registered`,
          content: i18n.t('Registered')
        })
        addVisItem({
          id: 'regdate',
          group: `${id.value}-registered`,
          start: new Date(node.regdate),
          end: (node.unregdate && node.unregdate !== '0000-00-00 00:00:00' && node.unregdate !== node.regdate) ? new Date(node.unregdate) : null,
          content: i18n.t('Registered')
        })
      }
      if (node.last_arp && node.last_arp !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-general`,
          content: i18n.t('General')
        })
        addVisItem({
          id: 'last_arp',
          group: `${id.value}-general`,
          start: new Date(node.last_arp),
          content: i18n.t('Last ARP')
        })
      }
      if (node.last_dhcp && node.last_dhcp !== '0000-00-00 00:00:00') {
        addVisGroup({
          id: `${id.value}-general`,
          content: i18n.t('General')
        })
        addVisItem({
          id: 'last_dhcp',
          group: `${id.value}-general`,
          start: new Date(node.last_dhcp),
          content: i18n.t('Last DHCP')
        })
      }
      try {
        node.ip4.history.forEach(function (ip4) {
          addVisGroup({
            id: `${id.value}-ipv4`,
            content: i18n.t('IPv4 Addresses')
          })
          addVisItem({
            id: `ipv4-${ip4.ip}`,
            group: `${id.value}-ipv4`,
            start: new Date(ip4.start_time),
            end: (ip4.end_time !== '0000-00-00 00:00:00' && ip4.end_time !== ip4.start_time) ? new Date(ip4.end_time) : null,
            content: ip4.ip
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.ip6.history.forEach(function (ip6) {
          addVisGroup({
            id: `${id.value}-ipv6`,
            content: i18n.t('IPv6 Addresses')
          })
          addVisItem({
            id: `ipv6-${ip6.ip}`,
            group: `${id.value}-ipv6`,
            start: new Date(ip6.start_time),
            end: (ip6.end_time !== '0000-00-00 00:00:00' && ip6.end_time !== ip6.start_time) ? new Date(ip6.end_time) : null,
            content: ip6.ip
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.locations.forEach(function (location) {
          addVisGroup({
            id: `${id.value}-location`,
            content: i18n.t('Locations')
          })
          addVisItem({
            id: `location-${location.start_time}`,
            group: `${id.value}-location`,
            start: new Date(location.start_time),
            end: (location.end_time && location.end_time !== '0000-00-00 00:00:00' && location.end_time !== location.start_time) ? new Date(location.end_time) : null,
            content: `${location.ssid}/${i18n.t('Role')}:${location.role}/VLAN:${location.vlan}`
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.security_events.forEach(function (securityEvent) {
          addVisGroup({
            id: `${id.value}-security_event`,
            content: i18n.t('Security Events')
          })
          addVisItem({
            id: `security_event-${securityEvent.security_event_id}`,
            group: `${id.value}-security_event`,
            start: new Date(securityEvent.start_date),
            end: (securityEvent.release_date !== '0000-00-00 00:00:00' && securityEvent.release_date !== securityEvent.start_date) ? new Date(securityEvent.release_date) : null,
            content: securityEventDescription(securityEvent.security_event_id)
          })
        })
      } catch (e) {
        // noop
      }
      try {
        node.dhcpoption82.forEach(function (dhcpoption82) {
          addVisGroup({
            id: `${id.value}-dhcpoption82`,
            content: i18n.t('DHCP Option 82')
          })
          addVisItem({
            id: `dhcpoption82-${dhcpoption82.created_at}`,
            group: `${id.value}-dhcpoption82`,
            start: new Date(dhcpoption82.created_at),
            content: ((dhcpoption82.switch_id) ? (`${dhcpoption82.switch_id}/`) : '') + ((dhcpoption82.port) ? `${i18n.t('Port')}:${dhcpoption82.port}/` : '') + `VLAN:${dhcpoption82.vlan}`
          })
        })
      } catch (e) {
        // noop
      }
    }
  }
  const addVisGroup = (group) => {
    if (!visGroups.getIds().includes(group.id)) {
      visGroups.add([group])
    }
  }
  const addVisItem = (item) => {
    if (!visItems.getIds().includes(item.id)) {
      if (!item.title) {
        item.title = item.content
      }
      visItems.add([item])
    }
  }
  let timeoutVis = null
  const redrawVis = () => {
    // buffer async calls to redraw
    if (timeoutVis) clearTimeout(timeoutVis)
    timeoutVis = setTimeout(() => {
      setupVis()
      if (timelineRef.value)
        timelineRef.value.redraw()
    }, 100)
  }

  const _node = computed(() => $store.state.$_nodes.nodes[id.value])
  watch(_node, () => redrawVis(), { deep: true })

  const _securityEvents = computed(() => $store.getters['config/sortedSecurityEvents'])
  watch(_securityEvents, (a, b) => {
    if (a !== b) redrawVis()
  })

  onMounted(() => {
    setupVis()
  })

  onBeforeUnmount(() => {
    if (timeoutVis) {
      clearTimeout(timeoutVis)
    }
  })

  const securityEventDescription = (id) => {
    const { state: { config: { securityEvents: { [id]: { desc = i18n.t('Unknown') } = {} } = {} } = {} } = {} } = $store
    return desc
  }

  return {
    timelineRef,
    visGroups,
    visItems,
    visOptions,
    securityEventDescription
  }
}
// @vue/component
export default {
  name: 'tab-timeline',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style lang="scss">
$vis-item-bg: theme-color("primary");
$vis-item-color: $white;

.vis-timeline {
  border: none;
}

.vis-labelset .vis-label,
.vis-foreground .vis-group {
  border-bottom-color: $table-border-color;
}

.vis-text,
.vis-label,
.vis-item {
  font-family: $font-family-sans-serif;
  font-size: $font-size-sm;
  font-weight: $font-weight-normal;
  line-height: $line-height-sm;
  white-space: normal;
}
.vis-text.vis-major {
  font-size: $font-size-base;
}
.vis-label,
.vis-labelset .vis-label {
  color: $gray-600;
  font-weight: 500;
  text-align: right;
}
.vis-item {
  padding: 2px 3px 1px;
  background-color: $gray-200;
  color: $vis-item-bg;
  text-align: center;
}
/* bottom arrow on box */
.vis-item.vis-box:after {
  content:'';
  position: absolute;
  top: 100%;
  left: 50%;
  width: 0;
  height: 0;
  border-top: solid 10px $vis-item-bg;
  border-right: solid 10px transparent;
  border-left: solid 10px transparent;
  margin-left: -10px;
}
/* left and right border on range */
.vis-item.vis-range {
  border-right: 5px solid $vis-item-bg;
  border-left: 5px solid $vis-item-bg;
  border-radius: 50px;
}
/* alternating column backgrounds */
.vis-time-axis .vis-grid.vis-odd {
  background: $gray-100;
}
/* gray background in weekends, white text color */
.vis-time-axis .vis-grid.vis-saturday,
.vis-time-axis .vis-grid.vis-sunday {
  background: $gray-700;
}
.vis-time-axis .vis-text.vis-saturday,
.vis-time-axis .vis-text.vis-sunday {
  color: $white;
}
/* match bootstrap tooltip style */
div.vis-tooltip {
  z-index: $zindex-tooltip;
  padding: $tooltip-padding-y $tooltip-padding-x;

  background-color: $tooltip-bg;
  color: $tooltip-color;

  font-family: $font-family-sans-serif;
  font-size: $tooltip-font-size;

  border-radius: $tooltip-border-radius;
  box-shadow: none;

  opacity: $tooltip-opacity;
}
</style>