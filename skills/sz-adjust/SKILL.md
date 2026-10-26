---
name: sz-adjust
description: Work through the review comments on the current ticket's PR - draft short human replies to the questions and small nits, post them after approval, then list the change requests to tackle. Use only when the user asks to adjust a PR or answer its review.
disable-model-invocation: true
---

# PR adjust

Go through the review on the PR of the branch you are on. You read every
comment, sort them, and draft replies to the ones that need an answer and
no real code change; the user corrects and approves them before anything is
posted. Then you list the change requests so the user can start on them.
Posting is outward-facing, so nothing is posted on its own.

## Rules

- Post a reply only after the user says yes to its exact text, and only as
  shown. Never edit, delete, resolve or unresolve anything on the PR, and
  never submit a review.
- Replies are written as the user would write them (see step 6). Never add
  AI attribution, and never mention commit SHAs. Nothing checks this for
  you; check every draft yourself before showing it.
- Answer only from what the code, the diff, the Linear ticket and its
  comments, and this session show. If you don't know, say so in the draft for the user to fill in;
  never guess.
- Read Linear only; never comment or change anything there.
- Don't change any code. This skill ends with a list; the user decides what
  to work on.
- Change branches only through `sz-branch switch`.

## 1. Read the state

```sh
sz-commit config
git status --short
gh pr view --json number,url,state,author,headRefName,comments,reviews
```

Go to step 2 when any of these holds:

- `ticket:` is empty (you are on `main` or a non-ticket branch);
- `gh pr view` finds no PR for this branch;
- the PR has no comments at all: no conversation comments, no review with
  a body, and no review threads (step 3). Run step 3 before deciding this.

If the PR is merged or closed, say so and ask whether to go on anyway.
If `gh` is missing or not logged in, stop and say so (`gh auth login`).

## 2. Wrong branch

Tell the user, in one or two lines, which branch you are on, its ticket (or
that it has none), and what you didn't find (no PR, or a PR with no
comments). Ask which ticket they meant to adjust. Never guess one.

With their answer:

```sh
sz-branch find TICKET
```

- No branch: stop. There is no PR to adjust.
- One branch: run `sz-branch check TICKET`, show its output, then
  `sz-branch switch TICKET`. If it refuses (git would overwrite a file,
  several branches), stop and show the message; don't work around it.

Then start again at step 1. If the ticket the user named has no PR or no
comments either, say so and stop; don't ask a second time.

## 3. Read the review

The `gh pr view` output from step 1 holds the conversation comments
(`comments`) and the review summaries (`reviews`, the text of each review
under its approve or request-changes button). Inline comments live in
review threads; read them with:

```sh
gh api graphql -F owner='{owner}' -F repo='{repo}' -F number=12 -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage }
        nodes {
          isResolved isOutdated path line
          comments(first: 50) { nodes { databaseId author { login } body url } }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads'
```

`{owner}` and `{repo}` are filled in by `gh` from the current repo; replace
only the number. If `hasNextPage` is true, say that you read the first 100
threads only.

The PR's author (`author.login` from step 1) is the user. Leave out:

- resolved threads;
- threads and comments the user already answered: the user wrote the last
  comment of the thread, or, in the conversation, replied after it (quoted
  it or mentioned its writer). When you can't tell, keep it and say it may
  already be answered;
- the user's own comments, and reviews with an empty body;
- bot messages that ask nothing (CI, coverage, deploy previews, Linear's
  link). A bot that asks or suggests something is kept like a person.

Keep outdated threads, and mark them as outdated.

## 4. Read the ticket

With the Linear MCP server (`linear-server`), read the branch's ticket
(`get_issue`): title, description, status, parent and sub-issues. Read its
comments (`list_comments`), and the parent's when the ticket is a
sub-issue. They say what the ticket is for, what was decided and why, and
what was left out on purpose, which is often what a reviewer is asking
about.

