# Changelog

## 0.1.0

* Initial release: reconcile Hauler `Images` / `Charts` / `Files` documents
  in a multi-document manifest, selected by `metadata.name`. Missing
  documents and items are created, existing ones are updated in place.
  Supports per-document annotations, per-item extra fields (including cosign
  keyless verification fields on `Images`), optional sorting, and optional
  pruning of undeclared items.
