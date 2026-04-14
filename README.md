# MdTVTycnRealNames

Echte Namen für Eggcode's **Mad Television Tycoon** (2026)

* https://www.eggcodegames.com/
* https://store.steampowered.com/app/3565020/Mad_Television_Tycoon/

## Beschreibung

Vermutlich aus Lizenz- und Urheberrechtsgründen verwendet Mad Television Tycoon leicht abgeänderte Versionen der echten
Namen für Serien, Filme, Werbedeals, Schauspieler und Regisseure. Es ist jedoch relativ einfach möglich die
Originalnamen "wiederherzustellen": In den relevanten JSON-Dateien der Spiel-Datenbank, insbesondere `ItemsData.json`
und `CastData.json`, enthält das Feld `_comment` die deutschen Originalnamen.

Als Inspiration für dieses Projekt diente ein [Python-Skript](https://drwolfsherz.net/file-download/106/)
von [DrWolfsherz](https://card.drwolfsherz.net/) welches er
in [seinem Forum](https://drwolfsherz.net/forum/thread/36-real-names-f%C3%BCr-mad-television-tycoon/) zur Verfügung
stellt. Im Gegensatz zu DrWolfsherz' Lösung wird hier jedoch keine Installation von Python benötigt. Das Skript basiert
auf MS PowerShell und kann einfach ausgeführt werden. 

## Ausführung

Für einen einfachen Start unter Windows führe `run-mdtvtycn-update.bat` aus.

Das Skript:

* erstellt ein Backup der originalen JSON-Dateien
* führt anschließend die JSON-Anpassung aus
* legt die Backup-Datei als `MdTVTycnDB.backup.tar.gz` direkt im verwendeten Datenbankordner ab

Standardmäßig verwendet die Batch-Datei diesen Pfad:

`C:\Program Files (x86)\Steam\steamapps\common\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE`

Du kannst diesen Pfad beim Start der Batch-Datei überschreiben:

```cmd
run-mdtvtycn-update.bat "D:\Games\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE"
```

Ohne Pause am Ende:

```cmd
run-mdtvtycn-update.bat "D:\Games\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE" --no-pause
```

Das Skript verwendet:

* `tools/backup-json-sources.ps1`
* `tools/json-copy.ps1`
* `json-copy.rules.MdTVTycn.json`
