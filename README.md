# bb orchestration skills

[![skills.sh](https://skills.sh/b/amrtawfik160/bb-orchestration-skills)](https://skills.sh/amrtawfik160/bb-orchestration-skills)

I wanted fresh context without an agent swarm. These two skills keep a BB build
serial. One worker gets one job, then hands the work to a new thread.

Implementation happens in a fresh thread. Review happens in another. A fixer
handles every finding, then a new reviewer checks the whole diff from the
original base. The loop stops only when Standards and Spec both report zero.

## Skills

### `orchestrate-implementation`

Takes a spec or ordered tickets. It implements one unit at a time, reviews it,
fixes every finding, and runs a final integration review.

### `review-fix-loop`

Starts with an existing committed diff. It reviews, fixes, and re-reviews from
one pinned base until both review axes are clean.

## What they enforce

- One active worker at a time.
- A fresh BB thread for every implementation, review, fix, and re-review.
- One shared worktree, so accepted commits remain visible to later workers.
- A clean managed worktree when the source checkout has unrelated changes.
- Standards first, then Spec, in one reviewer with no child agents.
- Re-review from the original base after every fix.

## Requirements

- `bb` on `PATH` and a BB project thread.
- The `bb-cli`, `implement`, `tdd`, and `code-review` skills.
- A configured issue tracker when the input comes from `/to-spec` or
  `/to-tickets`.

## Install

Install from skills.sh and choose one or both skills:

```bash
npx skills add amrtawfik160/bb-orchestration-skills
```

Or copy them into BB's default user skill directory:

```bash
git clone https://github.com/amrtawfik160/bb-orchestration-skills.git
mkdir -p ~/.bb/skills
cp -R bb-orchestration-skills/skills/* ~/.bb/skills/
```

## Use

```text
/orchestrate-implementation <spec or ordered ticket references>
/review-fix-loop <fixed-point> [spec or ticket reference]
```

## License

MIT
