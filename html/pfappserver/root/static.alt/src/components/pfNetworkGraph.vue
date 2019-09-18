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

      <!-- links -->
      <path v-for="link in localLinks" :key="linkId(link)"
        v-bind="linkPathAttrs(link)"
        :class="[ 'link', { 'highlight': link.highlight } ]"
      />

      <!-- highlighted link text paths -->
      <text v-if="link.highlight" v-for="link in localLinks" :key="`${link.source.id}-${link.target.id}`" class="linkText" dy="-2">
        <textPath v-bind="linkSourceAttrs(link)">
          ↦{{ linkSourceText(link) }}
        </textPath>
        <textPath v-bind="linkTargetAttrs(link)">
          ↦{{ linkTargetText(link) }}
        </textPath>
      </text>

      <!-- tooltip handles/lines -->
      <line v-for="tooltip in tooltips" :key="tooltip.node.id" class="tt-link"
        :x1="tooltip.line.x1"
        :y1="tooltip.line.y1"
        :x2="tooltip.line.x2"
        :y2="tooltip.line.y2"
      />

      <!-- nodes -->
      <template v-for="(node, i) in localNodes">

        <!-- packetfence -->
        <use v-if="node.type === 'packetfence'" :key="node.id"
          xlink:href="#packetfence"
          width="32" height="32"
          :id="`node-${node.id}`"
          :x="coords[i].x - (32 / 2)"
          :y="coords[i].y - (32 / 2)"
          fill="#000000"
          @mouseover="mouseOverNode(node, $event)"
          @mouseout="mouseOutNode(node, $event)"
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
            @mouseout="mouseOutNode(node, $event)"
            @mousedown="mouseDownNode(node, $event)"
            :class="[ 'switch-group', 'pointer', { 'highlight': node.highlight } ]"
            :key="node.id"
          />
          <text class="switchText" v-show="!node.highlight"
            :x="coords[i].x" :y="coords[i].y"
            dy="3" dx="16"
            :key="node.id"
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
            @mouseout="mouseOutNode(node, $event)"
            @mousedown="mouseDownNode(node, $event)"
            :class="[ 'switch', 'pointer', { 'highlight': node.highlight } ]"
            :key="node.id"
          />
          <text class="switchText" v-show="!node.highlight"
            :x="coords[i].x" :y="coords[i].y"
            dy="3" dx="16"
            :key="node.id"
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
            @mouseout="mouseOutNode(node, $event)"
            :class="[ 'unknown', { 'highlight': node.highlight } ]"
            :key="node.id"
          />
          <text class="switchText" v-show="!node.highlight"
            :x="coords[i].x" :y="coords[i].y"
            dy="3" dx="16"
            :key="node.id"
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
          @mouseout="mouseOutNode(node, $event)"
          @mousedown="mouseDownNode(node, $event)"
          :class="[ 'node', 'pointer', color(node), { 'highlight': node.highlight } ]"
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
    <div v-for="tooltip in tooltips" :key="tooltip.node.id" class="tt-anchor"
      v-bind="tooltipAnchorAttrs(tooltip)">
      <div class="tt-container">
        <div class="tt-contents">
          <!-- NODE -->
          <pf-network-graph-tooltip-node v-if="['node'].includes(tooltip.node.type)"
            :id="tooltip.node.id"
          />
          <!-- SWITCH -->
          <pf-network-graph-tooltip-switch v-else-if="['switch', 'unknown'].includes(tooltip.node.type)"
            :id="tooltip.node.id"
            :properties="tooltip.node.properties"
          />
          <!-- PACKETFENCE -->
          <pf-network-graph-tooltip-packetfence v-else-if="['packetfence'].includes(tooltip.node.type)"/>
        </div>
      </div>
    </div>

    <!-- legend -->
    <div v-if="!lastX && !lastY" :class="[ 'legend', config.legendPosition ]" :style="{ padding: `${this.config.padding}px` }">
      <ul class="mb-0">
        <li v-for="legend in legends" :key="legend.color" :class="legend.color">{{ legend.text }} <span v-if="legend.count > 0">({{ legend.count }})</span></li>
      </ul>
    </div>

    <!-- empty (no data) -->
    <div class="emptyContainer" v-show="!isLoading && localNodes.length === 0 && localLinks.length === 0">
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media>
            <icon name="search" scale="2" slot="aside"></icon>
            <h4 v-t="'No Network Data'"></h4>
            <p class="font-weight-light" v-t="'Please refine your search.'"></p>
          </b-media>
        </b-col>
      </b-row>
    </div>

    <!-- loading -->
    <div class="loadingContainer" v-show="isLoading">
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media>
            <icon name="circle-notch" scale="2" slot="aside" spin></icon>
            <h4 v-t="'Loading Network Data'"></h4>
            <p class="font-weight-light" v-t="'Please wait...'"></p>
          </b-media>
        </b-col>
      </b-row>
    </div>

  </div>
</template>

<script>
import pfNetworkGraphTooltipNode from '@/components/pfNetworkGraphTooltipNode'
import pfNetworkGraphTooltipSwitch from '@/components/pfNetworkGraphTooltipSwitch'
import pfNetworkGraphTooltipPacketfence from '@/components/pfNetworkGraphTooltipPacketfence'

require('typeface-b612-mono') // custom pixel font

// import multiple `d3-*` micro-libraries into same namespace,
//  this has a smaller footprint than using full standalone `d3` library.
const d3 = {
  ...require('d3-force')
}

