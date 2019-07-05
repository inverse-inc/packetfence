<!--
https://plnkr.co/edit/iadT0ikcpKELU0eaE9f6?p=preview
-->
<template>
  <b-card no-body class="mt-3">
    <b-card-header>
      <h4 class="d-inline mb-0" v-t="'Network'"></h4>


      # nodes: {{ graph.nodes.length }}
<!--
<pre>{{ JSON.stringify(graph.nodes, null, 2) }}</pre>
<pre>{{ JSON.stringify(graph.links, null, 2) }}</pre>
-->

    </b-card-header>
    <div class="card-body">
      <div ref="svgContainer">
        <svg ref="svg"
          xmlns="http://www.w3.org/2000/svg"
          xmlns:xlink="http://www.w3.org/1999/xlink"
          width="100%"
          :height="dimensions.height+'px'"
          @mousemove="drag($event)"
          @mouseup="drop()"
          v-show="graph.bounds.minX"
        >
          <defs>
            <symbol id="packetfence" viewBox="0 0 120 75" preserveAspectRatio="xMinYMin slice">
                <path d="M0.962,14.55l26.875,9.047l0.182,10.494l-27.057,-8.683l0,-10.858Z" />
                <path d="M0.962,27.577l26.875,9.047l0.182,10.496l-27.057,-8.687l0,-10.856l0,0Z" />
                <path d="M91.87,23.96l26.876,9.045l0.181,10.496l-27.057,-8.685l0,-10.856l0,0Z" />
                <path d="M91.87,36.988l26.876,9.046l0.181,10.493l-27.057,-8.684l0,-10.855l0,0Z" />
                <path d="M48.22,17.265c3.187,0 5.771,2.592 5.771,5.791l0,26.596c0,3.199 -2.584,5.791 -5.771,5.791c-3.188,0 -5.772,-2.592 -5.772,-5.791l0,-26.596c0,-3.199 2.584,-5.791 5.772,-5.791" />
                <path d="M60.485,17.265c3.188,0 5.772,2.592 5.772,5.791l0,26.596c0,3.199 -2.584,5.791 -5.772,5.791c-3.187,0 -5.771,-2.592 -5.771,-5.791l0,-26.596c0,-3.199 2.584,-5.791 5.771,-5.791" />
                <path d="M72.751,17.265c3.187,0 5.771,2.592 5.771,5.791l0,26.596c0,3.199 -2.584,5.791 -5.771,5.791c-3.188,0 -5.772,-2.592 -5.772,-5.791l0,-26.596c0,-3.199 2.584,-5.791 5.772,-5.791" />
                <path d="M35.413,14.732c1.565,-2.172 5.411,-17.492 5.411,-14.295l0.181,49.215c0,3.199 -2.584,5.791 -5.773,5.791c-3.186,0 -5.77,-2.592 -5.77,-5.791l0,-26.596c0,-3.199 4.085,-5.732 5.951,-8.324" />
                <path d="M84.835,57.388c-1.564,2.17 -5.41,17.49 -5.41,14.293l-0.182,-49.215c0,-3.197 2.584,-5.789 5.774,-5.789c3.187,0 5.772,2.592 5.772,5.789l0,26.6c0,3.195 -4.085,5.73 -5.954,8.322" />
            </symbol>

            <symbol id="router" viewBox="0 0 32 32" preserveAspectRatio="xMinYMin slice">
              <path d="M 16 4 C 9.3844277 4 4 9.3844277 4 16 C 4 22.615572 9.3844277 28 16 28 C 22.615572 28 28 22.615572 28 16 C 28 9.3844277 22.615572 4 16 4 z M 16 6 C 21.534692 6 26 10.465308 26 16 C 26 21.534692 21.534692 26 16 26 C 10.465308 26 6 21.534692 6 16 C 6 10.465308 10.465308 6 16 6 z M 16 8 L 13 11 L 15 11 L 15 14 L 17 14 L 17 11 L 19 11 L 16 8 z M 11 13 L 11 15 L 8 15 L 8 17 L 11 17 L 11 19 L 14 16 L 11 13 z M 21 13 L 18 16 L 21 19 L 21 17 L 24 17 L 24 15 L 21 15 L 21 13 z M 15 18 L 15 21 L 13 21 L 16 24 L 19 21 L 17 21 L 17 18 L 15 18 z"/>
            </symbol>

            <symbol id="laptop" viewBox="0 0 640 640" preserveAspectRatio="xMinYMin slice">
              <path d="M624 416H381.54c-.74 19.81-14.71 32-32.74 32H288c-18.69 0-33.02-17.47-32.77-32H16c-8.8 0-16 7.2-16 16v16c0 35.2 28.8 64 64 64h512c35.2 0 64-28.8 64-64v-16c0-8.8-7.2-16-16-16zM576 48c0-26.4-21.6-48-48-48H112C85.6 0 64 21.6 64 48v336h512V48zm-64 272H128V64h384v256z"></path>
            </symbol>
          </defs>
          <line v-for="link in graph.links"
            v-bind="linkCoords(link)"
            stroke="black"
            stroke-width="2"
          />
          <!--
          <circle v-for="(node, i) in nodes"
            :cx="coords[i].x"
            :cy="coords[i].y"
            :r="20"
            :fill="colors[Math.ceil(Math.sqrt(node.id))]"
            stroke="white"
            stroke-width="1"
            @mousedown="currentMove = {x: $event.screenX, y: $event.screenY, node: node}"
          />
          -->
          <template v-for="(node, i) in graph.nodes">
            <!--- packetfence icon --->
            <use v-if="node.type === 'packetfence'"
              xlink:href="#packetfence"
 width="32" height="32"
              :x="graph.coords[i].x - (32 / 2)"
              :y="graph.coords[i].y - (32 / 2)"
              fill="#000000"
            />
            <!--- router icon --->
            <use v-if="node.type === 'router'"
              xlink:href="#router"
 width="32" height="32"
              :x="graph.coords[i].x - (32 / 2)"
              :y="graph.coords[i].y - (32 / 2)"
              :fill="colors[Math.ceil(Math.sqrt(node.index))]"
            />
            <!--- laptop icon --->
            <use v-if="node.type === 'node'"
              xlink:href="#laptop"
 width="32" height="32"
              :x="graph.coords[i].x - (32 / 2)"
              :y="graph.coords[i].y - (32 / 2)"
              :fill="colors[Math.ceil(Math.sqrt(node.index))]"
            />
          </template>
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
      padding: 20,
      colors: ['#2196F3', '#E91E63', '#7E57C2', '#009688', '#00BCD4', '#EF6C00', '#4CAF50', '#FF9800', '#F44336', '#CDDC39', '#9C27B0'],
      currentMove: null,
      lastNodes: null
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
/*
      console.log('>>> link', JSON.stringify(link, null, 2))
      console.log('>>> coords', JSON.stringify(this.graph.coords[0], null, 2))
*/
    },
    setDimensions () {
      // get width of svg container
      const { $refs: { svgContainer: { offsetWidth: width = 0 } = {} } = {} } = this
      this.$set(this.dimensions, 'width', width)
      this.$store.dispatch(`${this.storeName}/setDimensions`, this.dimensions)
    },
    drag (event) {
      /*
      if (this.currentMove) {
        this.currentMove.node.fx = this.currentMove.node.x - (this.currentMove.x - event.screenX) * (this.bounds.maxX - this.bounds.minX) / (this.svgWidth - 2 * this.padding)
        this.currentMove.node.fy = this.currentMove.node.y -(this.currentMove.y - event.screenY) * (this.bounds.maxY - this.bounds.minY) / (this.svgHeight - 2 * this.padding)
        this.currentMove.x = event.screenX
        this.currentMove.y = event.screenY
      }
      */
    },
    drop () {
      /*
      if (this.currentMove) {
        delete this.currentMove.node.fx
        delete this.currentMove.node.fy
      }
      this.currentMove = null
      this.simulation.alpha(1)
      this.simulation.restart()
      */
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
