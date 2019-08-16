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

const cleanId = (id) => {
  return id
    .replace(/^[^a-z0-9]/gi,'') // trim head
    .replace(/[^a-z0-9]$/gi, '') // trim tail
    .replace(/[^a-z0-9]/gi, '-') // replace all
}

const state = {
  dimensions: { // svg dimensions
    height: 0,
    width: 0
  },
  limit: 1000,
  sizeRange: [5, 10],
  padding: 100,
  simulation: false, // d3 simulation
  pollingInterval: false,
  pollingIntervalMs: 100,
  nodes: [],
  links: [],
  tooltips: [],
  tooltipDistance: 10,
  test: false
}

const getters = {
  test: state => {
    return state.nodes.length
  },
  bounds: state => {
    return {
      minX: Math.min(0, ...state.nodes.map(n => n.x)),
      maxX: Math.max(0, ...state.nodes.map(n => n.x)),
      minY: Math.min(0, ...state.nodes.map(n => n.y)),
      maxY: Math.max(0, ...state.nodes.map(n => n.y))
    }
  },
  coords: (state, getters) => {
    const { minX = 0, maxX = 0, minY = 0, maxY = 0 } = getters.bounds
    if ((minX | maxX | minY | maxY) !== 0) { // not all zero's
      const xMult = (state.dimensions.width - (2 * state.padding)) / (maxX - minX)
      const yMult = (state.dimensions.height - (2 * state.padding)) / (maxY - minY)
      return state.nodes.map(node => {
        return {
          x: state.padding + (node.x - minX) * xMult,
          y: state.padding + (node.y - minY) * yMult
        }
      })
    }
    return state.nodes.map(node => { // all zero's
      return { x: 0, y: 0 }
    })
  },
  coordBounded: (state, getters) => (coord) => {
    const bounds = getters.bounds
    if (JSON.stringify(bounds) !== JSON.stringify({ minX: 0, maxX: 0, minY: 0, maxY: 0 })) {
      const xMult = (state.dimensions.width - (2 * state.padding)) / (bounds.maxX - bounds.minX)
      const yMult = (state.dimensions.height - (2 * state.padding)) / (bounds.maxY - bounds.minY)
      return {
        x: state.padding + (coord.x - bounds.minX) * xMult,
        y: state.padding + (coord.y - bounds.minY) * yMult
      }
    }
    return { x: 0, y: 0 }
  },
  dimensions: state => {
    return state.dimensions
  },
  padding: state => {
    return state.padding
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
    return state.nodes
  },
  tooltips: state => {
    return state.tooltips
  }
}

const actions = {
  startPolling: ({ commit, dispatch, state }) => {
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
      const sources = state.nodes.filter(node => ['packetfence', 'switch'].includes(node.type))
      const random = Math.ceil(Math.random() * sources.length) - 1
      const source = sources[random]
      let type = 'node'
      switch (source.type) { // source type
        case 'packetfence':
          type = 'switch'
          break
        case 'switch':
          type = (Math.ceil(Math.random() * 100) > 90) ? 'switch' : 'node'
          break
      }
      dispatch('addNodes', [{
        id: length,
        x: source.x,
        y: source.y,
        type,
        highlight: false,
        color: ['blue', 'red', 'yellow', 'green'][Math.floor(Math.random() * 4)]
      }])
      dispatch('addLinks', [{ source: source.id, target: length, highlight: false }])
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
    commit('SET_LIMIT', limit)
  },
  setTooltipDistance: ({ commit }, distance) => {
    commit('SET_TOOLTIP_DISTANCE', distance)
  },
  addNodes: ({ commit, getters, state }, nodes) => {
    commit('INIT')
    let newNodes = []
    let oldNodes = []
    nodes.forEach(node => {
      node.id = cleanId(node.id) // clean id
      const index = state.nodes.findIndex(n => n.id === node.id)
      if (index > -1) {
        // exists, update
        oldNodes.push({ index, node })
      } else {
        // not exists, insert
        newNodes.push(node)
      }
    })
    if (newNodes.length > 0 || oldNodes.length > 0) {
      commit('STOP')
      if (newNodes.length > 0) {
        commit('INSERT_NODES', { getters, nodes: newNodes })
      }
      if (oldNodes.length > 0) {
        commit('UPDATE_NODES', { getters, nodes: oldNodes })
      }
      commit('FORCE')
      commit('START')
    }
  },
  addLinks: ({ commit, getters, state }, links) => {
    commit('INIT')
    let newLinks = []
    let oldLinks = []
    links.forEach(link => {
      link.source = cleanId(link.source) // clean id
      link.target = cleanId(link.target) // clean id
      // let index = state.links.findIndex(l => l.source === link.source && l.target === link.target)
      let index = state.links.findIndex(l => [l.source, l.source.id].includes(link.source) && [l.target, l.target.id].includes(link.target))
      if (index > -1) {
        // exists, update
        oldLinks.push({ index, link })
      } else {
        // not exists, insert
        newLinks.push(link)
      }
    })
    if (newLinks.length > 0 || oldLinks.length > 0) {
      commit('STOP')
      if (newLinks.length > 0) {
        commit('INSERT_LINKS', { getters, links: newLinks })
      }
      if (oldLinks.length > 0) {
        commit('UPDATE_LINKS', { getters, links: oldLinks })
      }
      commit('FORCE')
      commit('START')
    }
  },
  highlightNodeById: ({ commit, getters, state }, id = null) => {
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
    commit('MAKE_TOOLTIPS', { getters })
  }
}

