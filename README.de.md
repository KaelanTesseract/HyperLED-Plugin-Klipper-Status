# HyperLED-Plugin: Klipper-Statusanzeige

*[English](README.md) · Deutsch*

Ein Plugin für [**HyperLED**](https://github.com/KaelanTesseract/HyperLED), den ESP32-S3-LED-Controller, das den Zustand eines 3D-Druckers mit **Klipper** und **Moonraker** als Licht zeigt: Leerlauf, Vorheizen, Druckfortschritt, Pause, Fehler und fertig.

Es ist **eine einzelne Datei** ([`klipper-status.json`](klipper-status.json)), ohne Firmware-Update installierbar und in der Weboberfläche von HyperLED einstellbar. Es wurde **mit einem Snapmaker U1 getestet**.

![Was die Anzeige in jedem Zustand des Druckers zeigt](docs/images/states.png)

> **Woher die Idee kommt.** Den Zustand eines Druckers als Lichtbalken zu zeigen, ist die Idee von **drc85** und seiner
> [Snapmaker U1 SnapStatus LED Status Bar (WLED, ESP32)](https://makerworld.com/en/models/2686608-snapmaker-u1-snapstatus-led-status-bar-wled-esp32)
> auf MakerWorld, die ihrerseits auf dem WLED-Zusatzmodul *Klipper Percentage* aufbaut. Dort findest du auch die
> **3D-Druckteile** (Halterungen für die Druckplatte, den Boden und die Oberseite des U1), um die Statusleiste selbst zu
> bauen. Dieses Plugin ist eine **eigene Neuentwicklung** für das Plugin-System von HyperLED und enthält **keinen Code**
> aus einem von beiden. Wer WLED statt HyperLED benutzt, schaut sich das Projekt von drc85 an.

*Die Bilder zeigen die Oberfläche von HyperLED auf Englisch; sie gibt es auch auf Deutsch und Russisch.*

## Was das Plugin macht

Alle fünf Sekunden fragt das Plugin den Drucker (über Moonraker) nach seinem Zustand, dem Druckfortschritt und den Temperaturen von Düsen und Heizbett. Ein kleines Lua-Skript macht daraus ein Bild auf dem gewählten LED-Segment. Das Bild richtet sich nach dem Zustand des Druckers:

| Zustand des Druckers | Anzeige auf dem Segment | Rückfall ohne Skript |
|---|---|---|
| **Leerlauf** (`standby`, `cancelled`, oder fertig und im Leerlauf) | gedämpfte Farbe (standardmäßig dunkelblau; Schwarz schaltet das Segment aus) | dieselbe Farbe |
| **Vorheizen** | ein oranger Balken, der sich füllt, je näher die Heizungen an ihrer Solltemperatur sind; er „atmet“ langsam | Effekt *Atmen* in Orange |
| **Drucken** (`printing`) | ein grüner Balken, der sich mit dem Druckfortschritt füllt | Effekt *Einfarbig* in Grün |
| **Pause** (`paused`) | das ganze Segment atmet in Gelb | Effekt *Atmen* in Gelb |
| **Fertig** (`complete`) | das ganze Segment in Cyan, bis der Drucker in den Leerlauf geht | Effekt *Einfarbig* in Cyan |
| **Fehler** (`error`) | das ganze Segment blinkt rot | Effekt *Stroboskop* in Rot |
| **Keine Verbindung** (Drucker aus, Moonraker nicht erreichbar) | einstellbare Farbe (standardmäßig Schwarz = aus) | dieselbe Farbe |

Alle Farben lassen sich in den Einstellungen ändern.

### Leerlauf

Passiert nichts, zeigt das Segment eine gedämpfte Farbe, so siehst du, dass die Anzeige lebt und verbunden ist. Die Klipper-Zustände `standby` und `cancelled` gelten als Leerlauf, ebenso ein fertiger Druck, sobald der Drucker in den Leerlauf gegangen ist (siehe *Fertig*). Stell die Farbe auf Schwarz, wenn das Segment im Leerlauf dunkel sein soll.

### Vorheizen

Das Vorheizen erkennt das Plugin an den Temperaturen, nicht an einem Knopf. Es gilt als Vorheizen, solange der Drucker im Zustand `standby` ist oder einen Druck gerade gestartet, aber noch nichts gefördert hat (Klipper hält `print_duration` bis dahin auf 0), **und** mindestens eine Heizung (eine von bis zu vier Düsen oder das Bett) mehr als *Vorheizen ab Abstand* (standardmäßig 10 °C) unter ihrer Solltemperatur liegt.

Der Balken zeigt dann, wie weit die Heizungen sind: Für jede Heizung, die heizen soll, rechnet das Plugin `Temperatur ÷ Soll`, und die **Heizung, die am weitesten zurückliegt, bestimmt** die Länge des Balkens. Ein noch kaltes Bett hält den Balken also kurz, auch wenn die Düse schon heiß ist. Der ganze Balken atmet, damit klar zu sehen ist, dass der Drucker auf etwas wartet. Mindestens eine LED leuchtet immer, ein Balken nahe 0 % sieht also nie wie ein dunkler Streifen aus.

### Drucken

Meldet Klipper `printing` (und hat zu fördern begonnen), folgt der Balken dem **Druckfortschritt** aus `display_status.progress`: dem Wert des letzten `M73` im G-Code, sonst dem gelesenen Anteil der Datei. Endet der Balken mitten in einer LED, leuchtet diese anteilig, der Balken wächst also auch auf einem kurzen Streifen gleichmäßig.

Der Balken **wächst nur**. Der Fortschritt kann ein Stück zurückspringen (er stammt vom letzten `M73`), und ein Balken, der um einige LEDs vor- und zurückspringt, sieht nach Flackern aus. Fällt der gemeldete Fortschritt in einem Druck um weniger als 30 Prozentpunkte, bleibt der Balken stehen, wo er war. Ein größerer Rückgang oder ein neuer Druck beginnt einen neuen Balken. Auf Wunsch atmet das Pixel am wachsenden Ende des Balkens (*Vorderstes Pixel atmet beim Drucken*), dann sieht man auf einen Blick, dass der Druck lebt.

### Pause, fertig, Fehler

- **Pause**: das ganze Segment atmet in der Pausenfarbe (standardmäßig Gelb).
- **Fertig**: Nach einem Druck bleibt Klipper im Zustand `complete`, bis eine neue Datei geladen wird, womöglich tagelang. Deshalb zeigt das Plugin die Fertig-Farbe (Cyan) nur, **bis der Drucker in den Leerlauf geht** (Klipper-Einstellung `idle_timeout`, standardmäßig zehn Minuten) und nur, wenn **„Fertig“ anzeigen** eingeschaltet ist. Danach kehrt die Leerlauffarbe zurück.
- **Fehler**: das ganze Segment blinkt in der Fehlerfarbe, 250 ms an und 250 ms aus.

### Keine Verbindung

Antwortet der Drucker nicht (ausgeschaltet, Netz weg, Moonraker läuft nicht), wartet das Plugin einige fehlgeschlagene Anfragen ab und zeigt dann die *Farbe ohne Verbindung*. Schwarz, die Voreinstellung, heißt: das Segment wird dunkel. Das Plugin zeigt keinen veralteten Zustand weiter an.

### Rührt deine Helligkeit nie an

Die Helligkeitsregler von HyperLED wirken wörtlich, und dieses Plugin verstellt sie nie. Alles, was es zeigt, liegt nur als Überlagerung über dem Segment und wird nie gespeichert. Schaltest du das Plugin aus oder entfernst es, ist das Segment sofort wieder so, wie du es eingestellt hast. Die Einstellung *Helligkeit der Anzeige* dimmt nur die eigenen Farben des Plugins.

## Wie sich der Balken auf Streifen und Panels verhält

Das Plugin erkennt **selbst**, wie das gewählte Segment eingerichtet ist, und braucht dafür keine Einstellung:

- Ein **Panel**, ein **einfacher Streifen** und alles auf einem **Slave** füllt sich entlang der Spalten, die **Richtung** gilt von links nach rechts.
- Hat der Master in den Geräte-Einstellungen eine **Matrix** eingerichtet (zum Beispiel 64 × 64 für die Leinwand), obwohl nur ein Streifen daran hängt, liegt dieser Streifen auf der Fläche in Reihen. Das erkennt HyperLED und meldet es dem Skript, der Balken läuft dann **der Reihe nach über die LEDs** des Streifens, wie du ihn dir vorstellst, und die **Richtung** gilt entlang des Streifens.

Das setzt eine Firmware voraus, die dem Skript das Segment beschreibt (`settings._layout`, siehe [Plugin-Skripte](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/11_Plugin_Skripte.md)). Auf einer älteren Firmware füllt sich ein solcher Streifen von beiden Enden her.

Die **Richtung** des Balkens ist eine Einstellung:

![Die vier Richtungen des Balkens](docs/images/directions.png)

*(Bilder: das eigene Skript des Plugins auf einem simulierten Streifen mit 48 LEDs und den Standardfarben, erzeugt von [`tools/render_states.py`](tools/render_states.py).)*

## Voraussetzungen

- HyperLED mit **Plugin-Unterstützung und Skripten** (Master-Firmware 0.3.000 oder neuer). Läuft das Segment auf einem **Slave**, braucht der Slave für den Balken die Firmware 0.3.000 oder neuer; ein älterer Slave zeigt die Rückfall-Spalte der Tabelle oben.
- Ein Drucker mit **Klipper** und **Moonraker**, den das HyperLED im Netzwerk erreicht. Moonraker hört standardmäßig auf Port **7125**.
- Moonraker verlangt von Adressen, die nicht zu den `trusted_clients` seiner `moonraker.conf` gehören, einen **API-Schlüssel**. Trage ihn dann in das Plugin ein (Feld *API-Schlüssel*); gehört dein HyperLED zu den `trusted_clients`, bleibt das Feld leer.

## Installieren

1. Lade die Datei [`klipper-status.json`](klipper-status.json) herunter (oder benutze die Datei der neuesten [Release](https://github.com/KaelanTesseract/HyperLED-Plugin-Klipper-Status/releases)).
2. Öffne in HyperLED **Einstellungen → Plugins → + Plugin hinzufügen** und wähle die Datei, oder gib die Adresse der Datei unter **Von einer Adresse laden** ein.

   ![Die Plugin-Liste in HyperLED](docs/images/ui-plugin-list.png)

3. HyperLED prüft die Datei und zeigt, was sie vorhat, **bevor etwas gespeichert wird**: wohin sie schaut und dass sie auf ein Segment zeichnet und ein Skript enthält. Bestätige mit *Installieren*.

   ![Die Vorschau vor dem Installieren](docs/images/ui-install.png)

4. Die **Einstellungen** des Plugins öffnen sich. Trage die **Drucker-Adresse** ein, wähle das **Segment** und schalte das Plugin ein.

   ![Die Einstellungen des Plugins](docs/images/ui-settings.png)

Die Adresse in den Bildern (`192.168.1.50`) ist nur ein Beispiel; nimm die Adresse deines Druckers.

Läuft es, sagt dir die Lichtseite, welches Segment das Plugin steuert, und bietet an, seine Einstellungen zu öffnen oder es zu **pausieren**, danach gelten wieder deine eigenen Einstellungen:

![Der Hinweis auf der Lichtseite](docs/images/ui-light-notice.png)

**Live-Werte** auf der Karte des Plugins zeigen, was das Plugin gerade vom Drucker gelesen hat und wer das Segment zeichnet. Das ist der schnellste Weg, eine falsche Adresse oder einen Wert zu finden, der nicht ankommt:

![Die Live-Werte](docs/images/ui-live-values.png)

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
| Helligkeit der Anzeige | dimmt die Farben des Plugins (5 bis 100 %); die Helligkeit des Segments gilt zusätzlich. Wirkt nur mit dem Skript | 100 |
| Farben | Leerlauf, Vorheizen, Drucken, Pause, Fertig, Fehler, ohne Verbindung | siehe Plugin |
| „Fertig“ anzeigen | die Fertig-Farbe nach einem Druck zeigen | an |

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

Moonraker lässt Objekte oder Felder, die es nicht gibt, einfach aus; das Plugin behandelt sie als „unbekannt“. Antwortet Moonraker mehrfach nicht, gilt der Zustand „keine Verbindung“. Zum Drucker wird nie etwas geschrieben: Das Plugin liest nur.

## Das Plugin selbst bauen

Ein Plugin ist reines JSON, und JSON kennt keine mehrzeiligen Texte. Deshalb liegt das Lua-Skript in [`src/klipper-status.lua`](src/klipper-status.lua) und der Rest in [`src/klipper-status.template.json`](src/klipper-status.template.json); `build.py` setzt das Skript in das Feld `script` und schreibt `klipper-status.json`:

```bash
python build.py
```

Die fertige Datei prüft HyperLED beim Installieren vollständig (`POST /api/plugins/preview` prüft sie, ohne etwas zu speichern). Das Format ist in [Plugins entwickeln](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/10_Plugins_entwickeln.md) und [Plugin-Skripte](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/11_Plugin_Skripte.md) beschrieben.

Die Bilder in dieser README erzeugt [`tools/render_states.py`](tools/render_states.py), das das eigene Skript des Plugins ausführt (braucht `pip install pillow lupa`).

## Getestet mit, und bekannte Punkte

**Getestet mit einem Snapmaker U1**, einem Klipper-Drucker mit **vier Werkzeugköpfen**. Fortschritt und Temperatur der gerade druckenden Düse kommen richtig an, alle vier Düsen und das Bett werden für den Vorheiz-Balken gelesen, und der Balken läuft über einen LED-Streifen an einem HyperLED-Master. Das Plugin wurde außerdem mit einem Nachbau der Moonraker-Antworten durch alle Zustände geführt (Leerlauf, Vorheizen von Hand und beim Druckstart, Drucken bei 0/25/50/100 %, Pause, fertig mit und ohne Leerlauf, abgebrochen, Fehler und Drucker verschwindet).

Es ist gegen die Dokumentation von Moonraker und Klipper und gegen den Quelltext von Klipper (`print_stats`) gebaut: Zustandsnamen, Felder und Abfrageform stammen von dort. Andere Drucker können abweichen, zum Beispiel einer mit mehr als vier Extrudern (diese werden nicht gelesen) oder ohne `M73` im G-Code. Wer es an einem anderen Drucker ausprobiert, ist herzlich eingeladen, das Ergebnis als Issue zu melden.

**Bekannt:** Auf manchen LED-Streifen, die über einen USB-Anschluss ohne eigene, kräftige Stromversorgung laufen, können LEDs hinter dem Balkenende kurz aufblitzen. Das hängt an der Stromversorgung und am Datensignal des Streifens und nicht am Plugin. Hilfreich sind ein Netzteil mit genug Strom, ein 330-Ω-Widerstand in der Datenleitung, ein Elko über 5 V und Masse am Streifenanfang und ein Pegelwandler (74AHCT125) von 3,3 V auf 5 V.

## Die Idee und die Hardware

Die Idee, den Zustand eines Klipper-Druckers als Lichtbalken zu zeigen, kommt von **drc85**: [Snapmaker U1 SnapStatus LED Status Bar (WLED, ESP32)](https://makerworld.com/en/models/2686608-snapmaker-u1-snapstatus-led-status-bar-wled-esp32) auf MakerWorld ([Quelltext auf GitHub](https://github.com/drc85/U1-SnapStatus)), das auf dem WLED-Zusatzmodul *Klipper Percentage* aufbaut. Auf dieser Seite gibt es die **3D-Druckteile** für die Statusleiste eines Snapmaker U1: eine Halterung für die Druckplatte, eine für den Boden und eine für die Oberseite. Die druckst du aus und setzt einen Streifen WS2812B-LEDs ein; dieses Plugin sorgt dafür, dass der Streifen den Zustand des Druckers zeigt, wenn HyperLED der Controller dahinter ist.

Dieses Plugin ist eine eigene Neuentwicklung für HyperLED. Es enthält keinen Code aus dem Projekt von drc85 oder aus dem WLED-Zusatzmodul und übernimmt auch deren Farbschema nicht; es hat eigene Zustände (siehe Tabelle oben).

## Über HyperLED

[**HyperLED**](https://github.com/KaelanTesseract/HyperLED) ist ein ESP32-S3-LED-Controller mit Glassmorphism-Weboberfläche, Effekten, Szenen, Matrix-Panels, Master/Slave-Gleichlauf über einen Kabelbus oder ESP-NOW, MQTT mit Home-Assistant-Erkennung, Updates über die Luft und **Plugins** wie diesem. Wer wissen will, was ein Plugin ist und was es darf, beginnt mit [Plugins nutzen](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/09_Plugins_nutzen.md), und wer ein eigenes schreiben will, mit [Plugins entwickeln](https://github.com/KaelanTesseract/HyperLED/blob/main/docs/de/10_Plugins_entwickeln.md).

Dieses Plugin ist ein eigenständiges Werk und kein Teil von HyperLED. HyperLED selbst steht unter der EUPL-1.2; dieses Plugin unter der unten beschriebenen Lizenz.

## Lizenz

Copyright (c) 2026 Dennis Guse.

Dieses Plugin steht unter der [**PolyForm Noncommercial License 1.0.0**](LICENSE) ([Text online](https://polyformproject.org/licenses/noncommercial/1.0.0), englisch):

- **Frei für nichtkommerzielle Nutzung.** Benutzen, kopieren, ändern und weitergeben für den privaten Gebrauch, Hobbyprojekte, Lernen und Forschung sowie für gemeinnützige, Bildungs- und öffentliche Einrichtungen, so wie die Lizenz es beschreibt.
- **Kommerzielle Nutzung braucht eine kommerzielle Lizenz vom Autor.** Wer das Plugin in einem Unternehmen, in einem Produkt oder sonst auf eine Weise nutzen will, mit der Geld verdient wird, kann bei mir eine Lizenz kaufen. Melde dich über mein GitHub-Profil ([KaelanTesseract](https://github.com/KaelanTesseract)), zum Beispiel mit einem Issue „Commercial license“ in diesem Repository.

Die Plugin-Datei nennt die Lizenz im Feld `license` (`PolyForm-Noncommercial-1.0.0`), und das Skript trägt einen Lizenzkopf. Der Hinweis, der mit Kopien mitgehen muss, steht in [`NOTICE`](NOTICE).

Ein Wort dazu: Weil kommerzielle Nutzung nicht frei ist, ist das **quelloffen einsehbar** („source-available“), aber kein „Open Source“ im Sinne der Definition der Open Source Initiative. Alles darf für nichtkommerzielle Zwecke gelesen, geändert und weitergegeben werden. Verbindlich ist der PolyForm-Text; dieser Abschnitt fasst ihn nur zusammen.
