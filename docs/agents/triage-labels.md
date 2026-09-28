# Triage labels

The engineering skills speak in five canonical triage roles. This file maps
them to the `**Status:**` strings used in `.scratch/<feature>/issues/`.

| Role in the skills | `Status:` string here | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | Maintainer needs to evaluate this ticket |
| `needs-info` | `needs-info` | Waiting on the reporter for more information |
| `ready-for-agent` | `ready-for-agent` | Fully specified, ready for an agent |
| `ready-for-human` | `ready-for-human` | Requires human implementation |
| `wontfix` | `wontfix` | Will not be actioned |

`done` is not a triage role: it closes a ticket once its acceptance criteria
pass and review is complete.

When a skill mentions a role (for example "apply the AFK-ready triage label"),
use the matching string from this table.
