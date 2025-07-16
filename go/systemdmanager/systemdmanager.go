package systemdmanager

import (
	"fmt"
	"log"
	"strings"

	"github.com/godbus/dbus/v5"
)

type SystemdManager struct {
	conn *dbus.Conn
}

type SystemdService struct {
	Name        string
	Description string
	LoadState   string
	ActiveState string
	SubState    string
	// ObjectPath  dbus.ObjectPath
}

// NewSystemdManager creates a new SystemdManager instance
func NewSystemdManager() (*SystemdManager, error) {
	conn, err := dbus.SystemBus()
	if err != nil {
		return nil, fmt.Errorf("unable to connect to the system D-Bus: %v", err)
	}

	return &SystemdManager{conn: conn}, nil
}

// Close closes the D-Bus connection
func (sm *SystemdManager) Close() {
	sm.conn.Close()
}

// Start starts a systemd service
func (sm *SystemdManager) Start(serviceName string) error {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.StartUnit", 0, serviceName, "replace")
	if call.Err != nil {
		return fmt.Errorf("error starting %s: %v", serviceName, call.Err)
	}

	return nil
}

// Stop stops a systemd service
func (sm *SystemdManager) Stop(serviceName string) error {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.StopUnit", 0, serviceName, "replace")
	if call.Err != nil {
		return fmt.Errorf("error stopping %s: %v", serviceName, call.Err)
	}

	return nil
}

// Restart restarts a systemd service
func (sm *SystemdManager) Restart(serviceName string) error {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.RestartUnit", 0, serviceName, "replace")
	if call.Err != nil {
		return fmt.Errorf("error restarting %s: %v", serviceName, call.Err)
	}

	return nil
}

// Status gets the status of a service
func (sm *SystemdManager) Status(serviceName string) (string, string, error) {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	// Get the object path of the service
	call := systemd.Call("org.freedesktop.systemd1.Manager.GetUnit", 0, serviceName)
	if call.Err != nil {
		return "", "", fmt.Errorf("error getting service %s: %v", serviceName, call.Err)
	}

	var unitPath dbus.ObjectPath
	err := call.Store(&unitPath)
	if err != nil {
		return "", "", fmt.Errorf("error decoding object path: %v", err)
	}

	// Get properties
	unit := sm.conn.Object("org.freedesktop.systemd1", unitPath)

	activeState, err := unit.GetProperty("org.freedesktop.systemd1.Unit.ActiveState")
	if err != nil {
		return "", "", fmt.Errorf("error getting ActiveState: %v", err)
	}

	subState, err := unit.GetProperty("org.freedesktop.systemd1.Unit.SubState")
	if err != nil {
		return "", "", fmt.Errorf("error getting SubState: %v", err)
	}

	return activeState.Value().(string), subState.Value().(string), nil
}

// IsActive checks if a service is active
func (sm *SystemdManager) IsActive(serviceName string) (bool, error) {
	activeState, _, err := sm.Status(serviceName)
	if err != nil {
		return false, err
	}

	return activeState == "active", nil
}

// Enable enables a service at startup
func (sm *SystemdManager) Enable(serviceName string) error {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.EnableUnitFiles", 0,
		[]string{serviceName}, false, true)
	if call.Err != nil {
		return fmt.Errorf("error enabling %s: %v", serviceName, call.Err)
	}

	return nil
}

// Disable disables a service at startup
func (sm *SystemdManager) Disable(serviceName string) error {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.DisableUnitFiles", 0,
		[]string{serviceName}, false)
	if call.Err != nil {
		return fmt.Errorf("error disabling %s: %v", serviceName, call.Err)
	}

	return nil
}

func (sm *SystemdManager) ListSystemdServices() ([]SystemdService, error) {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.ListUnits", 0)
	if call.Err != nil {
		return nil, call.Err
	}

	var units [][]interface{}
	err := call.Store(&units)
	if err != nil {
		return nil, err
	}

	var services []SystemdService
	for _, unit := range units {
		if len(unit) >= 6 {
			name := unit[0].(string)

			// Filtrer uniquement les services (.service)
			if strings.HasSuffix(name, ".service") {
				service := SystemdService{
					Name:        name,
					Description: unit[1].(string),
					LoadState:   unit[2].(string),
					ActiveState: unit[3].(string),
					SubState:    unit[4].(string),
				}
				services = append(services, service)
			}
		}
	}

	return services, nil
}

func (sm *SystemdManager) getActiveServices() {
	systemd := sm.conn.Object("org.freedesktop.systemd1", "/org/freedesktop/systemd1")

	call := systemd.Call("org.freedesktop.systemd1.Manager.ListUnitsByPatterns", 0,
		[]string{"active"}, []string{"*.service"})
	if call.Err != nil {
		log.Fatal("Error calling ListUnitsByPatterns:", call.Err)
	}

	var units [][]interface{}
	err := call.Store(&units)
	if err != nil {
		log.Fatal("Error to decode:", err)
	}

	fmt.Println("\nActives Services only:")
	for _, unit := range units {
		if len(unit) >= 4 {
			name := unit[0].(string)
			description := unit[1].(string)
			activeState := unit[3].(string)
			fmt.Printf("%-40s %-15s %s\n", name, activeState, description)
		}
	}
}
