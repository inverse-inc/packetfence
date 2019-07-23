<!--
https://plnkr.co/edit/iadT0ikcpKELU0eaE9f6?p=preview
https://bl.ocks.org/steveharoz/8c3e2524079a8c440df60c1ab72b5d03
https://flowingdata.com/2012/08/02/how-to-make-an-interactive-network-visualization/
-->
<template>
  <b-card no-body class="mt-3">
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Network'"></h4>
<p># nodes: {{ graph.nodes.length }}</p>
<p>zoom: {{ zoom }}</p>
<p>centerX: {{ centerX }}</p>
<p>centerY: {{ centerY }}</p>
<p>miniMapLatch: {{ (miniMapLatch) ? 'Y' : 'N' }}
    </b-card-header>
    <div class="card-body">
      <div ref="svgContainer" class="svgContainer">

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
        >
          <!-- SVG layer for mouse x, y offset capture during mouse drag (panning) -->
        </svg>

        <svg ref="svgDraw" class="svgDraw"
          xmlns="http://www.w3.org/2000/svg"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          width="100%"
          :height="dimensions.height+'px'"
          :viewBox="viewBoxString"
          :class="`zoom-${zoom}`"
          @mousedown.prevent="mouseDownSvg($event)"
          @mousewheel.prevent="mouseWheelSvg($event)"
        >
          <defs v-once>
            <symbol id="packetfence" viewBox="0 0 32 32" zzzpreserveAspectRatio="xMidYMid meet">
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

            <symbol id="router" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
              <circle class="bg" cx="16" cy="16" r="14"/>
              <path class="fg" d="M 16 4 C 9.3844277 4 4 9.3844277 4 16 C 4 22.615572 9.3844277 28 16 28 C 22.615572 28 28 22.615572 28 16 C 28 9.3844277 22.615572 4 16 4 z M 16 6 C 21.534692 6 26 10.465308 26 16 C 26 21.534692 21.534692 26 16 26 C 10.465308 26 6 21.534692 6 16 C 6 10.465308 10.465308 6 16 6 z M 16 8 L 13 11 L 15 11 L 15 14 L 17 14 L 17 11 L 19 11 L 16 8 z M 11 13 L 11 15 L 8 15 L 8 17 L 11 17 L 11 19 L 14 16 L 11 13 z M 21 13 L 18 16 L 21 19 L 21 17 L 24 17 L 24 15 L 21 15 L 21 13 z M 15 18 L 15 21 L 13 21 L 16 24 L 19 21 L 17 21 L 17 18 L 15 18 z"/>
            </symbol>

            <symbol id="laptop" viewBox="0 0 640 640" preserveAspectRatio="xMinYMin slice">
              <path d="M624 416H381.54c-.74 19.81-14.71 32-32.74 32H288c-18.69 0-33.02-17.47-32.77-32H16c-8.8 0-16 7.2-16 16v16c0 35.2 28.8 64 64 64h512c35.2 0 64-28.8 64-64v-16c0-8.8-7.2-16-16-16zM576 48c0-26.4-21.6-48-48-48H112C85.6 0 64 21.6 64 48v336h512V48zm-64 272H128V64h384v256z"></path>
            </symbol>

            <symbol id="node" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
              <circle cx="16" cy="16" r="14" />
            </symbol>
          </defs>

          <!--
          <line v-for="link in graph.links"
            v-bind="linkCoords(link)"
            :class="[ 'link', { 'highlight': link.highlight } ]"
          />
          -->

          <path v-for="link in graph.links"
            v-bind="linkPathAttrs(link)"
            :class="[ 'link', { 'highlight': link.highlight } ]"
          />

          <text v-for="link in graph.links" v-if="link.highlight" class="linkText" dy="-2">
            <textPath v-bind="linkSourceAttrs(link)">
              ↦{{ linkSourceText(link) }}
            </textPath>
            <textPath v-bind="linkTargetAttrs(link)">
              ↦{{ linkTargetText(link) }}
            </textPath>
          </text>

          <template v-for="(node, i) in graph.nodes">
            <!--- packetfence icon --->
            <use v-if="node.type === 'packetfence'"
              xlink:href="#packetfence"
width="32" height="32"
              :x="graph.coords[i].x - (32 / 2)"
              :y="graph.coords[i].y - (32 / 2)"
              fill="#000000"
              @mouseover="mouseOverNode(node, $event)"
              @mouseout="mouseOutNode(node, $event)"
              @click="clickNode(node, $event)"
              :class="[ 'packetfence', { 'highlight': node.highlight } ]"
            />
            <!--- router icon --->
            <use v-if="node.type === 'router'"
              xlink:href="#router"
