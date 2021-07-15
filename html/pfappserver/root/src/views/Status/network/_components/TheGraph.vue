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
        <symbol id="packetfence" viewBox="0 0 32 32">
          <circle class="bg" cx="16" cy="16" r="14" />
          <circle class="fg" cx="16" cy="16" r="11.75" />
          <g class="icon" transform="scale(0.2) translate(20.25, 45)" viewBox="0 0 140 75">
            <path d="M0.962,14.55l26.875,9.047l0.182,10.494l-27.057,-8.683l0,-10.858Z" />
            <path d="M0.962,27.577l26.875,9.047l0.182,10.496l-27.057,-8.687l0,-10.856l0,0Z" />
            <path d="M91.87,23.96l26.876,9.045l0.181,10.496l-27.057,-8.685l0,-10.856l0,0Z" />
            <path d="M91.87,36.988l26.876,9.046l0.181,10.493l-27.057,-8.684l0,-10.855l0,0Z" />
            <path d="M48.22,17.265c3.187,0 5.771,2.592 5.771,5.791l0,26.596c0,3.199 -2.584,5.791 -5.771,5.791c-3.188,0 -5.772,-2.592 -5.772,-5.791l0,-26.596c0,-3.199 2.584,-5.791 5.772,-5.791" />
            <path d="M60.485,17.265c3.188,0 5.772,2.592 5.772,5.791l0,26.596c0,3.199 -2.584,5.791 -5.772,5.791c-3.187,0 -5.771,-2.592 -5.771,-5.791l0,-26.596c0,-3.199 2.584,-5.791 5.771,-5.791" />
            <path d="M72.751,17.265c3.187,0 5.771,2.592 5.771,5.791l0,26.596c0,3.199 -2.584,5.791 -5.771,5.791c-3.188,0 -5.772,-2.592 -5.772,-5.791l0,-26.596c0,-3.199 2.584,-5.791 5.772,-5.791" />
            <path d="M35.413,14.732c1.565,-2.172 5.411,-17.492 5.411,-14.295l0.181,49.215c0,3.199 -2.584,5.791 -5.773,5.791c-3.186,0 -5.77,-2.592 -5.77,-5.791l0,-26.596c0,-3.199 4.085,-5.732 5.951,-8.324" />
            <path d="M84.835,57.388c-1.564,2.17 -5.41,17.49 -5.41,14.293l-0.182,-49.215c0,-3.197 2.584,-5.789 5.774,-5.789c3.187,0 5.772,2.592 5.772,5.789l0,26.6c0,3.195 -4.085,5.73 -5.954,8.322" />
          </g>
        </symbol>

        <symbol id="switch-group" viewBox="0 0 512 512" preserveAspectRatio="xMinYMin slice">
          <circle class="bg" cx="256" cy="256" r="256"/>
          <path class="fg" d="M257 8C120 8 9 119 9 256s111 248 248 248 248-111 248-248S394 8 257 8zm-49.5 374.8L81.8 257.1l125.7-125.7 35.2 35.4-24.2 24.2-11.1-11.1-77.2 77.2 77.2 77.2 26.6-26.6-53.1-52.9 24.4-24.4 77.2 77.2-75 75.2zm99-2.2l-35.2-35.2 24.1-24.4 11.1 11.1 77.2-77.2-77.2-77.2-26.5 26.5 53.1 52.9-24.4 24.4-77.2-77.2 75-75L432.2 255 306.5 380.6z"/>
        </symbol>

        <symbol id="switch" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
          <circle class="bg" cx="16" cy="16" r="14"/>
          <path class="fg" d="M 16 4 C 9.3844277 4 4 9.3844277 4 16 C 4 22.615572 9.3844277 28 16 28 C 22.615572 28 28 22.615572 28 16 C 28 9.3844277 22.615572 4 16 4 z M 16 6 C 21.534692 6 26 10.465308 26 16 C 26 21.534692 21.534692 26 16 26 C 10.465308 26 6 21.534692 6 16 C 6 10.465308 10.465308 6 16 6 z M 16 8 L 13 11 L 15 11 L 15 14 L 17 14 L 17 11 L 19 11 L 16 8 z M 11 13 L 11 15 L 8 15 L 8 17 L 11 17 L 11 19 L 14 16 L 11 13 z M 21 13 L 18 16 L 21 19 L 21 17 L 24 17 L 24 15 L 21 15 L 21 13 z M 15 18 L 15 21 L 13 21 L 16 24 L 19 21 L 17 21 L 17 18 L 15 18 z"/>
        </symbol>

        <symbol id="node" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
          <circle cx="16" cy="16" r="14" />
        </symbol>

        <symbol id="unknown" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
          <circle cx="16" cy="16" r="14" />
        </symbol>
      </defs>

      <!-- background to capture node mouseout event -->
      <rect fill-opacity="0" :x="viewBox.minX" :y="viewBox.minY" :width="viewBox.width" :height="viewBox.height"
        @mouseover="mouseOutNode($event)"
      />

      <!-- links -->
      <path v-for="link in localLinks" :key="linkId(link)"
        v-bind="linkPathAttrs(link)"
        :class="[ 'link', { 'highlight': link.highlight } ]"
      />

      <!-- highlighted link text paths -->
      <text v-for="link in highlightedLinks" :key="`${link.source.id}-${link.target.id}`" class="linkText" dy="-2">
        <textPath v-bind="linkSourceAttrs(link)">
          ↦{{ linkSourceText(link) }}
        </textPath>
        <textPath v-bind="linkTargetAttrs(link)">
          ↦{{ linkTargetText(link) }}
        </textPath>
      </text>

      <!-- tooltip handles/lines -->
      <line v-for="tooltip in tooltips" :key="`line-${tooltip.node.id}`" class="tt-link"
        :x1="tooltip.line.x1"
        :y1="tooltip.line.y1"
        :x2="tooltip.line.x2"
        :y2="tooltip.line.y2"
      />

      <!-- nodes -->
      <template v-for="(node, i) in localNodes">

        <!-- packetfence -->
        <use v-if="node.type === 'packetfence' && i in coords"
          xlink:href="#packetfence"
          width="32" height="32"
          :id="`node-${node.id}`"
          :x="coords[i].x - (32 / 2)"
          :y="coords[i].y - (32 / 2)"
          fill="#000000"
          @mouseover="mouseOverNode(node, $event)"
          :class="[ 'packetfence', { 'highlight': node.highlight } ]"
          :key="`use-packetfence-${node.id}`"
        />

        <!-- switch-group -->
        <template v-if="node.type === 'switch-group' && i in coords">
          <use
            xlink:href="#switch-group"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            :class="[ 'switch-group', 'pointer', { 'highlight': node.highlight } ]"
            :key="`use-switch-group-${node.id}`"
          />
          <text class="switchText" v-show="!node.highlight"
            :x="coords[i].x" :y="coords[i].y"
            dy="3" dx="16"
            :key="`use-switch-group-text-${node.id}`"
          >↦{{ node.id }}</text>
        </template>

        <!-- switch -->
        <template v-if="node.type === 'switch' && i in coords">
          <use
            xlink:href="#switch"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            :class="[ 'switch', 'pointer', { 'highlight': node.highlight } ]"
            :key="`use-switch-${node.id}`"
          />
          <text class="switchText" v-show="!node.highlight"
            :x="coords[i].x" :y="coords[i].y"
            dy="3" dx="16"
            :key="`use-switch-text-${node.id}`"
          >↦{{ node.id }}</text>
        </template>

        <!-- unknown -->
        <template v-if="node.type === 'unknown' && i in coords">
          <use
            xlink:href="#unknown"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            :class="[ 'unknown', { 'highlight': node.highlight } ]"
            :key="`use-unknown-${node.id}`"
          />
          <text class="switchText" v-show="!node.highlight"
            :x="coords[i].x" :y="coords[i].y"
            dy="3" dx="16"
            :key="`use-unknown-text-${node.id}`"
          >↦{{ node.id }}</text>
        </template>

        <!-- node -->
        <use v-if="node.type === 'node' && i in coords"
          xlink:href="#node"
          width="16" height="16"
          :id="`node-${node.id}`"
          :x="coords[i].x - (16 / 2)"
          :y="coords[i].y - (16 / 2)"
          @mouseover="mouseOverNode(node, $event)"
          :class="[ 'node', 'pointer', color(node), { 'highlight': node.highlight } ]"
          :key="`use-node-${node.id}`"
        />

      </template>

      <!-- mini map -->
      <rect v-if="showMiniMap" class="innerMiniMap" v-bind="innerMiniMapProps" />
      <rect v-if="showMiniMap" class="outerMiniMap" v-bind="outerMiniMapProps"
        @mousedown.stop="mouseDownMiniMap($event)"
        @mousemove.capture="mouseMoveMiniMap($event)"
      />

    </svg>

    <!-- tooltip -->
    <div v-for="tooltip in tooltips" :key="`tooltip-${tooltip.node.id}`" class="tt-anchor"
      v-bind="tooltipAnchorAttrs(tooltip)"
    >
      <div class="tt-container">
        <div class="tt-contents">
          <!-- NODE -->
          <tooltip-node v-if="['node'].includes(tooltip.node.type)"
            :id="tooltip.node.id"
          />
          <!-- SWITCH -->
          <tooltip-switch v-else-if="['switch', 'unknown'].includes(tooltip.node.type)"
            :id="tooltip.node.id"
            :properties="tooltip.node.properties"
          />
          <!-- SWITCH GROUP -->
          <tooltip-switch-group v-else-if="['switch-group'].includes(tooltip.node.type)"
            :id="tooltip.node.id"
            :properties="tooltip.node.properties"
          />
          <!-- PACKETFENCE -->
          <tooltip-packetfence v-else-if="['packetfence'].includes(tooltip.node.type)"/>
        </div>
      </div>
    </div>

    <!-- legend -->
    <div v-if="!lastX && !lastY" :class="[ 'legend', config.legendPosition ]" :style="{ padding: `${config.padding}px` }">
      <ul class="mb-0">
        <li v-for="legend in legends" :key="`legend-${legend.color}`" :class="legend.color">{{ legend.text }} <span v-if="legend.count > 0">({{ legend.count }})</span></li>
      </ul>
    </div>

    <!-- empty (no data) -->
    <div class="emptyContainer" v-show="!isLoading && localNodes.length === 0 && localLinks.length === 0">
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media no-body>
            <template v-slot:aside><icon name="search" scale="2"></icon></template>
            <div class="mx-2">
              <h4 v-t="'No Network Data'"></h4>
              <p class="font-weight-light" v-t="'Please refine your search.'"></p>
            </div>
          </b-media>
        </b-col>
      </b-row>
    </div>

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

  </div>
