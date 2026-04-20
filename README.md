# MdTVTycnRealNames

![Release](https://img.shields.io/github/v/release/chrtmnn/MdTVTycnRealNames)
![Windows](https://img.shields.io/badge/platform-Windows-blue)
![PowerShell](https://img.shields.io/badge/powershell-5.1-2671BE.svg)

<table border="0px">
  <tr>
    <td rowspan="2" valign="top"><img style="min-width:192px" src="/assets/MdTVTycnRealNames.png" alt="MdTVTycnRealNames Logo" width="192" height="192"></td>
    <td valign="top">
      <strong>Deutsche Originalnamen für Mad Television Tycoon</strong> (2026)
      <ul>
        <li>Link zum <a href="https://steamcommunity.com/sharedfiles/filedetails/?id=3709421607">Steam Guide</a></li>
      </ul>
      <p>Einfach entpacken, ausführen, fertig!</p>
    </td>
  </tr>
  <tr>
    <td valign="top">
      <strong>Mad Television Tycoon</strong> (2026)
      <ul>
        <li><a href="https://www.eggcodegames.com">Eggcode Games</a></li>
        <li><a href="https://store.steampowered.com/app/3565020/Mad_Television_Tycoon">Mad Television Tycoon</a>  auf Steam</li>
      </ul>
    </td>
  </tr>
</table>

## 📜 Beschreibung

Vermutlich aus Lizenz- und Urheberrechtsgründen verwendet Mad Television Tycoon leicht abgeänderte Versionen der echten
Namen für Serien, Filme, Werbedeals, SchauspielerInnen und RegisseurInnen. Diese Originalnamen lassen sich jedoch
relativ einfach wiederherstellen: In den relevanten JSON-Dateien der Spiel-Datenbank, insbesondere `ItemsData.json` und
`CastData.json`, enthält das Feld `_comment` die deutschen Originalnamen.

Als Inspiration für dieses Projekt diente ein [Python-Skript](https://drwolfsherz.net/file-download/106) von
[DrWolfsherz](https://card.drwolfsherz.net), das er in
[seinem Forum](https://drwolfsherz.net/forum/thread/36-real-names-f%C3%BCr-mad-television-tycoon) zur Verfügung
stellt. Im Gegensatz zu DrWolfsherz' Lösung wird hier jedoch keine Installation von Python benötigt. Das Skript basiert
auf MS PowerShell und lässt sich direkt ausführen.

Die Anpassungen funktionieren auch mit bereits vorhandenen Savegames, da die Daten im dafür von den Entwicklern
vorgesehenen `MOD`-Ordner abgelegt werden. Es werden keine Originaldateien oder Spielstanddateien geändert.

## 💾 Download

Die aktuelle Version steht als GitHub-Release bereit:

[![Neueste Version herunterladen](https://img.shields.io/github/v/release/chrtmnn/MdTVTycnRealNames?style=for-the-badge)](https://github.com/chrtmnn/MdTVTycnRealNames/releases/latest)

Lade das aktuelle Release herunter und entpacke das ZIP-Archiv anschließend in einen beliebigen Ordner. Danach kannst
du die enthaltene Batch-Datei direkt ausführen.

## 🚀 Ausführung

Nach dem Entpacken kannst du unter Windows einfach `run-mdtvtycn-update.bat` ausführen.

Das Skript führt folgende Schritte aus:

1. Optionales Backup der originalen JSON-Dateien als `MdTVTycnDB.backup.YYYYMMDD-HHMMSS.tar.gz` direkt im verwendeten
   Datenbankordner
2. Anschließend Ausführung der JSON-Anpassung

Das Backup wird nur ausgeführt, wenn du `--backup` mitgibst.

Standardmäßig verwendet die Batch-Datei diesen Pfad:

    C:\Program Files (x86)\Steam\steamapps\common\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE

Du kannst diesen Pfad beim Start der Batch-Datei überschreiben:

    run-mdtvtycn-update.bat "D:\Games\Mad Television Tycoon\MadTelevisionTycoon\EXTERN\DATABASE"

Ohne Pause am Ende:

    run-mdtvtycn-update.bat --no-pause

Mit Backup:

    run-mdtvtycn-update.bat --backup

Das Skript verwendet:

* `tools/backup-json-sources.ps1`
* `tools/json-copy.ps1`
* `MdTVTycn.json`
* `MdTVTycn.value-maps.json`

In `MdTVTycn.value-maps.json` können optionale Ersetzungen für spezielle Werte gepflegt werden. Die Datei wird beim
Start automatisch an `json-copy.ps1` übergeben. Regeln, die `replaceFromMap` verwenden, beziehen ihre Werte aus dieser
zentralen Map-Datei.

---

#### _Disclaimer_

_Dieses Projekt ist ein inoffizielles Fan- und Modding-Tool und steht in keiner Verbindung zu Eggcode Games oder den
Entwicklern von Mad Television Tycoon. Es ist weder gesponsert noch unterstützt. Namen, Marken und Inhalte des Spiels
gehören ihren jeweiligen Rechteinhabern._

_Die Nutzung erfolgt auf eigene Verantwortung und nur für eigene, legal erworbene Spielkopien. Ich übernehme keine
Haftung für Schäden, Datenverlust, kaputte Spielstände oder andere Probleme, die durch die Ausführung der Skripte
entstehen können. Bitte lege vor der Nutzung ein Backup an. Die Kompatibilität kann sich durch Updates des Spiels oder
geänderte Dateistrukturen jederzeit ändern._
