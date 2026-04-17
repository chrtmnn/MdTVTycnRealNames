![Release](https://img.shields.io/github/v/release/chrtmnn/MdTVTycnRealNames)
![Windows](https://img.shields.io/badge/Platform-Windows-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1-2671BE.svg)

# MdTVTycnRealNames

Echte Namen für Eggcode's **Mad Television Tycoon** (2026)

* https://www.eggcodegames.com/
* https://store.steampowered.com/app/3565020/Mad_Television_Tycoon/

## Beschreibung

Vermutlich aus Lizenz- und Urheberrechtsgründen verwendet Mad Television Tycoon leicht abgeänderte Versionen der echten
Namen für Serien, Filme, Werbedeals, Schauspieler und Regisseure. Diese Originalnamen lassen sich jedoch relativ
einfach wiederherstellen: In den relevanten JSON-Dateien der Spiel-Datenbank, insbesondere `ItemsData.json` und
`CastData.json`, enthält das Feld `_comment` die deutschen Originalnamen.

Als Inspiration für dieses Projekt diente ein [Python-Skript](https://drwolfsherz.net/file-download/106/) von
[DrWolfsherz](https://card.drwolfsherz.net/), das er in
[seinem Forum](https://drwolfsherz.net/forum/thread/36-real-names-f%C3%BCr-mad-television-tycoon/) zur Verfügung
stellt. Im Gegensatz zu DrWolfsherz' Lösung wird hier jedoch keine Installation von Python benötigt. Das Skript basiert
auf MS PowerShell und lässt sich direkt ausführen.

Die Anpassungen funktionieren auch mit bereits vorhandenen Savegames. Da lediglich die Namen in den JSON-Daten der
Spieldatenbank angepasst werden und keine Spielstanddateien verändert werden, können laufende Spielstände in der Regel
ohne Neustart oder Neuinitialisierung weitergespielt werden.

## Download

Die aktuelle Version steht als GitHub-Release bereit:

[![Neueste Version herunterladen](https://img.shields.io/github/v/release/chrtmnn/MdTVTycnRealNames?style=for-the-badge)](https://github.com/chrtmnn/MdTVTycnRealNames/releases/latest)

Lade das aktuelle Release herunter und entpacke das ZIP-Archiv anschließend in einen beliebigen Ordner. Danach kannst
du die enthaltene Batch-Datei direkt ausführen.

## Ausführung

Nach dem Entpacken kannst du unter Windows einfach `run-mdtvtycn-update.bat` ausführen.

Das Skript führt folgende Schritte aus:

1. Backup der originalen JSON-Dateien als `MdTVTycnDB.backup.YYYYMMDD-HHMM.tar.gz` direkt im verwendeten Datenbankordner
2. Anschließend Ausführung der JSON-Anpassung

Standardmäßig verwendet die Batch-Datei diesen Pfad:

    C:\Program Files (x86)\Steam\steamapps\common\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE

Du kannst diesen Pfad beim Start der Batch-Datei überschreiben:

```cmd
run-mdtvtycn-update.bat "D:\Games\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE"
```

Ohne Pause am Ende:

```cmd
run-mdtvtycn-update.bat --no-pause
```

Das Skript verwendet:

* `tools/backup-json-sources.ps1`
* `tools/json-copy.ps1`
* `json-copy.rules.MdTVTycn.json`