const getAngleFromCoords = (x1, y1, x2, y2) => {
  const dx = x2 - x1
  const dy = y2 - y1
  let theta = Math.atan2(dy, dx)
  theta *= 180 / Math.PI // radians to degrees
  return (360 + theta) % 360
}

const getCoordFromCoordAngle = (x1, y1, angle, length) => {
  const rads = angle * (Math.PI / 180) // degrees to radians
  return {
    x: x1 + (length * Math.cos(rads)),
    y: y1 + (length * Math.sin(rads))
  }
}

const explodeProperties = (properties = {}) => {
  let explodedProperties = {}
  Object.keys(properties).forEach(key => {
    if (key.includes('.')) { // handle dot-notation keys ('.')
      const [ first, ...remainder ] = key.split('.')
      if (!(first in explodedProperties)) {
        explodedProperties[first] = {}
      }
      explodedProperties[first] = {
        ...explodedProperties[first],
        ...explodeProperties({ [remainder.join('.')]: properties[key] })
      }
    } else {
      explodedProperties[key] = properties[key]
    }
  })
  return explodedProperties
}

const cleanNodeProperties = (node = {}) => {
  const { id, type, properties = {} } = node
  const props = { id, type, properties: explodeProperties(properties) }
  return props
}

export default {
  name: 'pf-network-graph',
  components: {
    pfNetworkGraphTooltipNode,
    pfNetworkGraphTooltipSwitch,
    pfNetworkGraphTooltipPacketfence
  },
  props: {
    dimensions: { // svg dimensions
      type: Object,
      default: () => {
        const { $refs: { svgContainer: { offsetWidth: width = 0, offsetHeight: height = 0 } = {} } = {} } = this
        return { height, width }
      },
      required: true
    },
    options: {
      type: Object,
      default: () => this.defaults
    },
    nodes: {
      type: Array,
      default: () => { return [] },
      required: true
    },
    links: {
      type: Array,
      default: () => { return [] },
      required: true
    },
    disabled: {
      type: Boolean,
      default: false
    },
    isLoading: {
      type: Boolean,
      default: false
    },
    palettes: {
      type: Object,
      default: () => { return {} }
    }
  },
  data () {
    return {
      simulation: null, // d3-force simulation
      localNodes: [], // private d3 nodes
      localLinks: [], // private d3 links
      lastX: null, // last mouseDown x
      lastY: null, // last mouseDown y
      zoom: 0, // user zoom level, bound by minZoom and maxZoom
      centerX: null, // viewBox center x
      centerY: null, // viewBox center y
      miniMapLatch: false, // mouseDown @ miniMap
      highlight: false, // mouseOver @ node
      defaults: { // default options
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
        tooltipDistance: 50,
        sort: 'last_seen',
        order: 'ASC' // 'ASC' or 'DESC'
      },
      layouts: ['radial', 'tree']
    }
  },
  computed: {
    config () {
      return { ...this.defaults, ...this.options }
    },
    scale () {
      return Math.pow(2, this.zoom)
    },
    bounds () {
      return {
        minX: Math.min(this.dimensions.width, ...this.localNodes.map(n => n.x)),
        maxX: Math.max(0, ...this.localNodes.map(n => n.x)),
        minY: Math.min(this.dimensions.height, ...this.localNodes.map(n => n.y)),
        maxY: Math.max(0, ...this.localNodes.map(n => n.y))
      }
    },
    coords () {
      const { minX = 0, maxX = 0, minY = 0, maxY = 0 } = this.bounds
      if ((minX | maxX | minY | maxY) !== 0) { // not all zero's
        const xMult = (this.dimensions.width - (2 * this.config.padding)) / (maxX - minX)
        const yMult = (this.dimensions.height - (2 * this.config.padding)) / (maxY - minY)
        return this.localNodes.map(node => {
          return {
            x: this.config.padding + (node.x - minX) * xMult,
            y: this.config.padding + (node.y - minY) * yMult
          }
        })
      }
      return this.localNodes.map(node => { // all zero's
        return { x: 0, y: 0 }
      })
    },
    viewBox () {
      let { dimensions: { height, width } = {}, centerX, centerY, scale } = this
      if (!centerX && width) { // initialize center (x)
        centerX = width / 2
        this.$set(this, 'centerX', centerX)
      }
      if (!centerY && height) { // initialize center (y)
        centerY = height / 2
        this.$set(this, 'centerY', centerY)
      }
      const widthScaled = width / scale
      const heightScaled = height / scale
      return {
        minX: centerX - (widthScaled / 2),
        minY: centerY - (heightScaled / 2),
        width: widthScaled,
        height: heightScaled
      }
    },
    viewBoxString () {
      const { viewBox: { minX = 0, minY = 0, width = 0, height = 0 } = {} } = this
      return `${minX} ${minY} ${width} ${height}`
    },
    showMiniMap () {
      return (~~this.config.miniMapHeight > 0 || ~~this.config.miniMapWidth > 0) && ~~this.config.maxZoom > ~~this.config.minZoom
    },
    innerMiniMapProps () {
      const {
        outerMiniMapProps: { x = 0, y = 0, width: outerMiniMapWidth, height: outerMiniMapHeight } = {},
        viewBox: { minX = 0, minY = 0, width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = {},
        scale
      } = this
      return {
        x: x + ((minX * outerMiniMapWidth) / (viewBoxWidth * scale)),
        y: y + ((minY * outerMiniMapHeight) / (viewBoxHeight * scale)),
        width: outerMiniMapWidth / scale,
        height: outerMiniMapHeight / scale,
        'stroke-width': `${1 / scale}px`
      }
    },
    outerMiniMapProps () {
      const { viewBox: { minX = 0, minY = 0, width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = {}, scale } = this
      const aspectRatio = viewBoxWidth / viewBoxHeight
      let miniMapHeight = 0
      let miniMapWidth = 0
      switch (true) {
        case ~~this.config.miniMapHeight > 0 && ~~this.config.miniMapWidth > 0:
          miniMapHeight = this.config.miniMapHeight / scale
          miniMapWidth = this.config.miniMapWidth / scale
          break
        case ~~this.config.miniMapHeight > 0:
          miniMapHeight = this.config.miniMapHeight / scale
          miniMapWidth = (this.config.miniMapHeight * aspectRatio) / scale
          break
        case ~~this.config.miniMapWidth > 0:
          miniMapWidth = this.config.miniMapWidth / scale
          miniMapHeight = this.config.miniMapWidth / (scale * aspectRatio)
          break
      }
      let miniMapX = 0
      let miniMapY = 0
      switch (this.config.miniMapPosition) {
        case 'top-right':
          miniMapX = minX + viewBoxWidth - miniMapWidth
          miniMapY = minY
          break
        case 'bottom-right':
          miniMapX = minX + viewBoxWidth - miniMapWidth
          miniMapY = minY + viewBoxHeight - miniMapHeight
          break
        case 'bottom-left':
          miniMapX = minX
          miniMapY = minY + viewBoxHeight - miniMapHeight
          break
        case 'top-left':
        default:
          miniMapX = minX
          miniMapY = minY
      }
      return {
        x: miniMapX,
        y: miniMapY,
        width: miniMapWidth,
        height: miniMapHeight,
        'stroke-width': `${1 / scale}px`,
        'stroke-dasharray': 2 / scale
      }
    },
    tooltips () {
      let tooltips = []
      const { minX, minY, width, height } = this.viewBox
      const constrainTooltipAngle = (coords, angle) => { // keep tooltip overflow inside viewBox
        const { x = 0, y = 0 } = coords
        let quad = Math.floor(((360 + angle) % 360) / 90) // quadrant angle points to (0-3)
        switch (true) { // top or bottom
          case ((y < minY + (height / 8)) && [2, 3].includes(quad)): // y @ top-eighth
            switch (quad) {
              case 2: // 180 -> 270
                angle = (angle - 90) % 360 // rotate ccw
                break
              case 3: // 270 -> 360
                angle = (angle + 90) % 360 // rotate cw
                break
            }
            break
          case ((y > minY + (height * 7 / 8)) && [0, 1].includes(quad)): // y @ bottom-eighth
            switch (quad) {
              case 0: // 0 -> 90
                angle = (angle - 90) % 360 // rotate ccw
                break
              case 1: // 90 -> 180
                angle = (angle + 90) % 360 // rotate cw
                break
            }
            break
        }
        quad = Math.floor(((360 + angle) % 360) / 90) // quadrant angle points to (0-3)
        switch (true) { // left or right
          case ((x > minX + (width * 7 / 8)) && [0, 3].includes(quad)): // x @ right-eighth
            switch (quad) {
              case 0: // 0 -> 90
                angle = (angle + 90) % 360 // rotate cw
                break
              case 3: // 270 -> 360
                angle = (angle - 90) % 360 // rotate ccw
                break
            }
            break
          case ((x < minX + (width / 8)) && [1, 2].includes(quad)): // x @ left-eighth
            switch (quad) {
              case 1: // 90 -> 180
                angle = (angle - 90) % 360 // rotate ccw
                break
              case 2: // 180 -> 270
                angle = (angle + 90) % 360 // rotate cw
                break
            }
            break
        }
        return angle
      }
      this.localNodes.filter(node => node.tooltip).forEach((node, index, nodes) => {
        const nodeBounded = this.coordBounded(node)
        let sourceAngle = 0
        let targetAngle = 0
        let tooltipAngle = 0
        let tooltipCoords = {}
        let tooltipCoordsBounded = {}
        switch (index) {
          case 0: // inner node (target only)
            if (nodes.length === 1) { // only the center node is highlighted
              tooltipAngle = 270 // upward
            } else {
              targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
              tooltipAngle = (180 + targetAngle) % 360 // reverse
            }
            tooltipAngle = constrainTooltipAngle(node, tooltipAngle)
            tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, this.tooltipDistance)
            tooltipCoordsBounded = this.coordBounded(tooltipCoords)
            break

          case nodes.length - 1: // outer node (source only)
            sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
            tooltipAngle = (180 + sourceAngle) % 360 // reverse
            tooltipAngle = constrainTooltipAngle(node, tooltipAngle)
            tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, this.tooltipDistance)
            tooltipCoordsBounded = this.coordBounded(tooltipCoords)
            break

          default: // middle nodes (source and target)
            sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
            targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
            tooltipAngle = ((sourceAngle + targetAngle) / 2) % 360
            // reverse angle (180°) if angle is inside knuckle
            if (Math.max(sourceAngle, targetAngle) - Math.min(sourceAngle, targetAngle) < 180) {
              tooltipAngle = (tooltipAngle + 180) % 360
            }
            tooltipAngle = constrainTooltipAngle(node, tooltipAngle)
            tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, this.tooltipDistance)
            tooltipCoordsBounded = this.coordBounded(tooltipCoords)
            // node = JSON.parse(JSON.stringify(node)) // dereference (avoid permanent overload)
            const { id, type, properties } = node
            node = JSON.parse(JSON.stringify({ id, type, properties })) // dereference (avoid permanent overload)
            node.properties = { ...node.properties, ...nodes[index + 1].properties } // overload properties from target, move node switch/locationlog properties to switch
            break
        }
        tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
      })
      return tooltips
    },
    tooltipDistance () {
      return this.config.tooltipDistance / this.scale // scale length
    },
    legends () {
      if (Object.keys(this.palettes).includes(this.config.palette)) {
        const palette = this.palettes[this.config.palette]
        return Object.keys(palette).map(key => {
          return { color: palette[key], text: `${this.config.palette}: ${key}`, count: this.localNodes.filter(node => node.properties[this.config.palette] === key).length }
        })
      }
      return []
    },
    nodeSiblingsById () {
      return (id) => {
        const node = this.localNodes.find(node => node.id === id)
        if (node) {
          const { source: { id: parentId = undefined } = {} } = node
          if (parentId) {
            return this.nodeChildrenById(parentId)
          }
        }
        return []
      }
    },
    nodeChildrenById () {
      return (id) => this.localLinks.filter(link => link.source.id === id).map(link => link.target)
    },
    sortedNodes () {
      const getMinMaxPropertyFromSwitch = (switche) => {
        return this.localLinks.filter(node => node.source.id === switche.id).reduce((limits, link, index) => {
          let { min = undefined, max = undefined } = limits
          const { target: { type } = {} } = link
          if (type !== 'node') {
            const { min: sMin, max: sMax } = getMinMaxPropertyFromSwitch(link.target) // recurse
            min = (min === undefined) ? sMin : ((min.localeCompare(sMin) === 1) ? sMin : min)
            max = (max === undefined) ? sMax : ((max.localeCompare(sMax) === -1) ? sMax : max)
          } else {
            const { target: { properties: { [this.config.sort]: prop } = {} } = {} } = link
            min = (min === undefined) ? prop : ((min.localeCompare(prop) === 1) ? prop : min)
            max = (max === undefined) ? prop : ((max.localeCompare(prop) === -1) ? prop : max)
          }
          return { min, max }
        }, { min: undefined, max: undefined })
      }
      const order = (this.config.order === 'ASC') ? 1 : -1 // order multiplier
      return Array.prototype.slice.call(this.localNodes).sort((a, b) => { // dereference w/ sort
        const { id: idA, type: typeA, properties: { [this.config.sort]: propA } = {} } = a
        const { id: idB, type: typeB, properties: { [this.config.sort]: propB } = {} } = b
        if (typeA === 'node' && typeB === 'node') {
          return (propA === propB) ? idA.localeCompare(idB) : (propA.localeCompare(propB) * order)
        } else if (typeA === 'node') {
          return 1 * order // switch (non-node) first
        } else if (typeB === 'node') {
          return -1 * order // switch (non-node) first
        } else {
          const { min: minA = null, max: maxA = null } = getMinMaxPropertyFromSwitch(a)
          const { min: minB = null, max: maxB = null } = getMinMaxPropertyFromSwitch(b)
          switch (order) {
            case -1: // ascending
              return (minA === minB) ? idA.localeCompare(idB) : String(minA).localeCompare(minB)
              // break
            case 1: // descending
              return (minA === minB) ? idA.localeCompare(idB) : String(maxA).localeCompare(maxB)
              // break
          }
        }
      })
    },
    forceCollideRadius () {
      return (node) => {
        const { type } = node
        switch (type) {
          case 'packetfence':
          case 'switch-group':
          case 'switch':
          case 'unknown':
            return 32 / 2
          case 'node':
            return 16 / 2
        }
      }
    },
    forceRadialRadius () {
      return (node) => {
        const { type, depth } = node
        const { depth: totalDepth } = this.localNodes.find(n => n.type === 'packetfence')
        switch (type) {
          case 'packetfence':
            return 0
          case 'switch-group':
          case 'switch':
          case 'unknown':
            return Math.min(this.dimensions.height, this.dimensions.width) * ((totalDepth - depth) / totalDepth) / 2
          case 'node':
            return Math.min(this.dimensions.height, this.dimensions.width) / 2
        }
      }
    },
    forceRadialStrength () {
      return (node) => {
        const { type } = node
        switch (type) {
          case 'packetfence':
            return 0
          case 'switch-group':
          case 'switch':
          case 'unknown':
            return 1
          case 'node':
            return 0.2
        }
      }
    },
    forceXY () {
      const { depth: totalDepth, num: totalNum } = this.localNodes.find(n => n.type === 'packetfence')
      return (node) => {
        const { id, type } = node
        let shift
        switch (this.config.layout) {
          case 'radial':
            /**
            * 'radial' force - rendered outside-in
            *  - node(s) on outer ring - evenly distributed
            *  - switch(es) on middle ring - using average angle of its target nodes
            *  - switch-group(s) on inner ring - using average angle of its target switches
            *  - packetfence - centered
            **/
            shift = 270 // start upward (12 o-clock)
            const { depth, num } = node
            let offset
            let angle
            let distance
            switch (type) {
              case 'node':
                offset = this.sortedNodes.filter(n => n.id === id).reduce((offset, node) => {
                  let { id, source = {} } = node
                  do {
                    if (source && 'targets' in source) {
                      for (let t = 0; t < source.targets.length; t++) {
                        if (source.targets[t].id === id) break
                        offset += source.targets[t].num || 1
                      }
                    }
                  } while ('source' in source && ({ id, source } = source))
                  return offset
                }, 0)
                angle = ((360 / totalNum * offset) + shift) % 360
                distance = Math.min(this.dimensions.height, this.dimensions.width) / 2
                return getCoordFromCoordAngle(this.dimensions.width / 2, this.dimensions.height / 2, angle, distance)
                // break

              case 'switch-group':
              case 'switch':
              case 'unknown':
                offset = this.sortedNodes.filter(n => n.id === id).reduce((offset, node) => {
                  let { id, source = {} } = node
                  do {
                    if (source && 'targets' in source) {
                      for (let t = 0; t < source.targets.length; t++) {
                        if (source.targets[t].id === id) break
                        offset += source.targets[t].num
                      }
                    }
                  } while ('source' in source && ({ id, source } = source))
                  return offset
                }, 0) + ((num - 1) / 2)
                angle = ((360 / totalNum * offset) + shift) % 360
                distance = Math.min(this.dimensions.height, this.dimensions.width) * ((totalDepth - depth) / totalDepth) / 2
                return getCoordFromCoordAngle(this.dimensions.width / 2, this.dimensions.height / 2, angle, distance)
                // break

              case 'packetfence':
                const x = this.dimensions.width / 2
                const y = this.dimensions.height / 2
                return { x, y }
                // break
            }
            break

          case 'tree':
            /**
            * 'tree' force - rendered inside-out
            *  - packetfence - centered
            *  - switch-group(s) on inner ring - evenly distributed around source (packetfence)
            *  - switch(es) on middle ring - evenly distributed around source (switch-group)
            *  - node(s) on outer ring - evenly distributed around source (switch)
            **/
            shift = 270 // start upward (12 o-clock)
            switch (type) {
              case 'packetfence':
                const x = this.dimensions.width / 2
                const y = this.dimensions.height / 2
                return { x, y }
                // break

              case 'switch-group':
              case 'switch':
              case 'unknown':
              case 'node':
                const getDistanceByDepth = (depth = 0) => {
                  let distance = Math.min(this.dimensions.width, this.dimensions.height) / 6
                  for (let n = 0; n < depth; n++) {
                    distance /= 0.5
                  }
                  return distance
                }
                const getNodeCoordAngle = (localNode, n = 0) => {
                  const sortedNode = this.sortedNodes.find(n => n.id === localNode.id)
                  if (!('source' in sortedNode)) { // packetfence node
                    const angle = shift
                    const x = this.dimensions.width / 2
                    const y = this.dimensions.height / 2
                    return { angle, x, y }
                  } else { // everything else
                    const { angle: sourceAngle, x: sourceX, y: sourceY } = getNodeCoordAngle(sortedNode.source, ++n)
                    const siblings = sortedNode.source.targets.length
                    let offset = sortedNode.source.targets.findIndex(target => target.id === localNode.id)
                    if (sortedNode.source.id !== 'packetfence' && siblings % 2 === 0) { // even # of siblings
                      offset += 0.5
                    }
                    const angle = ((360 / siblings * offset) + sourceAngle) % 360
                    const distance = getDistanceByDepth(sortedNode.depth)
                    const { x, y } = getCoordFromCoordAngle(sourceX, sourceY, angle, distance)
                    return { angle, x, y }
                  }
                }
                return getNodeCoordAngle(node)
                // break
            }
            break
        }
      }
    },
    forceX () {
      return (node) => {
        return this.forceXY(node).x
      }
    },
    forceY () {
      return (node) => {
        return this.forceXY(node).y
      }
    }
  },
  methods: {
    init () {
      this.simulation = d3.forceSimulation(this.localNodes)
      this.force()
    },
    start () {
      if (this.simulation) {
        this.$nextTick(() => {
          this.simulation.restart()
        })
      }
    },
    stop () {
      if (this.simulation) {
        this.simulation.stop()
      }
    },
    force () {
      /* `collide` force - prevents nodes from overlapping */
      this.simulation.force('collide', d3.forceCollide()
        .radius(this.forceCollideRadius)
        .strength(0.25)
        .iterations(8)
      )
      this.simulation.force('x', d3.forceX()
        .x(this.forceX)
        .strength(0.25)
      )
      this.simulation.force('y', d3.forceY()
        .y(this.forceY)
        .strength(0.25)
      )

      switch (this.config.layout) {
        case 'radial':
          this.simulation.velocityDecay(0.4) // default: 0.4
          /* `radial` force - orient on circle of specified radius centered at x, y */
          /*
          this.simulation.force('radial', d3.forceRadial()
            .radius(this.forceRadialRadius)
            .strength(this.forceRadialStrength)
            .x(this.dimensions.width / 2)
            .y(this.dimensions.height / 2)
          )
          */
          break

        case 'tree':
          this.simulation.velocityDecay(0.5) // default: 0.4
          break

        default:
          throw new Error(`Unhandled layout ${this.config.layout}`)
      }
      this.simulation.alpha(1)
    },
    linkCoords (link) {
      const { source: { index: sourceIndex = null } = {}, target: { index: targetIndex = null } = {} } = link
      const {
        coords: {
          [sourceIndex]: { x: x1 = 0, y: y1 = 0 } = {},
          [targetIndex]: { x: x2 = 0, y: y2 = 0 } = {}
        } = {}
      } = this
      return { x1, y1, x2, y2 }
    },
    linkId (link) {
      let { source = {}, target = {} } = link
      if (source.constructor === Object && 'id' in source) {
        source = source.id
      }
      if (target.constructor === Object && 'id' in target) {
        target = target.id
      }
      return `link-${source}-${target}`
    },
    linkPathAttrs (link) {
      const { x1 = 0, y1 = 0, x2 = 0, y2 = 0 } = this.linkCoords(link)
      return {
        id: this.linkId(link),
        d: `M${x1} ${y1} L${x2} ${y2} Z`
      }
    },
    linkSourceAttrs (link) {
      const {
        source: { id: sourceId = null, type: sourceType } = {},
        target: { id: targetId = null } = {}
      } = link
      const sourceMargin = (sourceType === 'node') ? 8 : 16
      return {
        href: `#link-${sourceId}-${targetId}`,
        startOffset: sourceMargin
      }
    },
    linkSourceText (link) {
      const { source: { id = null } = {} } = link
      return id
    },
    linkTargetAttrs (link) {
      const {
        source: { id: sourceId = null } = {},
        target: { id: targetId = null, type: targetType } = {}
      } = link
      const { x1 = 0, y1 = 0, x2 = 0, y2 = 0 } = this.linkCoords(link)
      const x = x2 - x1
      const y = y2 - y1
      const l = Math.sqrt((x * x) + (y * y))
      const targetMargin = (targetType === 'node') ? 8 : 16
      return {
        href: `#link-${sourceId}-${targetId}`,
        startOffset: l + targetMargin
      }
    },
    linkTargetText (link) {
      const { target: { id = null } = {} } = link
      return id
    },
    setCenter (x, y) {
      const { dimensions: { height, width } = {}, scale } = this
      // restrict min/max x bounds
      const minX = width / scale / 2
      const maxX = width - minX
      this.centerX = Math.min(Math.max(x, minX), maxX)
      // restrict min/max y bounds
      const minY = height / scale / 2
      const maxY = height - minY
      this.centerY = Math.min(Math.max(y, minY), maxY)
    },
    mouseDownSvg (event) {
      const { viewBox: { minX, minY } = {}, scale } = this
      // get mouse delta and offset from top/left corner of current viewBox
      const { offsetX, offsetY } = event
      // calculate mouse offset from 0,0
      this.lastX = (offsetX / scale) + minX
      this.lastY = (offsetY / scale) + minY
    },
    mouseMoveSvg (event) {
      if (this.lastX && this.lastY) {
        const { viewBox: { minX, minY } = {}, scale } = this
        // get mouse delta and offset from top/left corner of current viewBox
        const { offsetX, offsetY } = event
        this.$nextTick(() => { // smoothen animation
          const x = this.centerX + (this.lastX - ((offsetX / scale) + minX))
          const y = this.centerY + (this.lastY - ((offsetY / scale) + minY))
          this.setCenter(x, y)
        })
      }
    },
    mouseUpSvg () {
      this.lastX = null
      this.lastY = null
    },
    mouseWheelSvg (event) {
      if (this.config.mouseWheelZoom) {
        event.preventDefault() // don't scroll
        const { viewBox: { minX, minY } = {}, centerX, centerY, scale } = this
        // get mouse delta and offset from top/left corner of current viewBox
        const { deltaY = 0, offsetX, offsetY } = event
        // calculate mouse offset from 0,0
        const [ svgX, svgY ] = [ (offsetX / scale) + minX, (offsetY / scale) + minY ]
        // calculate mouse offset from center of current viewBox
        const [deltaCenterX, deltaCenterY] = [svgX - centerX, svgY - centerY]
        // handle zoom-in (-deltaY) and zoom-out (+deltaY)
        //  automatically match center of mouse pointer, so the
        //  x,y coord remains pinned at the mouse pointer after zoom.
        if (deltaY < 0) { // zoom in
          this.zoom = Math.min(++this.zoom, this.config.maxZoom)
        } else if (deltaY > 0) { // zoom out
          this.zoom = Math.max(--this.zoom, this.config.minZoom)
        }
        const factor = this.scale / scale
        // calculate new center x,y at the current mouse position
        const x = svgX - (deltaCenterX / factor)
        const y = svgY - (deltaCenterY / factor)
        this.setCenter(x, y)
      }
    },
    mouseOverNode (node, event = null) {
      this.stop() // pause animation
      this.highlightNodeById(node.id) // highlight node
      this.highlight = (node.type === 'node') ? this.color(node) : 'none'
    },
    mouseOutNode (node, event = null) {
      this.start() // unpause animation
      this.highlightNodeById(null) // unhighlight node
      this.highlight = null
    },
    mouseDownNode (node, event = null) {
      // eslint-disable-next-line
      console.log('mouseDownNode', node)
    },
    highlightNodeById (id) {
      this.unhighlightNodes()
      this.unhighlightLinks()
      // highlight all target nodes linked to this source node
      this.localLinks.filter(link => link.source.id === id).forEach(link => {
        this.$set(link, 'highlight', true) // highlight link
        this.$set(link.target, 'highlight', true) // highlight target node
      })
      var source = this.localNodes.find(node => node.id === id)
      while (source !== undefined) { // travel to center of tree [ (target|source) -> (target|source) -> ... ]
        this.$set(source, 'highlight', true) // highlight node
        this.$set(source, 'tooltip', true) // show node tooltip
        const { id: sourceId } = source
        this.localLinks.filter(link => {
          const { target: { id: targetId } = {} } = link
          return targetId === sourceId
        }).map(link => {
          this.$set(link, 'highlight', true)
        })
        // eslint-disable-next-line no-redeclare
        var { source = undefined } = source // recurse source
      }
    },
    unhighlightNodes () {
      this.localNodes.forEach((node, index) => {
        if (node.highlight) {
          this.$set(this.localNodes[index], 'highlight', false)
        }
        if (node.tooltip) {
          this.$set(this.localNodes[index], 'tooltip', false)
        }
      })
    },
    unhighlightLinks () {
      this.localLinks.forEach((link, index) => {
        if (link.highlight) {
          this.$set(this.localLinks[index], 'highlight', false)
        }
      })
    },
    mouseDownMiniMap (event) {
      const {
        dimensions: { height: svgHeight, width: svgWidth },
        outerMiniMapProps: { width: outerMiniMapWidth, height: outerMiniMapHeight },
        viewBox: { width: viewBoxWidth, height: viewBoxHeight },
        scale
      } = this
      const { offsetX, offsetY } = event
      let mouseX = 0
      let mouseY = 0
      switch (this.config.miniMapPosition) {
        case 'top-right':
          mouseX = (outerMiniMapWidth * scale) - (svgWidth - offsetX)
          mouseY = offsetY
          break
        case 'bottom-right':
          mouseX = (outerMiniMapWidth * scale) - (svgWidth - offsetX)
          mouseY = (outerMiniMapHeight * scale) - (svgHeight - offsetY)
          break
        case 'bottom-left':
          mouseX = offsetX
          mouseY = (outerMiniMapHeight * scale) - (svgHeight - offsetY)
          break
        case 'top-left':
        default:
          mouseX = offsetX
          mouseY = offsetY
      }
      const x = viewBoxWidth * (mouseX / outerMiniMapWidth)
      const y = viewBoxHeight * (mouseY / outerMiniMapHeight)
      this.setCenter(x, y)
      this.miniMapLatch = true // latch miniMapLatch
    },
    mouseMoveMiniMap (event) {
      if (!(event.which)) {
        this.miniMapLatch = false
      }
      if (this.miniMapLatch) {
        this.mouseDownMiniMap(event)
      }
    },
    tooltipAnchorAttrs (tooltip) {
      let { line: { angle, x2: x, y2: y } = {} } = tooltip
      let style = [] // set styles
      const {
        dimensions: { height: dHeight, width: dWidth } = {},
        viewBox: { minX, minY, width: vWidth, height: vHeight } = {}
      } = this
      if (x < minX || x > minX + vWidth || y < minY || y > minY + vHeight) {
        style.push('display: none') // hide if tooltip is outside viewBox
      } else {
        // scale coords to absolute offset from outer container (x: 0, y: 0)
        let absoluteX = (x - minX) / vWidth * dWidth
        let absoluteY = (y - minY) / vHeight * dHeight
        style.push(`top: ${absoluteY}px`, `left: ${absoluteX}px`)
      }
      style = `${style.join('; ')};` // collapse
      // set classes
      const octa = Math.floor(((360 + angle - 22.5) % 360) / 45)
      let vertical = ['bottom', 'bottom', 'bottom', false, 'top', 'top', 'top', false][octa] // vertical position
      let horizontal = ['right', false, 'left', 'left', 'left', false, 'right', 'right'][octa] // horizontal position
      switch (true) { // keep tooltip overflow inside viewBox
        case (y < minY + (vHeight / 16)): // y @ top-sixteenth
          vertical = 'bottom'
          break
        case (y > minY + (vHeight * 15 / 16)): // y @ bottom-sixteenth
          vertical = 'top'
          break
        case (x > minX + (vWidth * 15 / 16)): // x @ right-sixteenth
          horizontal = 'left'
          break
        case (x < minX + (vWidth / 16)): // x @ left-sixteenth
          horizontal = 'right'
          break
      }
      let position = ''
      switch (true) {
        case (!!vertical && !!horizontal):
          position = `${vertical}-${horizontal}`
          break
        case (!!vertical):
          position = vertical
          break
        case (!!horizontal):
          position = horizontal
          break
      }
      return { style, class: position }
    },
    coordBounded (coord) {
      const { minX = 0, maxX = 0, minY = 0, maxY = 0 } = this.bounds
      if ((minX | maxX | minY | maxY) !== 0) { // not all zero's
        const xMult = (this.dimensions.width - (2 * this.config.padding)) / (maxX - minX)
        const yMult = (this.dimensions.height - (2 * this.config.padding)) / (maxY - minY)
        return {
          x: this.config.padding + (coord.x - minX) * xMult,
          y: this.config.padding + (coord.y - minY) * yMult
        }
      }
      return { x: 0, y: 0 }
    },
    color (node) {
      if (Object.keys(this.palettes).includes(this.config.palette) && this.config.palette in node.properties) {
        const value = node.properties[this.config.palette]
        if (Object.keys(this.palettes[this.config.palette]).includes(value)) {
          return this.palettes[this.config.palette][value]
        }
      }
      return 'black'
    }
  },
  mounted () {
    this.$emit('layouts', this.layouts)
  },
  created () {
    this.init()
  },
  watch: {
    /* watch `dimensions` prop and rebuild simulation forces on resize */
    dimensions: {
      handler: function (a, b) {
        // limit centerX, centerY within viewBox (fixes out-of-bounds after resize)
        const { dimensions: { width = 0, height = 0 }, scale } = this
        const minCenterX = width / (scale * 2)
        const maxCenterX = width - (width / (scale * 2))
        const minCenterY = height / (scale * 2)
        const maxCenterY = height - (height / (scale * 2))
        this.$set(this, 'centerX', Math.max(Math.min(this.centerX, maxCenterX), minCenterX))
        this.$set(this, 'centerY', Math.max(Math.min(this.centerY, maxCenterY), minCenterY))
        // adjust fixed nodes x, y
        this.localNodes.forEach((node, index) => {
          if ('fx' in node && 'fy' in node) {
            this.localNodes[index].fx = width / 2
            this.localNodes[index].fy = height / 2
          }
        })
        this.force()
        this.start()
      },
      deep: true
    },
    /* watch `node` prop and rebuild private `localNodes` data on change */
    nodes: {
      handler: function (a, b) {
        // build lookup maps to determine insert/update/delete
        const $a = a.reduce((map, node, index) => { // build id => index object map
          map[node.id] = index; return map
        }, {})
        const $b = b.reduce((map, node, index) => { // build id => index object map
          map[node.id] = index; return map
        }, {})
        const $u = [...a, ...b].reduce((map, node) => { // build unique node.id array
          if (!map.includes(node.id)) {
            map.push(node.id)
          }
          return map
        }, [])
        let $d = [] // deferred delete indexes
        this.stop() // stop simulation
        $u.forEach(id => {
          let aIndex = $a[id]
          let lIndex = this.localNodes.findIndex(node => node.id === id)
          switch (true) {
            case (id in $a && id in $b): // update
              this.$set(this.localNodes, lIndex, {
                ...this.localNodes[lIndex],
                ...cleanNodeProperties(a[aIndex])
              })
              break
            case !(id in $b): // insert
              if (a[aIndex].type === 'packetfence') {
                // always center packetfence node
                this.$set(this.localNodes, this.localNodes.length, {
                  ...{ fx: this.dimensions.width / 2, fy: this.dimensions.height / 2 }, // fx = fixed x, y
                  ...cleanNodeProperties(a[aIndex])
                })
              } else {
                this.$set(this.localNodes, this.localNodes.length, {
                  ...{ x: this.dimensions.width / 2, y: this.dimensions.height / 2 },
                  ...cleanNodeProperties(a[aIndex])
                })
              }
              break
            default: // delete
              // defer unsorted deletion during loop, avoid subsequent index mismatches
              $d.push(lIndex)
          }
        })
        $d.sort((a, b) => b - a).forEach(index => { // reverse sort, delete bottom-up
          this.$delete(this.localNodes, index)
        })
        this.simulation.nodes(this.localNodes) // push nodes to simulation
        this.start() // start simulation
        this.force() // reset forces
      }
    },
    /* watch `link` prop and rebuild private `localLinks` data on change */
    links: {
      handler: function (a, b) {
        this.localNodes.map((node, index) => {
          this.$set(this.localNodes[index], 'num', 0) // reset `num` counter
          this.$set(this.localNodes[index], 'depth', 0) // reset `depth` counter
          this.$set(this.localNodes[index], 'targets', []) // reset `targets`
        })
        let links = []
        a.forEach((link, index) => {
          const { source: sourceId = {}, target: targetId = {} } = link
          const sourceIndex = this.localNodes.findIndex(node => node.id === sourceId)
          const targetIndex = this.localNodes.findIndex(node => node.id === targetId)
          if (sourceIndex > -1 && targetIndex > -1) {
            links.push({ source: this.localNodes[sourceIndex], target: this.localNodes[targetIndex] })
            // set reference from source (parent) to target (child)
            this.$set(this.localNodes[sourceIndex].targets, this.localNodes[sourceIndex].targets.length, this.localNodes[targetIndex])
            // set reference from target (child) to source (parent)
            this.$set(this.localNodes[targetIndex], 'source', this.localNodes[sourceIndex])
            // set reference from target (child) to source (parent)
            let source = this.localNodes[sourceIndex]
            do {
              source.num++
            } while ('source' in source && (source = source.source))
          }
        })
        this.localNodes.filter(node => node.type === 'node').map((node, index) => { // set `depth` counter
          let source = node
          let depth = 0
          do {
            depth = Math.max(source.depth, depth)
            source.depth = depth
          } while ('source' in source && (source = source.source) && (++depth))
        })
        this.stop() // stop simulation
        this.$set(this, 'localLinks', links)
        this.start() // start simulation
        this.force() // reset forces
      }
    },
    'config.layout': {
      handler: function (a, b) {
        if (this.simulation && a !== b) {
          this.stop()
          this.init()
          this.start()
        }
      }
    }
  }
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

