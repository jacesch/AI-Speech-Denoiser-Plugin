function testDenoiserAlignment
% Verify dry/wet phase alignment through the actual plugin at a passband tone.
    p=SpeechDenoiser; p.MIN_THRES=-120; p.MAX_THRES=-120;
    p.ATTACK=0.01; p.RELEASE=5; p.HOLD=0;
    for fs=[8000 11025 12000 16000 22050 24000 32000 44100 48000 88200 96000 176400 192000]
        setSampleRate(p,fs);
        t=(0:round(fs*0.6)-1)'/fs;
        x=single(0.5*sin(2*pi*1000*t));
        last=round(fs*0.3)+1:numel(x);
        phaseReference=exp(-1j*2*pi*1000*t(last));
        for model={'CNN','FF'}
            p.MODEL=model{1};
            p.DENOISE_STRENGTH=0; reset(p); dry=process(p,x);
            p.DENOISE_STRENGTH=1; reset(p); wet=process(p,x);
            dryTone=sum(double(dry(last)).*phaseReference);
            wetTone=sum(double(wet(last)).*phaseReference);
            phaseError=abs(angle(wetTone/dryTone));
            assert(abs(wetTone)>0.01 && phaseError<0.01);
            fprintf('PASS phase alignment %g Hz %s error=%g radians\n',fs,model{1},phaseError);
        end
    end
    % Confirm double output and silence/empty-block handling.
    y=process(p,zeros(64,1)); assert(isa(y,'double') && all(isfinite(y)));
    y=process(p,zeros(0,1)); assert(isempty(y));
    % Model loading must not depend on the working directory.
    previous=pwd; cleanup=onCleanup(@()cd(previous));
    addpath(previous); cd(fileparts(previous)); clear denoise;
    y=denoise(zeros(129,8,1,5,'single'),true);
    assert(isequal(size(y),[129 5]) && all(isfinite(y),'all'));
    fprintf('PASS precision, empty blocks, and model path\n');
end
