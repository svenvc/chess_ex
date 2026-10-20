# Forgejo CI — status & open issues (thread TODO)

Last updated: 2026-10-20 — ✅ DONE. Real `Elixir CI` run (push) is green:
checkout, setup-beam, deps, format, compile, tests all pass. Job containers
run with `network="host"` (config loaded via `--config`). Probe workflow
removed. wcx (Elixir) and wc (Python) both rerun green on the same runner.
Only open follow-up: optional upstream bug reports.

## Goal

`.forgejo/workflows/ci.yaml` for this repo, modeled on
<https://git.stfx.eu/sven/wcx/src/branch/main/.forgejo/workflows/ci.yaml>
(release job and "Verify OS" step skipped). Gates: `mix deps.get`,
`mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`
(Elixir 1.20 / OTP 28 via setup-beam). Committed & pushed; ci.yaml itself is
fine (parses on the server, all gates pass locally).

## Infrastructure

- ds9: Forgejo 16.0.4 (rootless podman) + forgejo-runner **v12.10.2**
  (user `forgejo-runner`, socket `unix:///run/user/1002/podman/podman.sock`,
  `capacity: 1`, daemon started **Oct 18**).
- Runner service: `~/.config/systemd/user/forgejo-runner.service`,
  `ExecStart=/home/forgejo-runner/bin/forgejo-runner daemon` (no `--config`!),
  `WorkingDirectory=/home/forgejo-runner`, `Environment=DOCKER_HOST=…podman.sock`.
- `/home/forgejo-runner/config.yml` is correct (`container:` at 180,
  `network: "host"` at 184, `options: "--add-host=…"` at 191) but **was never
  loaded** — see root cause above. Runner ran on defaults: no network mode,
  no options, capacity 1, labels/registration from `.runner` in cwd.
- Job containers must be able to reach `git.stfx.eu` (served by ds9 itself,
  public IP 157.173.107.19). Rootless podman hairpin to that public IP from a
  bridge-network container is refused; host network and bridge +
  `--add-host=…:169.254.1.2` both work (manual proofs).

## Probe run results (dispatch works again ✓)

The dispatch 500 (`workflow.Dispatch: SetJob: yaml: line 8`) was fixed by
removing blank lines inside probe.yaml's `run: |` block scalar. Forgejo's
`SetJob` re-marshals each job with `go.yaml.in/yaml/v3`; a block scalar whose
value starts with a blank line is emitted with an explicit indent indicator
(`|4`) that the same library's parser misreads. (Reproduced locally against
Forgejo v16.0.4 + runner v12.13.2 jobparser; upstream-worthy bug.)

- Probe runs #79/#80 verdicts:
  - `node ok`, `pids.max=2048` — no fork problems.
  - `--add-host` **not applied**: no `git.stfx.eu` in the container's
    `/etc/hosts`; `getent` resolved via DNS to the public IP (broken hairpin).
  - Daemon restarted (PID …746 → …249), still `WORKFLOW-…` bridge network,
    still no options.
- Probe run #81 (after `--config` fix): ✅ `docker create … network="host"`,
  no `WORKFLOW-…` network create/cleanup, job runs normally.
- Root cause (final): the unit runs `forgejo-runner daemon` without
  `--config`; v12.10.2 `--config` defaults to `""`, and `config.FromFile("")`
  logs "No configuration file specified; using default settings." and
  **skips the file**. `cwd`/`WorkingDirectory`/key placement were all red
  herrings — the file was simply never read.
- v12.10.2 source: keys `container.network` / `container.options` are
  applied verbatim (`applyTo`) and mapped per task
  (`internal/app/run/runner.go:369-370`); `getNetworkName` prefers
  `ContainerNetworkMode` and the bridge create is skipped when set.

## Findings from runner source (v12.10.2, v13.1.0, v13.2.0)

- **PidsLimit bug is NOT fixed in any released runner** (checked through
  v13.2.0): `parseOptions` always builds `PidsLimit: &copts.pidsLimit`
  (CLI default 0) and `mergo.WithOverride` merges that non-nil pointer over
  the real host config. Triggers on **any** non-empty options string —
  workflow-level *and* runner-config-level. → **Plan A (runner-level
  `options: --add-host`) is dead; Plan B (runner upgrade) does not fix it.**
- Config `container.network` IS honored by code: mapped to
  `ContainerNetworkMode` (`internal/app/run/runner.go:370`), preferred over
  the `WORKFLOW-…` bridge network (`run_context.go:ensureNetworkName`),
  passed as `NetworkMode` to the job container, and the bridge network
  create is skipped when set.
- `--config` defaults to `""` (not `config.yml`) in v12.10.2
  (`internal/app/cmd/cmd.go:27-28` + `internal/pkg/config/config.go:570-575`)
  — the flag is mandatory to load a config file.

## Outcome

Config `container.network: "host"` is live (config loaded via `--config`),
no `container.options` anywhere. Real CI run on push is **green**.

1. ✅ `--config /home/forgejo-runner/config.yml` added to the unit's
   ExecStart + `daemon-reload`.
2. ✅ `options:` line removed from config.yml; `network: "host"` kept.
3. ✅ Daemon restarted; probe #81 confirms `network="host"`.
4. ✅ Real ci.yaml run green (checkout/fetch succeeds over host network).
5. ✅ `.forgejo/workflows/probe.yaml` removed.
6. ✅ **wcx** (Elixir, <https://git.stfx.eu/sven/wcx>) and **wc** (Python)
   reran green when triggered manually — the runner fix is global.
7. Optional upstream report: the `|N` marshal round-trip bug
   (<https://codeberg.org/go-yaml/yaml> / runner jobparser) and the
   PidsLimit=0 options bug (still present in v12.10.2–v13.2.0).

## History / notes

- `network: "host"` works on rootless podman via the host netns; the
  container resolves `git.stfx.eu` to the public IP and connects fine
  (manual proof + probe #81).
- The PidsLimit=0 bug remains latent: never re-add `container.options`
  (workflow- or runner-level) on runner ≤ v13.2.0.

## Reference

- `.forgejo/workflows/ci.yaml` — the deliverable (green pending infra fix).
- `.forgejo/workflows/probe.yaml` — temporary diagnostic workflow
  (node check / hosts check / pids check / sleep 300); delete when done.
- Runner/Forgejo source clones for debugging lived in
  `$TMPDIR/opencode/{forgejo-src,runner-src,runner-12,runner-13}` —
  throwaway, re-clone from code.forgejo.org / codeberg.org if needed
  (plain `git clone --depth 1 --branch <tag>` works; Codeberg blocks HTTP
  scraping but not git).
