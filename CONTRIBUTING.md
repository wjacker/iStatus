# Contributing to iStatus

Thanks for contributing to iStatus.

This document is intended for human collaborators and explains the basic expectations for making changes in this repository.

## Development Setup

1. Open `iStatus.xcodeproj` in Xcode.
2. Select the `iStatus` target.
3. Build and run on macOS.

Recommended environment:

- macOS 14.0+
- Xcode 15+

## Project Principles

When contributing, try to preserve the current product direction:

- Native macOS feel first
- Fast, glanceable system telemetry
- Dense but readable information design
- Menu bar first, dashboard as a deeper inspection surface

## Commit Message Format

All commits in this repository should use Conventional Commit style:

`type(scope): summary`

Examples:

- `chore(config): normalize project config`
- `feat(ui): add battery panel`
- `fix(metrics): avoid stale network samples`
- `docs(readme): add simplified chinese version`

Commit message rules:

- Always include a `type`
- Always include a `scope`
- Keep the summary short and action-oriented
- Prefer lowercase unless a proper noun requires capitalization

Common commit types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `test`
- `chore`

## Pull Request Guidelines

If you open a pull request, please:

- Keep the scope focused
- Explain the user-facing impact
- Mention any notable tradeoffs
- Include screenshots for visible UI changes when possible
- Note any testing limitations or environment-specific blockers

## Documentation Expectations

If your change affects user-facing behavior, update the relevant documentation when appropriate.

In particular:

- Update `README.md` for English-facing project documentation
- Update `README.zh-CN.md` when the same information should be available in Simplified Chinese
- Keep screenshot references current when UI changes materially

## Code Style Notes

- Prefer small, readable changes over broad rewrites
- Avoid introducing dependencies unless clearly necessary
- Preserve existing UI patterns unless intentionally redesigning a feature
- Be careful not to revert unrelated work in a dirty working tree

## Before Submitting

Before submitting changes, try to:

- Build the project in Xcode or with `xcodebuild`
- Review the diff for unrelated changes
- Confirm commit messages follow the repository format
- Update docs if behavior or visuals changed

## Repository-Specific Agent Rules

Automation and coding agents should also follow the repository rules in [AGENTS.md](AGENTS.md).
