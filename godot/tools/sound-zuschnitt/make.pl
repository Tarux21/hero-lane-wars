# Schneidet die Roh-Downloads aus Sounds/ zu Spiel-Sounds in godot/assets/sounds/. Aufruf: perl make.pl (aus diesem Ordner)
use strict; use warnings; use File::Basename; use Cwd 'abs_path';
my $here = dirname(abs_path($0));
require "$here/wav.pl";
my $in = "$here/../../../Sounds/"; my $out = "$here/../../assets/sounds/";
my @jobs = (
 # Datei (Anfang des Namens + *), Ausgabe, von, bis (s), Einblenden, Ausblenden, Spitze, Stille am Anfang kuerzen, Vorlauf (s), Verstaerkung (Begrenzer)
 ["169666*", "zap.wav", 0.0, 0.6, 0.003, 0.12, 0.85, 0, 0],                       # Kettenblitz-Glied
 ["169666*", "zap_crit.wav", 0.0, 0.6, 0.003, 0.12, 0.95, 0, 0],                  # Kettenblitz Krit
 ["249418*", "fire_ignite.wav", 2.0, 7.5, 0.4, 1.4, 0.85, 0, 0],                  # Feuerfeld
 ["275608*", "summon_fire.wav", 0.0, 2.0, 0.004, 0.55, 0.9, 0, 0.6],              # Feuer-Elementar rufen
 ["709888*", "summon_frost.wav", 0.15, 1.7, 0.02, 0.45, 0.9, 0, 0.5, 4],          # Frost-Elementar rufen
 ["745549*", "meteor_hit.wav", 0.0, 2.3, 0.004, 0.5, 0.95, 0, 0],                 # Meteor-Einschlag
 ["845385*", "summon_lightning.wav", 0.45, 2.5, 0.02, 0.5, 0.9, 1, 0.7],          # Blitz-Elementar rufen
 ["367700*", "elem_shot_lightning.wav", 9.25, 9.95, 0.004, 0.2, 0.85, 1, 0],      # Blitz-Elementar Autoangriff (3. Knistern)
 ["442827*", "caster_shot.wav", 0.0, 0.65, 0.003, 0.25, 0.85, 0, 0],              # Autoangriff Magier
 ["442827*", "elem_shot_fire.wav", 0.0, 0.65, 0.003, 0.25, 0.85, 0, 0],           # Autoangriff Feuer-Elementar
);
sub resolve { my $p = shift; $p =~ s/\*$//; opendir(my $d, $in) or die "Ordner $in fehlt"; my ($m) = grep { index($_, $p) == 0 } readdir $d; die "keine Datei $p*" unless $m; return $m; }
my %cache;
for my $j (@jobs) {
  my ($file,$o,$t0,$t1,$fi,$fo,$pk,$trim,$pad,$boost) = @$j;
  $file = resolve($file); $cache{$file} ||= [ decode($in.$file) ];
  my ($rate,$f) = @{$cache{$file}};
  print write_cut($out.$o, $rate, $f, $t0, $t1, $fi, $fo, $pk, $trim, $pad, $boost), "\n";
}
