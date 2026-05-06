# icloud-to-org-contacts Roadmap

This document captures likely future directions for the project without
turning the README into a planning document.

## Current Direction

The working implementation is a standalone Python CLI. That remains the
best short-term production path because it already handles CardDAV
syncing, vCard parsing, Org output, manifests, archiving, and tests.

For Emacs users, the next practical step is a thin Emacs Lisp wrapper
package. That wrapper can expose `M-x` commands, defcustoms, async
process buffers, and executable checks while continuing to call the
standalone CLI.

## Emacs Lisp Package Feasibility

It is possible to rewrite the package in Emacs Lisp. A pure Elisp
implementation would be more natural for MELPA or GNU ELPA users:

- no Python virtual environment;
- direct `auth-source` integration with `.authinfo.gpg`;
- native interactive commands and defcustoms;
- direct use of `org-id`;
- direct Org property drawer generation.

The main maintenance risk is replacing the mature Python parsing pieces,
especially vCard support. A robust Elisp implementation would need to
handle folded lines, multiple values, parameters such as `TYPE=HOME`,
Apple-specific fields, labels, addresses, Unicode, escaping rules, and
CardDAV XML responses.

## Recommended Path

1. Keep the Python CLI as the supported engine.
2. Add a small Emacs Lisp wrapper package for Emacs integration.
3. Build full Elisp parsing and CardDAV support only if the wrapper plus
   CLI install step proves too awkward for users.
4. If a pure Elisp rewrite begins, port behavior behind the existing
   synthetic test cases before changing the user-facing output contract.

## Possible Elisp Architecture

```text
icloud-contacts.el          user commands, defcustoms, package entry
icloud-contacts-auth.el     auth-source lookup
icloud-contacts-carddav.el  iCloud/CardDAV discovery, groups, fetches
icloud-contacts-vcard.el    vCard parsing and normalization
icloud-contacts-org.el      Org generation, property drawers, org-id
icloud-contacts-state.el    ETags, resource URLs, contact state
test/                       ERT tests with synthetic fixtures
```

Suggested module boundaries:

- `icloud-contacts-auth.el` should use Emacs `auth-source` instead of
  shelling out to GPG directly.
- `icloud-contacts-carddav.el` should stay read-only and never write
  remote contact changes.
- `icloud-contacts-vcard.el` should be developed test-first because
  vCard edge cases are the highest-risk part of a rewrite.
- `icloud-contacts-org.el` should preserve the current property drawer
  contract, including stable `:ID:`, `:VCARD_UID:`, and `:VCARD_URL:`
  fields.
- `icloud-contacts-state.el` should preserve ETag and archive behavior
  compatible with the current manifest semantics.

## Distribution Notes

MELPA and GNU ELPA packages are usually primarily Emacs Lisp. They can
depend on external programs, but package installation does not normally
create Python virtual environments or manage Python dependencies for the
user.

For that reason, the most idiomatic distribution shape is:

- a standalone CLI that can be installed with `pipx`, `pip`, Homebrew,
  or Nix;
- an optional Emacs Lisp package that checks for the executable, exposes
  user options, and runs the CLI from Emacs.

Bundling the Python engine directly into a MELPA package would likely be
more fragile than maintaining the CLI and Elisp wrapper separately.