const mutations = {
  DIMENSIONS: (state, { height = null, width = null }) => {
    if (height && width) {
      Vue.set(state, 'dimensions', { height, width })
    }
  },
  INIT: (state) => {
    if (!state.simulation) {
      /* TRY 1
      state.simulation = d3.forceSimulation(state.nodes)
        .force('link', d3.forceLink(state.links).id(d => d.id))
      */
      Vue.set(state, 'simulation', d3.forceSimulation(state.nodes)
        .stop()
        .alpha(0.3)
        .force('charge', d3.forceManyBody().strength(d => -100))
        .force('link', d3.forceLink(state.links))
        .force('x', d3.forceX())
        .force('y', d3.forceY())
      )
    }
  },
  START: (state, alpha = 0.3) => {
    state.simulation.alpha(alpha).restart()
  },
  STOP: (state) => {
    state.simulation.stop()
  },
  FORCE: (state) => {
    state.simulation.nodes(state.nodes)
    state.simulation.force('link', d3.forceLink(state.links).id(d => d.id))
return
    state.simulation = d3.forceSimulation(state.nodes)
      .force('link', d3.forceLink(state.links).id(d => d.id))
      //.force('radius', d3.forceCollide().radius(5))
      //.force('charge', d3.forceManyBody())
      /*
      .force('radial_force', d3.forceRadial((node, index) => {
        const { type } = node
        switch (true) {
          case type === 'packetfence':
            return 0
          case type === 'switch':
          case type === 'unknown':
            return 200
          default:
            return 100
        }
      }, state.dimensions.width / 2, state.dimensions.height / 2))
      .on('tick', () => {
        console.log('TICK', state.nodes[0].x, state.nodes[0].y)
      })
    */
  },
  FORCE_OLD: (state) => {
    /*
    state.simulation.force('link', d3.forceLink(state.links).id(d => d.id).distance((link, index) => {
      const { target: { type } = {} } = link
      switch (true) {
        case type === 'switch':
        case type === 'unknown':
          return 20  // default
        default:
          return 10
      }
    }).strength((link, index) => {
      const { source: { links: sourceLinks } = {}, target: { type, links: targetLinks } = {} } = link
      switch (true) {
        case type === 'switch':
        case type === 'unknown':
          return 1
        default:
          // reduce the strength of links connected to heavily-connected nodes, improving stability
          return 1 / Math.max(sourceLinks, targetLinks)
      }
    })
    )
    */
    /*
    .force('charge_force', d3.forceManyBody())
    .force('collide', d3.forceCollide(10)
      .radius((d) => {
        const { type } = d
        switch (true) {
          case type === 'packetfence':
            return 50
          case type === 'switch':
          case type === 'unknown':
            return 0
          default:
            return 2
        }
      })
      .strength(1)
      .iterations(2)
    )
    .on('tick', () => {
console.log('TICK')
    })
    */
  },
  SET_INTERVAL: (state, pollingInterval) => {
    Vue.set(state, 'pollingInterval', pollingInterval)
  },
  SET_LIMIT: (state, limit) => {
    Vue.set(state, 'limit', limit)
  },
  CLEAR_INTERVAL: (state) => {
    Vue.set(state, 'pollingInterval', false)
  },
  INSERT_NODES: (state, { getters, nodes }) => {
    /*
    const countExtent = d3.extent(nodes, function (d) {
      return state.links.filter(link => link.source.id === d.id).length
    })
    const	radiusScale = d3.scalePow().exponent(2).domain(countExtent).range(state.sizeRange)
    nodes.forEach((node, index) => {
      nodes[index].links = 1
      nodes[index].r = radiusScale(nodes[index].links)
      nodes[index].force = getters.scale(node)
      if (node.type === 'packetfence') { // force center x/y
        nodes[index].fx = () => state.dimensions.width / 2
        nodes[index].fy = () => state.dimensions.height / 2
      }
    })
    */
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
    // const newNodes = state.nodes
    // newNodes.push(...nodes)
    // state.nodes.push(...nodes)
    // state.nodes = Object.assign({}, [ ...state.nodes, ...nodes ])
    Vue.set(state, 'nodes', [ ...state.nodes, ...nodes ])
    // state.simulation.nodes(state.nodes)
    // state.simulation.force('link').links(state.links)
    // state.simulation.alpha(0.3).restart()
    // state.simulation.restart()
  },
  UPDATE_NODES: (state, { getters, nodes }) => {
    nodes.forEach(({ index = null, node = {} }) => {
      Vue.set(state.nodes, index, Object.assign(state.nodes[index], node)) // keep reactivity
    })
  },
  INSERT_LINKS: (state, { getters, links }) => {
    links = links.map(link => {
      return {
        source: state.nodes.find(node => node.id === link.source), // reference link source to node
        target: state.nodes.find(node => node.id === link.target) // reference link target to node
      }
    })
    // state.links.push(...links)
    // state.links = Object.assign({}, [ ...state.links, ...links ])
    Vue.set(state, 'links',  [ ...state.links, ...links ])
  },
  UPDATE_LINKS: (state, { getters, links }) => {
    links.forEach(({ index = null, link = {} }) => {
      Vue.set(state.links, index, Object.assign(state.links[index], link)) // keep reactivity
    })
  },
  UNHIGHLIGHT_NODES: (state) => {
    state.nodes.forEach((node, index) => {
      if (node.highlight) {
        Vue.set(state.nodes[index], 'highlight', false)
      }
    })
  },
  HIGHLIGHT_NODE: (state, index) => {
    Vue.set(state.nodes[index], 'highlight', true)
  },
  UNHIGHLIGHT_LINKS: (state) => {
    state.links.forEach((link, index) => {
      if (link.highlight) {
        Vue.set(state.links[index], 'highlight', false)
      }
    })
  },
  HIGHLIGHT_LINK: (state, index) => {
    Vue.set(state.links[index], 'highlight', true)
  },
  SET_TOOLTIP_DISTANCE: (state, distance) => {
    Vue.set(state, 'tooltipDistance', distance)
  },
  MAKE_TOOLTIPS: (state, { getters }) => {
    let tooltips = []
    state.nodes.filter(node => node.highlight).forEach((node, index, nodes) => {
      const nodeBounded = getters.coordBounded(node)
      let sourceAngle = 0
      let targetAngle = 0
      let tooltipAngle = 0
      let tooltipCoords = {}
      let tooltipCoordsBounded = {}
      switch (true) {

        case index === 0: // inner node (target only)
          targetAngle = getAngleFromCoords(node.x, node.y, nodes[index + 1].x, nodes[index + 1].y)
          tooltipAngle = (180 + targetAngle) % 360  // reverse
          tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, state.tooltipDistance)
          tooltipCoordsBounded = getters.coordBounded(tooltipCoords)
          tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
          break

        case index === nodes.length - 1: // outer node (source only)
          sourceAngle = getAngleFromCoords(node.x, node.y, nodes[index - 1].x, nodes[index - 1].y)
          tooltipAngle = (180 + sourceAngle) % 360 // reverse
          tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, state.tooltipDistance)
          tooltipCoordsBounded = getters.coordBounded(tooltipCoords)
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
          tooltipCoords = getCoordFromCoordAngle(node.x, node.y, tooltipAngle, state.tooltipDistance)
          tooltipCoordsBounded = getters.coordBounded(tooltipCoords)
          tooltips.push({ node, line: { angle: tooltipAngle, x1: nodeBounded.x, y1: nodeBounded.y, x2: tooltipCoordsBounded.x, y2: tooltipCoordsBounded.y } })
          break
      }
    })
    Vue.set(state, 'tooltips', tooltips)
  }
}

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations
}
