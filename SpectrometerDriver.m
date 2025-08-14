classdef SpectrometerDriver < handle
    % SpectrometerDriver A class to control the Avenir Photonics spectrometer
    %   This class provides an interface to control and acquire data from the
    %   spectrometer using the ZioLinkLibrary.dll
    
    properties (Access = private)
        spectrometer  % Handle to the spectrometer device
        isConnected = false  % Connection status
        darkSpectrum = []   % Dark spectrum for background subtraction
    end
    
    properties (Access = public)
        deviceName    % Model name of the spectrometer
        serialNumber  % Serial number of the device
        pixelCount   % Number of pixels in the sensor
        wavelengths  % Array of wavelength values
    end
    
    properties
        exposureTime = 0.02  % Exposure time in seconds (default: 20ms)
        averaging = 10       % Number of spectra to average (default: 10)
        autoExposure = false % Auto exposure setting
        triggerMode = 0     % Trigger mode (0: Internal, 1: External Rising Edge, 2: External Falling Edge)
    end
    
    methods
        function obj = SpectrometerDriver()
            % Constructor: Initialize the driver
            try
                % Load the .NET assembly
                dllPath = fullfile(fileparts(mfilename('fullpath')), 'ZioLinkLibrary.dll');
                NET.addAssembly(dllPath);
            catch e
                error('Failed to load ZioLinkLibrary.dll: %s', e.message);
            end
        end
        
        function success = connect(obj)
            % Connect to the first available spectrometer
            try
                % Close any previously opened device
                if obj.isConnected
                    obj.disconnect();
                end
                
                % Search for devices
                devices = DeviceClasses.ZioLinkSpectrometer.FindDevices();
                if devices.Length == 0
                    error('No spectrometer device found.');
                end
                
                % Connect to the first device
                obj.spectrometer = devices(1);
                obj.spectrometer.Open();
                
                % Get device information
                obj.deviceName = char(obj.spectrometer.DeviceName)';
                obj.serialNumber = char(obj.spectrometer.SerialNumber)';
                obj.pixelCount = obj.spectrometer.PixelCount;
                obj.wavelengths = double(obj.spectrometer.Wavelengths());  % Convert to MATLAB array
                
                obj.isConnected = true;
                success = true;
            catch e
                warning('Failed to connect to spectrometer: %s', e.message);
                obj.isConnected = false;
                success = false;
            end
        end
        
        function disconnect(obj)
            % Disconnect from the spectrometer
            if obj.isConnected && ~isempty(obj.spectrometer)
                try
                    obj.spectrometer.Close();
                catch
                    % Ignore errors during disconnect
                end
                obj.isConnected = false;
            end
        end
        
        function applySettings(obj)
            % Apply current settings to the device
            if ~obj.isConnected
                error('Spectrometer is not connected.');
            end
            
            obj.spectrometer.ExposureTime = obj.exposureTime;
            obj.spectrometer.Averaging = obj.averaging;
            obj.spectrometer.AutoExposure = obj.autoExposure;
            
            % Set trigger mode using the correct enumeration
            triggerModes = obj.spectrometer.GetType().Assembly.GetType('DeviceClasses.ZioLinkSpectrometer+TriggerModes');
            if obj.triggerMode == 0
                obj.spectrometer.TriggerMode = System.Enum.ToObject(triggerModes, 0);  % Internal
            elseif obj.triggerMode == 1
                obj.spectrometer.TriggerMode = System.Enum.ToObject(triggerModes, 2);  % External Rising
            elseif obj.triggerMode == 2
                obj.spectrometer.TriggerMode = System.Enum.ToObject(triggerModes, 3);  % External Falling
            end
        end
        
        function setTriggerMode(obj, mode)
            % Set the trigger mode for the spectrometer
            % mode: 0 = Internal trigger (default)
            %       1 = External trigger, rising edge
            %       2 = External trigger, falling edge
            if ~ismember(mode, [0, 1, 2])
                error('Invalid trigger mode. Use 0 (Internal), 1 (External Rising), or 2 (External Falling)');
            end
            obj.triggerMode = mode;
            if obj.isConnected
                obj.applySettings();
            end
        end
        
        function acquireDarkSpectrum(obj)
            % Acquire and store a dark spectrum for background subtraction
            % This should be called with the input light blocked
            if ~obj.isConnected
                error('Spectrometer is not connected.');
            end
            
            try
                [spectrum, ~] = obj.acquireRawSpectrum();
                obj.darkSpectrum = spectrum;
                fprintf('Dark spectrum acquired successfully.\n');
            catch e
                error('Failed to acquire dark spectrum: %s', e.message);
            end
        end

        function [spectrum, metadata] = acquireSpectrum(obj)
            % Acquire a single spectrum from the device with dark correction
            if ~obj.isConnected
                error('Spectrometer is not connected.');
            end
            
            try
                [rawSpectrum, metadata] = obj.acquireRawSpectrum();
                
                % Apply dark correction if available
                if ~isempty(obj.darkSpectrum)
                    spectrum = rawSpectrum - obj.darkSpectrum;
                    spectrum(spectrum < 0) = 0;  % Ensure no negative values
                else
                    spectrum = rawSpectrum;
                end
            catch e
                error('Failed to acquire spectrum: %s', e.message);
            end
        end

        function [spectrum, metadata] = acquireRawSpectrum(obj, timeout)
            % Acquire a raw spectrum without dark correction
            % timeout: Optional timeout in seconds (default: 10 seconds)
            if ~obj.isConnected
                error('Spectrometer is not connected.');
            end
            
            if nargin < 2
                timeout = 10; % Default timeout of 10 seconds
            end
            
            try
                % Start timer for timeout
                startTime = tic;
                
                % Start exposure
                obj.spectrometer.StartExposure();
                
                % For external trigger modes, first verify we enter trigger wait state
                if obj.triggerMode > 0
                    fprintf('Waiting for trigger ready state...\n');
                    while true
                        [status, ~] = obj.spectrometer.GetStatus();
                        if status == DeviceClasses.SpectrStatus.WaitingForTrigger
                            fprintf('Ready for external trigger...\n');
                            break;
                        elseif toc(startTime) > timeout
                            error('Timeout waiting to enter trigger wait state');
                        end
                        pause(0.002);
                    end
                end
                
                % Now wait for acquisition to complete
                while true
                    [status, availableSpectra] = obj.spectrometer.GetStatus();
                    
                    if obj.triggerMode > 0
                        % For external trigger, check valid states
                        if status == DeviceClasses.SpectrStatus.Idle && availableSpectra > 0
                            fprintf('Trigger received and acquisition complete.\n');
                            break;
                        elseif status ~= DeviceClasses.SpectrStatus.WaitingForTrigger && ...
                               status ~= DeviceClasses.SpectrStatus.Exposing
                            error('Unexpected state while waiting for trigger: %d', status);
                        elseif toc(startTime) > timeout
                            error('Timeout waiting for external trigger');
                        end
                    else
                        % For internal trigger, just wait for completion
                        if status == DeviceClasses.SpectrStatus.Idle && availableSpectra > 0
                            break;
                        elseif toc(startTime) > timeout
                            error('Timeout waiting for acquisition');
                        end
                    end
                    pause(0.002);
                end
                
                % Read spectrum data
                spectrumData = obj.spectrometer.GetSpectrumData();
                
                % Prepare output
                spectrum = double(spectrumData.Values);  % Ensure MATLAB array
                metadata.loadLevel = spectrumData.LoadLevel * 100;  % Convert to percentage
                metadata.availableSpectra = availableSpectra;
            catch e
                error('Failed to acquire spectrum: %s', e.message);
            end
        end
        
        function plotSpectrum(obj, spectrum)
            % Plot the spectrum
            if nargin < 2
                [spectrum, metadata] = obj.acquireSpectrum();
            end
            
            figure;
            plot(obj.wavelengths, spectrum);
            grid on;
            axis tight;
            xlabel('Wavelength [nm]');
            ylabel('Intensity');
            title(sprintf('Measured Spectrum - %s', obj.deviceName));
        end
        
        function delete(obj)
            % Destructor: Clean up when object is deleted
            obj.disconnect();
        end
    end
end
