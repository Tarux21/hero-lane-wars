require "/tmp/wt/wav.pl";
my $in = "C:/Users/kipps/Projekt hero lane wars/Sounds/"; my $out = "C:/Users/kipps/Projekt hero lane wars/godot/assets/sounds/";
my @jobs = (
 # Datei, Ausgabe, t0, t1, fade_in, fade_out, Spitze, Stille_am_Anfang_kuerzen, Vorlauf
 ["169666__knova__electricspark--- Kettenblitz.wav", "zap.wav", 0.0, 0.6, 0.003, 0.12, 0.85, 0, 0],
 ["169666__knova__electricspark--- Kettenblitz.wav", "zap_crit.wav", 0.0, 0.6, 0.003, 0.12, 0.95, 0, 0],
 ["249418__midimagician__fire-burning-loop ---- Feuerfeld.wav", "fire_ignite.wav", 2.0, 7.5, 0.4, 1.4, 0.85, 0, 0],
 ["275608__discoversound__fire-spell-01---- Feuer Elementar.wav", "summon_fire.wav", 0.0, 2.0, 0.004, 0.55, 0.9, 0, 0.6],
 ["709888__lotteria001__ice-magic-arrow_type-01 --- Frost Elementar.wav", "summon_frost.wav", 0.15, 1.7, 0.02, 0.45, 0.9, 0, 0.5, 4],
 ["745549__samsterbirdies__beefy-explosions--- Meteor für rang 5 Feuerfeld.wav", "meteor_hit.wav", 0.0, 2.3, 0.004, 0.5, 0.95, 0, 0],
 ["845385__artninja__custom_electrical_lance_impact_02152026 --- Blitz elementar.wav", "summon_lightning.wav", 0.45, 2.5, 0.02, 0.5, 0.9, 1, 0.7],
);
my %cache;
for my $j (@jobs) {
  my ($file,$o,$t0,$t1,$fi,$fo,$pk,$trim,$pad,$boost) = @$j;
  $cache{$file} ||= [ decode($in.$file) ];
  my ($rate,$f) = @{$cache{$file}};
  print write_cut($out.$o, $rate, $f, $t0, $t1, $fi, $fo, $pk, $trim, $pad, $boost), "\n";
}
