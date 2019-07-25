/**
* "network" store module
*/
import Vue from 'vue'
import store from '@/store'

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

const state = {
  initialized: false,
  dimensions: { // svg dimensions
    height: 0,
    width: 0
  },
  limit: 1000,
  sizeRange: [5, 10],
  padding: 20,
  simulation: null, // d3 simulation
  isLoading: false,
  pollingInterval: false,
  pollingIntervalMs: 100,
  nodes: [],
  links: []
}

const getters = {
  bounds: state => {
    return {
      minX: Math.min(...state.nodes.map(n => n.x)),
      maxX: Math.max(...state.nodes.map(n => n.x)),
      minY: Math.min(...state.nodes.map(n => n.y)),
      maxY: Math.max(...state.nodes.map(n => n.y))
    }
  },
  coords: (state, getters) => {
    const bounds = getters.bounds
    if (JSON.stringify(bounds) !== JSON.stringify({ minX: 0, maxX: 0, minY: 0, maxY: 0 })) {
      const xMult = (state.dimensions.width - 2 * state.padding) / (bounds.maxX - bounds.minX)
      const yMult = (state.dimensions.height - 2 * state.padding) / (bounds.maxY - bounds.minY)
      return state.nodes.map(node => {
        return {
          x: state.padding + (node.x - bounds.minX) * xMult,
          y: state.padding + (node.y - bounds.minY) * yMult
        }
      })
    }
    return state.nodes.map(node => {
      return { x: 0, y: 0 }
    })
  },
  coordBounded: (state, getters) => (coord) => {
    const bounds = getters.bounds
    if (JSON.stringify(bounds) !== JSON.stringify({ minX: 0, maxX: 0, minY: 0, maxY: 0 })) {
      const xMult = (state.dimensions.width - 2 * state.padding) / (bounds.maxX - bounds.minX)
      const yMult = (state.dimensions.height - 2 * state.padding) / (bounds.maxY - bounds.minY)
      return {
        x: state.padding + (coord.x - bounds.minX) * xMult,
        y: state.padding + (coord.y - bounds.minY) * yMult
      }
    }
    return { x: 0, y: 0 }
  },
  extent: () => nodes => {
    return d3.extent(nodes, (d) => d.links)
  },
  scale: state => node => {
    const scale = d3.scaleLog().domain(state.sizeRange).range(state.sizeRange.slice().reverse())
    return node.r + scale(node.r)
  },
  links: state => {
    return state.links
  },
  nodes: state => {
    return state.nodes.map(node => {
      return {
        ...node,
        ...{
          links: state.links.filter(link => [link.source, link.target].includes(node.index)).length
        }
      }
    })
  },
  tooltips: (state, getters) => (length) => {
    let tooltips = []
    state.nodes.filter(node => node.highlight).forEach((node, index, nodes) => {
      const nodeBounded = getters.coordBounded(node)
      let sourceAngle = 0
      let targetAngle = 0
      let tooltipAngle = 0
      let tooltipCoords = {}
      let tooltipCoordsBounded = {}
let stroke = '#000000'
      switch (true) {
        // inner node
        case index === 0: // inner node (target only)
          targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
          tooltipAngle = (180 + targetAngle) % 360  // reverse
          tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, length)
          tooltipCoordsBounded = getters.coordBounded(tooltipCoords)
          tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
          break

        // outer node
        case index === nodes.length - 1: // outer node (source only)
          sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
          tooltipAngle = (180 + sourceAngle) % 360 // reverse
          tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, length)
          tooltipCoordsBounded = getters.coordBounded(tooltipCoords)
          tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
          break

        // middle nodes (source and target)
        default:
          sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
          targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
          tooltipAngle = ((sourceAngle + targetAngle) / 2) % 360
          // reverse angle (180°) if angle is inside knuckle
          if (Math.max(sourceAngle, targetAngle) - Math.min(sourceAngle, targetAngle) < 180) {
            tooltipAngle = (tooltipAngle + 180) % 360
          }
          tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, length)
          tooltipCoordsBounded = getters.coordBounded(tooltipCoords)
          tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
          break
      }
    })
    return tooltips
  }
}

