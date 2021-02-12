package common

import (
	"context"
	"fmt"

	"github.com/inverse-inc/packetfence/go/unifiedapiclient"
)

type NodeCategory struct {
	CategoryID                  string `json:"category_id"`
	Name                        string `json:"name"`
	MaxNodesPerPID              string `json:"max_nodes_per_pid"`
	Notes                       string `json:"notes"`
	IncludeParentACLs           string `json:"include_parent_acls"`
	FingerbankDynamicAccessList string `json:"fingerbank_dynamic_access_list"`
	ACLs                        string `json:"acls"`
}

func FetchNodeCategory(ctx context.Context, id int) (NodeCategory, unifiedapiclient.UnifiedAPIError) {
	client := unifiedapiclient.NewFromConfig(ctx)

	resp := struct {
		Item NodeCategory
	}{}
	err := client.Call(ctx, "GET", fmt.Sprintf("/api/v1/node_category/%d", id), &resp)
	return resp.Item, err
}
