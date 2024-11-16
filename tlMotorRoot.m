classdef tlMotorRoot < handle
    % =========================================================================
    % This is the root class for all Thorlabs motors.
    % this class ensures that all the .NET files were added to the path
    % and that all class objects exsist in the obj to use.
    %
    % =========================================================================

    %% properties
    properties (SetAccess = protected)

        lastwarning
        is_opened

    end

    properties (Access = public)

        config
        DeviceName
        ChannelNum
        is_enabled

    end

    properties (Access = 'protected')

        wait_timeout = 60000;
        excluded_fields = {};

    end


    properties (SetObservable)

        Simulator
        DeviceManager
        Device
        Motor
        container
        IsEmulated
        InitStatus
        length_enum
        ObjTypes 
        Status

    end


    %% abstract properties

  %  properties (Abstract , SetAccess = 'protected')

       properties (Abstract , Access = public)

        %         unit_type
        %         range_move
        %         range_velocity
        %         range_acceleration
        MotorConfiguration
        SerialNo
        DeviceTypeID


    end

    %     properties (Access = 'protected', Constant)    %Abstract
    %
    %         config_base
    %
    %     end

    %% abstract methods
    methods (Abstract)

        CreateDevice(obj, device_type, serial_number);

        GetMotorConfiguration(obj);

        Channel = GetAllChannels(obj)

        %
        %         PrepareUnitConverter(obj);
        %
        %         ImportUnitConverter(obj, channel);
        %
        %         ImportMotorConfiguration(obj, channel, serial_number);
        %
        %         SetLoopMode(obj, channel);
        %
        %         config = GetConfigParams(obj, config, channel);
        %
        %         SetConfigParams(obj, config, channel);
        %
        %         position = GetPositionDeviceSpecific(obj, channel);
        %
        %         HomeDeviceSpecific(obj, channel);
        %
        %         MoveJogDeviceSpecific(obj, direction, timeout, channel)
        %
        %         MoveRelativeDeviceSpecific(obj, direction, step_size, timeout, channel)
        %
        %         MoveAbsoluteDeviceSpecific(obj, new_position, timeout, channel)

    end


    %% methods
    methods
        %% Constructor
        function obj = tlMotorRoot(varargin)

            %TLMOTOR create a new ThorLabs motor control object
            %   obj = TLMOTOR(serial_number) will immediately try to open a device with serial number
            %   obj = TLMOTOR(config) will immediately try to open a device with config.serialNo and update it's configuration

            %Initialize .net assemblies required if needed
            obj.ObjTypes = obj.CheckDotNet();    % make sure all .NET dll and class are accessable
            obj.lastwarning = '';
            obj.DeviceManager = Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI;
            obj.DeviceManager.BuildDeviceList();

            pause(0.2);

            obj.Simulator = Thorlabs.MotionControl.DeviceManagerCLI.SimulationManager.Instance;
            obj.IsEmulated = false;
            obj.is_opened = false;
%            obj.ObjTypes = []; 

            if nargin >= 1  % only if a serial number is added

                try

                    obj.Open(varargin{1});
                    obj.Initialize(varargin{1});
