# Tools

This folder contains PowerShell scripts for updating JSON files defined in a rule file and for creating backups of the referenced source files.

## Files

* `json-copy.ps1` copies values from one JSON path to another
* `backup-json-sources.ps1` creates a `tar.gz` backup of all source files listed in the rule file
* `json-copy.rules.sample.json` is a sample configuration
* `json-copy.value-maps.sample.json` is a sample value map configuration
* `examples/sample.json` is a test input file

## Rule file format

Both scripts use the same rule file structure:

```json
{
  "files": [
    {
      "path": "${env:MDTVTYCN_DB_PATH}/CastData.json",
      "targetPath": "CastData.json",
      "rules": [
        {
          "sourcePath": "$.data[*]._comment",
          "targetPath": "$.data[*].Name",
          "replaceFromMap": "commentTranslations"
        }
      ]
    }
  ]
}
```

Notes:

* `path` is required and points to the original source file
* `rules` is required and is executed in order for that file
* `targetPath` is optional; if omitted, the source file is updated in place
* `ignoreValues` is optional per rule; matching values are skipped and not copied
* `replaceFromMap` is optional per rule and selects one map from the file passed via `-ValueMapFile`
* environment variables can be used in `path` and `targetPath` via `${env:NAME}`
* the root project rule file uses `${env:MDTVTYCN_DB_PATH}`
* relative paths are resolved relative to the rule file location

Value map example:

```json
{
  "commentTranslations": {
    "Wheel of Fortune": "Glücksrad"
  }
}
```

## json-copy.ps1

This script reads each configured source file, applies its rules in order, and writes the result either back to the source file or to `targetPath`.

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\json-copy.ps1 `
  -RuleFile ".\tools\json-copy.rules.sample.json" `
  -ValueMapFile ".\tools\json-copy.value-maps.sample.json" `
  -Indented
```

Parameters:

* `-RuleFile` JSON file containing the file entries and rules
* `-ValueMapFile` optional JSON file containing named replacement maps
* `-Indented` optional, writes formatted JSON with indentation
* `-WhatIf` optional, shows what would be written without changing files

Behavior:

* missing target nodes are created automatically
* simple paths like `$.person.name` are supported
* array paths like `$.items[0].id` are supported
* wildcard array paths like `$.data[*]._comment` are supported
* if a `sourcePath` cannot be found, the script writes a warning and continues with the next rule
* if a source value matches `ignoreValues`, that copy operation is skipped
* if `replaceFromMap` is configured and a matching entry exists in the selected map, the mapped value is written instead of the original value

Quick test:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\json-copy.ps1 `
  -RuleFile ".\tools\json-copy.rules.sample.json" `
  -ValueMapFile ".\tools\json-copy.value-maps.sample.json" `
  -Indented
```

Expected output file:

`examples/sample.output.json`

```json
{
  "person": {
    "name": "Alice"
  },
  "items": [
    {
      "id": 42
    }
  ],
  "metadata": {
    "displayName": "Alice",
    "favoriteShowDe": "Glücksrad"
  },
  "summary": {
    "primaryItemId": 42
  }
}
```

## backup-json-sources.ps1

This script creates a `tar.gz` archive containing all original files referenced in `files[].path`.
Configured `targetPath` values are ignored.

Example:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\backup-json-sources.ps1 `
  -RuleFile ".\tools\json-copy.rules.sample.json" `
  -OutputFile ".\tools\backups\sample-backup.tar.gz"
```

Parameters:

* `-RuleFile` JSON file containing the file entries
* `-OutputFile` optional, archive path; defaults to a timestamped archive next to the rule file
* `-WhatIf` optional, shows which files would be included without creating the archive

Behavior:

* only original source files from `path` are included
* duplicate source files are added only once
* relative archive paths match the configured relative `path` values where possible
