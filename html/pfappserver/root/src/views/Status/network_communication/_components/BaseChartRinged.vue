<template>
  <div ref="svgContainer" :class="[ 'svgContainer', { [`highlight highlight-${highlight}`]: highlight } ]">

    <!-- SVG drag layer (for event capture only) -->
    <svg ref="svgDrag" class="svgDrag"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      width="100%"
      :height="dimensions.height+'px'"
      :viewBox="viewBoxString"
      v-show="lastX && lastY"
      @mousemove="mouseMoveSvg($event)"
      @mouseout="mouseUpSvg($event)"
      @mouseup="mouseUpSvg($event)"
    ></svg>

    <!-- SVG draw layer -->
    <svg ref="svgDraw" :class="[ 'svgDraw', `zoom-${zoom}` ]"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      width="100%"
      :height="dimensions.height+'px'"
      :viewBox="viewBoxString"
      @mousedown.prevent="mouseDownSvg($event)"
      @mousewheel="mouseWheelSvg($event)"
    >
      <defs v-once>
        <!-- symbol definitions -->
      </defs>

      <!-- background to capture node mouseout event -->
<!--
      <rect fill-opacity="0" :x="viewBox.minX" :y="viewBox.minY" :width="viewBox.width" :height="viewBox.height"
        @mouseover="mouseOutNode($event)"
      />
-->
      <!-- outer hosts ring -->
      <circle v-bind="svgOuterHostsRingProps" />

      <!-- inner hosts ring -->
      <circle v-bind="svgInnerHostsRingProps" />

      <!-- devices ring -->
      <circle v-bind="svgDevicesRingProps" />

      <!-- flows -->
      <path v-for="props in flows" :key="props.key" v-bind="props" />

      <!-- outer hosts -->
      <circle v-for="props in svgOuterHosts" :key="props.key" v-bind="props" />

      <!-- inner hosts -->
      <circle v-for="props in svgInnerHosts" :key="props.key" v-bind="props" />

      <!-- devices -->
      <circle v-for="props in svgDevices" :key="props.key" v-bind="props" />

      <!-- mini map -->
      <rect v-if="showMiniMap" class="innerMiniMap" v-bind="innerMiniMapProps" />
      <rect v-if="showMiniMap" class="outerMiniMap" v-bind="outerMiniMapProps"
        @mousedown.stop="mouseDownMiniMap($event)"
        @mousemove.capture="mouseMoveMiniMap($event)"
      />
    </svg>

    <!-- loading -->
    <div class="loadingContainer" v-show="isLoading">
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media no-body>
            <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
            <div class="mx-2">
              <h4 v-t="'Loading Network Data'"></h4>
              <p class="font-weight-light" v-t="'Please wait...'"></p>
            </div>
          </b-media>
        </b-col>
      </b-row>
    </div>

<pre>{{ {assocInnerHostsCount, assocOuterHostsCount,
innerHostsRingCircumference,
outerHostsRingCircumference,
totalCount,
innerHosts,
outerHosts,
svgInnerHosts,
svgOuterHosts,
items,
} }}</pre>

  </div>
</template>

<script>
const components = {}

require('typeface-b612-mono') // custom pixel font

const defaults = { // default options
  layout: 'radial',
  palette: 'status',
  legendPosition: 'bottom-right',
  miniMapHeight: undefined,
  miniMapWidth: undefined,
  miniMapPosition: 'bottom-left',
  minZoom: 0,
  maxZoom: 4,
  mouseWheelZoom: true,
  padding: 25
}

const props = {
  dimensions: { // svg dimensions
    type: Object,
    required: true
  },
  options: {
    type: Object
  },
  isLoading: {
    type: Boolean
  },
  items: {
    type: Array
  },
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useViewBox, useMiniMap } from '@/composables/useSvg'

