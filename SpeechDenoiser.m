classdef SpeechDenoiser < audioPlugin
    % Stateful mono speech denoiser. Fixed latency: 80 ms.
    properties
        MODEL = 'CNN'
        DENOISE_STRENGTH = 1.0
        ATTACK = 1
        RELEASE = 20
        HOLD = 50
        BYPASS = 'OFF'
        MIN_THRES = -60
        MAX_THRES = -20
    end
    properties (Constant)
        PluginInterface = audioPluginInterface( ...
            'PluginName', 'Denoiser', ...
            'BackgroundImage', 'background.jpg', ...
            'VendorName', 'JXS', ...
            'VendorVersion', '1.0.0', ...
            'UniqueId', 'JXSd', ...
            audioPluginParameter('MODEL', ...
                'DisplayName', 'Model', ...
                'Mapping', {'enum','FF','CNN'}, ...
                'Style','vtoggle', ...
                'Layout',[2,4], ...
                'Filmstrip', 'Model.png', ...
                'FilmstripFrameSize', [50, 50]), ...
            audioPluginParameter('DENOISE_STRENGTH', ...
                'DisplayName','Denoise Strength', ...
                'Mapping',{'lin',0,1}, ...
                'Style','rotaryknob', ...
                'Layout',[2,6], ...
                'Filmstrip', 'BigPurple.png', ...
                'FilmstripFrameSize', [128, 128]), ...
            audioPluginParameter('ATTACK', ...
                'DisplayName','Attack', ...
                'Label','ms', ...
                'Mapping',{'log',0.01,100}, ...
                'Style','rotaryknob', ...
                'Layout',[4,2], ...
                'Filmstrip', 'LittlePurple.png', ...
                'FilmstripFrameSize', [48, 48]), ...
            audioPluginParameter('RELEASE', ...
                'DisplayName','Release', ...
                'Label','ms', ...
                'Mapping',{'log',5,100}, ...
                'Style','rotaryknob', ...
                'Layout',[4,6], ...
                'Filmstrip', 'LittlePurple.png', ...
                'FilmstripFrameSize', [48, 48]), ...
            audioPluginParameter('HOLD', ...
                'DisplayName','Hold', ...
                'Label','ms', ...
                'Mapping',{'lin',0,100}, ...
                'Style','rotaryknob', ...
                'Layout',[4,4], ...
                'Filmstrip', 'LittlePurple.png', ...
                'FilmstripFrameSize', [48, 48]), ...
            audioPluginParameter('BYPASS', ...
                'DisplayName','Bypass', ...
                'Mapping',{'enum','ON','OFF'}, ...
                'Style','vtoggle', ...
                'Layout',[2,2], ...
                'Filmstrip', 'Bypass.png', ...
                'FilmstripFrameSize', [50, 30]), ...
            'InputChannels',1, ...
            'OutputChannels',1, ...
            audioPluginGridLayout(...
                'RowHeight', [35, 120, 35, 120, 35],...
                'ColumnWidth', [35, 120, 35, 120, 35, 120, 35, 120] ) ...
            )
    end



    properties (Access = private)
        VADnet
        VADpredict
        vadChunkCounter = 0
        NoiseGate
        stf
        istf
        srcTo8
        srcFrom8
        inputQueue
        outputQueue
        dryDelay
        bypassDelay
        wetDelay
        history = zeros(129,8,'single')
        vadHistory = zeros(0,1,'single')
        smoothedSpeechProb = 0
        smoothedThreshold = -30
        currentSampleRate = 0
        chunkLength = 0
        latencySamples = 0
        haveHistory = false
    end
    methods
        function plugin = SpeechDenoiser()
            plugin.VADnet = audioPretrainedNetwork("vadnet");
            plugin.VADpredict = dlaccelerate(@SpeechDenoiser.predictVAD);
            % Load and warm both models before the audio callback starts.
            for k = 1:10
                denoise(zeros(129,8,1,5,'single'),true);
                denoise(zeros(129,8,1,5,'single'),false);
            end
            feats = dlarray(vadnetPreprocess(zeros(800,1,'single'),8000),'CT');
            for k = 1:10, plugin.VADpredict(plugin.VADnet,feats); end
            reset(plugin);
        end
        function reset(plugin)
            fs = getSampleRate(plugin);
            supported = [8000 11025 12000 16000 22050 24000 32000 44100 48000 88200 96000 176400 192000];
            if ~ismember(fs,supported)
                error('SpeechDenoiser:SampleRate', ...
                    'Unsupported sample rate %g Hz. Use a standard audio sample rate.',fs);
            end
            plugin.currentSampleRate = fs;
            % 40 ms is 320 samples at 8 kHz: five complete STFT hops.
            % Also an exact rational-resampler frame at 44.1/88.2 kHz.
            plugin.chunkLength = round(fs*0.040);
            plugin.latencySamples = 2*plugin.chunkLength;
            setLatencyInSamples(plugin,plugin.latencySamples);
            win = hamming(256,'periodic');
            plugin.stf = dsp.STFT(win,192,256,'FrequencyRange','onesided');
            plugin.istf = dsp.ISTFT(win,192,'WeightedOverlapAdd',false, ...
                'FrequencyRange','onesided');
            plugin.smoothedThreshold = max(plugin.MIN_THRES,min(plugin.MAX_THRES,-30));
            plugin.NoiseGate = noiseGate('SampleRate',fs, ...
                'Threshold',single(plugin.smoothedThreshold),'AttackTime',plugin.ATTACK/1000, ...
                'ReleaseTime',plugin.RELEASE/1000,'HoldTime',plugin.HOLD/1000);
            plugin.inputQueue = dsp.AsyncBuffer('Capacity',2*plugin.chunkLength);
            plugin.outputQueue = dsp.AsyncBuffer('Capacity',3*plugin.chunkLength);
            write(plugin.outputQueue,zeros(plugin.chunkLength,1,'single'));
            plugin.dryDelay = dsp.Delay(plugin.chunkLength);
            plugin.bypassDelay = dsp.Delay(plugin.latencySamples);
            plugin.history = zeros(129,8,'single');
            plugin.vadHistory = zeros(0,1,'single');
            plugin.vadChunkCounter = 0;
            plugin.haveHistory = false;
            plugin.smoothedSpeechProb = 0;
            plugin.smoothedThreshold = max(plugin.MIN_THRES,min(plugin.MAX_THRES,-30));
            if fs == 8000
                plugin.srcTo8 = [];
                plugin.srcFrom8 = [];
                plugin.wetDelay = dsp.Delay(128);
            else
                divisor = gcd(round(fs),8000);
                L = 8000/divisor;
                M = round(fs)/divisor;
                % Each linear-phase filter has exactly 12 samples of delay
                % at 8 kHz. STFT adds 192; 104 more makes exactly 40 ms.
                order = 24*max(L,M);
                h = fir1(order,1/max(L,M),kaiser(order+1,8));
                plugin.srcTo8 = dsp.FIRRateConverter(L,M,L*h);
                plugin.srcFrom8 = dsp.FIRRateConverter(M,L,M*h);
                plugin.wetDelay = dsp.Delay(104);
            end
        end
        function out = process(plugin,in)
            if getSampleRate(plugin) ~= plugin.currentSampleRate
                reset(plugin);
            end
            if isempty(in)
                out = in;
                return
            end
            validateattributes(in,{'single','double'},{'real','finite','column'});
            dt = class(in);
            x = single(in);
            bypassed = plugin.bypassDelay(x);
            wet = zeros(size(x),'single');
            % Bound FIFO occupancy even if a caller supplies a large block.
            for first = 1:plugin.chunkLength:size(x,1)
                last = min(first+plugin.chunkLength-1,size(x,1));
                write(plugin.inputQueue,x(first:last));
                if plugin.inputQueue.NumUnreadSamples >= plugin.chunkLength
                    frame = read(plugin.inputQueue,plugin.chunkLength);
                    write(plugin.outputQueue,processChunk(plugin,frame));
                end
                % Zero-fill only the initial fixed delay; retain every sample.
                assert(plugin.outputQueue.NumUnreadSamples >= last-first+1, ...
                    'SpeechDenoiser:Underflow','Output queue underflow.');
                wet(first:last) = read(plugin.outputQueue,last-first+1);
            end
            if strcmp(plugin.BYPASS,'ON')
                out = cast(bypassed,dt);
            else
                out = cast(wet,dt);
            end
        end
    end
    methods (Static, Access = private)
        function p = predictVAD(net,features)
            p = predict(net,features,'Acceleration','none');
        end
    end
    methods (Access = private)
        function out = processChunk(plugin,frame)
            fs = plugin.currentSampleRate;
            % Use a rolling window of real audio, not zero-padded host blocks.
            plugin.vadHistory = [plugin.vadHistory;frame];
            vadLength = round(0.100*fs);
            plugin.vadChunkCounter = plugin.vadChunkCounter + 1;
            if size(plugin.vadHistory,1) > vadLength
                plugin.vadHistory = plugin.vadHistory(end-vadLength+1:end);
            end
            if size(plugin.vadHistory,1) >= vadLength && plugin.vadChunkCounter >= 3
                plugin.vadChunkCounter = 0;
                plugin.vadHistory = plugin.vadHistory(end-vadLength+1:end);
                feats = vadnetPreprocess(plugin.vadHistory,fs);
                p = plugin.VADpredict(plugin.VADnet,dlarray(feats,'CT'));
                if isa(p,'dlarray'), p = extractdata(p); end
                p = double(gather(mean(p(:))));
                p = min(1,max(0,p));
                alpha = 1-exp(-0.120/0.200);
                plugin.smoothedSpeechProb = alpha*p + ...
                    (1-alpha)*plugin.smoothedSpeechProb;
                target = plugin.MAX_THRES - ...
                    (plugin.MAX_THRES-plugin.MIN_THRES)*plugin.smoothedSpeechProb;
                plugin.smoothedThreshold = alpha*target + ...
                    (1-alpha)*plugin.smoothedThreshold;
            end
            plugin.NoiseGate.Threshold = single(plugin.smoothedThreshold);
            plugin.NoiseGate.AttackTime = plugin.ATTACK/1000;
            plugin.NoiseGate.ReleaseTime = plugin.RELEASE/1000;
            plugin.NoiseGate.HoldTime = plugin.HOLD/1000;
            gated = plugin.NoiseGate(frame);
            dry = plugin.dryDelay(gated);
            if fs == 8000
                x8 = gated;
            else
                x8 = plugin.srcTo8(gated);
            end
            spectra = complex(zeros(129,5,'single'));
            predictors = zeros(129,8,1,5,'single');
            for k = 1:5
                S = plugin.stf(x8((k-1)*64+1:k*64));
                spectra(:,k) = S;
                if ~plugin.haveHistory
                    plugin.history = repmat(abs(S),1,8);
                    plugin.haveHistory = true;
                else
                    plugin.history = [plugin.history(:,2:end),abs(S)];
                end
                predictors(:,:,1,k) = plugin.history;
            end
            % Batch five frames to reduce neural-network call overhead.
            magnitudes = denoise(predictors,strcmp(plugin.MODEL,'CNN'));
            y8 = zeros(320,1,'single');
            for k = 1:5
                reconstructed = magnitudes(:,k).*exp(1j*angle(spectra(:,k)));
                y8((k-1)*64+1:k*64) = plugin.istf(reconstructed);
            end
            y8 = plugin.wetDelay(y8);
            if fs == 8000
                wet = y8;
            else
                wet = plugin.srcFrom8(y8);
            end
            assert(size(wet,1)==plugin.chunkLength, ...
                'SpeechDenoiser:Resampling','Incorrect resampler output length.');
            out = single(plugin.DENOISE_STRENGTH)*wet + ...
                single(1-plugin.DENOISE_STRENGTH)*dry;
        end
    end
end



