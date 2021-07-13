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
        <template v-if="i in coords">

          <!-- packetfence -->
          <use v-if="node.type === 'packetfence'" :key="`use-packetfence-${node.id}`"
            xlink:href="#packetfence"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            fill="#000000"
            @mouseover="mouseOverNode(node, $event)"
            :class="[ 'packetfence', { 'highlight': node.highlight } ]"
          />

          <!-- switch-group -->
          <template v-if="node.type === 'switch-group'">
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
          <template v-if="node.type === 'switch'">
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
          <template v-if="node.type === 'unknown'">
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
          <use v-if="node.type === 'node'" :key="node.id"
            xlink:href="#node"
            width="16" height="16"
            :id="`node-${node.id}`"
            :x="coords[i].x - (16 / 2)"
            :y="coords[i].y - (16 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            :class="[ 'node', 'pointer', color(node), { 'highlight': node.highlight } ]"
          />

        </template>
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
// import d3 from '@/utils/d3'
import { useViewBox, useMiniMap } from '../_composables/useSvg'
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
    coordBounded,
    localTooltips,
    tooltips,
    tooltipAnchorAttrs
  } = useTooltips(props, config, bounds, viewBox, nodes)

  const highlightedLinks = computed(() => {
    return localLinks.value.filter(link => { link.highlight })
  })

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

  let highlight = false // mouseOver @ node
  let highlightNodeId = false // last highlighted node

  const _unhighlightNodes = () => {
    localNodes.value = localNodes.value.map(node => ({ ...node, highlight: false, tooltip: false }))
  }

  const _unhighlightLinks = () => {
    localLinks.value = localLinks.value.map(link => ({ ...link, highlight: false }))
  }

  const _highlightNodeById = id => {
    _unhighlightNodes()
    _unhighlightLinks()
    // highlight all target nodes linked to this source node
    localLinks.value.forEach((link, index)=> {
      if (link.source.id === id) {
        localLinks.value[index].highlight = true // highlight link
        localLinks.value[index].target.highlight = true // highlight target node
      }
    })
    var sourceIndex = localNodes.value.findIndex(node => node.id === id)
    while (sourceIndex > -1) { // travel to center of tree [ (target|source) -> (target|source) -> ... ]
      localNodes.value[sourceIndex].highlight = true  // highlight node
      localNodes.value[sourceIndex].tooltip = true // show node tooltip
      const { id: sourceId } = localNodes.value[sourceIndex]
      localLinks.value.forEach((link, index) => {
        const { target: { id: targetId } = {} } = link
        if (targetId === sourceId)
          localLinks.value[index].highlight = true
      })
      sourceIndex = localNodes.value.findIndex(node => node.id === sourceId) // recurse source
    }
  }

  const mouseOverNode = node => {
/*
    const { width, height } = dimensions.value
    stop() // pause animation
    _highlightNodeById(node.id) // highlight node
    highlight = (node.type === 'node') ? color(node) : 'none'
    // tooltips
    if (highlightNodeId !== node.id) {
      highlightNodeId = node.id
      const highlightedNodes = localNodes.value.filter(node => node.tooltip)
      localTooltips.value = [
        ...highlightedNodes.map(node => {
          const { id, type, properties } = node
          const { x, y } = coordBounded(node)
          return JSON.parse(JSON.stringify({ id, type, properties, x, y }))
        }),
        ...highlightedNodes.map(node => {
          const { id } = node
          const { x: fx, y: fy } = coordBounded(node)
          return JSON.parse(JSON.stringify({ id: `${id}-fixed`, fx, fy }))
        })
      ]
      // link force from tooltip to node (self)
      let selfLinks = []
      highlightedNodes.map(node => {
        const { id } = node
        selfLinks.push({ source: id, target: `${id}-fixed` })
      })
      // link force from tooltip to other nodes
      let nodeLinks = []
      highlightedNodes.map(node => {
        const { id } = node
        highlightedNodes.map(other => {
          const { id: otherId } = other
          if (otherId !== id) {
            if (nodeLinks.filter(link =>
              ([link.source, link.target].includes(id) && [link.source, link.target].includes(`${otherId}-fixed`))
            ).length === 0) {
              nodeLinks.push({ source: id, target: `${otherId}-fixed` })
            }
          }
        })
      })
      // link force from tooltip to other tooltips
      let tooltipLinks = []
      highlightedNodes.map(node => {
        const { id } = node
        highlightedNodes.map(other => {
          const { id: otherId } = other
          if (otherId !== id) {
            if (tooltipLinks.filter(link =>
              ([link.source, link.target].includes(id) && [link.source, link.target].includes(otherId))
            ).length === 0) {
              tooltipLinks.push({ source: otherId, target: id })
            }
          }
        })
      })
      d3.forceSimulation(localTooltips.value)
        .alphaDecay(1 - Math.pow(0.001, 1 / 50)) // default: 1 - Math.pow(0.001, 1 / 300)
        .velocityDecay(0.8) // default: 0.4
        .force('x', d3.forceX() // force: tooltip w/ center x
          .x(centerX.value)
          .strength(0.5)
        )
        .force('y', d3.forceY() // force: tooltip w/ center y
          .y(centerY.value)
          .strength(0.5)
        )
        .force('selfLinks', d3.forceLink(selfLinks) // force: tooltip w/ node
          .id((d) => d.id)
          .distance(Math.min(width, height) / 8)
          .strength(0.5)
          .iterations(4)
        )
        .force('nodeLinks', d3.forceLink(nodeLinks) // force: tooltip w/ other nodes
          .id((d) => d.id)
          .distance(Math.min(width, height) / 2)
          .strength(0.5)
          .iterations(2)
        )
        .force('tooltipLinks', d3.forceLink(tooltipLinks) // force: tooltip w/ other tooltips
          .id((d) => d.id)
          .distance(Math.min(width, height) / 2)
          .strength(0.5)
          .iterations(8)
        )
        .restart()
    }
*/
  }

  const mouseOutNode = () => {
/*
    start() // unpause animation
    _unhighlightNodes()
    _unhighlightLinks()
    highlight = false
    highlightNodeId = false
    localTooltips.value = []
*/
  }

  const color = node => {
    if (Object.keys(palettes.value).includes(config.value.palette) && config.value.palette in node.properties) {
      const value = node.properties[config.value.palette]
      if (Object.keys(palettes.value[config.value.palette]).includes(value)) {
        return palettes.value[config.value.palette][value]
      }
    }
    return 'black'
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
console.log('watch nodes', {a,b})
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
console.log('UPDATE', lIndex)
          localNodes.value[lIndex] = { ...localNodes.value[lIndex], ..._cleanNodeProperties(a[aIndex]) }
          break
        case !(id in $b): // insert
console.log('INSERT', lIndex)
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
console.log('DELETE', lIndex)
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
console.log('watch links', a)
//    stop() // stop simulation
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

    simulation,
    bounds,
    coords,
    start,
    stop,
    force,

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

    miniMapLatch,
    showMiniMap,
    innerMiniMapProps,
    outerMiniMapProps,
    mouseDownMiniMap,
    mouseMoveMiniMap,

    coordBounded,
    localTooltips,
    tooltips,
    tooltipAnchorAttrs,

    highlightedLinks,
    legends,
    linkId,
    linkPathAttrs,
    linkSourceAttrs,
    linkSourceText,
    linkTargetAttrs,
    linkTargetText,
    highlight,
    highlightNodeId,
mouseOverNode, //TODO: move
mouseOutNode, //TODO: move
    color,
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
:root { /* defaults */
  --color-black: var(--dark);
  --color-blue: var(--blue);
  --color-red: var(--red);
  --color-yellow: var(--yellow);
  --color-green: var(--green);

  /* default highlight color */
  --highlight-color: var(--color-black);
}

@keyframes fadein {
  from { opacity: 0; }
  to   { opacity: 1; }
}

.svgContainer {
  position: relative;
  .packetfence,
  .switch-group,
  .switch,
  .node,
  .unknown,
  .link {
    transition: opacity 300ms ease, fill 300ms ease, stroke 300ms ease;
    &.pointer {
      cursor: pointer;
    }
  }

  &.highlight {
    .packetfence,
    .switch-group,
    .switch,
    .node,
    .unknown,
    .link,
    .switchText {
      opacity: 0.25;
      &.highlight {
        opacity: 1.0;
      }
    }
  }

  &.highlight-blue {
    --highlight-color: rgba(66, 133, 244, 1);
  }
  &.highlight-red {
    --highlight-color: rgba(219, 68, 55, 1);
  }
  &.highlight-yellow {
    --highlight-color: rgba(244, 160, 0, 1);
  }
  &.highlight-green {
    --highlight-color: rgba(15, 157, 88, 1);
  }

  .tt-anchor {
    position: absolute;
    width: 0px;
    height: 0px;
    animation: fadein 300ms;
    & > .tt-container {
      position: relative;
      & > .tt-contents {
        position: absolute;
        background: rgba(255, 255, 255, 1);
        background-clip: padding-box;
        border-color: var(--highlight-color);
        border-radius: 4px;
        border-style: solid;
        border-width: 2px;
        box-shadow: 5px 5px 15px rgba(0, 0, 0, 0.125);
        transform: translate(-50%, -50%);
        z-index: 4;
        min-width: 175px;
      }
    }
  }

  .tt-link {
    stroke: var(--highlight-color);
    /*stroke-linecap: round;*/
  }

  .legend {
    position: absolute;
    background: rgba(255, 255, 255, 0.5);
    font-family: -apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;
    font-size: .9rem;
    font-weight: 400;
    line-height: 24px;
    &.top-right {
      top: 0px;
      right: 0px;
    }
    &.bottom-right {
      right: 0px;
      bottom: 0px;
    }
    &.bottom-left {
      bottom: 0px;
      left: 0px;
    }
    &.top-left {
      top: 0px;
      left: 0px;
    }
    & > ul {
      & > li {
        list-style-type: none;
        position: relative;
        &.blue::before {
          color: var(--color-blue);
        }
        &.red::before {
          color: var(--color-red);
        }
        &.yellow::before {
          color: var(--color-yellow);
        }
        &.green::before {
          color: var(--color-green);
        }
        &::before {
          content: '\2022';
          position: absolute;
          left: -0.575em;
          font-size: 48px;
          line-height: 24px;
        }
      }
    }
  }

  text {
    font-family: "B612 Mono", "Courier New", Courier, "Lucida Sans Typewriter", "Lucida Typewriter", monospace;
    font-size: 12px;
    fill: var(--highlight-color);
    stroke: rgba(255, 255, 255, 1);
    stroke-alignment: outer;
    stroke-width: 0.125;
    transform-origin: center center;
  }

  .svgDrag {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
  }

  .svgDraw {
    &.zoom-0 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 2;
        &.highlight {
          stroke-width: 4;
        }
      }
      .tt-link {
        stroke-width: 4;
        stroke-dasharray: 4 4;
      }
    }
    &.zoom-1 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 1;
        &.highlight {
          stroke-width: 2;
        }
      }
      .tt-link {
        stroke-width: 2;
        stroke-dasharray: 2 2;
      }
    }
    &.zoom-2 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.5;
        &.highlight {
          stroke-width: 1;
        }
      }
      .tt-link {
        stroke-width: 1;
        stroke-dasharray: 1 1;
      }
    }
    &.zoom-3 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.25;
        &.highlight {
          stroke-width: 0.5;
        }
      }
      .tt-link {
        stroke-width: 0.5;
        stroke-dasharray: 0.5 0.5;
      }
    }
    &.zoom-4 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.125;
        &.highlight {
          stroke-width: 0.25;
        }
      }
      .tt-link {
        stroke-width: 0.25;
        stroke-dasharray: 0.25 0.25;
      }
    }
    &.zoom-5 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.0625;
        &.highlight {
          stroke-width: 0.125;
        }
      }
      .tt-link {
        stroke-width: 0.125;
        stroke-dasharray: 0.125 0.125;
      }
    }
    &.zoom-6 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.03125;
        &.highlight {
          stroke-width: 0.0625;
        }
      }
      .tt-link {
        stroke-width: 0.0625;
        stroke-dasharray: 0.0625 0.0625;
      }
    }
    &.zoom-7 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.015625;
        &.highlight {
          stroke-width: 0.03125;
        }
      }
      .tt-link {
        stroke-width: 0.03125;
        stroke-dasharray: 0.03125 0.03125;
      }
    }
    &.zoom-8 {
      .packetfence,
      .switch-group,
      .switch,
      .node,
      .unknown,
      .link {
        stroke-width: 0.0078125;
        &.highlight {
          stroke-width: 0.015625;
        }
      }
      .tt-link {
        stroke-width: 0.015625;
        stroke-dasharray: 0.015625 0.015625;
      }
    }
  }

  .bg {
    fill: var(--bg-fill);
    stroke: var(--bg-stroke);
  }
  .fg {
    fill: var(--fg-fill);
    stroke: var(--fg-stroke);
  }
  .icon {
    fill: var(--icon-fill);
  }

  .outerMiniMap {
    fill: rgba(0, 123, 255, 0.125);
    stroke: rgba(0, 0, 0, 0.5);
  }
  .innerMiniMap {
    fill: rgba(0, 123, 255, 1);
    stroke: rgba(0, 0, 0, 0.5);
  }

  .packetfence {
    --bg-fill: rgba(255, 255, 255, 1);
    --bg-stroke: rgba(128, 128, 128, 1);
    --fg-fill: rgba(0, 0, 0, 1);
    --icon-fill: rgba(255, 255, 255, 1);
    &.highlight {
      --bg-stroke: var(--highlight-color);
      --fg-fill: var(--highlight-color);
    }
  }

  .switch-group {
    --bg-fill: rgba(128, 128, 128, 1);
    --bg-stroke: rgba(255, 0, 0, 1);
    --fg-fill: rgba(255, 255, 255, 1);
    &.highlight {
      --bg-fill: rgba(255, 255, 255, 1);
      --bg-stroke: var(--highlight-color);
      --fg-fill: var(--highlight-color);
    }
  }

  .switch {
    --bg-fill: rgba(255, 255, 255, 1);
    --bg-stroke: rgba(128, 128, 128, 1);
    --fg-fill: rgba(128, 128, 128, 1);
    &.highlight {
      --bg-fill: var(--highlight-color);
      --bg-stroke: var(--highlight-color);
      --fg-fill: rgba(255, 255, 255, 1);
    }
  }

  .node,
  .unknown {
    fill: rgba(192, 192, 192, 1);
    stroke: rgba(128, 128, 128, 1);
    &.blue {
      fill: var(--color-blue);
    }
    &.red {
      fill: var(--color-red);
    }
    &.yellow {
      fill: var(--color-yellow);
    }
    &.green {
      fill: var(--color-green);
    }
    &.highlight {
      fill: var(--highlight-color);
      stroke: var(--highlight-color);
    }
  }

  .link {
    stroke: rgba(192, 192, 192, 1);
    &.highlight {
      stroke: var(--highlight-color);
    }
  }

  .emptyContainer,
  .loadingContainer {
    position: absolute;
    top: 0px;
    left: 0px;
    width: 100%;
    height: 100%;
    background: rgba(255, 255, 255, 0.5);
    & > * {
      position: relative;
      top: 50%;
      transform: translateY(-50%);
    }
  }

  .switchText {
    fill: #000000 !important;
  }
}
</style>
