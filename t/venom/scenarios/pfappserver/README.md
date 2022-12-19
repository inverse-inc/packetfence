# Venpm End To End (E2E) Testing - Pfappserver

## Test Suites

* [Configurator](../../test_suites/pfappserver_configurator/run_e2e.yml)

## Execution

This scenario uses Cypress E2E testing through a custom Venom executor [`html_e2e`](../../lib/html_e2e.yml).

## Psono User Variables

Create Psono variables in `Datastore -> PsonoCI -> Cypress Project ID` and `Datastore -> PsonoCI -> Cypress Recording Key`.

Set vagrant user variables in [`addons/vagrant/inventory/hosts`](../../../../addons/vagrant/inventory/hosts).

```bash
      _dsatkunas:
        vars:
          psono_secrets:
            pfappserver:
              cypress_project_id: '4c81fde5-be04-4eba-bab3-8bbfea1fcafa'
              cypress_record_key: 'd3d28327-16b9-47f0-8206-1c04fc0bebae'
```

## More Information

See the [Cypress E2E Testing README](../../../html/pfappserver/README.md) for more information about running the tests without Ansible or Venom.