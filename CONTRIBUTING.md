# Contributing to Medusa

Thanks for thinking about contributing. Medusa is a small, opinionated
toolkit and the goal is to keep it that way: an entry point, a handful of
`lib/` files, and a registry of curated open-source security tools.

If you only want to **add a tool**, jump to
[`docs/ADDING_A_TOOL.md`](docs/ADDING_A_TOOL.md) — it's the recipe for the
most common contribution.

## Ground rules

- Be respectful (see [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)).
- Open an issue before sending a non-trivial PR. For new tools, the
  [tool request issue template](.github/ISSUE_TEMPLATE/tool_request.yml)
  is the right starting point.
- Keep PRs focused. One tool, one bug fix, one refactor — not all three.

## Local setup

Medusa is a pure bash project. The only hard prerequisites are bash 4+,
Docker, `docker compose` (or `docker-compose`), and `git`. The
`./medusa.sh check` command lists everything (required and recommended).

```sh
git clone https://github.com/WhiteMuush/Medusa.git
cd Medusa
chmod +x medusa.sh
./medusa.sh check
```

Run the menu without deploying anything:

```sh
./medusa.sh
# pick option 3 to auto-generate a throwaway environment
```

## Code conventions

- Shebang: `#!/usr/bin/env bash`.
- Strict mode in entry points: `set -uo pipefail` (intentionally **not**
  `-e` — a single `read` returning non-zero would tear down the menu loop).
- Quote variables: `"${var}"`, not `$var`.
- Function naming: `snake_case`. Internal helpers prefix with `_`
  (e.g. `_require_compose`, `_oscap_detect_ds`). Deployers are named
  `deploy_<tool>` and run sub-menus are `run_<tool>` so the dispatchers in
  `core.sh` and `run_cli.sh` can find them.
- Files under `lib/` must guard against double-sourcing:

  ```sh
  [[ -n "${_MY_FILE_SH_LOADED:-}" ]] && return 0
  _MY_FILE_SH_LOADED=1
  ```

- Never use a raw `cd "$dir"` in a function — it leaks the working
  directory back into the menu loop and breaks all subsequent relative
  paths. Use `compose_in_dir` / `run_in_dir` (defined in `core.sh`) or
  an explicit subshell.
- Never emit colored output by interpolating raw escape sequences. Use
  `log_message <level> <msg>` (`info`, `success`, `warning`, `error`,
  `step`).

## Helpers you should be using

All defined in `lib/core.sh`:

| Helper                       | Purpose                                                |
|------------------------------|--------------------------------------------------------|
| `tool_dir <tool>`            | Absolute path of the tool's deployment directory       |
| `is_tool_installed <tool>`   | Returns 0 if Medusa or the system has the tool         |
| `compose_in_dir <dir> ...`   | `docker compose ...` inside `<dir>`, no `cd` leak      |
| `run_in_dir <dir> <cmd...>`  | Same, but for any command                              |
| `ensure_command_absent <c>`  | Bail out of a CLI installer if `<c>` is already on PATH |
| `mark_cli_installed <tool>`  | Write the `.installed` marker                          |
| `gen_password [length=24]`   | Random alphanumeric password                           |
| `gen_uuid`                   | UUID v4 (python / `/proc` / openssl fallback chain)    |
| `save_credentials <tool> ...`| Write `credentials.txt` (chmod 600)                    |
| `show_access_info <tool> ...`| Final box with URL / user / password                   |
| `prompt_value <label> [d]`   | `read` with a label and default                        |
| `prompt_yesno <msg> [Y/N]`   | Returns 0 on yes, 1 on no                              |

## Validation before opening a PR

```sh
# Syntax — both must be clean
bash -n medusa.sh lib/*.sh
shellcheck medusa.sh lib/*.sh

# Smoke — source chain and registered tools all resolve
MEDUSA_HOME="$PWD" bash -c '
  for f in lib/core.sh lib/deploy_soc.sh lib/deploy_grc.sh \
           lib/deploy_integration.sh lib/deploy_ot.sh \
           lib/run_cli.sh lib/modules.sh; do source "$f"; done
  for t in "${!TOOL_DESC[@]}"; do
    declare -F "deploy_${t//-/_}" >/dev/null || echo "missing deploy: $t"
  done
'
```

CI runs the same three checks (`.github/workflows/ci.yml`).

## Commit messages

Conventional prefixes are nice but not enforced. The signal is in the
body — explain **why** more than **what**. Examples that are useful:

- `feat(soc): add Falco runtime detection`
- `fix(core): docker_down no longer leaks cwd into the menu loop`
- `docs: clarify the ADDING_A_TOOL recipe for non-Docker tools`

## Reporting security issues

Do not open a public issue. See [`SECURITY.md`](SECURITY.md).
