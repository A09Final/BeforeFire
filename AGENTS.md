# AGENTS.md

These rules apply to all coding agents working in this repository.

## Initial Project Context

- Before planning, reviewing, or changing this project, read [PROJECT_SPEC.md](PROJECT_SPEC.md) in the repository root.
- Use the specification as the initial context for the product purpose, scope, user flows, and system responsibilities.
- Preserve the distinction between owner-confirmed decisions, board-supported concepts, proposals, and open decisions. Owner-confirmed architecture updates replace conflicting earlier concepts. Do not treat design decisions, draft thresholds, or proposed features as verified integrations or implemented behavior.
- Follow the user's current instructions when they change the specification. Report any relevant conflict with the document.

## Output and Implementation

- When presenting code, provide complete files unless fragments are explicitly requested.
- State the path where each new or modified file belongs.
- Follow the project's existing naming, formatting, and architectural conventions.
- Deliver working, buildable code rather than pseudocode or theoretical examples.
- Verify unfamiliar APIs before using them. Do not invent APIs or behavior.
- If an integration cannot be verified, isolate the uncertain part behind a small boundary and add a specific TODO describing what must be confirmed. Clearly report the limitation.
- Do not add package dependencies unless explicitly requested.
- Summarize what changed, what was verified, and any remaining limitations.

## Simplified Technical English

- Use ASD-STE100 Simplified Technical English (STE) for English explanations, documentation, code comments, and user-facing text you write or edit.
- Follow the standard's writing rules and dictionary. Use permitted technical terms when needed.
- Write short sentences in the active voice. Keep each sentence on one topic.
- Use consistent terms. Avoid idioms, slang, and ambiguous words.
- Preserve exact code identifiers, API names, paths, commands, and quoted text when you apply these language rules.
- Keep the language requested by the user. Apply STE when the text is in English.
- Do not claim verified compliance unless the text was checked against the standard's writing rules and dictionary.

Reference: [ASD-STE100 official website](https://www.asd-ste100.org/).

## Structure and Responsibilities

- Keep files focused on one feature or responsibility.
- Follow the existing project structure. Separate presentation, application state, business logic, persistence, and shared components where applicable.
- Keep UI components focused on rendering and user interaction.
- Keep business logic separate from UI and persistence code.
- Keep storage access in the project's persistence layer.
- Extract subcomponents when a UI component becomes hard to scan.
- Split functions that perform multiple distinct jobs.

## Naming

- Use clear, descriptive names that explain intent.
- Avoid vague names such as `data`, `item`, `thing`, `manager`, `helper`, or `temp` unless the scope is genuinely generic and obvious.
- Name booleans so they read naturally, such as `isLoading`, `hasChanges`, or `shouldRetry`.
- Name functions to describe their action and result, following the project's naming conventions.

## Comments

- Add comments only to clarify intent, constraints, or non-obvious behavior.
- Keep comments short and plain. Explain why the code exists rather than repeating what it does.
- Use specific TODOs that identify the unresolved decision, missing behavior, or API verification needed.

## Constants and Magic Values

- Do not scatter magic numbers or hardcoded strings throughout the code.
- Put repeated or non-obvious values in named constants or configuration.
- Centralize reused limits, filenames, storage keys, paths, and user-facing copy.
- Give constants meaningful names that explain their purpose.

## Reuse and Abstraction

- Avoid duplicating logic. Extract shared behavior when it is reused or makes a complex flow easier to understand.
- Prefer small, concrete components over large generic managers.
- Do not introduce abstractions, interfaces, or architectural layers without a clear need, such as testing or interchangeable implementations.

## State and Error Handling

- Keep substantial UI state and presentation logic in the project's designated state layer.
- Make asynchronous work cancellable when navigation, retries, or lifecycle changes can make it obsolete.
- Use typed or structured errors for important domain failures.
- Convert technical errors into clear, user-friendly messages at the presentation boundary.
- Do not silently ignore errors. Use deliberate fallbacks and make failures observable when appropriate.

## Privacy and User-Facing Language

- Preserve privacy and avoid exposing secrets or sensitive information in code, logs, or output.
- Use clear, neutral wording and avoid unsupported claims.

## Testing and Verification

- Add focused tests for relevant parsing, validation, matching, persistence, asynchronous state, and business logic changes.
- Prefer deterministic fixtures over random test data.
- Cover relevant edge cases, including empty input, missing required information, unavailable resources, partial operations, malformed responses, cancellation, and failures.
- Run the smallest useful test or build command after meaningful implementation changes when feasible.
- Report what was actually checked. If verification could not run, explain why and identify what remains unverified.
