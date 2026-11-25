package manager

import (
	"errors"
	"fmt"
	"slices"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
)

type (
	Node struct {
		Key      string
		Parents  []*Node
		Children []*Node
		ID       int
	}
	Graph struct {
		ValueToID map[string]*Node // direct acces to Node by key
		Nodes     []*Node          // access node by id, used internally
	}
)

// GetNodes return the list of nodes key in topological order
// item 0 must be built before item 1, etc
func (g *Graph) GetNodes() []string {
	nodes := make([]string, 0, len(g.Nodes))
	for _, node := range g.Nodes {
		nodes = append(nodes, node.Key)
	}
	return nodes
}

func (g *Graph) GetNodesFrom(key string) []string {
	nodes := make([]string, 0)
	_, ok := g.ValueToID[key]
	if !ok {
		return nil
	}

	return nodes
}

// TopologicalOrder execute the topoloical order in place
// The output graph will have the same nodes, but in a different order.
// Iterating over the nodes in the new graph ensure dependencies.
// The implementation uses a greedy algorithm in linear time O(|V|)
// The algorithm also detects cycles
func (g *Graph) TopologicalOrder() error {
	order := make([]*Node, 0, len(g.Nodes))
	// 0 initialized incomming degree of Nodes, 0 = no parent, id = node id in the original graph
	indeg := make([]int, len(g.Nodes))
	// compute degrees of each Node, meaning how many parents they have
	for _, node := range g.Nodes {
		for _, child := range node.Children {
			indeg[child.ID] += 1
		}
	}
	// get root nodes with no parents, order doesn't matter
	q := make([]*Node, 0, 4) // stack
	for _, node := range g.Nodes {
		if indeg[node.ID] == 0 {
			q = append(q, node)
		}
	}
	// while we have root node to process
	newID := len(g.Nodes) - 1 // we reverse order at the end, so set ID from N to 0
	var tmpNode *Node
	for len(q) > 0 {
		tmpNode, q = q[len(q)-1], q[:len(q)-1] // pop
		tmpNode.ID = newID                     // update new node id inplace
		newID--
		order = append(order, tmpNode) // add nodes in order of appearance
		for _, child := range tmpNode.Children {
			indeg[child.ID] -= 1      // we remove a parent, so update children
			if indeg[child.ID] == 0 { // new root (by (de)construction)
				q = append(q, child)
			}
		}
	}
	// graph doesn't change, so any cycle will result in a smaller output
	if len(order) != len(g.Nodes) {
		return errors.New("cycle detected")
	}
	// actual order is N-1 > N (meanings N-1 needs N), so we reverse it to simplify usage later
	slices.Reverse(order)
	g.Nodes = order // replace original nodes list
	return nil
}

// NamespacesToGraph takes the list of namespaces, and make a graph of dependencies
// The graph can contains multiple components, each component can contains multiple root node
// It doesn't matter for the algorithms, what we need is parent/child relation in the graph,
// and the topological order.
// Internal nodes use position in the graph as id, the key->id mapping is only used at application level
func NamespacesToGraph(namespaces []*namespace.NamespaceInfos) (*Graph, error) {
	g := Graph{
		Nodes:     make([]*Node, 0, len(namespaces)),
		ValueToID: make(map[string]*Node, len(namespaces)),
	}
	// first create all node with key->id mapping in the graph
	for i, ns := range namespaces {
		node := &Node{
			Key:      ns.Name,
			ID:       i,
			Parents:  make([]*Node, 0),
			Children: make([]*Node, 0),
		}
		g.ValueToID[ns.Name] = node
		g.Nodes = append(g.Nodes, node)
	}
	// then add parents/children id (not the key)
	for i, ns := range namespaces {
		node := g.Nodes[i] // same order as above, no need to map key->id here
		for _, childKey := range ns.DepResources {
			childNode, ok := g.ValueToID[childKey] // get the id in the graph from key
			if !ok {
				return nil, fmt.Errorf("unknown dependency '%s' in namespace '%s'", childKey, ns.Name)
			}
			childNode.Parents = append(childNode.Parents, node)
			node.Children = append(node.Children, childNode)
		}
	}
	return &g, nil
}