Use them to answer and to sort, not to quote: a reply can say why ("the
ticket only covers the import, export is a follow-up"), but don't paste
Linear text, links or internal details into the PR beyond what the answer
needs. If the ticket can't be read (MCP server not logged in), say so and
go on with the code and the session only.

## 5. Sort

Read each kept comment with the code it points to: open the file at its
`path` and `line`, and read enough around it to answer. Then put it in one
group:

- **Answer**: questions about the code that need no code change ("why a
  loop here?", "what calls this?") and small idiomatic corrections or
  refactors (naming, a more idiomatic call, a style nit).
- **Change**: requests that change behaviour or need real work: a bug, a
  missing case, missing tests, a different design. A question whose honest
  answer is "you're right, it's wrong" goes here too.
- **Skip**: comments that need no reply (thanks, approvals, "nice").

When unsure between Answer and Change, put it in Answer and add "(might be
a change)" after its draft, so the user decides. Mark a Change that goes
beyond what the ticket covers with "(outside the ticket)", so the user can
leave it for a follow-up.

## 6. Draft the answers

One reply per Answer comment, in the user's voice:

- Short: one to three sentences. Plain and direct, the way a colleague
  answers in a review.
- The same language as the comment.
- First person ("I went with...", "Good point, I'll rename it").
- No em or en dashes, no emojis, no headings, bold or bullet lists, no
  curly quotes. Backticks around code names are fine.
- No filler: no "Great question", "Certainly", "I hope this helps", no
  restating the question.
- No commit SHAs or "fixed in commit ...", no links to commits.
- For a nit: agree and say what you'll change ("Fair, I'll use `map`
  there"), or say in one sentence why it stays. Every nit the reply agrees
  to also goes into the step 9 list, since agreeing doesn't make the change.

Before showing them, read each draft once more against these rules.

## 7. Approve

Show the Answer group as a numbered list. For each:

```
1. reviewer · path/to/file.ts:42 (outdated)
   > the comment, or its first line if long
   Reply: Good point, I'll rename it to `retryCount` so it matches the config.
```

Use `conversation` or `review summary` in place of the path for comments
that have no line. Under the list, give the Change group's count and the
Skip group in one line ("Skipped: 2 approvals, 1 coverage bot"), so the user
can move a comment between groups.

Say how they will be posted: inline comments as replies in their thread;
conversation comments and review summaries together in one PR comment, each
answer under a quote of what it answers (they have no thread to reply in).

Wait. The user may correct a reply, drop one, or move a comment to another
group. Show the changed items again and wait for a yes to the whole list.

## 8. Post

Only the approved replies, one per tool call, exactly as approved.

Inline comment: reply in its thread, using the `databaseId` of the
thread's first comment:

```sh
gh api repos/{owner}/{repo}/pulls/12/comments/1234567/replies -F body=@- <<'EOF'
Good point, I'll rename it to `retryCount` so it matches the config.
EOF
```

Conversation comments and review summaries, in one PR comment:

```sh
gh pr comment 12 --body-file - <<'EOF'
> Why not reuse the existing parser?

It only reads the old format, and this needs the new header too.

> Could this be a const?

Yep, I'll change it.
EOF
```

Keep the heredoc delimiter quoted (`<<'EOF'`) so nothing in the body is
expanded, and pick another delimiter if `EOF` appears in the body. If a
post fails, stop, show the output and say which replies were posted and
which were not. Don't retry with other flags.

## 9. List the changes

Show what is left to do, as a numbered list the user can work from: the
Change group, then the nits the replies agreed to. For each, one line with
the reviewer, `path:line` (or where it was asked), and what they want in
your own words, plus the comment's URL:

```
1. reviewer · src/retry.ts:88 · retries never stop when the server returns 429
   https://github.com/...
```

Order them so related changes sit together, the bigger ones first. Say how
many replies were posted. Then stop; the user picks what to start on.
