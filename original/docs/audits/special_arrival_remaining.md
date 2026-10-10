# Special-event arrival verification

LORESPEC.PAS's ten remaining control sites were the map25 guardian loops
(2017/2019/2020) and map26 actor-arrival loops/guards
(2120/2121/2127/2128/2134/2135/2145).

`tool/export_dos_special_arrival.py` executes both closed original EXE
fragments, supplying only Delay and PutImage. Thirty cases vary party coordinates
and patterned background tiles. Unmodified original instructions compute loop
counters, conditional restores, fixed-stride map reads and image-bank offsets.
The fixture records every platform call. The Dart replay compares the entire
ordered trace, including CHARA AND(3)/OR(2) and FONT COPY(0), without RNG.
Python regeneration compares the full fixture and executable/fragment hashes.

The modern renderer retains the ordered drawing history during the speech:
opaque background restoration and transparent merged CHARA sprites replace
the original BGI AND/OR operations. Source pixel positions scale to the current
viewport; font0 follows the existing map-specific default-font adapter. This
does not claim BGI pixel or CPU busy-wait wall-clock identity.

The UI driver waits six seconds for the guardian and sixteen seconds for the
three final actors. Before the final actors it displays the source north-three,
east-until26 walk with 1500ms waits and faces5/6/5. Input stays blocked. Temporary
presentation coordinates are restored before the existing reducer commits the
same nudges once; interruption restores the initial coordinates. No extra
movement RNG or special-tile dispatch occurs. Widget tests check blocked input,
initial/terminal positions, arrival before speech, and the existing encounter,
retry, reward and ending continuations. DOS hardware timing remains excluded.

Only those ten sites change from partial to verified; other source units remain
partial where their hardware/storage contracts are still open.