</template>

<script>
import TooltipNode from './TooltipNode'
import TooltipPacketfence from './TooltipPacketfence'
import TooltipSwitch from './TooltipSwitch'
import TooltipSwitchGroup from './TooltipSwitchGroup'

const components = {
  TooltipNode,
  TooltipPacketfence,
  TooltipSwitch,
  TooltipSwitchGroup
}

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
  padding: 25,
  sort: 'last_seen',
  order: 'DESC' // 'ASC' or 'DESC'
}

const props = {
  dimensions: { // svg dimensions
    type: Object,
    required: true
  },
  options: {
    type: Object
  },
  nodes: {
    type: Array,
    required: true
  },
  links: {
    type: Array,
    required: true
  },
  disabled: {
    type: Boolean
  },
  isLoading: {
    type: Boolean
  },
  palettes: {
    type: Object
  }
}

import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import { useViewBox, useMiniMap } from '../_composables/useSvg'
import useColor from '../_composables/useColor'
import useSimulation from '../_composables/useSimulation'
import useTooltips from '../_composables/useTooltips'

const setup = props => {

  const {
    options,
    dimensions,
    nodes,
    links,
    palettes
  } = toRefs(props)
  const config = computed(() => ({ ...defaults, ...options.value }))

  const localNodes = ref([])
  const localLinks = ref([])

  const {
    simulation,
    bounds,
    coords,
    init,
    start,
    stop,
    force
  } = useSimulation(props, config, localNodes, localLinks)

  // initialize simulation
  init()

  // watch `dimensions` prop and rebuild simulation forces on resize
  watch(dimensions, () => {
    const { width = 0, height = 0 } = dimensions.value
    // adjust fixed nodes x, y
    localNodes.value.forEach((node, index) => {
      if ('fx' in node && 'fy' in node) {
        localNodes.value[index].fx = width / 2
        localNodes.value[index].fy = height / 2
      }
    })
    nextTick(() => {
      force()
      start()
    })
  }, { deep: true, imediate: true })

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

  const {
    color
  } = useColor(props, config)

  const {
    coordBounded,
    localTooltips,
    tooltips,
    tooltipAnchorAttrs,
    highlight,
    highlightNodeId,
    highlightedLinks,
    mouseOverNode,
    mouseOutNode
  } = useTooltips(props, config, bounds, viewBox, localNodes, localLinks)

  const legends = computed(() => {
    if (Object.keys(palettes.value).includes(config.value.palette)) {
      const palette = palettes.value[config.value.palette]
      return Object.keys(palette).map(key => {
        return {
          color: palette[key],
          text: `${config.value.palette}: ${key}`,
          count: localNodes.value.filter(node => node.properties[config.value.palette] === key).length
        }
      })
    }
    return []
  })

  const _linkCoords = link => {
    const { source: { index: sourceIndex = null } = {}, target: { index: targetIndex = null } = {} } = link
    const {
      [sourceIndex]: { x: x1 = 0, y: y1 = 0 } = {},
      [targetIndex]: { x: x2 = 0, y: y2 = 0 } = {}
    } = coords.value
    return {
      x1: (isNaN(x1)) ? 0 : x1,
      y1: (isNaN(y1)) ? 0 : y1,
      x2: (isNaN(x2)) ? 0 : x2,
      y2: (isNaN(y2)) ? 0 : y2
    }
  }

  const linkId = link => {
    let { source = {}, target = {} } = link
    if (source.constructor === Object && 'id' in source)
      source = source.id
    if (target.constructor === Object && 'id' in target)
      target = target.id
    return `link-${source}-${target}`
  }

  const linkPathAttrs = link => {
    const { x1 = 0, y1 = 0, x2 = 0, y2 = 0 } = _linkCoords(link)
    return {
      id: linkId(link),
      d: `M${x1} ${y1} L${x2} ${y2} Z`
    }
  }

  const linkSourceAttrs = link => {
    const {
      source: { id: sourceId = null, type: sourceType } = {},
      target: { id: targetId = null } = {}
    } = link
    const startOffset = (sourceType === 'node') ? 8 : 16
    return {
      href: `#link-${sourceId}-${targetId}`,
      startOffset
    }
  }

  const linkSourceText = link => {
    const { source: { id = null } = {} } = link
    return id
  }

  const linkTargetAttrs = link => {
    const {
      source: { id: sourceId = null } = {},
      target: { id: targetId = null, type: targetType } = {}
    } = link
    const { x1 = 0, y1 = 0, x2 = 0, y2 = 0 } = _linkCoords(link)
    const x = x2 - x1
    const y = y2 - y1
    const l = Math.sqrt((x * x) + (y * y))
    const startOffset = l + (targetType === 'node') ? 8 : 16
    return {
      href: `#link-${sourceId}-${targetId}`,
      startOffset
    }
  }

  const linkTargetText = link => {
    const { target: { id = null } = {} } = link
    return id
  }

  const _explodeProperties = (properties = {}) => {
    let explodedProperties = {}
    Object.keys(properties).forEach(key => {
      if (key.includes('.')) { // handle dot-notation keys ('.')
        const [ first, ...remainder ] = key.split('.')
        if (!(first in explodedProperties)) {
          explodedProperties[first] = {}
        }
        explodedProperties[first] = {
          ...explodedProperties[first],
          ..._explodeProperties({ [remainder.join('.')]: properties[key] })
        }
      }
      else {
        explodedProperties[key] = properties[key]
      }
    })
    return explodedProperties
  }

  const _cleanNodeProperties = node => {
    const { id, type, properties = {} } = node || {}
    return { id, type, properties: _explodeProperties(properties) }
  }

  // watch `node` prop and rebuild private `localNodes` data on change
  watch(nodes, (a, b) => {
    stop() // stop simulation
    // build lookup maps to determine insert/update/delete
    const $a = a.reduce((map, node, index) => { // build id => index object map
      map[node.id] = index; return map
    }, {})
    const $b = b.reduce((map, node, index) => { // build id => index object map
      map[node.id] = index; return map
    }, {})
    const $u = [...a, ...b].reduce((map, node) => { // build unique node.id array
      if (!map.includes(node.id))
        map.push(node.id)
      return map
    }, [])
    let $d = [] // deferred delete indexes
    const { width, height } = dimensions.value
    $u.forEach(id => {
      let aIndex = $a[id]
      let lIndex = localNodes.value.findIndex(node => node.id === id)
      switch (true) {
        case (id in $a && id in $b): // update
          localNodes.value[lIndex] = { ...localNodes.value[lIndex], ..._cleanNodeProperties(a[aIndex]) }
          break
        case !(id in $b): // insert
          if (a[aIndex].type === 'packetfence') {
            // always center packetfence node
            localNodes.value[localNodes.value.length] = {
              fx: width / 2,
              fy: height / 2,
              ..._cleanNodeProperties(a[aIndex])
            }
          }
          else {
            localNodes.value[localNodes.value.length] = {
              x: width / 2,
              y: height / 2,
              ..._cleanNodeProperties(a[aIndex])
            }
          }
          break
        default: // delete
          // defer unsorted deletion during loop, avoid subsequent index mismatches
          $d.push(lIndex)
      }
    })
    $d.sort((a, b) => b - a).forEach(index => { // reverse sort, delete bottom-up
      localNodes.value.splice(index, 1)
    })
    simulation.value.nodes(localNodes.value) // push nodes to simulation
    nextTick(() => {
      force() // reset forces
      start() // start simulation
    })
  }, { deep: true, immediate: true })

  // watch `link` prop and rebuild private `localLinks` data on change
  watch (links, a => {
    localNodes.value.forEach((node, index) => {
      localNodes.value[index].num = 0
      localNodes.value[index].depth = 0
      localNodes.value[index].targets = []
    })
    let _links = []
    a.forEach(link => {
      const { source: sourceId = {}, target: targetId = {} } = link
      const sourceIndex = localNodes.value.findIndex(node => node.id === sourceId)
      const targetIndex = localNodes.value.findIndex(node => node.id === targetId)
      if (sourceIndex > -1 && targetIndex > -1) {
        _links.push({ source: localNodes.value[sourceIndex], target: localNodes.value[targetIndex] })
        // set reference from source (parent) to target (child)
        localNodes.value[sourceIndex].targets[localNodes.value[sourceIndex].targets.length] = localNodes.value[targetIndex]
        // set reference from target (child) to source (parent)
        localNodes.value[targetIndex].source = localNodes.value[sourceIndex]
        // set reference from target (child) to source (parent)
        let source = localNodes.value[sourceIndex]
        do {
          source.num++
        } while ('source' in source && (source = source.source))
      }
    })
    localNodes.value
      .filter(node => node.type === 'node')
      .map(node => { // set `depth` counter
        let source = node
        let depth = 0
        do {
          depth = Math.max(source.depth, depth)
          source.depth = depth
        } while ('source' in source && (source = source.source) && (++depth))
      })
    localLinks.value = _links
  }, { deep: true, immediate: true })

  return {
    config,
    localNodes,
    localLinks,
    legends,
    linkId,
    linkPathAttrs,
    linkSourceAttrs,
    linkSourceText,
    linkTargetAttrs,
    linkTargetText,

    // useSimulation
    simulation,
    bounds,
    coords,
    start,
    stop,
    force,

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

    // useColor
    color,

    // useTooltips
    coordBounded,
    localTooltips,
    tooltips,
    tooltipAnchorAttrs,
    highlight,
    highlightNodeId,
    highlightedLinks,
    mouseOverNode,
    mouseOutNode,
  }
}

// @vue/component
export default {
  name: 'the-graph',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>

<style lang="scss">
@import './TheGraph.scss';
</style>