const setup = (props) => {

  const {
    options,
    dimensions,
    isLoading,
    items
  } = toRefs(props)
  const config = computed(() => ({ ...defaults, ...options.value }))

  const {
    zoom,
    scale,
    centerX,
    centerY,
    lastX,
    lastY,
    viewBox,
    viewBoxString,
    setCenter,
    mouseDownSvg,
    mouseMoveSvg,
    mouseUpSvg,
    mouseWheelSvg
  } = useViewBox(config, dimensions)

  const {
    miniMapLatch,
    showMiniMap,
    innerMiniMapProps,
    outerMiniMapProps,
    mouseDownMiniMap,
    mouseMoveMiniMap
  } = useMiniMap(props, config, viewBox, scale, setCenter)

  const highlight = ref(false)

  const cx = computed(() => dimensions.value.width / 2)
  const cy = computed(() => dimensions.value.height / 2)

  const totalCount = computed(() => {
    return items.value.reduce((total, item) => {
      const { count } = item
      return total + count
    }, 0)
  })

  const devicesRingScale = .3 // 30% height
  const devicesRingCircumference = computed(() => (Math.PI * dimensions.value.height * innerHostsRingScale))
  const devicesRingRadius = computed(() => (dimensions.value.height / 2) * devicesRingScale)
  const svgDevicesRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: devicesRingRadius.value,
    fill: 'rgb(255, 255, 255, 1)',
    stroke: 'rgb(0, 0, 0, 0.2)',
    'stroke-width': 1,
  }))
  const assocDevicesCount = computed(() => {
    if (items.value.length === 0) {
      return {}
    }
    return items.value.reduce((assoc, item) => {
      const { count, mac } = item
      assoc[mac] = (assoc[mac] || 0) + count
      return assoc
    }, {})
  })
  const devices = computed(() => {
    const keys = Object.keys(assocDevicesCount.value)
    const maxSize = Math.min(
      devicesRingCircumference.value / 32,
      devicesRingCircumference.value / keys.length
    )
    return keys.reduce((nodes, node, n) => {
      const angle = n * 360 / keys.length + 90
      const x = cx.value + (devicesRingRadius.value * Math.cos(angle * Math.PI / 180))
      const y = cy.value + (devicesRingRadius.value * Math.sin(angle * Math.PI / 180))
      const size = scaleCount(assocDevicesCount.value[node], totalCount.value, 12, maxSize)
      return { ...nodes, [node]: { node, size, angle, x ,y } }
    }, {})
  })
  const svgDevices = computed(() => {
    return Object.values(devices.value).map(node => {
      return {
        key: node.node,
        r: node.size,
        cx: node.x,
        cy: node.y,
        fill: 'rgb(192, 192, 192, 1)',
        stroke: 'rgb(0, 0, 0, 0.2)',
        'stroke-width': 1,
      }
    })
  })

  const innerHostsRingScale = .6 // 60% height
  const innerHostsRingCircumference = computed(() => (Math.PI * dimensions.value.height * innerHostsRingScale))
  const innerHostsRingRadius = computed(() => (dimensions.value.height / 2) * innerHostsRingScale)
  const svgInnerHostsRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: innerHostsRingRadius.value,
    fill: 'rgb(255, 255, 255, 1)',
    stroke: 'rgb(0, 0, 0, 0.2)',
    'stroke-width': 1,
  }))
  const assocInnerHostsCount = computed(() => {
    if (items.value.length === 0) {
      return {}
    }
    return items.value.reduce((assoc, item) => {
      const { count, host, internalHost } = item
      if (internalHost) {
        assoc[host] = (assoc[host] || 0) + count
      }
      return assoc
    }, {})
  })
  const innerHosts = computed(() => {
    const keys = Object.keys(assocInnerHostsCount.value)
    const maxSize = Math.min(
      innerHostsRingCircumference.value / 32,
      innerHostsRingCircumference.value / keys.length
    )
    return keys.reduce((nodes, node, n) => {
      const angle = n * 360 / keys.length + 45
      const x = cx.value + (innerHostsRingRadius.value * Math.cos(angle * Math.PI / 180))
      const y = cy.value + (innerHostsRingRadius.value * Math.sin(angle * Math.PI / 180))
      const size = scaleCount(assocInnerHostsCount.value[node], totalCount.value, 12, maxSize)
      return { ...nodes, [node]: { node, size, angle, x ,y } }
    }, {})
  })
  const svgInnerHosts = computed(() => {
    return Object.values(innerHosts.value).map(node => {
      return {
        key: node.node,
        r: node.size,
        cx: node.x,
        cy: node.y,
        fill: 'rgb(192, 192, 192, 1)',
        stroke: 'rgb(0, 0, 0, 0.2)',
        'stroke-width': 1,
      }
    })
  })

  const outerHostsRingScale = .9 // 90% height
  const outerHostsRingCircumference = computed(() => (Math.PI * dimensions.value.height * outerHostsRingScale))
  const outerHostsRingRadius = computed(() => (dimensions.value.height / 2) * outerHostsRingScale)
  const svgOuterHostsRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: outerHostsRingRadius.value,
    //fill: 'rgb(0, 0, 0, 0.05)',
    fill: 'rgb(255, 255, 255, 1)',
    stroke: 'rgb(0, 0, 0, 0.2)',
    'stroke-width': 1,
  }))
  const assocOuterHostsCount = computed(() => {
    if (items.value.length === 0) {
      return {}
    }
    return items.value.reduce((assoc, item) => {
      const { count, host, internalHost } = item
      if (!internalHost) {
        assoc[host] = (assoc[host] || 0) + count
      }
      return assoc
    }, {})
  })
  const outerHosts = computed(() => {
    const keys = Object.keys(assocOuterHostsCount.value)
    const maxSize = Math.min(
      outerHostsRingCircumference.value / 64,
      outerHostsRingCircumference.value / keys.length
    )
    return keys.reduce((nodes, node, n) => {
      const angle = n * 360 / keys.length - 90
      const x = cx.value + (outerHostsRingRadius.value * Math.cos(angle * Math.PI / 180))
      const y = cy.value + (outerHostsRingRadius.value * Math.sin(angle * Math.PI / 180))
      const size = scaleCount(assocOuterHostsCount.value[node], totalCount.value, 12, maxSize)
      return { ...nodes, [node]: { node, size, angle, x ,y } }
    }, {})
  })
  const svgOuterHosts = computed(() => {
    return Object.values(outerHosts.value).map(node => {
      return {
        key: node.node,
        r: node.size,
        cx: node.x,
        cy: node.y,
        fill: 'rgb(192, 192, 192, 1)',
        stroke: 'rgb(0, 0, 0, 0.2)',
        'stroke-width': 1,
      }
    })
  })

  const scaleCount = (count, total, min = 1, max = 100) => {
    const p = count / total // 0 to 1
    const l = Math.log10(p * 9 + 1) // 1 to 10 => 0 to 1
    return l * (max - min) + min
  }

  const strokeProto = (proto, opacity = 1) => {
    switch (proto) {
      case 'TCP':
        return `rgb(0, 0, 255, ${opacity})`
        // break
      case 'UDP':
        return `rgb(255, 0, 0, ${opacity})`
        // break
      default:
        return `rgb(0, 0, 0, ${opacity})`
    }
  }

  const flows = computed(() => {
    const dx1 = cx.value
    const dy1 = cy.value
    const dx2 = cx.value
    const dy2 = cy.value
    return items.value
      .sort((a, b) => b.count - a.count)
      .map(item => {
        const { mac, host, count, proto } = item
        if (mac in devices.value) {
          const { x: sx, y: sy, size: iSize } = devices.value[mac]
          if (host in outerHosts.value) {
            const { x: dx, y: dy, size: oSize } = outerHosts.value[host]
            const d = `M ${sx},${sy} C ${dx1},${dy1} ${dx2},${dy2} ${dx},${dy}`
            const maxSize = Math.min(iSize, oSize)
            const strokeOpacity = scaleCount(count, totalCount.value, 0.25, 1)
            const strokeWidth = scaleCount(count, totalCount.value, 1, maxSize)
            const stroke = strokeProto(proto, strokeOpacity)
            return { d, fill: 'transparent', stroke, 'stroke-width': strokeWidth }
          }
          else if (host in innerHosts.value) {
            const { x: dx, y: dy, size: oSize } = innerHosts.value[host]
            const d = `M ${sx},${sy} C ${dx1},${dy1} ${dx2},${dy2} ${dx},${dy}`
            const maxSize = Math.min(iSize, oSize)
            const strokeOpacity = scaleCount(count, totalCount.value, 0.25, 1)
            const strokeWidth = scaleCount(count, totalCount.value, 1, maxSize)
            const stroke = strokeProto(proto, strokeOpacity)
            return { d, fill: 'transparent', stroke, 'stroke-width': strokeWidth }
          }
        }
        return null
      })
      .filter(item => item)
  })

  return {
    config,

    // useViewBox
    zoom,
    scale,
    centerX,
    centerY,
    lastX,
    lastY,
    viewBox,
    viewBoxString,
    setCenter,
    mouseDownSvg,
    mouseMoveSvg,
    mouseUpSvg,
    mouseWheelSvg,

    // useMiniMap
    miniMapLatch,
    showMiniMap,
    innerMiniMapProps,
    outerMiniMapProps,
    mouseDownMiniMap,
    mouseMoveMiniMap,

    // ...
    highlight,
    svgDevicesRingProps,
    svgInnerHostsRingProps,
    svgOuterHostsRingProps,

    svgDevices,
    svgInnerHosts,
    svgOuterHosts,



assocInnerHostsCount,
assocOuterHostsCount,
innerHostsRingCircumference,
outerHostsRingCircumference,
totalCount,
innerHosts,
outerHosts,
flows,
  }
}

// @vue/component
export default {
  name: 'base-chart-ringed',
  components,
  props,
  setup
}
</script>

<style lang="scss">
@import './BaseChartRinged.scss';
</style>