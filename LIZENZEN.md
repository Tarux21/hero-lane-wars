# Lizenzen und Quellen (Figuren, Sounds, Bilder)

Alles, was wir nicht selbst gemacht haben, steht hier mit Quelle, Lizenz und Änderungen. Bei einer Veröffentlichung gehören die Namensnennungen (CC BY) in den Abspann bzw. auf die Store-Seite.

## Selbst erzeugt (keine fremden Rechte)
- Alle berechneten Klänge (`godot/scripts/sfx.gd`, `sfx_caster.gd`), alle Effekte (`godot/scripts/fx.gd`), Zauberkreise und Texturen im Code.

## 3D-Figuren
- **Quaternius** – „RPG Characters" (Krieger, Schurke, Magier) und „Cute Animated Monsters" (GreenDemon, Cyclops, Skull, Bat, Demon, YellowDragon). Lizenz **CC0** (keine Namensnennung nötig). https://quaternius.com – Dateien in `godot/assets/quaternius/`.

## Sounds
| Datei | Quelle | Lizenz | Änderungen |
|---|---|---|---|
| `godot/assets/sounds/frost_cast.wav` (Frostnova) | „f_Synth_Wind_Whoosh_6.wav" von **cyclonek**, https://freesound.org/people/cyclonek/sounds/529411/ | **CC BY 4.0** (Namensnennung nötig) https://creativecommons.org/licenses/by/4.0/ | erste von zwei Windstößen ausgeschnitten und auf 1,6 s gekürzt, Stille am Anfang/Ende entfernt, ein- und ausgeblendet, auf 16 Bit umgewandelt, Lautstärke angepasst |
| `zap.wav`, `zap_crit.wav` (Kettenblitz) | „electricspark.wav" von **knova**, https://freesound.org/people/knova/sounds/169666/ | **CC BY 4.0** | unverändert bis auf Ein-/Ausblenden und Lautstärke (Krit: etwas tiefer abgespielt) |
| `fire_ignite.wav` (Feuerfeld) | „Fire Burning Loop" von **midimagician**, https://freesound.org/people/midimagician/sounds/249418/ | **CC0** | 5,5 s aus der Mitte ausgeschnitten, ein-/ausgeblendet, auf 16 Bit umgewandelt |
| `summon_fire.wav` (Feuer-Elementar) | „Fire Spell 01" von **DiscoverSound**, https://freesound.org/people/discoversound/sounds/275608/ | **CC BY 4.0** | auf die ersten 2 s gekürzt, Stereo zu Mono, Vorlauf (Stille) davor, ausgeblendet |
| `summon_frost.wav` (Frost-Elementar) | „Ice Magic Arrow_type 01" von **lotteria001**, https://freesound.org/people/lotteria001/sounds/709888/ | **CC0** | gekürzt, Stereo zu Mono, leise Teile angehoben (Begrenzer), Vorlauf davor |
| `meteor_hit.wav` (Meteor, Rang 5) | „Beefy Explosions" von **SamsterBirdies**, https://freesound.org/people/samsterbirdies/sounds/745549/ | **CC0** | erste Explosion (2,3 s) aus 18 s ausgeschnitten, Stereo zu Mono |
| `summon_lightning.wav` (Blitz-Elementar rufen) | Selbst gemischt (`godot/tools/mix_blitz_elementar.gd`): Einschlag aus „lightning strike.wav" von **parnellij** (https://freesound.org/people/parnellij/sounds/74892/, **CC0**) plus selbst berechnetes Aufladen, Zaps und Knistern | **CC0** / selbst erzeugt | Donnergrollen entfernt, höher gestimmt, Ringmodulation, Sättigung, auf 2,3 s gemischt |
| `elem_shot_lightning.wav` (Autoangriff Blitz-Elementar) | „Sähköisiä räsähdyksiä …" (electrical short crackling) von **YleArkisto**, https://freesound.org/people/ylearkisto/sounds/367700/ | **CC BY 4.0** | drittes Knistern (0,6 s) aus 14,6 s ausgeschnitten, Stereo zu Mono, ausgeblendet |
| `elem_shot_frost.wav` (Autoangriff Frost-Elementar) | „Magic Ice Spell Impact & Punch" von **EminYILDIRM**, https://freesound.org/people/EminYILDIRIM/sounds/541479/ | **CC BY 4.0** | erste 0,7 s, Stereo zu Mono, ausgeblendet |
| `tank_shot.wav` (Autoangriff Tank) | „Metallic Whoosh.wav" von **MissCellany**, https://freesound.org/people/MissCellany/sounds/240640/ | **CC0** | unverändert bis auf Ein-/Ausblenden und Lautstärke |
| `tank_q.wav` (Schockwelle Tank) | Selbst gemischt (`godot/tools/mix_tank_q.gd`): erste Explosion aus „Beefy Explosions" von **SamsterBirdies** (https://freesound.org/people/samsterbirdies/sounds/745549/, **CC0**) plus selbst berechneter Boom, Steinknistern und Grollen | **CC0** / selbst erzeugt | Schlag gefiltert und geschärft, 1,0 s |
| `caster_shot.wav`, `elem_shot_fire.wav` (Autoangriff Magier und Feuer-Elementar) | „Fireball" von **qubodup**, https://freesound.org/people/qubodup/sounds/442827/ | **CC BY** (laut Seite 3.0, bitte vor Veröffentlichung nochmal prüfen) | auf 0,65 s gekürzt, Stereo zu Mono, ausgeblendet |

### Namensnennung (Text für Abspann)
„Frostnova-Sound: f_Synth_Wind_Whoosh_6 von cyclonek; Kettenblitz-Sound: electricspark von knova; Feuer-Elementar-Sound: Fire Spell 01 von DiscoverSound ; Blitz-Elementar-Angriff: Sähköisiä räsähdyksiä von YleArkisto; Frost-Elementar-Angriff: Magic Ice Spell Impact & Punch von EminYILDIRM; Feuerball-Angriff: Fireball von qubodup (alle freesound.org, CC BY, bearbeitet).“

## Hinweise
- Neue Dateien: Quelle, Lizenz und Änderungen hier eintragen, **bevor** sie ins Repository kommen. Sounds von Pixabay (Pixabay-Lizenz) nicht unverändert ins öffentliche Repository legen.
- Unbearbeitete Roh-Downloads liegen im Ordner `Sounds/` (nicht im Repository).

