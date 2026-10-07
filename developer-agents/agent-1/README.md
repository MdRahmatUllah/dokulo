# agent-1: developer, lane B

agent-1 builds what every screen stands on, and the screens around the files.

- **Lane B:** Design system & components (tokens, theme, `Dk…` components, icons and illustrations), Home, Files & the locked folder, Me/Pro & the system surfaces, Localisation (EN/DE ARB, copy decks), Tablet & layout, Accessibility (351 tasks, about 456 dev-days: the biggest lane, so agent-0 moves work to the others when it runs ahead).
- **First, while DK-0001 is being built:** the compliance tasks assigned to it (DK-0672 licence register, DK-0678 sRGB ICC profile, DK-0680 OpenCV module exclusion, DK-0681 MPL/LGPL handling), written to `docs/compliance/`. Then the tokens and components as soon as DK-0001 merges: the other lanes' screens wait for them.
- **Worktree:** `.worktrees/agent-1`.

## How it works

`CLAUDE.md`, "One task, start to finish", for each task or batch. In lane B:

- **Components** follow `docs/dokulo-ui-design-spec.md` (anatomy, states, sizes, the Flutter class name) and the artboards in `dokulo-design/*/00-design-system/`. Each gets goldens (light, dark; phone, tablet where it differs) compared with its artboard.
- **Tokens and shared components re-render other screens' goldens:** take the `shared-look` lock for such a change, and say so in a `heads-up`.
- **Copy** comes from the spec's EN/DE strings (the fixed tool names in `docs/Overview & foundations.md`). German uses "du". Renaming or deleting ARB keys takes the `l10n` lock.
- **Reviews:** it reviews agent-0's and agent-2's PRs when asked, the same day.
