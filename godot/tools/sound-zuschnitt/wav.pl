use strict; use warnings;
# decode: liefert (rate, \@mono_floats)
my @STEP = (7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767);
my @IDX = (-1,-1,-1,-1,2,4,6,8);
sub decode {
  my ($file) = @_;
  open(my $fh, "<:raw", $file) or die "$file: $!"; local $/; my $d = <$fh>; close $fh;
  my $pos = 12; my ($fmt,$ch,$rate,$ba,$bits,$spb); my ($dstart,$dlen);
  while ($pos + 8 <= length $d) {
    my $id = substr($d,$pos,4); my $sz = unpack("V", substr($d,$pos+4,4));
    if ($id eq "fmt ") { ($fmt,$ch,$rate,undef,$ba,$bits) = unpack("vvVVvv", substr($d,$pos+8,16)); $spb = unpack("v", substr($d,$pos+8+20,2)) if $sz >= 22; }
    elsif ($id eq "data") { $dstart = $pos+8; $dlen = $sz; last; }
    $pos += 8 + $sz + ($sz % 2);
  }
  $dlen = length($d) - $dstart if $dstart + $dlen > length $d;
  my @frames; # je Frame Mittelwert der Kanäle
  if ($fmt == 1 && $bits == 16) { my @s = unpack("s<*", substr($d,$dstart,$dlen)); for (my $i=0;$i<@s;$i+=$ch){ my $a=0; $a += $s[$i+$_] for 0..$ch-1; push @frames, $a/$ch/32768; } }
  elsif ($fmt == 1 && $bits == 24) { my $n = int($dlen/3/$ch); for my $i (0..$n-1){ my $a=0; for my $c (0..$ch-1){ my ($b0,$b1,$b2)=unpack("C3",substr($d,$dstart+($i*$ch+$c)*3,3)); my $v=$b0+$b1*256+$b2*65536; $v-=16777216 if $v>=8388608; $a+=$v/8388608; } push @frames,$a/$ch; } }
  elsif ($fmt == 1 && $bits == 32) { my @s = unpack("l<*", substr($d,$dstart,$dlen)); for (my $i=0;$i<@s;$i+=$ch){ my $a=0; $a += $s[$i+$_] for 0..$ch-1; push @frames, $a/$ch/2147483648; } }
  elsif ($fmt == 3 && $bits == 32) { my @s = unpack("f<*", substr($d,$dstart,$dlen)); for (my $i=0;$i<@s;$i+=$ch){ my $a=0; $a += $s[$i+$_] for 0..$ch-1; push @frames, $a/$ch; } }
  elsif ($fmt == 0x11) { # IMA ADPCM, Mono
    die "ADPCM nur mono" if $ch != 1;
    for (my $b=0; $b + $ba <= $dlen; $b += $ba) {
      my $blk = substr($d,$dstart+$b,$ba);
      my ($pred,$idx) = unpack("s<C", $blk); push @frames, $pred/32768;
      for my $byte (unpack("C*", substr($blk,4))) {
        for my $nib ($byte & 15, $byte >> 4) {
          my $step = $STEP[$idx]; my $diff = $step >> 3;
          $diff += $step if $nib & 4; $diff += $step>>1 if $nib & 2; $diff += $step>>2 if $nib & 1;
          $diff = -$diff if $nib & 8; $pred += $diff; $pred = 32767 if $pred > 32767; $pred = -32768 if $pred < -32768;
          $idx += $IDX[$nib & 7]; $idx = 0 if $idx < 0; $idx = 88 if $idx > 88;
          push @frames, $pred/32768;
        }
      }
    }
  } else { die "Format $fmt/$bits nicht unterstützt" }
  return ($rate, \@frames);
}
sub envelope { my ($rate,$f,$win)=@_; $win ||= 0.25; my $n=int($win*$rate); my @o; for (my $i=0;$i<@$f;$i+=$n){ my ($s,$c,$pk)=(0,0,0); for my $j ($i..($i+$n-1<$#$f?$i+$n-1:$#$f)){ my $v=$f->[$j]; $s+=$v*$v; $c++; $pk=abs($v) if abs($v)>$pk } push @o, sprintf("%.2fs:%.2f", $i/$rate, sqrt($s/$c)); } return @o; }
# Ausschnitt schreiben: t0,t1 in s, fade in/out in s, Spitze
sub tanh_ { my $x = shift; my $e = exp(2*$x); return ($e-1)/($e+1); }
sub write_cut {
  my ($out,$rate,$f,$t0,$t1,$fi,$fo,$peak,$trim_silence,$pad,$boost,$lp) = @_; $pad ||= 0; $boost ||= 1;
  my $a = int($t0*$rate); my $b = int($t1*$rate); $b = $#$f if $b > $#$f;
  if ($trim_silence) { $a++ while $a < $b && abs($f->[$a]) < 0.003; $a = $a - int(0.01*$rate); $a = 0 if $a < 0; }
  my @x = @$f[$a..$b]; if ($lp) { my $k = 1 - exp(-6.2831853*$lp/$rate); for (1..2) { my $y = 0; for my $s (@x) { $y += $k*($s-$y); $s = $y; } } }   # Tiefpass (2 Stufen): weicher, weniger schrill
  my $pk = 0.0001; for (@x) { $pk = abs($_) if abs($_) > $pk }
  unshift @x, (0) x int($pad*$rate); my $g = $peak / $pk; my $n = @x; my $nfi = int($fi*$rate); my $nfo = int($fo*$rate); my $pcm = "";
  for my $i (0..$n-1) { my $v = $x[$i]*$g; if ($boost > 1) { $v = $peak * tanh_($v/$peak*$boost) / tanh_($boost); } $v *= $i/$nfi if $nfi && $i < $nfi; $v *= ($n-1-$i)/$nfo if $nfo && $i > $n-$nfo; $pcm .= pack("s<", int($v*32767)); }
  open(my $o, ">:raw", $out) or die; print $o "RIFF", pack("V", 36+length $pcm), "WAVEfmt ", pack("VvvVVvv",16,1,1,$rate,$rate*2,2,16), "data", pack("V", length $pcm), $pcm; close $o;
  return sprintf("%s: %.2f s ab %.2f s", $out, $n/$rate, $a/$rate);
}
1;
