<!--
https://plnkr.co/edit/iadT0ikcpKELU0eaE9f6?p=preview
https://bl.ocks.org/steveharoz/8c3e2524079a8c440df60c1ab72b5d03
https://flowingdata.com/2012/08/02/how-to-make-an-interactive-network-visualization/
-->
<template>

  <div>
  <!--
    <pre>{{ JSON.stringify(config, null, 2) }}</pre>
    <pre>{{ JSON.stringify(bounds, null, 2) }}</pre>
    <pre>{{ JSON.stringify(nodes.map(n => { return { type: n.type, x: n.x, y: n.y } }), null, 2) }}</pre>
    <pre>{{ JSON.stringify(localNodes, null, 2) }}</pre>
    <pre>{{ JSON.stringify(localLinks, null, 2) }}</pre>
  -->

    <div ref="svgContainer" :class="[ 'svgContainer', { [`highlight-${highlight}`]: highlight } ]">

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
        @mousewheel.prevent="mouseWheelSvg($event)"
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

          <symbol id="switch" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
            <circle class="bg" cx="16" cy="16" r="14"/>
            <path class="fg" d="M 16 4 C 9.3844277 4 4 9.3844277 4 16 C 4 22.615572 9.3844277 28 16 28 C 22.615572 28 28 22.615572 28 16 C 28 9.3844277 22.615572 4 16 4 z M 16 6 C 21.534692 6 26 10.465308 26 16 C 26 21.534692 21.534692 26 16 26 C 10.465308 26 6 21.534692 6 16 C 6 10.465308 10.465308 6 16 6 z M 16 8 L 13 11 L 15 11 L 15 14 L 17 14 L 17 11 L 19 11 L 16 8 z M 11 13 L 11 15 L 8 15 L 8 17 L 11 17 L 11 19 L 14 16 L 11 13 z M 21 13 L 18 16 L 21 19 L 21 17 L 24 17 L 24 15 L 21 15 L 21 13 z M 15 18 L 15 21 L 13 21 L 16 24 L 19 21 L 17 21 L 17 18 L 15 18 z"/>
          </symbol>

          <symbol id="laptop" viewBox="0 0 640 640" preserveAspectRatio="xMinYMin slice">
            <path d="M624 416H381.54c-.74 19.81-14.71 32-32.74 32H288c-18.69 0-33.02-17.47-32.77-32H16c-8.8 0-16 7.2-16 16v16c0 35.2 28.8 64 64 64h512c35.2 0 64-28.8 64-64v-16c0-8.8-7.2-16-16-16zM576 48c0-26.4-21.6-48-48-48H112C85.6 0 64 21.6 64 48v336h512V48zm-64 272H128V64h384v256z"></path>
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

          <!--- packetfence icon --->
          <use v-if="node.type === 'packetfence'" :key="node.id"
            xlink:href="#packetfence"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            fill="#000000"
            @mouseover="mouseOverNode(node, $event)"
            @mouseout="mouseOutNode(node, $event)"
            @click="clickNode(node, $event)"
            :class="[ 'packetfence', { 'highlight': node.highlight } ]"
          />

          <!--- switch icon --->
          <use v-if="node.type === 'switch'" :key="node.id"
            xlink:href="#switch"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            @mouseout="mouseOutNode(node, $event)"
            @click="clickNode(node, $event)"
            :class="[ 'switch', { 'highlight': node.highlight } ]"
          />

          <!--- node icon --->
          <use v-if="node.type === 'node'" :key="node.id"
            xlink:href="#node"
            width="16" height="16"
            :id="`node-${node.id}`"
            :x="coords[i].x - (16 / 2)"
            :y="coords[i].y - (16 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            @mouseout="mouseOutNode(node, $event)"
            @click="clickNode(node, $event)"
            :class="[ 'node', node.color, { 'highlight': node.highlight } ]"
          />

          <!--- unknown icon --->
          <use v-if="node.type === 'unknown'" :key="node.id"
            xlink:href="#unknown"
            width="32" height="32"
            :id="`node-${node.id}`"
            :x="coords[i].x - (32 / 2)"
            :y="coords[i].y - (32 / 2)"
            @mouseover="mouseOverNode(node, $event)"
            @mouseout="mouseOutNode(node, $event)"
            @click="clickNode(node, $event)"
            :class="[ 'unknown', { 'highlight': node.highlight } ]"
          />

        </template>

        <!-- mini map -->
        <rect v-if="showMiniMap" class="innerMiniMap" v-bind="innerMiniMapProps" />
        <rect v-if="showMiniMap" class="outerMiniMap" v-bind="outerMiniMapProps"
          @mousedown.stop="mouseDownMiniMap($event)"
          @mousemove.capture="mouseMoveMiniMap($event)"
        />

      </svg>

      <!-- tooltip body -->
      <div v-for="tooltip in tooltips" :key="tooltip.node.id" class="tt-anchor"
        v-bind="tooltipAnchorAttrs(tooltip)">
        <div class="tt-container">
          <div class="tt-contents">
            <pre>{{ JSON.stringify(tooltip, null, 2) }}</pre>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script>
