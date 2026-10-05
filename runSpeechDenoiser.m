function report = runSpeechDenoiser(model,durationSeconds)
%RUNSPEECHDENOISER Stream mono microphone audio to the default output device.
% Example: runSpeechDenoiser('CNN',30)
% Uses an 80 ms device frame to allow CPU headroom for batched inference.
    if nargin<1, model='CNN'; end
    if nargin<2, durationSeconds=30; end
    model=validatestring(model,{'CNN','FF'});
    validateattributes(durationSeconds,{'numeric'},{'scalar','positive','finite'});
    fs=48000; frameLength=3840;
    plugin=SpeechDenoiser; setSampleRate(plugin,fs); reset(plugin);
    plugin.MODEL=model;
    % Warm this sample-rate path before opening the microphone.
    for k=1:12, process(plugin,zeros(frameLength,1,'single')); end
    reset(plugin);
    reader=audioDeviceReader('SampleRate',fs,'SamplesPerFrame',frameLength, ...
        'NumChannels',1,'OutputDataType','single');
    writer=audioDeviceWriter('SampleRate',fs);
    cleanup=onCleanup(@()releaseDevices(reader,writer));
    overrun=0; underrun=0; maxProcessing=0;
    fprintf('Streaming %s at 48 kHz for %g seconds. Press Ctrl+C to stop.\n',model,durationSeconds);
    start=tic;
    while toc(start)<durationSeconds
        [x,lostInput]=reader();
        processing=tic; y=process(plugin,x);
        maxProcessing=max(maxProcessing,toc(processing));
        lostOutput=writer(y);
        overrun=overrun+lostInput; underrun=underrun+lostOutput;
    end
    report=struct('inputOverrunSamples',overrun,'outputUnderrunSamples',underrun, ...
        'maxProcessingMs',1000*maxProcessing,'audioDeadlineMs',80, ...
        'pluginLatencyMs',80);
    disp(report);
end
function releaseDevices(reader,writer)
    release(reader); release(writer);
end
