# Yard-Scape Northstar Water Lab — Public Render Slice

This branch contains only the authorized minimal renderer witness needed to execute
and inspect the isolated water lab. The application authority remains the private
Yard-Scape repository.

## What is rendered

- pool shell;
- Baja shelf;
- three steps;
- deep floor;
- thin pool walls;
- one animated water surface;
- fixed camera and fixed sun.

No coping, deck, plantings, house, UI, save/undo, pricing, customer data, or other
application systems are present.

## Deterministic baseline

The native worker renders the same water at:

- 0.00 seconds;
- 1.75 seconds;
- 4.00 seconds.

For every time it captures:

1. full water;
2. caustics disabled;
3. surface disabled.

That gives nine directly comparable PNGs. The source shader uses explicit
`visual_time`; it does not use shader `TIME`.

## Persistent outputs

Successful native runs replace:

`ci/yardscape-water-lab/outputs/baseline-01/`

The workflow commits those images back to this public CI branch. They are therefore
browsable in GitHub and do not depend on the temporary Actions artifact remaining
available.

## Evidence boundary

The public source is a reviewed renderer-only mirror. Passing here establishes that
the selected Godot 4.7.1 Compatibility worker can parse, render, animate, toggle and
capture this water lab. It does not establish target-tablet performance or Northstar
artistic acceptance.
