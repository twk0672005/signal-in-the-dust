# Ecology research and implementation boundary
Primary references consulted 2026-09-19:
- NOAA: https://oceanexplorer.noaa.gov/explainers/marine-life/ — chemical energy can support food production at vents; use spatial energy sources when designing the Ember habitat.
- NASA: https://science.nasa.gov/astrobiology/learning-resources/alp/conditions-can-life-survive-in/ — extreme terrestrial environments and non-solar energy motivate distinct environmental constraints.
These are terrestrial analogues, not evidence of discovered alien animals. Veyra, Aeral and Morrow are fictional designs. Their throttle sensitivity, recovery and observation pulses are gameplay choices.
Implemented: each organism has independent alarm, short recovery memory and observation pulse; Veyra retreats along terrain, Aeral rises/spreads, Morrow contracts. Quiet restores the resting state. Material instances are isolated. Pause/reset clear or freeze all responses. No runtime network or new dependency.
Still incomplete: trophic relationships, habitat-specific resource gradients, light response, fine creature models/rigs, side routes and content supporting30minutes. Current response model is a local stimulus prototype.