const actions = {
  startPolling: ({ commit, dispatch, state }) => {
    commit('INITIALIZE')
    if (!state.pollingInterval) {
      const pollingInterval = setInterval(() => {
        dispatch('doPoll')
      }, state.pollingIntervalMs)
      commit('SET_INTERVAL', pollingInterval)
      dispatch('doPoll')
    }
  },
  stopPolling: ({ commit, state }) => {
    if (state.pollingInterval) {
      clearInterval(state.pollingInterval)
      commit('CLEAR_INTERVAL')
    }
  },
  doPoll: ({ commit, dispatch, state }) => {
    if (state.nodes.length === 0) {
      // 1st iteration
      dispatch('addNodes', [{
        id: 0,
        x: null,
        y: null,
        type: 'packetfence',
        highlight: false,
        color: ['blue', 'red', 'yellow', 'green'][Math.floor(Math.random() * 4)]
      }])
    } else {
      // 2nd+ iterations
      //  generate some random stuff
      const length = state.nodes.length
      const sources = state.nodes.filter(node => ['packetfence', 'router'].includes(node.type))
      const random = Math.ceil(Math.random() * sources.length) - 1
      const source = sources[random]
      let type = 'node'
      switch (source.type) { // source type
        case 'packetfence':
          type = 'router'
          break
        case 'router':
          type = (Math.ceil(Math.random() * 100) > 90) ? 'router' : 'node'
          break
      }
      dispatch('addLinks', [{ source: source.id, target: length, highlight: false }])
      dispatch('addNodes', [{
        id: length,
        x: source.x,
        y: source.y,
        type,
        highlight: false,
        color: ['blue', 'red', 'yellow', 'green'][Math.floor(Math.random() * 4)]
      }])
    }

    if (state.nodes.length === 50) {
      clearInterval(state.pollingInterval)
      commit('CLEAR_INTERVAL')
    }
  },
  setDimensions: ({ commit }, dimensions) => {
    commit('DIMENSIONS', dimensions)
  },
  setLimit: ({ commit }, limit) => {
    commit('LIMIT', limit)
  },
  addNodes: ({ commit, getters, state }, nodes) => {
    let newNodes = []
    let oldNodes = []
    nodes.forEach(node => {
      const index = state.nodes.findIndex(n => n.id === node.id)
      if (index > -1) {
        // exists, update
        oldNodes.push({ index, node })
      } else {
        // not exists, insert
        newNodes.push(node)
      }
    })
    if (newNodes.length > 0) {
      commit('INSERT_NODES', { getters, nodes: newNodes })
    }
    if (oldNodes.length > 0) {
      commit('UPDATE_NODES', { getters, nodes: oldNodes })
    }
  },
  addLinks: ({ commit, getters, state }, links) => {
    let newLinks = []
    let oldLinks = []
    links.forEach(link => {
      let index = state.links.findIndex(l => l.source === link.source && l.target === link.target)
      if (index > -1) {
        // exists, update
        oldLinks.push({ index, link })
      } else {
        // not exists, insert
        newLinks.push(link)
      }
    })
    if (newLinks.length > 0) {
      commit('INSERT_LINKS', { getters, links: newLinks })
    }
    if (oldLinks.length > 0) {
      commit('UPDATE_LINKS', { getters, links: oldLinks })
    }
  },
  highlightNodeById: ({ commit, state }, id = null) => {
    commit('UNHIGHLIGHT_NODES')
    commit('UNHIGHLIGHT_LINKS')
    while (id !== null) { // travel to center of tree [ (target|source) -> (target|source) -> ... ]
      const nodeIndex = state.nodes.findIndex(n => n.id === id)
      if (nodeIndex > -1) {
        commit('HIGHLIGHT_NODE', nodeIndex)
        const linkIndex = state.links.findIndex(link => {
          const { target: { id: targetId } = {} } = link
          return targetId === id
        })
        if (linkIndex > -1) {
          commit('HIGHLIGHT_LINK', linkIndex)
          const { source: { id: sourceId } = {} } = state.links[linkIndex]
          id = sourceId
        } else {
          id = null
        }
      } else {
        id = null
      }
    }
  }
}

