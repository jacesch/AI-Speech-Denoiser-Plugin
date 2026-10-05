function y = denoise(x,useCNN)
%DENOISE Predict nonnegative magnitudes for one frame or a batch of frames.
% Input: 129-by-8-by-1-by-B. Output: 129-by-B, in chronological order.
    persistent stats trainedNetCNN trainedNetFF
    if isempty(stats)
        modelFile = fullfile(fileparts(mfilename('fullpath')),'denoisenet.mat');
        s = load(modelFile);
        stats = single([s.noisyMean s.noisyStd s.cleanMean s.cleanStd]);
        if any(~isfinite(stats)) || stats(2)<=0 || stats(4)<=0
            error('denoise:Statistics','Invalid model normalization statistics.');
        end
        trainedNetCNN = s.denoiseNetFullyConvolutional;
        trainedNetFF = s.denoiseNetFullyConnected;
    end
    x = (single(x)-stats(1))/stats(2);
    if useCNN
        prediction = predict(trainedNetCNN,x,'ExecutionEnvironment','cpu');
        y = reshape(prediction,129,[]);
    else
        prediction = predict(trainedNetFF,x,'ExecutionEnvironment','cpu');
        y = prediction.';
    end
    y = max(single(0),single(y)*stats(4)+stats(3));
end
