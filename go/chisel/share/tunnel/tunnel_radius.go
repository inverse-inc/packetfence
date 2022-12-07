//go:build !test_radius
// +build !test_radius

package tunnel

import (
	"context"
	"os"
	"time"

	"github.com/inverse-inc/packetfence/go/chisel/share/tunnel/radius_proxy"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/tools/cache"
)

func radiusProxyFromKubernetes(t *Tunnel) (*radius_proxy.Proxy, chan struct{}, error) {
	clientset, err := clientSetFromEnv()
	if err != nil {
		return nil, nil, err
	}

	data, err := os.ReadFile(os.Getenv("K8S_NAMESPACE_PATH"))
	if err != nil {
		return nil, nil, err
	}

	namespace := string(data)
	pods, err := clientset.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{LabelSelector: radiusAuthK8Filter})
	if err != nil {
		return nil, nil, err
	}

	servers := []string{}
	for _, p := range pods.Items {
		addr := p.Status.PodIP + ":1812"
		t.Infof("Adding address %s", addr)
		servers = append(servers, addr)
	}

	radiusProxy := radius_proxy.NewProxy(
		&radius_proxy.ProxyConfig{
			Secret:         []byte(t.Config.RadiusSecret),
			Addrs:          servers,
			SessionTimeout: 20 * time.Second,
			Logger:         t.Logger,
		},
	)

	watchlist := cache.NewFilteredListWatchFromClient(
		clientset.CoreV1().RESTClient(),
		string(v1.ResourcePods),
		namespace,
		func(opts *metav1.ListOptions) {
			opts.LabelSelector = radiusAuthK8Filter
		},
	)

	_, controller := cache.NewInformer( // also take a look at NewSharedIndexInformer
		watchlist,
		&v1.Pod{},
		0, //Duration is int64
		cache.ResourceEventHandlerFuncs{
			AddFunc: func(obj interface{}) {
				pod := obj.(*v1.Pod)
				if isPodReady(pod) {
					address := pod.Status.PodIP + ":1812"
					t.Infof("Adding %s", address)
					radiusProxy.AddBackend(address)
					return
				}
			},
			DeleteFunc: func(obj interface{}) {
				pod := obj.(*v1.Pod)
				address := pod.Status.PodIP + ":1812"
				t.Infof("Removing %s", address)
				radiusProxy.DeleteBackend(address)
			},
			UpdateFunc: func(oldObj, newObj interface{}) {
				pod := newObj.(*v1.Pod)
				if isPodReady(pod) {
					address := pod.Status.PodIP + ":1812"
					t.Infof("Adding %s", address)
					radiusProxy.AddBackend(address)
					return
				}

				if pod.DeletionTimestamp != nil {
					address := pod.Status.PodIP + ":1812"
					t.Infof("%s is terminating removing", address)
					radiusProxy.DeleteBackend(address)
				}
			},
		},
	)
	stop := make(chan struct{})
	go controller.Run(stop)

	return radiusProxy, stop, nil
}
