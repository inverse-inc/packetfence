# Self-hosted runner job hooks

Hooks the GitHub Actions runner service runs around every job on our
self-hosted build machines. They are versioned here so they get reviewed, but
they are **not** picked up from the repository: the runner reads the hook path
from its own `.env`, so installing or changing a hook is a host-side action on
each runner (see [Install](#install)).

## Why

Container jobs run as root, and `$GITHUB_WORKSPACE` (`/__w/<repo>/<repo>`
inside the container) is a bind mount of the runner's real workspace. Every
file such a job writes there stays root-owned after the container is gone:
`actions/checkout`'s `.git`, build products, and the dotfiles that land in the
runner-forced `HOME=/github/home`.

The next job to land on that runner runs as the unprivileged runner user, and
its checkout cannot clean the leftovers:

```
File was unable to be removed
Error: EACCES: permission denied, unlink '.../.git/logs/refs/heads/<branch>'
```

`job-completed.sh` runs after every job and hands the whole `_work` tree back
to the runner user, so no workflow has to remember to do it.

Workflows may still fix up their own workspace — `build_package` in
`.github/workflows/packetfence-perl_build_image_package.yml` does, because it
checks out and builds as root inside a container. That step is the targeted
fix; this hook is the catch-all for every container job, present and future.

## Install

Per runner host, once per runner installation. Paths below assume the runner
lives in `/home/github_runner/actions-runner` and its service runs as
`github_runner` — adjust to match the host.

1. Install the scripts in the runner's `hooks/` directory, owned by root so the
   runner user cannot rewrite what it is about to invoke through `sudo`:

   ```bash
   RUNNER_ROOT=/home/github_runner/actions-runner
   sudo install -d -o root -g root -m 755 "$RUNNER_ROOT/hooks"
   sudo install -o root -g root -m 755 \
       ci/runner-hooks/job-completed.sh \
       ci/runner-hooks/reclaim-workspace-ownership.sh \
       "$RUNNER_ROOT/hooks/"
   ```

   `reclaim-workspace-ownership.sh` derives the tree it touches, and the
   ownership to restore, from its own location — keep it inside
   `<runner-root>/hooks/`.

2. Let the runner user run the helper as root, and only the helper. The
   trailing `""` restricts the rule to an invocation with no arguments, so it
   cannot be turned into a `chown -R` of an arbitrary path:

   ```bash
   sudo tee /etc/sudoers.d/actions-runner-workspace >/dev/null <<'SUDOERS'
   github_runner ALL=(root) NOPASSWD: /home/github_runner/actions-runner/hooks/reclaim-workspace-ownership.sh ""
   SUDOERS
   sudo chmod 440 /etc/sudoers.d/actions-runner-workspace
   sudo visudo -c
   ```

3. Point the runner at the hook and restart it **while it is idle** — a restart
   mid-job kills that job:

   ```bash
   echo 'ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/home/github_runner/actions-runner/hooks/job-completed.sh' \
       | sudo tee -a "$RUNNER_ROOT/.env"
   sudo "$RUNNER_ROOT/svc.sh" stop && sudo "$RUNNER_ROOT/svc.sh" start
   ```

4. Clean up what earlier container jobs already left behind — the hook only
   covers jobs that run after it is installed:

   ```bash
   sudo "$RUNNER_ROOT/hooks/reclaim-workspace-ownership.sh"
   ```

Runners for the `packetfence-perl-package-build` and `package-build` labels are
the ones that run container jobs today.

## Verify

The tail of any job log on that runner should show the hook:

```
reclaim-workspace-ownership.sh: reclaimed 1287 path(s) under /home/github_runner/actions-runner/_work for 1001:1001
```

or, once the workspace is clean, `... is already owned by 1001:1001`. A
failure appears as a `Runner workspace ownership` warning: the hook never fails
the job over cleanup.

## If a sudoers rule is not an option

The runner user is already in the `docker` group — it has to be, to run
container jobs — so a container can do the chown instead of `sudo`. Bind-mount
the runner root and the helper resolves the same paths inside the container:

```bash
docker run --rm -v /home/github_runner/actions-runner:/runner \
    debian:12 /runner/hooks/reclaim-workspace-ownership.sh
```

Swap that in for the `sudo -n` line in `job-completed.sh`, and prefer an image
already present on the host so a job's cleanup never waits on a registry pull.
