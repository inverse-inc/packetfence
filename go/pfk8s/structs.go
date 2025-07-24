package pfk8s

type PatchPortAdd struct {
	Port       int    `json:"port"`
	TargetPort int    `json:"targetPort"`
	Protocol   string `json:"protocol"`
	Name       string `json:"name"`
}

type PatchPortDel struct {
	Name string `json:"name"`
}

type PatchPorts struct {
	Op    string      `json:"op"`
	Path  string      `json:"path"`
	Value interface{} `json:"value,omitempty"`
}

type Service struct {
	Status     Status   `json:"status"`
	Kind       string   `json:"kind"`
	APIVersion string   `json:"apiVersion"`
	Metadata   Metadata `json:"metadata"`
	Spec       Spec     `json:"spec"`
}

type Status struct {
	LoadBalancer map[string]interface{} `json:"loadBalancer"`
}

type Metadata struct {
	Annotations       map[string]string `json:"annotations"`
	ManagedFields     []ManagedField    `json:"managedFields"`
	Name              string            `json:"name"`
	Namespace         string            `json:"namespace"`
	UID               string            `json:"uid"`
	ResourceVersion   string            `json:"resourceVersion"`
	CreationTimestamp string            `json:"creationTimestamp"`
}

type ManagedField struct {
	Manager    string                 `json:"manager"`
	Operation  string                 `json:"operation"`
	APIVersion string                 `json:"apiVersion"`
	Time       string                 `json:"time"`
	FieldsType string                 `json:"fieldsType"`
	FieldsV1   map[string]interface{} `json:"fieldsV1"`
}

type Spec struct {
	ClusterIP             string            `json:"clusterIP"`
	Type                  string            `json:"type"`
	IPFamilies            []string          `json:"ipFamilies"`
	IPFamilyPolicy        string            `json:"ipFamilyPolicy"`
	InternalTrafficPolicy string            `json:"internalTrafficPolicy"`
	Ports                 []Port            `json:"ports"`
	ClusterIPs            []string          `json:"clusterIPs"`
	SessionAffinity       string            `json:"sessionAffinity"`
	Selector              map[string]string `json:"selector"`
}

type Port struct {
	Name       string  `json:"name"`
	Protocol   string  `json:"protocol"`
	Port       float64 `json:"port"`
	TargetPort float64 `json:"targetPort"`
}
