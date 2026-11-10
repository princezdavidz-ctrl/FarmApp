# Legacy duplicate — do not use for new development

This directory is a historical parallel copy of the main Flutter application.
The canonical FarmApp application is now maintained in `../proj/`.

- Make new features, fixes, and shared UI changes in `../proj/`.
- Do not deploy this directory as the primary farm application.
- Any useful iOS-specific changes here must be reviewed and selectively ported
  into `../proj/ios/` before this copy is retired.
- This directory is intentionally retained until that comparison and migration
  are complete; it has not been deleted.

See [the canonical app documentation](../proj/README.md).