%                     obj.InitStatus = 1;
                    obj.is_opened = true;

                catch SpenStatus

                    warning(SpenStatus.message);
                    obj.InitStatus = 0;
                    obj.lastwarning = lastwarn;
                    return;

                end

            end

        end


        %% Connection functions

        function Open(obj , serial_number)
            % OPEN connects to a thorlabs motor device, also loads settings to object

            device_type = serial_number(1:2);      
            obj.CreateDevice(device_type, serial_number);

            try   % open device:

                obj.Device.Connect(serial_number);

                %obj.Device.ResetConnection(serial_number);
            catch ME

                obj.lastwarning = lastwarn;
                error(ME.message);

            end

            % in the case the device is a benchtop or a Rack withseveral channels: 

            switch device_type

                case {'70' , '71', '44'}

                   obj.SubDevices = obj.GetAllChannels; 

                otherwise

                    % do nothing
            end

        end

        
        function Initialize(obj)

            if ~obj.Device.IsSettingsInitialized()

                obj.Device.WaitForSettingsInitialized(5000);

            end

            obj.Device.StartPolling(250); % start the polling process -
            % This process update the Status every 250ms (it replace the request commands)

            if ~obj.Device.IsEnabled()  % check if device enabled. if not enable it.

                obj.Device.EnableDevice();

            end

            obj.GetMotorConfiguration(obj.Device.DeviceID); % without this setting is not initialize. 
            obj.InitStatus = 1;

        end



        function Close(obj) % close device

            if obj.InitStatus

                obj.Device.StopPolling();
                obj.Device.DisableDevice();
                obj.Device.DisconnectTidyUp();
                obj.Device.Disconnect();
                obj.Simulator.UninitializeSimulations(); % in case of emulation. 

            end

            obj.delete;
            %obj.Device = [];  

        end


        function GetStatus(obj)

            obj.Status = obj.Device.Status;

        end


        function Persist(obj)
            % send configuration to device



        end



        function LastMessage(obj) % get message of success or faliur




        end



    end

    %% Static methods
    methods(Static)

        function serialNumbers = GetMotorList(device_prefix)

            NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.DeviceManagerCLI.dll');

            Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.BuildDeviceList();

            if exist('device_prefix','var')

                serialNumbersObj = Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.GetDeviceList(device_prefix);

            else

                serialNumbersObj = Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.GetDeviceList();

            end

            serialNumbers = cell(serialNumbersObj.Count,1);

            for index = 0:serialNumbersObj.Count-1
                serialNumbers{index+1} = char(serialNumbersObj.Item(index));
            end

        end


        function ListOfItems = GetListOfObj (NumOfItems)
            % translate the specific list of items after quering different
            % classes of Thorlabs.MotionControl

            ListOfItems = cell(NumOfItems.Count,1);

            for index = 0:NumOfItems.Count-1
            
              ListOfItems{index+1} = char(NumOfItems.Item(index));
            
            end

       end

       function ListOfProperties = GetListOfpropeties (ClassName)
           % returns the liat of properties from a .Net class

           ListOfItems = cell(ClassName.Count,1);

           for index = 0:ClassName.Count-1

               temp = ClassName.Item(index); 
               ListOfProperties{index+1} = char(temp.Title);

           end


       end



        function ObjTypes = CheckDotNet

            clearvars asm_info;

            asm_info(1) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.DeviceManagerCLI.dll');

            % start with generic motors:

            % Generic DC servo
            asm_info(2) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.GenericMotorCLI.dll');
            % Generic Piezo motors:
            asm_info(3) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.GenericPiezoCLI.dll');
            % Generic NanoTrack motor:
            asm_info(4) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.GenericNanoTrakCLI.dll');


            % Kcube drivers:

            % Kcube DC servo Brushed motors:
            asm_info(5) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.DCServoCLI.dll');
            % Kcube DC servo Brushless motors:
            asm_info(6) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.BrushlessMotorCLI.dll');
            % Kcube Piezo Inertia motors:
            asm_info(7) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.InertialMotorCLI.dll');
            % Kcube NanoTarck motor:
            asm_info(8) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.NanoTrakCLI.dll');
            % Kcube Strain Gauge motor:
            asm_info(9) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.KCube.StrainGaugeCLI.dll');

            % Benchtop drivers:

            % Benchtop stepper motors:
            asm_info(10) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.Benchtop.StepperMotorCLI.dll');
            
            %Added by ItamarP on 1/2/24 to include linear travel stages
            % Benchtop stepper motor for travel stage: 
            asm_info(11) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.IntegratedStepperMotorsCLI.dll');
            % Benchtop Piezo motors:
            asm_info(12) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.Benchtop.PiezoCLI.dll');
            % Benchtop NanoTrack motors:
            asm_info(13) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.Benchtop.NanoTrakCLI.dll');


            % Polarizer driver:

            asm_info(14) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.PolarizerCLI.dll');

            % Tools dll for all motors:

            asm_info(15) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.Tools.Logging.dll');
            asm_info(16) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.Tools.Common.dll');
            asm_info(17) = NET.addAssembly('C:\Program Files\Thorlabs\Kinesis\Thorlabs.MotionControl.PrivateInternal.dll');

            % get access to subclasses:

            str = '+';

            ObjTypes = []; 

            for asm_ind = 1:length(asm_info)  % outer loop

                Enum_array = asm_info(asm_ind).Enums;

                for ii = 1:length(Enum_array)

                    if contains(Enum_array{ii},str)

                        temp = asm_info(asm_ind).AssemblyHandle.GetType(Enum_array{ii});
                        name = regexp(Enum_array{ii}, str , 'split');

                        try

                            if ~isfield(ObjTypes , name{2})
                            
                                ObjTypes.(name{2}) = temp.GetEnumValues();
                            % obj.ObjTypes.(name{2}).Length will give the right number of enums

                            else

                                ObjTypes.([name{2} , '1']) = temp.GetEnumValues();

                            end

                        catch

                            continue; % pass to the next iteration

                        end


                    end

                end

            end

        end

    end

end


