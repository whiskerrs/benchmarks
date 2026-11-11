# Prompt and run protocol

- `PROMPT.md`: the specification given to the AI, with three placeholders.
- `frameworks.md`: the values for each framework.
- `storefront.graphql`: the GraphQL operations every app sends (validated against mock.shop on 2026-11-10).
- The design is in `../design/`.

## Running one framework

`python3 tools/ai_run.py <app dir>` performs steps 1–4 and the recording in step 6 (into `results/ai-runs/<app dir>/`): Claude Code headless (`claude -p`), effort `high`, bypass permissions, project settings only, no MCP servers, no skills.

Every run uses the same setup so that only the framework differs.

1. Create an empty directory outside any repository and outside any directory with a `CLAUDE.md`, for example `~/shopbench-runs/<app dir>/`. Use a path that has never been used with Claude Code, so no project memory is loaded.
2. Populate `spec/` in it:
   - `spec/PROMPT.md`: `PROMPT.md` with the placeholders substituted from `frameworks.md`.
   - `spec/storefront.graphql`: copied as is.
   - `spec/design/`: a copy of `../design/`.
3. Start Claude Code in that directory with:
   - model `claude-opus-5-5`, the same effort level for every run;
   - permission mode that does not prompt (bypass permissions), web access allowed;
   - no extra skills, plugins, MCP servers, or user-level `CLAUDE.md`/memory beyond the defaults.
4. Send exactly one message: `Read spec/PROMPT.md and follow it.`
5. Do not intervene. If a human message is unavoidable, record it verbatim with a timestamp in the results.
6. When the session ends, record:
   - wall-clock time from sending the message to the end of the final turn;
   - input/output tokens and cost;
   - number of turns and tool calls;
   - whether each item of the Done checklist actually passes when verified by hand.
7. Export the transcript and copy the project, without dependency or build output directories, to `apps/<app dir>/`.