const mutations = {
  INITIALIZE: (state) => {
    if (!state.initialized) {
      state.simulation = d3.forceSimulation(state.nodes)
        .stop()  // pause animation until nodes/links exist
        .force('link', d3.forceLink(state.links).id(d => d.id).distance((link, index) => {
          const { target: { type } = {} } = link
          switch (true) {
            case type === 'router':
              return 20  // default
            default:
              return 10
          }
        }).strength((link, index) => {
          const { source: { links: sourceLinks } = {}, target: { type, links: targetLinks } = {} } = link
          switch (true) {
            case type === 'router':
              return 1
            default:
              // reduce the strength of links connected to heavily-connected nodes, improving stability
              return 1 / Math.max(sourceLinks, targetLinks)
          }
        })
        )
        //.force('link', d3.forceLink(state.links).distance(10).strength(1))
        .force('charge_force', d3.forceManyBody())
        //.force('center_force', d3.forceCenter(state.dimensions.width / 2, state.dimensions.height / 2))
        .force('radial_force', d3.forceRadial((node, index) => {
          const { type } = node
          switch (true) {
            case type === 'packetfence':
              return 0
            case type ==='router':
              return 0.5
            default:
              return 1
          }
        }, state.dimensions.width / 2, state.dimensions.height / 2).strength(0.1))
        /*
        .force('collide', d3.forceCollide(10)
          .radius((d) => {
            const { type } = d
            switch (true) {
              case type === 'packetfence':
                return 50
              case type === 'router':
                return 0
              default:
                return 2
            }
          })
          .strength(1)
          .iterations(2)
        )
        */
        /*
        .on('tick', () => {
console.log('TICK')
        })
        */
      state.initialized = true
    }
  },
  DIMENSIONS: (state, { height = null, width = null }) => {
    if (height && width) {
      state.dimensions = { height, width }
    }
  },
  LIMIT: (state, limit) => {
    state.limit = limit
  },
  SET_INTERVAL: (state, pollingInterval) => {
    state.pollingInterval = pollingInterval
  },
  CLEAR_INTERVAL: (state) => {
    state.pollingInterval = false
  },
  INSERT_NODES: (state, { getters, nodes }) => {
    state.simulation.stop()
    const countExtent = d3.extent(nodes, function (d) { return d.links })
    const	radiusScale = d3.scalePow().exponent(2).domain(countExtent).range(state.sizeRange)
    nodes.forEach((node, index) => {
      nodes[index].links = 1
      nodes[index].r = radiusScale(nodes[index].links)
      nodes[index].force = getters.scale(node)
    })

    /*
	  const countExtent = d3.extent(graph.nodes, function (d) { return d.connections })
		const	radiusScale = d3.scalePow().exponent(2).domain(countExtent).range(this.nodes.sizeRange);
    // Let D3 figure out the forces
		for(var i=0,ii=graph.nodes.length;i<ii;i++) {
			var node = graph.nodes[i];

			node.r = radiusScale(node.connections);
			node.force = this.forceScale(node);
		};
    */

    state.nodes = [ ...state.nodes, ...nodes ]

    state.simulation.nodes(state.nodes)
    state.simulation.force('link').links(state.links)
    state.simulation.alpha(0.3).restart()
    // state.simulation.restart()

    /*
    // Feed to simulation
		this.simulation
			.nodes(this.graph.nodes);
//
		this.simulation.force("link")
			.links(this.graph.links);

		this.simulation.alpha(0.3).restart();
    */
  },
  UPDATE_NODES: (state, { getters, nodes }) => {
    nodes.forEach(({ index = null, node = {} }) => {
      state.nodes[index] = node
    })
  },
  INSERT_LINKS: (state, { getters, links }) => {
    state.links = [ ...state.links, ...links ]
  },
  UPDATE_LINKS: (state, { getters, links }) => {
    links.forEach(({ index = null, link = {} }) => {
      state.links[index] = link
    })
  },
  UNHIGHLIGHT_NODES: (state) => {
    state.nodes.forEach((node, index) => {
      if (node.highlight) {
        state.nodes[index].highlight = false
      }
    })
  },
  HIGHLIGHT_NODE: (state, index) => {
    state.nodes[index].highlight = true
  },
  UNHIGHLIGHT_LINKS: (state) => {
    state.links.forEach((link, index) => {
      if (link.highlight) {
        state.links[index].highlight = false
      }
    })
  },
  HIGHLIGHT_LINK: (state, index) => {
    state.links[index].highlight = true
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