width="32" height="32"
              :x="graph.coords[i].x - (32 / 2)"
              :y="graph.coords[i].y - (32 / 2)"
              @mouseover="mouseOverNode(node, $event)"
              @mouseout="mouseOutNode(node, $event)"
              @click="clickNode(node, $event)"
              :class="[ 'router', { 'highlight': node.highlight } ]"
            />
            <!--- laptop icon --->
            <use v-if="node.type === 'node'"
              xlink:href="#node"
width="16" height="16"
              :x="graph.coords[i].x - (16 / 2)"
              :y="graph.coords[i].y - (16 / 2)"
              @mouseover="mouseOverNode(node, $event)"
              @mouseout="mouseOutNode(node, $event)"
              @click="clickNode(node, $event)"
              :class="[ 'node', node.color, { 'highlight': node.highlight } ]"
            />
          </template>

          <rect class="innerMiniMap" v-bind="innerMiniMapProps" />
          <rect class="outerMiniMap" v-bind="outerMiniMapProps"
            @mousedown.stop="mouseDownMiniMap($event)"
            @mousemove.capture="mouseMoveMiniMap($event)"
          />

          <circle :cx="dimensions.width / 2" :cy="dimensions.height / 2" r="4" fill="#ff000"/>

        </svg>
      </div>
    </div>
  </b-card>
</template>

<script>
// import multiple `d3-*` micro-libraries into same namespace,
//  this has a smaller footprint than using full standalone `d3` library.
const d3 = {
  ...require('d3-force'),
  ...require('d3-array') // `d3-extent`
}

require('typeface-b612-mono')

import { createDebouncer } from 'promised-debounce'

