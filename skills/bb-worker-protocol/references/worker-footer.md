# WORKER_RESULT footer

End your final message with this YAML block. The orchestrator parses it, so
keep the keys exact. Put evidence and explanation above the block, not inside
it.

```yaml
WORKER_RESULT:
  phase: implement | diagnose | review | check | fix | closure | recover | rebase | pr
  status: DONE | BLOCKED
  base: <sha you started from>
  head: <sha of HEAD when you finished>
  tree: clean | dirty
  validation: PASS | FAIL | NOT_RUN
  validation_command: "<command you ran, or empty>"
  blocked_by: "<one line; only when BLOCKED>"
```

Add the keys for your phase:

```yaml
  # review
  findings_standards: <count>
  findings_spec: <count> | skipped

  # check: one entry per finding ID
  findings:
    - id: standards-1
      verdict: CONFIRMED | DISPUTED

  # closure: one entry per finding ID in the attached ledger
  findings:
    - id: standards-1
      state: RESOLVED | OPEN | CONFIRMED_FIX_REGRESSION
  open_root_causes: <count>

  # pr
  pr_url: <url>
  pr_base_ref: <branch>
  pr_base_sha: <sha>
  pr_head_sha: <sha>
```
