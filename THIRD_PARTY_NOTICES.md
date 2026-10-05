# Third-party sources and redistribution status

Reviewed 2026-10-04. Evidence includes the supplied files, linked official documentation, and Jacey's confirmations during this review. "Unverified" means a permission grant was not established; it does not assert that use is prohibited.

| Component | Source / evidence | Redistribution status |
| --- | --- | --- |
| `examples/denoiser_test.m` | Closely follows [MathWorks speech-denoising example](https://www.mathworks.com/help/audio/ug/denoise-speech-using-deep-learning-networks.html): matching STFT features, model architectures, dataset and pretrained archive downloads | Applicable example-code license/permission not supplied; obtain exact terms before distribution |
| `examples/HelperGenerateSpeechDenoisingFeatures.m` | Same example helper; existing notice: **Copyright 2018 The MathWorks, Inc.** | Notice preserved verbatim; copyright is not a redistribution grant |
| `examples/testFileCreator.m` | Adapts the example's clean-speech/noise mixture setup | Same unresolved example-source and recording terms |
| `SpeechDenoiser.m`, `denoise.m`, `runSpeechDenoiser.m`, test source | Supplied project integration and streaming implementation; STFT/inference approach based on the example | No project contribution license supplied; exact authorship history not present |
| `examples/classifyNoise.m`, `examples/randomizeDataSet.m` | Supplied synthetic-noise classification experiment; no external source notice found | Original source/authorship and license unverified |
| `denoisenet.mat` | Jacey confirmed training the bundled runtime weights. The training approach follows the MathWorks example. The script also offers `audio/examples/sefc.zip` and `audio/examples/secnn.zip` as pretrained alternatives; these are not established as the bundled file's origin | Author training confirmed; exact training run, dataset/version, normalization/export history, and chosen model distribution license are not supplied. Check applicable example/dataset terms before distribution |
| VAD model (not bundled here) | Runtime calls [audioPretrainedNetwork("vadnet")](https://www.mathworks.com/help/audio/ref/audiopretrainednetwork.html) | Obtain through MathWorks; retain and review the model download's own notices before repackaging |
| Common Voice subset (not bundled) | Example downloads MathWorks-hosted `audio/commonvoice.zip`; upstream dataset: [Mozilla Common Voice](https://commonvoice.mozilla.org/) | Mozilla documents Common Voice dataset availability under CC0 unless otherwise specified; verify the actual subset/version metadata. This does not license MathWorks code, weights, or unrelated audio |
| Missing speech/noise inputs | `SpeechDFT-16-8-mono-5secs.wav`, `WashingMachine-16-8-mono-1000secs.mp3`, `WashingMachine-16-8-mono-200secs.mp3`; filenames match the MathWorks example | Original recording creators and recording-specific terms not established here; not included |
| `examples/audio/noisySpeech.wav` | Supplied audition file; `testFileCreator.m` generates this filename from MathWorks example inputs | Exact recording origin not verified; recording terms remain unresolved |
| `examples/audio/denoised_output_CNN.wav`, `examples/audio/denoised_output_FF.wav` | Supplied denoised audition outputs; no generation manifest supplied | Exact inputs and generation history unverified; processing does not establish permission to distribute source recordings |
| `background.jpg`, `BigPurple.png`, `LittlePurple.png`, `Bypass.png`, `Model.png` | Supplied interface background and control filmstrips referenced by `SpeechDenoiser.m` | Jacey confirmed all interface graphics are cleared in terms of licensing. Exact creator/source and license text not supplied; clearance is based on that confirmation |
| `audioplugin/lib/SpeechDenoiser/html/report.mldatx` | Supplied generated MATLAB report | Not a source dependency; excluded from new Git tracking; do not treat it as original authored code |
| `test-results.txt`, `test-results.mat` | Supplied verification artifacts | Historical evidence only; no license or machine/provenance manifest supplied |

## Terms checked

The MathWorks documentation identifies the example dataset and pretrained downloads, but no component-specific redistribution license was found in this project. The [MathWorks answer about example-code legal status](https://www.mathworks.com/matlabcentral/answers/1796190-what-is-the-legal-status-of-code-examples-on-mathworks-com) directs legal questions to Customer Service; it does not itself grant redistribution permission. The [MATLAB Central terms](https://www.mathworks.com/matlabcentral/content/terms-of-use.html) should not be substituted for the missing license of documentation-example downloads.

MathWorks identifies the installed agreement as `license_agreement.txt` in the MATLAB installation ([official support answer](https://www.mathworks.com/matlabcentral/answers/1979884-where-can-i-find-the-mathworks-software-license-agreement)). No installed agreement was available in the inspected project. Review the agreement applicable to the actual MATLAB release and any notices inside the original example/model archives.

Mozilla's [Common Voice terms](https://commonvoice.mozilla.org/en/terms) identify CC0 dataset terms unless otherwise specified. The [CC0 1.0 legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode) is the referenced instrument, not a blanket license for this folder.

## Evidence needed before public redistribution

Record the bundled weights' training dataset/version, training/export procedure, and checksum, and choose their distribution license. If using the optional pretrained archives, record their versions/checksums and retain the exact notices. Confirm the origin and terms of all three audition WAVs and the missing example recordings. Retain source/license evidence supporting Jacey's graphics clearance; record the source of any future screenshot. Select a license for contributions whose ownership is established without extending that grant to third-party material. Store the exact notices in `licenses/` and update this inventory.

Files were preserved locally while documentation was added; this review did not publish them or establish redistribution clearance.