.svgContainer {
  position: relative;
  /*overflow: hidden; /* prevent jitter from tooltip forcing window.clientHeight expansion */

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
    .link {
      opacity: 0.6;
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
    &.top .tt-contents { bottom: 0px; transform: translateX(-50%); }
    &.top-right .tt-contents { bottom: 0px; left: 0px; }
    &.right .tt-contents { transform: translateY(-50%); left: 0px; }
    &.bottom-right .tt-contents { top: 0px; left: 0px; }
    &.bottom .tt-contents { top: 0px; transform: translateX(-50%); }
    &.bottom-left .tt-contents { top: 0px; right: 0px; }
    &.left .tt-contents { transform: translateY(-50%); right: 0px; }
    &.top-left .tt-contents { bottom: 0px; right: 0px; }
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
        z-index: 4;
      }
    }
  }

  .tt-link {
    stroke: var(--highlight-color);
    /*stroke-linecap: round;*/
  }

  .legend {
    position: absolute;
    font-family: -apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica Neue,Arial,Noto Sans,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol,Noto Color Emoji;
    font-size: .9rem;
    font-weight: 400;
    line-height: 24px;
    background: rgba(255, 255, 255, 0.5);
    &.top-right {
      top: 0px;
      right: 0px;
    }
    &.bottom-right {
      bottom: 0px;
      right: 0px;
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
    left: 0;
    right: 0;
    bottom: 0;
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
