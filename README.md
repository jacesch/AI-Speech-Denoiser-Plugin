# SpeechDenoiser

A MATLAB mono speech-denoising plugin project by Jacey Schell. The interface combines selectable fully connected (FF) and convolutional (CNN) denoising models, a voice-activity-driven noise gate, adjustable denoise strength, and bypass. It explores bringing an offline deep-learning speech example into a continuous audio-processing interface.

The training workflow closely follows MathWorks' [Denoise Speech Using Deep Learning Networks](https://www.mathworks.com/help/audio/ug/denoise-speech-using-deep-learning-networks.html). The network architectures and example training approach are credited to MathWorks; Jacey trained the bundled `denoisenet.mat` weights using this example-based workflow. The architectures are credited to MathWorks; the bundled weights are not claimed to be their downloaded pretrained files.

## Limitations

- **80 ms fixed processing latency**, including the aligned dry and bypass paths. Audio-device and host buffering add further delay.
- **Roughly 4 kHz denoised output bandwidth**: inference operates at 8 kHz. Upsampling does not restore removed high frequencies. Strength 0 returns delayed gated audio; bypass returns delayed original audio.
- **Small buffers missed deadlines** in the supplied warmed CPU measurements at 48 kHz. With 256 samples (5.333 ms), CNN missed 25/188 calls and FF missed 18/188. With 1920 samples (40 ms) and 3840 samples (80 ms), both models recorded 0/30 misses per configuration. These results depend on the computer and are not an audio-device dropout guarantee.
- Native MEX/VST/AU export and actual microphone/device operation have not been verified. Plugin validation with `-nomex` skips code-generation checks.

## Interface

Controls: Model (FF/CNN), Denoise Strength, Attack, Release, Hold, and Bypass. Gate timing controls are displayed in milliseconds.

An interface screenshot has not been captured yet, as confirmed by Jacey. Add the actual capture as `docs/interface.png` and embed it here when available. The bundled background and control filmstrips are interface assets, not screenshots.

## Project work and current implementation

Jacey trained the bundled denoising weights and developed this project around the example-based workflow. The project integrates the denoising models with MATLAB's audioPlugin interface, a noise gate driven by voice activity detection, dry/wet blending, and graphical controls. The optional scripts explore the example training workflow and a separate synthetic-noise classifier.

The supplied implementation also contains streaming corrections: bounded input/output queues preserve samples across changing host blocks; rational resampling supports standard rates including 44.1 kHz; wet, dry, and bypass paths share a reported 80 ms latency; reset rebuilds DSP state; and bypass continues advancing the processing state. Inference batches five frames, warms both models before streaming, and uses a rolling VAD window to reduce repeated work. These describe the present source; the supplied folder does not establish who authored each later correction.

## Run in MATLAB

Open MATLAB with this `SpeechDenoiser` directory as the current folder. Keep `denoisenet.mat`, `background.jpg`, and all four PNG control assets beside `SpeechDenoiser.m`.

Requires MATLAB with Audio Toolbox, DSP System Toolbox, Signal Processing Toolbox, and Deep Learning Toolbox. The supplied README reports testing on R2025b; no new MATLAB execution was performed during this documentation cleanup. The VAD model is obtained separately through MathWorks' `audioPretrainedNetwork("vadnet")`; if it is not installed, follow MATLAB's download instructions and put it on the MATLAB path.

```matlab
audioTestBench(SpeechDenoiser)

% Default microphone/output devices; 30-second run:
runSpeechDenoiser('CNN',30)
runSpeechDenoiser('FF',30)
```

The launcher uses 48 kHz, 3840-sample device frames and prints input-overrun/output-underrun counts. Use a sufficiently large testbench buffer.

## Source layout

| Location | Purpose |
| --- | --- |
| `SpeechDenoiser.m`, `denoise.m`, `runSpeechDenoiser.m` | Unpacked plugin, prediction helper, live launcher |
| `denoisenet.mat` and root JPG/PNG assets | Runtime weights and interface artwork; provenance/permission status below |
| `testSpeechDenoiser.m`, `testDenoiserAlignment.m` | Functional, timing, and alignment checks |
| `test-results.txt`, `test-results.mat` | Supplied verification artifacts |
| `examples/` | Optional training and exploration source; see [dependencies](examples/README.md) |
| `examples/audio/` | Existing audition files, preserved without regeneration |
| `audioplugin/` | Existing generated MATLAB report, excluded from new Git tracking |
| `licenses/`, `THIRD_PARTY_NOTICES.md` | Licensing status and asset attribution |

## Verification

```matlab
testSpeechDenoiser
testDenoiserAlignment
validateAudioPlugin('-nomex','SpeechDenoiser')
```

The [supplied results](test-results.txt) cover both models at 13 sample rates, variable blocks, reset/partition invariance, 80 ms dry/bypass latency, live controls, and prediction ordering. Additional recorded checks cover phase alignment, double/empty input, and loading weights from a different working directory. These are historical results, not a fresh test run.

## Sources and licensing

The training script and STFT feature helper derive from the MathWorks example linked above. The helper retains `Copyright 2018 The MathWorks, Inc.` The training script downloads MathWorks pretrained FF/CNN archives (`sefc.zip`, `secnn.zip`) and a Common Voice subset (`commonvoice.zip`). These downloads are an optional example path. Jacey confirmed that the bundled `denoisenet.mat` was trained by Jacey, rather than identified as a combination of those downloads. The exact training run, dataset version, and export history are not recorded in the supplied files.

The existing WAV files appear related to that example workflow, but their exact recordings and generation history are unverified. Jacey confirmed that all five interface graphics are cleared in terms of licensing. Their exact creator/source and license names are not recorded in the supplied files; no independent license text was supplied.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the per-file inventory and [LICENSE.md](LICENSE.md) for the licensing status. **Redistribution clearance is incomplete.** Attribution alone does not establish permission, and this folder is not currently documented as a fully licensed open-source release. Resolve the applicable terms for the example code, trained-model dependencies, and recordings before public distribution; retain the evidence supporting the confirmed graphics clearance. The source is unpacked for review; no remote publication was performed.