export default {
  name: 'network',
  components: {},
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      dimensions: {
        height: Math.max(document.documentElement.clientHeight, window.innerHeight || 0) - 40,
        width: 0
      },

      colors: [ 'blue', 'red', 'yellow', 'green' ],

      // zoom/pan
      lastX: null,
      lastY: null,
      minZoom: 0,
      maxZoom: 4,
      zoom: 0,
      centerX: null,
      centerY: null,
      miniMapHeight: 150,
      miniMapLatch: false
    }
  },
  computed: {
    isLoading () {
      return this.$store.state[this.storeName].isLoading
    },
    graph () {
      return {
        bounds: this.$store.getters[`${this.storeName}/bounds`],
        coords: this.$store.getters[`${this.storeName}/coords`],
        links: this.$store.getters[`${this.storeName}/links`],
        nodes: this.$store.getters[`${this.storeName}/nodes`]
      }
    },
    windowSize () {
      return this.$store.getters['events/windowSize']
    },
    viewBox () {
      let { dimensions: { height, width } = {}, centerX, centerY, zoom } = this
      if (!centerX && width) { // initialize center (x)
        centerX = this.centerX = width / 2
      }
      if(!centerY && height) { // initialize center (y)
        centerY = this.centerY = height / 2
      }
      const divisor = Math.pow(2, zoom) // 0 = 1, 1 = 2, 2 = 4, 3 = 8, ...
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
    innerMiniMapProps () {
      const {
        outerMiniMapProps: { x, y, width: outerMiniMapWidth, height: outerMiniMapHeight } = {},
        viewBox: { minX = 0, minY = 0, width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = {},
        zoom,
        centerX,
        centerY
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
        width: (this.miniMapHeight * aspectRatio) / divisor,
        height: this.miniMapHeight / divisor,
        'stroke-width': `${1 / divisor}px`,
        'stroke-dasharray': 2 / divisor
      }
    }
  },
  methods: {
    linkCoords (link) {
      const coords = {
        x1: this.graph.coords[link.source.index].x,
        y1: this.graph.coords[link.source.index].y,
        x2: this.graph.coords[link.target.index].x,
        y2: this.graph.coords[link.target.index].y
      }
      return coords
    },
    linkId (link) {
      const { source: { id: sourceId = null } = {}, target: { id: targetId = null } = {} } = link
      return `link-${sourceId}-${targetId}`
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
      const { x1 = 0, y1 = 0, x2 = 0, y2 = 0 } = this.linkCoords(link)
      const x = x2 - x1
      const y = y2 - y1
      const l = Math.sqrt((x * x) + (y * y))
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
      const { dimensions: { height, width } = {}, centerX, centerY, zoom } = this
      const divisor = Math.pow(2, zoom) // 0 = 1, 1 = 2, 2 = 4, 3 = 8, ...
      // restrict min/max x bounds
      const minX = width / divisor / 2
      const maxX = width - minX
      this.centerX = Math.min(Math.max(x, minX), maxX)
      // restrict min/max y bounds
      const minY = height / divisor / 2
      const maxY = height - minY
      this.centerY = Math.min(Math.max(y, minY), maxY)
    },
    setDimensions () {
      // get width of svg container
      const { $refs: { svgContainer: { offsetWidth: width = 0 } = {} } = {} } = this
      this.$set(this.dimensions, 'width', width)
      this.$store.dispatch(`${this.storeName}/setDimensions`, this.dimensions)
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
      const { viewBox: { minX, minY, width, height } = {}, centerX, centerY } = this
      // get mouse delta and offset from top/left corner of current viewBox
      const { /*deltaX = 0, */deltaY = 0, offsetX, offsetY } = event
      // calculate mouse offset from 0,0
      const [ svgX, svgY ] = [ (offsetX / divisor) + minX, (offsetY / divisor) + minY ]
      // calculate mouse offset from center of current viewBox
      const [deltaCenterX, deltaCenterY] = [svgX - centerX, svgY - centerY]
      // handle zoom-in (-deltaY) and zoom-out (+deltaY)
      //  automatically match center of mouse pointer, so the
      //  x,y coord remains pinned at the mouse pointer after zoom.
      if (deltaY < 0) { // zoom in
        this.zoom = Math.min(++this.zoom, this.maxZoom)
      } else if (deltaY > 0) { // zoom out
        this.zoom = Math.max(--this.zoom, this.minZoom)
      }
      const factor = Math.pow(2, this.zoom) / divisor
      // calculate new center x,y where the current mouse position remains pinned
      const x = svgX - (deltaCenterX / factor)
      const y = svgY - (deltaCenterY / factor)
      this.setCenter(x, y)
    },
    mouseOverNode (node, event = null) {
      this.$store.dispatch(`${this.storeName}/highlightNodeById`, node.id)
      const { $refs: { svgDraw = {} } = {} } = this
      // remove highlight class
      svgDraw.classList.forEach(className => {
        if (/^highlight-/.test(className)) {
          svgDraw.classList.remove(className)
        }
      })
      if (node.type === 'node') {
        // add highlight class
        svgDraw.classList.add(`highlight-${node.color}`)
      }
    },
    mouseOutNode (node, event = null) {
      this.$store.dispatch(`${this.storeName}/highlightNodeById`, null)
      const { $refs: { svgDraw = {} } = {} } = this
      // remove highlight class
      svgDraw.classList.forEach(className => {
        if (/^highlight-/.test(className)) {
          svgDraw.classList.remove(className)
        }
      })
    },
    clickNode (node, event = null) {
      console.log('click Node', event, node)
    },
    mouseDownMiniMap (event) {
      // get mouse delta and offset from top/left corner of current viewBox
      const { offsetX, offsetY } = event
      const {
        outerMiniMapProps: { width: outerMiniMapWidth, height: outerMiniMapHeight } = {},
        viewBox: { width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = {}
      } = this
      const x = viewBoxWidth * ( offsetX / outerMiniMapWidth)
      const y = viewBoxHeight * ( offsetY / outerMiniMapHeight)
      this.setCenter(x, y)
      this.miniMapLatch = true  // latch miniMapLatch
    },
    mouseMoveMiniMap (event) {
      if (!(event.which)) {
        this.miniMapLatch = false
      }
      if (this.miniMapLatch) {
        this.mouseDownMiniMap(event)
      }
    }
  },
  mounted () {
    this.setDimensions()
    this.$store.dispatch(`${this.storeName}/startPolling`)
  },
  beforeDestroy () {
    this.$store.dispatch(`${this.storeName}/stopPolling`)
  },
  watch: {
    windowSize: {
      handler: function (a, b) {
        if (a.clientWidth !== b.clientWidth || a.clientHeight !== b.clientHeight) {
          this.setDimensions()
        }
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
    &.zoom-0 {
      .packetfence,
      .router,
      .node,
      .link {
        stroke-width: 2;
        &.highlight {
          stroke-width: 4;
        }
      }
    }
    &.zoom-1 {
      .packetfence,
      .router,
      .node,
      .link {
        stroke-width: 1;
        &.highlight {
          stroke-width: 2;
        }
      }
    }
    &.zoom-2 {
      .packetfence,
      .router,
      .node,
      .link {
        stroke-width: 0.5;
        &.highlight {
          stroke-width: 1;
        }
      }
    }
    &.zoom-3 {
      .packetfence,
      .router,
      .node,
      .link {
        stroke-width: 0.25;
        &.highlight {
          stroke-width: 0.5;
        }
      }
    }
    &.zoom-4 {
      .packetfence,
      .router,
      .node,
      .link {
        stroke-width: 0.125;
        &.highlight {
          stroke-width: 0.25;
        }
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

  .router {
    --bg-fill: rgba(255, 255, 255, 1);
    --bg-stroke: rgba(128, 128, 128, 1);
    --fg-fill: rgba(128, 128, 128, 1);
    &.highlight {
      --bg-fill: var(--highlight-color);
      --bg-stroke: var(--highlight-color);
      --fg-fill: rgba(255, 255, 255, 1);
    }
  }

  .node {
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
