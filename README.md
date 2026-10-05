# HyperLED-Plugin: Klipper-Statusanzeige

Ein Plugin für [HyperLED](https://github.com/KaelanTesseract/HyperLED), das den Zustand eines 3D-Druckers mit **Klipper** und **Moonraker** als Licht zeigt: Leerlauf, Vorheizen, Druckfortschritt, Pause, Fehler und fertig.

Es ist **eine einzelne Datei** ([`klipper-status.json`](klipper-status.json)), ohne Firmware-Update installierbar und in der Weboberfläche von HyperLED einstellbar.

## Was du siehst

| Zustand des Druckers | Anzeige auf dem Segment | Rückfall ohne Skript |
|---|---|---|
| **Leerlauf** (`standby`, `cancelled`) | gedämpfte Farbe (einstellbar, Schwarz = aus) | dieselbe Farbe |
| **Vorheizen** (Düse oder Bett liegt mehr als der eingestellte Abstand unter der Solltemperatur) | ein Balken, der sich füllt, je näher die Heizungen an ihrer Solltemperatur sind; er „atmet“ | Effekt *Atmen* |
| **Drucken** (`printing`) | ein Balken, der sich mit dem Fortschritt füllt (bei 0 % leuchtet eine LED); auf Wunsch atmet das Pixel am wachsenden Ende | Effekt *Einfarbig* in der Druckfarbe |
| **Pause** (`paused`) | die Pausenfarbe, atmend | Effekt *Atmen* |
| **Fertig** (`complete`) | die Fertig-Farbe, bis der Drucker in den Leerlauf geht | Effekt *Einfarbig* |
| **Fehler** (`error`) | schnelles rotes Blinken | Effekt *Stroboskop* |
| **Keine Verbindung** (Drucker aus, Moonraker nicht erreichbar) | einstellbare Farbe (Standard: Schwarz = aus) | dieselbe Farbe |

Der Balken kommt von einem kleinen **Lua-Skript** im Plugin. Kann das Skript nicht laufen (zum Beispiel auf einem Slave mit Firmware vor 0.3.000), zeigt das Plugin den Zustand mit den **Regeln** in der letzten Spalte; die Oberfläche von HyperLED nennt dann den Grund. Der Fortschritt ist in diesem Rückfall nicht zu sehen.

Nach einem Druck bleibt Klipper im Zustand `complete`, bis eine neue Datei geladen wird. Deshalb zeigt das Plugin „fertig“ nur, **bis der Drucker in den Leerlauf geht** (Klipper-Einstellung `idle_timeout`, standardmäßig 10 Minuten) und nur, wenn **„Fertig“ anzeigen** eingeschaltet ist.

### Wie sich der Balken auf Streifen und Panels verhält

Das Plugin erkennt **selbst**, wie das gewählte Segment eingerichtet ist, und braucht dafür keine Einstellung:

- Ein **Panel**, ein **einfacher Streifen** und alles auf einem **Slave** füllt sich entlang der Spalten, die **Richtung** gilt von links nach rechts.
- Hat der Master in den Geräte-Einstellungen eine **Matrix** eingerichtet (zum Beispiel 64 × 64 für die Leinwand), obwohl nur ein Streifen daran hängt, liegt dieser Streifen auf der Fläche in Reihen. Das erkennt HyperLED und meldet es dem Skript, der Balken läuft dann **der Reihe nach über die LEDs** des Streifens, wie du ihn dir vorstellst, und die **Richtung** gilt entlang des Streifens.

Das setzt eine Firmware voraus, die dem Skript das Segment beschreibt (`settings._layout`, siehe [Plugin-Skripte](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/11_Plugin_Skripte.md)). Auf einer älteren Firmware füllt sich ein solcher Streifen von beiden Enden her.

## Voraussetzungen

- HyperLED mit **Plugin-Unterstützung und Skripten** (Master-Firmware 0.3.000 oder neuer). Läuft das Segment auf einem **Slave**, braucht der Slave für den Balken die Firmware 0.3.000 oder neuer.
- Ein Drucker mit **Klipper** und **Moonraker**, den das HyperLED im Netzwerk erreicht. Moonraker hört standardmäßig auf Port **7125**.
- Moonraker verlangt von Adressen, die nicht zu den `trusted_clients` seiner `moonraker.conf` gehören, einen **API-Schlüssel**. Trage ihn dann in das Plugin ein (Feld *API-Schlüssel*); gehört dein HyperLED zu den `trusted_clients`, bleibt das Feld leer.

## Installieren

1. Lade die Datei [`klipper-status.json`](klipper-status.json) herunter (oder benutze den Link zur Datei aus der neuesten Release).
2. Öffne in HyperLED **Einstellungen → Plugins → + Plugin hinzufügen** und wähle die Datei, oder gib die Adresse der Datei unter **Von einer Adresse laden** ein.
3. Prüfe in der Vorschau, was das Plugin abfragt, und bestätige.
4. Öffne die **Einstellungen** des Plugins, trage die **Drucker-Adresse** ein, wähle das **Segment** und schalte das Plugin ein.

## Einstellungen

| Einstellung | Bedeutung | Standard |
|---|---|---|
| Drucker-Adresse | IP-Adresse oder Name des Druckers | – |
| Port | Port von Moonraker | 7125 |
| API-Schlüssel | nur nötig, wenn HyperLED nicht zu den `trusted_clients` gehört (wird nie angezeigt und verlässt das Gerät nie) | leer |
| Segment | das Segment, das die Anzeige übernimmt | – |
| Richtung des Balkens | von links nach rechts, von rechts nach links, von beiden Seiten zur Mitte oder von der Mitte nach außen | links nach rechts |
| Vorheizen ab Abstand | so viele °C muss Düse oder Bett unter ihrer Solltemperatur liegen, damit es als Vorheizen gilt | 10 |
| Vorderstes Pixel atmet | beim Drucken atmet das Pixel am wachsenden Ende des Balkens; aus ist ruhiger, denn jedes Bild, das an die LEDs geht, kann auf manchen Streifen ein Flackern auslösen | aus |
| Helligkeit der Anzeige | dimmt die Farben des Plugins (5 bis 100 %); die Helligkeit des Segments gilt zusätzlich. Wirkt nur mit dem Skript, im Rückfall mit Regeln zählen die Farben | 100 |
| Farben | Leerlauf, Vorheizen, Drucken, Pause, Fertig, Fehler, ohne Verbindung | siehe Plugin |
| „Fertig“ anzeigen | die Fertig-Farbe nach einem Druck zeigen | an |

Der Balken **wächst nur**: Geht der gemeldete Fortschritt innerhalb eines Zustands um weniger als 30 Prozentpunkte zurück, bleibt er stehen, wo er war.

Das Plugin ändert **nie die Helligkeit**: Die Regler in HyperLED wirken wörtlich. Alles, was das Plugin zeigt, liegt nur als Überlagerung über dem Segment und wird nie gespeichert; schaltest du es aus oder entfernst es, ist das Segment sofort wieder so, wie du es eingestellt hast.

## Was abgefragt wird

Alle fünf Sekunden ein einziger `GET` an Moonraker:

```
http://<Adresse>:<Port>/printer/objects/query?print_stats=state,print_duration&display_status=progress&idle_timeout=state&extruder=temperature,target&extruder1=temperature,target&extruder2=temperature,target&extruder3=temperature,target&heater_bed=temperature,target
```

Gelesen werden:

| Wert | Quelle in der Antwort | Bedeutung |
|---|---|---|
| `state` | `print_stats.state` | `standby`, `printing`, `paused`, `complete`, `cancelled` oder `error` |
| `duration` | `print_stats.print_duration` | Druckzeit; bleibt 0, bis Filament gefördert wird (so wird das Vorheizen vor dem ersten Strich erkannt) |
| `progress` | `display_status.progress` · 100 | Fortschritt in Prozent: der Wert des letzten `M73`, sonst der Anteil der gelesenen Datei (nach der Klipper-Dokumentation) |
| `idle` | `idle_timeout.state` | `Idle`, `Ready` oder `Printing` |
| `e0` bis `e3`, `bed` | `extruder`, `extruder1` bis `extruder3`, `heater_bed` | Temperatur der Düsen und des Betts; eine Düse, die der Drucker nicht hat, fehlt einfach |
| `g0` bis `g3`, `bed_gap` | dieselben | wie weit die Heizung unter ihrer Solltemperatur liegt (Soll minus Ist) |

Moonraker lässt Objekte oder Felder, die es nicht gibt, einfach aus; das Plugin behandelt sie als „unbekannt“. Antwortet Moonraker mehrfach nicht, gilt der Zustand „keine Verbindung“.

## Das Plugin selbst bauen

Ein Plugin ist reines JSON, und JSON kennt keine mehrzeiligen Texte. Deshalb liegt das Lua-Skript in [`src/klipper-status.lua`](src/klipper-status.lua) und der Rest in [`src/klipper-status.template.json`](src/klipper-status.template.json); `build.py` setzt das Skript in das Feld `script` und schreibt `klipper-status.json`:

```bash
python build.py
```

Die fertige Datei prüft HyperLED beim Installieren vollständig (`POST /api/plugins/preview` prüft sie, ohne etwas zu speichern). Das Format ist in [Plugins entwickeln](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/10_Plugins_entwickeln.md) und [Plugin-Skripte](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/11_Plugin_Skripte.md) beschrieben.

## Stand und Prüfung

Das Plugin ist gegen die Dokumentation von Moonraker und Klipper und gegen den Quelltext von Klipper (`print_stats`) gebaut: Zustandsnamen, Felder und Abfrageform stammen von dort. Die Datei besteht die Prüfung der Installation in HyperLED (Format, Ausdrücke, Skript wird übersetzt) und wurde mit einem nachgebauten Moonraker durch alle Zustände geführt.

**Am echten Drucker** lief es mit einem Klipper-Drucker mit **vier Extrudern** (Werkzeugwechsler): Der Fortschritt und die Temperatur des gerade druckenden Extruders kommen richtig an, und der Balken läuft über einen LED-Streifen am Master. Bei anderen Druckern können Abweichungen auftauchen, zum Beispiel bei mehr als vier Extrudern (diese werden nicht gelesen) oder bei einem Drucker ohne `M73` im G-Code. Wer es ausprobiert, ist herzlich eingeladen, das Ergebnis als Issue zu melden.

**Bekannt:** Auf manchen LED-Streifen, die über einen USB-Anschluss ohne eigene, kräftige Stromversorgung laufen, können LEDs hinter dem Balkenende kurz aufblitzen. Das hängt an der Stromversorgung und am Datensignal des Streifens und nicht am Plugin. Hilfreich sind ein Netzteil mit genug Strom, ein 330-Ω-Widerstand in der Datenleitung, ein Elko über 5 V und Masse am Streifenanfang und ein Pegelwandler (74AHCT125) von 3,3 V auf 5 V.

## Herkunft

Die Idee, einen 3D-Drucker als Licht anzuzeigen, kommt vom WLED-Zusatzmodul von drc85. Dieses Plugin ist eine **eigene Neuentwicklung** für das Plugin-System von HyperLED und enthält keinen Code daraus.

## Lizenz

[EUPL-1.2](LICENSE) (European Union Public Licence), wie HyperLED. Das Feld `license` der Plugin-Datei nennt sie ebenfalls; das Skript trägt einen Lizenzkopf.
