<!--
Thanks for sending a PR. Before you submit, please tick the relevant boxes
below. If something does not apply, leave the box unchecked and explain why
in the description.
-->

## Summary

<!-- 1-3 sentences. What does this PR change and why. -->

## Type of change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New tool (added a deploy_<tool> + register_tool entry)
- [ ] Enhancement to an existing tool (deploy / run / docker compose tweaks)
- [ ] Refactor (no behavior change)
- [ ] Documentation only
- [ ] CI / tooling

## Checklist

- [ ] `bash -n medusa.sh lib/*.sh` is clean
- [ ] `shellcheck medusa.sh lib/*.sh` is clean (or each new warning is justified inline with a `# shellcheck disable=` comment)
- [ ] If a new tool was added: `register_tool` entry, `deploy_<tool>` function, README updated, port doesn't collide with existing ones
- [ ] I tested the change locally (menu interaction OR the relevant `./medusa.sh <cmd>` CLI invocation)
- [ ] No secret / credential is committed

## How was this tested

<!-- Concrete commands run and what you observed. -->