// import multiple `d3-*` micro-libraries into same namespace,
//  this has a smaller footprint than using full standalone `d3` library.
const d3 = {
  ...require('d3-force'),
  ...require('d3-array'), // `d3.extent`
  ...require('d3-scale') // `d3.scalePow`
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

const cleanId = (id) => {
  return id
    .replace(/^[^a-z0-9]/gi,'') // trim head
    .replace(/[^a-z0-9]$/gi, '') // trim tail
    .replace(/[^a-z0-9]/gi, '-') // replace all
}

require('typeface-b612-mono') // custom pixel font

export default {
  name: 'pf-network-graph',
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
    isLoading: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      simulation: null, // d3-force simulation
      localNodes: [], // private d3 nodes
      localLinks: [], // private d3 links

      colors: [ 'blue', 'red', 'yellow', 'green' ],
      lastX: null,
      lastY: null,
      zoom: 0,
      centerX: null,
      centerY: null,
      miniMapLatch: false,
      highlight: false,

      defaults: { // default options
        tooltipDistance: 10,
        miniMapHeight: 150,
        minZoom: 0,
        maxZoom: 4,
        padding: 100
      }
    }
  },
  computed: {
    config () {
      return { ...this.defaults, ...this.options }
    },
    bounds () {
      return {
        minX: Math.min(0, ...this.localNodes.map(n => n.x)),
        maxX: Math.max(0, ...this.localNodes.map(n => n.x)),
        minY: Math.min(0, ...this.localNodes.map(n => n.y)),
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
      let { dimensions: { height, width } = {}, centerX, centerY, zoom } = this
      if (!centerX && width) { // initialize center (x)
        centerX = width / 2
        this.$set(this, 'centerX', centerX)
      }
      if (!centerY && height) { // initialize center (y)
        centerY = height / 2
        this.$set(this, 'centerY', centerY)
      }
      const divisor = Math.pow(2, zoom)
      const widthScaled = width / divisor
      const heightScaled = height / divisor
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
      return ~~this.config.miniMapHeight > 0 && ~~this.config.maxZoom > 0
    },
    innerMiniMapProps () {
      const {
        outerMiniMapProps: { width: outerMiniMapWidth, height: outerMiniMapHeight } = {},
        viewBox: { minX = 0, minY = 0, width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = {},
        zoom
      } = this
      const divisor = Math.pow(2, zoom)
      return {
        x: minX + ((minX * outerMiniMapWidth) / (viewBoxWidth * divisor)),
        y: minY + ((minY * outerMiniMapHeight) / (viewBoxHeight * divisor)),
        width: outerMiniMapWidth / divisor,
        height: outerMiniMapHeight / divisor,
        'stroke-width': `${1 / divisor}px`
      }
    },
    outerMiniMapProps () {
      const { viewBox: { minX = 0, minY = 0, width = 0, height = 0 } = {}, zoom } = this
      const divisor = Math.pow(2, zoom)
      const aspectRatio = width / height
      return {
        x: minX,
        y: minY,
        width: (this.config.miniMapHeight * aspectRatio) / divisor,
        height: this.config.miniMapHeight / divisor,
        'stroke-width': `${1 / divisor}px`,
        'stroke-dasharray': 2 / divisor
      }
    },
    tooltips () {
      let tooltips = []
      this.localNodes.filter(node => node.highlight).forEach((node, index, nodes) => {
        const nodeBounded = this.coordBounded(node)
        let sourceAngle = 0
        let targetAngle = 0
        let tooltipAngle = 0
        let tooltipCoords = {}
        let tooltipCoordsBounded = {}
        switch (true) {

          case index === 0: // inner node (target only)
            targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
            tooltipAngle = (180 + targetAngle) % 360  // reverse
            tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, this.tooltipDistance)
            tooltipCoordsBounded = this.coordBounded(tooltipCoords)
            tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
            break

          case index === nodes.length - 1: // outer node (source only)
            sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
            tooltipAngle = (180 + sourceAngle) % 360 // reverse
            tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, this.tooltipDistance)
            tooltipCoordsBounded = this.coordBounded(tooltipCoords)
            tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
            break

          default: // middle nodes (source and target)
            sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
            targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
            tooltipAngle = ((sourceAngle + targetAngle) / 2) % 360
            // reverse angle (180°) if angle is inside knuckle
            if (Math.max(sourceAngle, targetAngle) - Math.min(sourceAngle, targetAngle) < 180) {
              tooltipAngle = (tooltipAngle + 180) % 360
            }
            tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, this.tooltipDistance)
            tooltipCoordsBounded = this.coordBounded(tooltipCoords)
            tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
            break
        }
      })
      return tooltips
    },
    tooltipDistance () {
      const divisor = Math.pow(2, this.zoom)
      let tooltipDistance = this.config.tooltipDistance / divisor // scale length
      return Math.max(3.5, tooltipDistance) // enforce minimum length to prevent overlapping
    }
    /*
    linksHighlighted () {
      return this.links.filter(link => link.highlight)
    },
    nodesHighlighted () {
      return this.nodes.filter(node => node.highlight)
    },
    tooltips () {
      const divisor = Math.pow(2, this.zoom)
      let tooltipDistance = this.tooltipDistance / divisor // scale length
      tooltipDistance = Math.max(3.5, tooltipDistance) // enforce minimum length to prevent overlapping
      return this.$store.getters[`${this.storeName}/tooltips`](tooltipDistance)
    }
    */
  },
  methods: {
    init () {
      if (!this.simulation) {
        this.simulation = d3.forceSimulation(this.localNodes)
          .force('charge', d3.forceManyBody().strength(d => -100))
          .force('link', d3.forceLink(this.localLinks))
          .force('x', d3.forceX())
          .force('y', d3.forceY())
      }
      console.log('INIT')
    },
    linkCoords (link) {
      const {
        coords: {
          [link.source.index]: { x: x1 = 0, y: y1 = 0 } = {},
          [link.target.index]: { x: x2 = 0, y: y2 = 0 } = {}
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
      const { dimensions: { height, width } = {}, zoom } = this
      const divisor = Math.pow(2, zoom)
      // restrict min/max x bounds
      const minX = width / divisor / 2
      const maxX = width - minX
      this.centerX = Math.min(Math.max(x, minX), maxX)
      // restrict min/max y bounds
      const minY = height / divisor / 2
      const maxY = height - minY
      this.centerY = Math.min(Math.max(y, minY), maxY)
    },
    mouseDownSvg (event) {
      const divisor = Math.pow(2, this.zoom)
      const { viewBox: { minX, minY } = {} } = this
      // get mouse delta and offset from top/left corner of current viewBox
      const { offsetX, offsetY } = event
      // calculate mouse offset from 0,0
      this.lastX = (offsetX / divisor) + minX
      this.lastY = (offsetY / divisor) + minY
    },
    mouseMoveSvg (event) {
      if (this.lastX && this.lastY) {
        const divisor = Math.pow(2, this.zoom)
        const { viewBox: { minX, minY } = {} } = this
        // get mouse delta and offset from top/left corner of current viewBox
        const { offsetX, offsetY } = event
        this.$nextTick(() => { // smoothen animation
          const x = this.centerX + (this.lastX - ((offsetX / divisor) + minX))
          const y = this.centerY + (this.lastY - ((offsetY / divisor) + minY))
          this.setCenter(x, y)
        })
      }
    },
    mouseUpSvg () {
      this.lastX = null
      this.lastY = null
    },
    mouseWheelSvg (event) {
      const divisor = Math.pow(2, this.zoom)
      const { viewBox: { minX, minY } = {}, centerX, centerY } = this
      // get mouse delta and offset from top/left corner of current viewBox
      const { deltaY = 0, offsetX, offsetY } = event
      // calculate mouse offset from 0,0
      const [ svgX, svgY ] = [ (offsetX / divisor) + minX, (offsetY / divisor) + minY ]
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
      const factor = Math.pow(2, this.zoom) / divisor
      // calculate new center x,y at the current mouse position
      const x = svgX - (deltaCenterX / factor)
      const y = svgY - (deltaCenterY / factor)
      this.setCenter(x, y)
    },
    mouseOverNode (node, event = null) {
      this.highlightNodeById(node.id) // highlight node
      this.highlight = (node.type === 'node') ? node.color : null
    },
    mouseOutNode (node, event = null) {
      this.highlightNodeById(null) // unhighlight node
      this.highlight = null
    },
    clickNode (node, event = null) {
      console.log('click Node', event, node)
    },
    highlightNodeById (id) {
      this.unhighlightNodes()
      this.unhighlightLinks()
      while (id !== null) { // travel to center of tree [ (target|source) -> (target|source) -> ... ]
        const nodeIndex = this.localNodes.findIndex(n => n.id === id)
        if (nodeIndex > -1) {
          this.$set(this.localNodes[nodeIndex], 'highlight', true) // highlight node
          const linkIndex = this.localLinks.findIndex(link => {
            const { target: { id: targetId } = {} } = link
            return targetId === id
          })
          if (linkIndex > -1) {
            this.$set(this.localLinks[linkIndex], 'highlight', true) // highlight link
            const { source: { id: sourceId } = {} } = this.localLinks[linkIndex]
            id = sourceId
          } else {
            id = null
          }
        } else {
          id = null
        }
      }
    },
    unhighlightNodes () {
      this.localNodes.forEach((node, index) => {
        if (node.highlight) {
          this.$set(this.localNodes[index], 'highlight', false)
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
      // get mouse delta and offset from top/left corner of current viewBox
      const { offsetX, offsetY } = event
      const {
        outerMiniMapProps: { width: outerMiniMapWidth, height: outerMiniMapHeight } = {},
        viewBox: { width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = {}
      } = this
      const x = viewBoxWidth * (offsetX / outerMiniMapWidth)
      const y = viewBoxHeight * (offsetY / outerMiniMapHeight)
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
      // set styles
      let style = []
      const {
        dimensions: { height: dHeight, width: dWidth } = {},
        viewBox: { minX, minY, width: vWidth, height: vHeight } = {}
      } = this
      if (x < minX || x > minX + vWidth || y < minY || y > minY + vHeight) {
        style.push('display: none') // hide if tooltip is outside viewBox
      } else {
        // scale coords to absolute offset from outer container (x: 0, y: 0)
        x = (x - minX) / vWidth * dWidth
        y = (y - minY) / vHeight * dHeight
      }
      style.push(`top: ${y}px`, `left: ${x}px;`)
      style = style.join('; ') // collapse
      // set classes
      const octa = Math.floor(((360 + angle - 22.5) % 360) / 45)
      const vertical = ['bottom', 'bottom', 'bottom', false, 'top', 'top', 'top', false][octa] // vertical position
      const horizontal = ['right', false, 'left', 'left', 'left', false, 'right', 'right'][octa] // horizontal position
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
      const bounds = this.bounds
      if (JSON.stringify(bounds) !== JSON.stringify({ minX: 0, maxX: 0, minY: 0, maxY: 0 })) {
        const xMult = (this.dimensions.width - (2 * this.config.padding)) / (bounds.maxX - bounds.minX)
        const yMult = (this.dimensions.height - (2 * this.config.padding)) / (bounds.maxY - bounds.minY)
        return {
          x: this.config.padding + (coord.x - bounds.minX) * xMult,
          y: this.config.padding + (coord.y - bounds.minY) * yMult
        }
      }
      return { x: 0, y: 0 }
    }
  },
  created () {
    this.init()
  },
  watch: {
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
        $u.forEach((id, index) => {
          switch (true) {
            case (id in $a && id in $b): // update
              index = $a[id]
              this.$set(this.localNodes, index, { ...this.localNodes[index], ...a[index] })
              break
            case !(id in $b): // insert
              index = this.localNodes.length
              this.$set(this.localNodes, index, { ...{ x: 0, y: 0 }, ...a[index] })
              break
            default: // delete
              index = $b[id]
              this.$delete(this.localNodes, index)
          }
        })
        this.simulation.nodes(this.localNodes) // push nodes to simulation
      },
      deep: true
    },
    /* watch `link` prop and rebuild private `localLinks` data on change */
    links: {
      handler: function (a, b) {
        let source
        let target
        // build lookup maps to determine insert/update/delete
        const $a = a.reduce((map, link, index) => { // build id => index object map
          map[`${link.source}-${link.target}`] = index; return map
        }, {})
        const $b = b.reduce((map, link, index) => { // build id => index object map
          map[`${link.source}-${link.target}`] = index; return map
        }, {})
        const $u = [...a, ...b].reduce((map, link) => { // build unique link.id array
          if (!map.includes(`${link.source}-${link.target}`)) {
            map.push(`${link.source}-${link.target}`)
          }
          return map
        }, [])
        $u.forEach((id, index) => {
          switch (true) {
            case (id in $a && id in $b): // update
              index = $a[id]
              source = this.localNodes.find(node => node.id === a[index].source)
              target = this.localNodes.find(node => node.id === a[index].target)
              this.$set(this.localLinks, index, { source, target })
              break
            case !(id in $b): // insert
              index = this.localLinks.length
              source = this.localNodes.find(node => node.id === a[index].source)
              target = this.localNodes.find(node => node.id === a[index].target)
              this.$set(this.localLinks, index, { source, target })
              break
            default: // delete
              index = $b[id]
              this.$delete(this.localLinks, index)
          }
        })
        this.simulation.force('link').links(this.localLinks) // push links to simulation
      },
      deep: true
    }
  }
}
</script>

<style lang="scss">
:root { /* defaults */
  --color-black: rgba(0, 0, 0, 1);
  --color-blue: rgba(66, 133, 244, 1);
  --color-red: rgba(219, 68, 55, 1);
  --color-yellow: rgba(244, 160, 0, 1);
  --color-green: rgba(15, 157, 88, 1);

  /* default highlight color */
  --highlight-color: var(--color-black);
}

.svgContainer {
  position: relative;
  /*overflow: hidden; /* prevent jitter from tooltip forcing window.clientHeight expansion */

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
        padding: 12px;
      }
    }
  }

  .tt-link {
    stroke: var(--highlight-color);
    /*stroke-linecap: round;*/
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
  }

  .bg {
    fill: var(--bg-fill);
    stroke: var(--bg-stroke);
  }
  .fg {
    fill: var(--fg-fill);
  }
  .icon {
    fill: var(--icon-fill);
  }

  .outerMiniMap {
    fill: rgba(255, 255, 255, 0.5);
    stroke: rgba(0, 0, 0, 0.5);
  }
  .innerMiniMap {
    fill: rgba(0, 255, 0, 0.75);
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
}
</style>
