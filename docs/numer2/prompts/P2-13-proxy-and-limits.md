# P2-13: Optional: own project for the reverse proxy, right-sized limits

**Recommended model:** opus   **Effort:** medium
**Risk:** low for the files, high when applied   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P2-12

## Goal
Every module API is reached through a reverse proxy container that belongs to another of the
owner's projects. If that project is ever shut down, all NUmer modules go offline. Prepare,
without applying anything, the files and the procedure to move the proxy into its own small
project, and a procedure to bring memory limits in line with real use.

## Read first
- `AGENTS.md`
- `infra/RUNBOOK.md`
- `docs/numer2/RESEARCH.md` sections 9.1 and 9.2
- In each module repo if available locally: the production compose file and its shared-host overlay (to see the external network they join and the upstream names)

## Context
- Today: one Caddy container in another compose project publishes 80, 443 and 443/udp and
  owns a Docker network. Each module joins that network through a compose overlay and is
  addressed by container name: `gradus-api:8000`, `clavis-api:8000`, `muto-api:8000`,
  `events_bot_web:8000`. The proxy's site configuration lives in that other project.
- The modules start uvicorn with `--forwarded-allow-ips 172.16.0.0/12`, so the proxy must
  reach them from inside that range.
- Only one process can own ports 80 and 443, so a move is a short cutover, and certificates
  are issued again by the new proxy (HTTP-01 needs port 80 reachable).
- Other projects on the same server also sit behind the current proxy. They are outside this
  repo; the runbook must tell the owner to list them first and carry their site blocks over.
- Module domains are configuration. The repo may show placeholders only.

## Steps
1. `infra/edge/compose.yml`: project name `numer-edge`; one `caddy:2-alpine` service (pin the
   minor version); ports 80, 443, 443/udp; a named external network `edge` that modules will
   join (created once by hand with a subnet inside 172.16.0.0/12; the README gives the
   command); volumes `edge_caddy_data` and `edge_caddy_config` with explicit names; the
   Caddyfile and a `sites/` directory mounted read-only; `read_only: true`, `cap_drop: [ALL]`,
   `cap_add: [NET_BIND_SERVICE]`, `security_opt: [no-new-privileges:true]`, `mem_limit: 128m`,
   `restart: unless-stopped`.
2. `infra/edge/Caddyfile`: global options (`email {$ACME_EMAIL}`, `admin off`), a snippet
   `security_common` (compression, `-Server`, `X-Content-Type-Options nosniff`,
   `Strict-Transport-Security "max-age=31536000"`, JSON logs to stdout), and
   `import sites/*.caddy`.
   `infra/edge/sites/modules.caddy.example`: one site block per module using environment
   placeholders for the domain (`{$GRADUS_API_DOMAIN}` and so on), importing the snippet,
   `header Referrer-Policy no-referrer`, and `reverse_proxy <container name>:8000`. For Muto
   add `request_body { max_size 6MB }`.
   `infra/edge/edge.env.example` with the placeholder variables.
3. `infra/RUNBOOK.md`, new section `Moving the reverse proxy`:
   1. inventory: every site the current proxy serves, from its configuration, including
      projects that are not NUmer modules;
   2. create the `edge` network; add each module (and each other project) to it alongside the
      old network, so both proxies can reach them;
   3. rehearsal: start the new proxy on spare host ports and test every site with
      `curl --resolve <domain>:<port>:127.0.0.1`;
   4. cutover in a quiet window: stop the old proxy, start the new one on 80 and 443, watch
      certificate issuance in its log, run each module's external health URL;
   5. rollback: stop the new proxy, start the old one (nothing else changed);
   6. after a stable week: remove the old network from the overlays.
   State the expected downtime honestly (a minute or two while certificates are issued).
4. `infra/RUNBOOK.md`, new section `Right-sizing memory limits`: record
   `docker stats --no-stream` at three busy moments; for each container set the limit to about
   twice the highest value seen, never below 64 MB; change one project at a time through its
   own compose file and redeploy it; a database container gets its limit lowered only together
   with its own memory settings. Include a blank table for the owner to fill in.
5. Validate: `docker compose -f infra/edge/compose.yml --env-file infra/edge/edge.env.example config -q` and `docker run --rm -v "$PWD/infra/edge:/etc/caddy:ro" --env-file infra/edge/edge.env.example caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile` after copying the example site file to `sites/modules.caddy` in a temp copy of the directory. Add the compose check to the CI `infra` job.

## Non-goals
- Do not apply anything. Do not connect to the server.
- Do not change any module repo or its overlays in this task.
- Do not merge databases or change any module's compose project.
- Do not write a real domain, address or the name of a project that is not a NUmer module.

## Constraints
- No file may contain a server address, a real domain that is not already public in a module repo, a credential or a key.
- Scripts are POSIX-friendly bash with `set -euo pipefail`, pass `shellcheck`, and never act on production data by default.
- The executor does not connect to any server. The deliverable is code and documentation that the owner runs.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] The two validation commands of step 5 exit 0 (show the output).
- [ ] `grep -rnE "([0-9]{1,3}\.){3}[0-9]{1,3}" infra | grep -v "172.16.0.0/12\|127.0.0.1"` prints nothing.
- [ ] `grep -rniE "\.dev|\.kz|\.com" infra/edge` prints nothing.
- [ ] Both runbook sections exist with numbered steps and a rollback.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed, and only if you plan to shut down the project that owns the proxy: follow `Moving the reverse proxy` (`docs/numer2/USER_ACTIONS.md` D-9).

## Deliverable
Branch `numer2/p2-13-proxy-and-limits`, one commit, message `docs: add reverse proxy move and memory limit runbooks` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- Docker is not available to validate the files.
- A module's forwarded-header trust cannot be satisfied by a network inside 172.16.0.0/12.
