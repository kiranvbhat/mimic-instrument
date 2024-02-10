# Mimic Instrument
A multi-track instrument you can play with your voice and an Xbox controller.

## Demo
Demo coming soon

## Controls

* mute/unmute track(s): `press [track](s)`
* switch track section(s): `hold [track](s) + press RB`
* select instrument for track: `hold [track] + hold LB + mimick instrument with voice!`

`[track]` can be `A`, `B`, `X`, or `Y`. `[track](s)` means that you can press multiple `[track]` buttons at the same time, and the action will apply to all selected tracks.

## Installation Instructions
1. [Install ChucK](https://chuck.stanford.edu/release/) if you don't have it. I used ChucK version 1.5.2.0 (chai) while developing this project.
2. Clone this repository. 

        git clone https://github.com/kiranvbhat/mimic-instrument.git

3. `cd` to the repository and run `chuck mimic-instrument.ck`

## Troubleshooting

### Inaccurate Instrument Selection
If instrument selection is inaccurate (e.g. mimicking a guitar into your mic and piano is selected), then you might need to record your own voice sounds (instead of using mine) for the prediction. This can be done with the following steps:

1. Record yourself mimicking all instrument samples in `instrument_sounds/` The recordings should be `.wav` format.
2. Remove all files in `voice_sounds/` except `filelist.txt`.
3. Put your mimic recordings into `voice_sounds/`. They should all have the same filenames as their respective `.wav` files in `instrument_sounds/`.
4. Run `chuck extract_voice_features.ck`. This will create a new `voice_features.txt` file with your voice features instead of mine.

This should improve the instrument recognition, since it will use your instrument-mimicking sounds for the predictions instead of mine.