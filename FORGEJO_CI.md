# Forgejo CI — status & open issues

Last updated: 2026-10-20

## Goal

`.forgejo/workflows/ci.yaml` for this repo, modeled on
<https://git.stfx.eu/sven/wcx/src/branch/main/.forgejo/workflows/ci.yaml>
(release job and "Verify OS" step skipped). Gates: `mix deps.get`,
`mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix test`
(Elixir 1.20 / OTP 28 via setup-beam). All gates verified locally; file is
committed and pushed (ci.yaml itself is **fine** — it parses on the server).

## Infrastructure

- ds9: Forgejo 16.0.4 (rootless podman) + forgejo-runner **v12.10.2**
  (separate user `forgejo-runner`, socket
  `unix:///run/user/1002/podman/podman.sock`, `capacity: 1`).
- Live runner config: `/home/forgejo-runner/config.yml` on ds9.
- Job containers must reach `git.stfx.eu` via `--add-host=git.stfx.eu:169.254.1.2`
  (host gateway = `host.containers.internal`).

## Problem 1 — checkout failures (solved in theory, verification pending)

Two independent root causes were found:

1. **PidsLimit bug**: runner v12.10.2 serializes `"PidsLimit": 0` into the
   container create request **whenever the workflow's `container.options` is
   non-empty**. Podman turns that into cgroup `pids.max=1` → nothing can fork
   (`fork: retry: Resource temporarily unavailable`, node
   `uv_thread_create` assertion). Proven via `podman inspect` diff
   (with options: `PidsLimit: 0`, `pids.max: 1`; without: `PidsLimit: 2048`).
   Therefore `container.options` must **not** be used in the workflow file.
2. **Rootless networking**: act_runner ignores config `network: "host"` for
   jobs with a `container:` block (always creates a `WORKFLOW-…` bridge
   network) → rootless podman hairpin to the host's public IP
   (157.173.107.19:443) is refused → `git fetch` fails. A manual
   `--add-host=git.stfx.eu:169.254.1.2` on a bridge network works (verified
   with curl: HTTP/2 200).

**Plan A (current)**: runner-level `container.options: "--add-host=git.stfx.eu:169.254.1.2"`
added to `config.yml` under `container:` — applies to all jobs without putting
options in the workflow (avoids bug 1). **Not yet verified** (blocked by
problem 2).

Fallbacks: **Plan B** upgrade runner v12.10.2 → v13.1.0; **Plan C** drop the
`container:` block from the job and test whether config `network: "host"`
applies to container-less jobs.

## Problem 2 — dispatch HTTP 500 (root cause found, fix pending)

Dispatching any workflow (probe.yaml) from the web UI fails with:

```
workflow.Dispatch: SetJob: yaml: line 8: did not find expected key
```

**Root cause** (reproduced locally against exact server code: Forgejo v16.0.4
+ its dependency runner v12.13.2 jobparser):

- Forgejo's dispatch calls `jobparser.Parse` → `SingleWorkflow.SetJob`, which
  **round-trips** the job: `yaml.Marshal(job)` then `yaml.Unmarshal` of the
  result (lib: `go.yaml.in/yaml/v3` v3.0.4).
- If a step's block scalar (`run: |`) **value starts with a blank line**, the
  emitter writes an explicit indentation indicator (`run: |4`) whose base
  disagrees with the library's own parser (emitter counts from the sequence
  indent, parser from the mapping indent) → the block ends up empty, the
  following content lines are parsed as YAML at the wrong level →
  "did not find expected key".
- Trigger in this repo: the **pids check step in `.forgejo/workflows/probe.yaml`**
  (`run: |` followed by a blank line, in the repo's blank-line-everywhere
  style). Bisected and confirmed: removing only the leading blank line inside
  the block (or all blank lines inside it) parses fine; ci.yaml and the old
  probe.yaml (d3c35bb) parse fine. Plain yaml.v2/v3 parse the raw file without
  error — only the marshal round-trip fails, which is why it only broke
  dispatch (not pushes).

**Fix applied** (2026-10-20): `probe.yaml` rewritten without blank lines
inside the block scalar (compact block). Verified against the exact server
code path (Forgejo v16.0.4 + runner v12.13.2 `jobparser.Parse`, SetJob
round-trip included): probe.yaml and ci.yaml both parse OK. Temp source
clones/probe programs were deleted afterwards.

## Next steps

1. Commit + push `probe.yaml`, dispatch probe from the web UI.
2. Verify all three checks in the probe run:
   - `node ok`
   - `getent hosts git.stfx.eu` → `169.254.1.2`
   - `pids.max=2048` (if `1` again → Plan A failed → Plan B / Plan C)
3. Confirm the full ci.yaml run passes on push.
4. Delete `.forgejo/workflows/probe.yaml` (temporary diagnostic workflow).
5. **wcx** (<https://git.stfx.eu/sven/wcx>) has the same checkout problem and
   needs the runner-config fix (or its own workflow fix) too.
6. Optional: report the `|N` round-trip bug upstream
   (<https://codeberg.org/go-yaml/yaml> / runner jobparser).
