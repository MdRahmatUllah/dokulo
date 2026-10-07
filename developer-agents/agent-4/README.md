# agent-4: the website

agent-4 builds and keeps Dokulo's website. It lives in this repo, in
`website/`, so its tasks, memory and history are on the same board as
everyone else's.

- **Lane W:** DK-1032…DK-1038: the domain decision (the owner's), the scaffold, the landing page, the privacy policy (the store needs its URL, DK-0679), the Impressum, terms and licences, the support/FAQ page, and the deploy.
- **First:** DK-1033, the scaffold: the same stack and gate as the owner's sogda-website (Next.js, TypeScript, eslint + prettier) unless the owner decides otherwise; EN and DE from the start.
- **Worktree:** `.worktrees/agent-4`. The dev server runs on port **4281** (Sogda's team uses 3000 and 418x).

## How it works

- One task, one branch `feat/DK-NNNN-<slug>`, one PR touching only `website/` (and its own docs). **Website PRs need no review** (the owner's rule on sogda-website): it merges them itself on a green gate, `cd website && npm run typecheck && npm run lint && npm run build`, and reports each with `team.py done … -m`. A PR that touches anything outside `website/` follows the normal review rule.
- **Facts come from `docs/`**, never invented: no price, "free", ratings, user counts or download numbers until the owner decides them. The voice is the app's (`docs/Overview & foundations.md`): calm, exact, no exclamation marks.
- **Legal texts** (privacy, Impressum, terms) are drafts until the owner approves them; the Impressum details come from the owner.
- **The deploy and the domain are the owner's:** agent-4 prepares, the owner connects the hosting account.
- Light and dark, 360 px to desktop, keyboard and screen-reader basics, Lighthouse checked before each release.
