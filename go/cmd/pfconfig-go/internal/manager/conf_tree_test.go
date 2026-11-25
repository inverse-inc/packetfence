package manager_test

import (
	"slices"
	"testing"

	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/manager"
	"github.com/inverse-inc/packetfence/go/cmd/pfconfig-go/internal/namespace"
)

var ns1 = []*namespace.NamespaceInfos{
	{Name: "root", DepResources: []string{"child1", "child2"}},
	{Name: "child1", DepResources: []string{"child1.1"}},
	{Name: "child2", DepResources: []string{"child1.1.1"}},
	{Name: "child1.1", DepResources: []string{}},
	{Name: "child1.1.1", DepResources: []string{}},
	{Name: "child3", DepResources: []string{"child1.1", "child1.1.1"}},
	{Name: "child4", DepResources: []string{}}, // alone, root + no children
}

var topoNs1Expected = []string{
	"child1.1", "child1", "child1.1.1", "child2", "root", "child3", "child4",
}

var nodesFromExpected = []struct {
	child    string
	expected []string
}{
	{"child1.1.1", []string{"child1.1.1", "child2", "root", "child3"}},
	{"child1.1", []string{"child1.1", "child1", "root", "child3"}},
	{"child2", []string{"child2", "root"}},
	{"root", []string{"root"}},
	{"child4", []string{"child4"}},
	{"child3", []string{"child3"}},
	{"INVALID", nil},
}

func TestNsToGraph(t *testing.T) {
	g, err := manager.NamespacesToGraph(ns1)
	if err != nil {
		t.Fatalf("bad ns definition: %s", err.Error())
	}
	if g == nil {
		t.Fatal("graph should not be nil")
	}
	for i, ns := range ns1 {
		node, ok := g.ValueToID[ns.Name]
		if !ok {
			t.Fatalf("key %s should exists", ns.Name)
		}
		if node == nil {
			t.Fatalf("node %s should not be nil", ns.Name)
		}
		if i != node.ID {
			t.Fatalf("bad node id %s, expected %d got %d", ns.Name, i, node.ID)
		}
		if len(ns.DepResources) != len(node.Children) {
			t.Fatalf("node %s has the wrong number of children, expected %d got %d", ns.Name, len(ns.DepResources), len(node.Children))
		}
	}
}

func TestTopo(t *testing.T) {
	g, err := manager.NamespacesToGraph(ns1)
	if err != nil {
		t.Fatalf("bad ns definition: %s", err.Error())
	}
	if err = g.TopologicalOrder(); err != nil {
		t.Fatalf("topo err %s", err.Error())
	}
	if len(g.Nodes) != len(ns1) {
		t.Fatalf("topo graph differs in node size, expected %d got %d", len(ns1), len(g.Nodes))
	}
	topo := g.GetNodesKeys()
	if len(topo) == 0 {
		t.Fatal("topo nodes should not be empty")
	}
	if len(topo) != len(topoNs1Expected) {
		t.Fatalf("topo nodes differs in size, expected %d got %d", len(topoNs1Expected), len(topo))
	}
	for idExpected, v := range topoNs1Expected {
		node, ok := g.ValueToID[v]
		if !ok {
			t.Fatalf("topo has no key %s", v)
		}
		if node.ID != idExpected {
			t.Fatalf("expected node order %d, got %d", idExpected, node.ID)
		}
		if topo[idExpected] != v {
			t.Fatalf("expected node %s, got %s", v, topo[idExpected])
		}
	}
}

func TestTopoNodes(t *testing.T) {
	g, err := manager.NamespacesToGraph(ns1)
	if err != nil {
		t.Fatalf("bad ns definition: %s", err.Error())
	}
	if err = g.TopologicalOrder(); err != nil {
		t.Fatalf("topo err %s", err.Error())
	}
	nodes := g.GetNodesKeys()
	if nodes == nil {
		t.Fatal("GetNodes should not be nil")
	}
	if slices.Compare(topoNs1Expected, nodes) != 0 {
		t.Fatalf("GetNodes differ in expected result: \nExpected: \t%v\nGot:\t\t%v", topoNs1Expected, nodes)
	}
	t.Run("GetNodesFrom", func(t *testing.T) {
		for i, test := range nodesFromExpected {
			tmp := g.GetNodesFrom(test.child)
			if slices.Compare(test.expected, tmp) != 0 {
				t.Errorf("GetNodesFrom %d differ in expected result: \nExpected: \t%v\nGot:\t\t%v", i, test.expected, tmp)
			}

		}
	})
}
