clear all; clc;

%----- Setup

SubAcq = 10;                 % Number of Sub-Accumulations
Tsub = 0.001;                % Sub-Accumulation Time
Tfull = SubAcq*Tsub;         % Time interval of data to load

IF = 1405000;                % Intermediate Frequency (Hz)
fsampIF = 40e6/7;            % IF sampling frequency (Hz)
N = fsampIF*Tsub;            % Sampling interval
N = floor(N/16)*16;          % Number of data samples to load
delFmin = -5000;
delFstep = 250;
delFmax = 5000;
delFVec = delFmin:delFstep:delFmax;


%----- Load data
fid = fopen('/home/zach/Documents/School/College/Aerospace/ASE397P/Test 3/dfDataHead.bin','r','l');
[Y,count] = binloadSamples(fid,N,'dual');
Y = Y(:,1);
%Y = fread(fid, [1,N*SubAcq], 'int16')';
[IVec,QVec] = if2iq(Y,N,IF);
Y = IVec + 1i*QVec;
fclose(fid);
PRNCodes = load('/home/zach/Documents/School/College/Aerospace/ASE397P/Test 3/cacodes.bin');
acqCodes = zeros(32,N);


for (PRN = 1:32)
    acqCodes(PRN,:) = oversampleSpreadingCode(PRNCodes(PRN,:)',1.023e6/fsampIF,N,1023)';
    lenCode = length(acqCodes(PRN,:));
    mag = zeros(length(delFVec),lenCode);
    for ( SubA = 1:SubAcq)
        magSub = zeros(length(delFVec),lenCode);
        fInd = 1;
        for ( delF = delFVec )
             Sk = ccorr((Y((SubA-1)*lenCode+1:lenCode*SubA).*exp(-1i*2*pi*delF*(0:lenCode-1)'*(1/fsampIF))),acqCodes(PRN,:)');
             center = ceil(lenCode/2);
             Sk = [Sk(center:end); Sk(1:center-1)];
             magSub(fInd,:) = (Sk .* conj(Sk))';
             fInd = fInd + 1;
        end
        mag = (mag + magSub)./2;
       
        
    end
    

   
    [carrierPeak, codePhaseInd] = max(max(mag));
    [carrierPeak, dopFreqInd] = max(max(mag'));
   
    dopFreq = delFVec(dopFreqInd);
    if(dopFreqInd > length(delFVec)/2)
        noiseFloor = mean(mean(mag(1:floor(length(delFVec)/2)-1,:)));
    else
        noiseFloor = mean(mean(mag(floor(length(delFVec)/2)+1:end,:)));
    end
    
    C_N = 10*log10((carrierPeak - noiseFloor)/(noiseFloor*Tsub));
    
    if(C_N >= 42)
        fprintf('PRN # %2.0f   C/No: %2.3f    Apperent Doppler: %5.0f Hz\n',PRN,C_N,dopFreq);
         figure(PRN);
         surf((1:lenCode),delFVec,mag);
         shading interp;
    end
end
