function results = testSpeechDenoiser
% Regression checks for streaming, reset, latency and both trained models.
    rng(7);
    diary('test-results.txt');
    cleanup = onCleanup(@()diary('off'));
    p = SpeechDenoiser;
    rates = [8000 11025 12000 16000 22050 24000 32000 44100 48000 88200 96000 176400 192000];
    for fs = rates
        setSampleRate(p,fs); reset(p);
        for model = {'CNN','FF'}
            p.MODEL = model{1}; reset(p);
            x = single(0.1*randn(round(fs*0.24),1));
            y = stream(p,x,[1 63 128 256 511 1024 20000]);
            assert(isequal(size(y),size(x)) && all(isfinite(y)));
            fprintf('PASS rate=%g model=%s variable blocks\n',fs,p.MODEL);
        end
    end
    % Chunk boundaries must not depend on the host's callback size.
    for fs = [44100 48000]
        setSampleRate(p,fs);
        x = single(0.15*randn(round(fs*0.32),1));
        for model = {'CNN','FF'}
            p.MODEL=model{1}; p.DENOISE_STRENGTH=0.5; p.BYPASS='OFF';
            reset(p); a=stream(p,x,256);
            reset(p); b=stream(p,x,[1 64 127 441 1024]);
            assert(max(abs(a-b))<1e-6);
            fprintf('PASS partition/reset invariance rate=%g model=%s\n',fs,p.MODEL);
        end
    end
    % Bypass retains the reported delay and preserves the source samples.
    fs=48000; setSampleRate(p,fs); p.BYPASS='ON'; reset(p);
    latency=round(fs*0.080);
    x=single(randn(round(fs*0.24),1));
    a=stream(p,x,[64 256 511]);
    expected=[zeros(latency,1,'single');x(1:end-latency)];
    assert(isequal(a,expected));
    p.BYPASS='OFF'; p.DENOISE_STRENGTH=0;
    p.MIN_THRES=-120; p.MAX_THRES=-120;
    p.ATTACK=0.01; p.RELEASE=5; p.HOLD=0;
    reset(p); a=stream(p,x,[64 256 511]);
    referenceGate=noiseGate('SampleRate',fs,'Threshold',single(-120), ...
        'AttackTime',0.00001,'ReleaseTime',0.005,'HoldTime',0);
    gated=referenceGate(x);
    expectedDry=[zeros(latency,1,'single');gated(1:end-latency)];
    assert(max(abs(a-expectedDry))<1e-6);
    fprintf('PASS 80 ms bypass/dry latency\n');
    % A continuous pipeline must survive bypass changes and model switching.
    p.DENOISE_STRENGTH=1; reset(p);
    for k=1:30
        if k==8, p.BYPASS='ON'; end
        if k==16, p.BYPASS='OFF'; p.MODEL='CNN'; end
        if k==24, p.MODEL='FF'; end
        p.ATTACK=10; p.RELEASE=50; p.HOLD=20;
        y=process(p,single(0.1*randn(256,1)));
        assert(all(isfinite(y)) && size(y,1)==256);
    end
    fprintf('PASS live controls/model/bypass changes\n');
    % Batch inference must have the same ordering as single-frame inference.
    predictors=single(abs(randn(129,8,1,5)));
    for cnn=[false true]
        batch=denoise(predictors,cnn);
        for k=1:5
            one=denoise(predictors(:,:,:,k),cnn);
            assert(max(abs(batch(:,k)-one))<1e-4);
        end
    end
    fprintf('PASS batch prediction ordering\n');
    % Benchmark warmed callbacks: worst-call time controls dropout risk.
    results=struct;
    for model={'CNN','FF'}
        p.MODEL=model{1}; p.MIN_THRES=-60; p.MAX_THRES=-20;
        for blockSize=[256 1920 3840]
            reset(p); frame=single(0.1*randn(blockSize,1));
            for k=1:30, process(p,frame); end
            times=zeros(max(30,ceil(fs/blockSize)),1);
            for k=1:numel(times)
                t=tic; process(p,frame); times(k)=toc(t);
            end
            deadline=blockSize/fs;
            item=struct('meanMs',mean(times)*1000,'maxMs',max(times)*1000, ...
                'deadlineMs',deadline*1000,'misses',nnz(times>deadline));
            results.(model{1}).(sprintf('B%d',blockSize))=item;
            fprintf('%s block=%d mean=%.3f ms max=%.3f ms deadline=%.3f ms misses=%d/%d\n', ...
                model{1},blockSize,item.meanMs,item.maxMs,item.deadlineMs,item.misses,numel(times));
        end
    end
    save('test-results.mat','results');
    fprintf('ALL FUNCTIONAL TESTS PASSED\n');
end
function y=stream(p,x,blocks)
    y=zeros(size(x),'like',x); pos=1; k=1;
    while pos<=numel(x)
        n=min(blocks(mod(k-1,numel(blocks))+1),numel(x)-pos+1);
        z=process(p,x(pos:pos+n-1));
        assert(isa(z,class(x)) && isequal(size(z),[n 1]));
        y(pos:pos+n-1)=z; pos=pos+n; k=k+1;
    end
end




