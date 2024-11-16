classdef tlDCMotor < tlMotorRoot
    % =========================================================================
    % This is the class the contains Thorlabs DC servo, Stepper motors and
    % Integral motors
    % These motors have similar properties, therefore they were unified to a
    % single class
    %
    % =========================================================================

    %% properties
    properties  (SetAccess = 'protected')

        % unit_type
        range_move (1,2) double {mustBeNonnegative} = [0 12]     % {mustBeNonnegative} removed due to bug in kinesis simulation that goves [0 0] values for benchtop motors
        range_velocity (1,2) double {mustBeNonnegative} = [0 2.6]
        range_acceleration (1,2) double {mustBeNonnegative} = [0 2.3]

    end

    properties (Access = public)

        MotorConfiguration
        DeviceTypeID
        SerialNo
        StageName
        UnitConverter
        Setting           % contains information about Jog, Limits and Home
        VelocityParam     % contains information about the Velocity
        %Status           % contains the status of the device

    end

    properties % these are the properties that everyone can see and change

        Jog = struct(...
            'JogStepSize', double.empty,...
            'JogStopMode', char(),...
            'JogMode', char(),...
            'JogMaxVel', double.empty,...
            'JogAcc', double.empty...
            )


        MotorDriveSettingsArray = struct(...
            'Velocity1' , double.empty,...
            'Velocity2' , double.empty,...
            'Velocity3' , double.empty,...
            'Velocity4' , double.empty,...
            'Velocities', double.empty...
            )

        VelParam = struct(...
            'Acceleration' , double.empty,...
            'MaxVelocity' , double.empty,...
            'MinVelocity' , double.empty...
            )

        Backlash double {mustBeNonnegative} = 0.3

    end

    properties (Dependent, GetAccess = 'protected')

        CurrentPosition double {mustBeNumeric}

    end

    properties (Constant)

        WaitTimeOut double = 5000;

        stage = struct( ...
            'Z812' , 34304,...
            'Z825', 34304,...
            'Z825B', 34304,...
            'Z925B', 34304,...
            'LTS150M' , 409600,...
            'LTS300M' , 409600,...
            'MAX343' , 819200,...
            'DRV208' , 819200,...
            'Unknown' , 34304) % factor of movemet for the device units

    end

    properties (Access = public)

        SubDevices    % in the case of benchtop
        %ChannelNum

    end


    %% methods:

    methods

        %% Constructor
        function obj = tlDCMotor(varargin)
            %TLMOTOR create a new ThorLabs motor control object
            %   obj = TLMOTOR(serial_number) will immediately try to open a device with serial number
            %   obj = TLMOTOR(config) will immediately try to open a device with config.serialNo and update it's configuration
            obj@tlMotorRoot(varargin{:});
        end

        %% connection methods
        function CreateDevice(obj, device_type, serial_number)

            if ischar (device_type)

                device_type = str2double(device_type);

            end

            obj.SerialNo = serial_number;
            obj.DeviceTypeID = device_type;

            switch device_type

                case 27 % Brushed DC servo
                    obj.Device = Thorlabs.MotionControl.KCube.DCServoCLI.KCubeDCServo.CreateKCubeDCServo(serial_number);

                case 28 % Brushless DC servo
                    obj.Device = Thorlabs.MotionControl.KCube.BrushlessMotorCLI.KCubeBrushlessMotor.CreateKCubeBrushlessMotor(serial_number);

                case 45 % Integrated stepper motor
                    obj.Device = Thorlabs.MotionControl.IntegratedStepperMotorsCLI.LongTravelStage.CreateLongTravelStage(serial_number);

                case {70 , 40} % Benchtop stepper motor
                    obj.Device = Thorlabs.MotionControl.Benchtop.StepperMotorCLI.BenchtopStepperMotor.CreateBenchtopStepperMotor(serial_number);

                otherwise

                    warning('ThorLabsMotors:UnsupportedDevice', 'DeviceTypeID %s not supported.',num2str(device_type));
                    obj.lastwarning = lastwarn;
                    return
            end
        end


        function GetMotorConfiguration(obj , serial_number)

                 StartupSettningMode = obj.ObjTypes.DeviceSettingsUseOptionType.GetValue(0);
                 serial_number = obj.Device.DeviceID;


            %obj.MotorConfiguration = obj.Device.GetNanoTrakConfiguration(serialNumber , StartupSettningMode);

            obj.MotorConfiguration = obj.Device.LoadMotorConfiguration(serial_number , StartupSettningMode);
            obj.StageName = obj.MotorConfiguration.DeviceSettingsPartNumber.char;

            if isempty(obj.StageName)

                obj.StageName = 'Unknown';

            end

        end


        function GetSetting(obj)
            % This function will get the settings from the device and update the
            % corresponding structs. Many of the properties of this
            % settings are only in [get] mode. To update them we need the
            % dedicated functions for each property. 

            import System.Decimal.ToDouble

            obj.Setting = obj.Device.MotorDeviceSettings();

            % get Jog Setting:

            obj.Jog.JogAcc      = ToDouble(obj.Setting.Jog.JogAccn);
            obj.Jog.JogMaxVel   = ToDouble(obj.Setting.Jog.JogMaxVel);
            obj.Jog.JogStepSize = ToDouble(obj.Setting.Jog.JogStepSize);
            obj.Jog.JogMode     = obj.Setting.Jog.JogMode.char;
            obj.Jog.JogStopMode = obj.Setting.Jog.JogStopMode.char;

            % get Velocity Setting:

            obj.Device.RequestVelocityParams();
            obj.VelocityParam         = obj.Device.GetVelocityParams();
            obj.VelParam.Acceleration = ToDouble(obj.VelocityParam.Acceleration);
            obj.VelParam.MaxVelocity  = ToDouble(obj.VelocityParam.MaxVelocity);
            obj.VelParam.MinVelocity  = ToDouble(obj.VelocityParam.MinVelocity);

            % get backlash

            obj.Backlash = ToDouble(obj.Device.GetBacklash);

            % get the 4 velocities:

            obj.MotorDriveSettingsArray.Velocity1 = ToDouble(obj.Setting.MotorDriveSettingsArray.Velocity1);
            obj.MotorDriveSettingsArray.Velocity2 = ToDouble(obj.Setting.MotorDriveSettingsArray.Velocity2);
            obj.MotorDriveSettingsArray.Velocity3 = ToDouble(obj.Setting.MotorDriveSettingsArray.Velocity3);
            obj.MotorDriveSettingsArray.Velocity4 = ToDouble(obj.Setting.MotorDriveSettingsArray.Velocity4);

            % get all limit information:

            obj.range_move(1)         = ToDouble(obj.Setting.Physical.MinPosUnit);
            obj.range_move(2)         = ToDouble(obj.Setting.Physical.MaxPosUnit);  % chnage temporery to 12 % 
            obj.range_velocity(2)     = ToDouble(obj.Setting.Physical.MaxVelUnit);
            obj.range_acceleration(2) = ToDouble(obj.Setting.Physical.MaxAccnUnit);


        end


        function SetJogSetting(obj)

            import System.Decimal

            % This function writes the settings to the motor

            % create a JogParameter variable type:
            JogParam = Thorlabs.MotionControl.GenericMotorCLI.ControlParameters.JogParameters();

            switch obj.Jog.JogMode

                case 'ContinuousHeld'

                    JogParam.JogMode = obj.ObjTypes.JogModes.GetValue(0);

                case 'SingleStep'

                    JogParam.JogMode = obj.ObjTypes.JogModes.GetValue(1);

                case 'ContinuousUnheld'

                    JogParam.JogMode = obj.ObjTypes.JogModes.GetValue(2);

                otherwise


            end

            switch obj.Jog.JogStopMode

                case 'Immediate'

                    JogParam.StopMode = obj.ObjTypes.StopModes.GetValue(0);

                case 'Profiled'

                    JogParam.StopMode = obj.ObjTypes.StopModes.GetValue(1);

                otherwise

            end

            JogParam.StepSize = Decimal(obj.Jog.JogStepSize);
            JogParam.VelocityParams.Acceleration = Decimal(obj.Jog.JogAcc);
            JogParam.VelocityParams.MaxVelocity = Decimal(obj.Jog.JogMaxVel);
            JogParam.VelocityParams.MinVelocity = Decimal(1);

            % update setting to device:
            obj.Device.SetJogParams(JogParam);


        end


        function SetMoveToSetting(obj)

            import System.Decimal

            MoveToParam = Thorlabs.MotionControl.GenericMotorCLI.ControlParameters.VelocityParameters();
            MoveToParam.Acceleration = Decimal(obj.VelParam.Acceleration);
            MoveToParam.MaxVelocity  = Decimal(obj.VelParam.MaxVelocity);
            MoveToParam.MinVelocity  = Decimal(obj.VelParam.MinVelocity);

            % update setting to device:
            obj.Device.SetVelocityParams(MoveToParam);

        end

        function Channel = GetAllChannels(obj)

            % This function creates an array of tlDCMotor objects for each
            % channle of the Benchtop controller.

            obj.ChannelNum = obj.Device.ChannelCount;

            for ChannelNumber = 1 : obj.Device.ChannelCount

                Channel{ChannelNumber} = tlDCMotor;
                Channel{ChannelNumber}.Device = obj.Device.GetChannel(ChannelNumber);

            end
        end

        function MoveJog (obj , direction)
            % This function Jogs the motor forward or backward

            switch direction

                case 0

                    direction = Thorlabs.MotionControl.GenericMotorCLI.MotorDirection.Forward;

                case 1

                    direction = Thorlabs.MotionControl.GenericMotorCLI.MotorDirection.Backward;

            end    % obj.range_move(1)

            % move Jog
            obj.Device.MoveJog(direction , int32(obj.WaitTimeOut));

        end


        function MoveToAbsolute (obj , position)
            % This function moves the motor to the specified position via
            % the variable position using a pre-calculated factor.
            % This is the most accurate way to move the motor

            arguments

                obj % this is the obj itself no validation function needed.

                %  direction (1,1) double {mustBeInRange(direction ,
                %  range_move)} doesn't work
                position (1,1) double {ValidateArgument(obj , position , 'range_move')}

            end

            factor = obj.stage.(erase(obj.StageName,'/')); % this is the factor of the counter
            Pos = position*factor;

            try 

            obj.Device.MoveTo_DeviceUnit(Pos , 2000); % give short timeout on purpose so matlab will not hang

            catch MEmove % matlab will throw an error

                while obj.Device.Status.IsInMotion

                    pause(0.3);

                end

            end

        end

        function Position = GetPositionAbsolute(obj)


            Counter = double(obj.Device.GetPositionCounter);
            factor = obj.stage.(erase(obj.StageName,'/'));
            Position = Counter/factor; % This has to be double, calculating in int32 give wrong answer.


        end


        function isHomed = Home (obj)

            try
                
                obj.Device.Home(1);

            catch MeHome

                pause(0.5);

                while obj.Device.Status.IsHoming 

                    pause(2)

                end

            end

            if obj.Device.Status.IsHomed  

              isHomed = true; 

            else

              isHomed = false; 

            end

        end

        %% The following functions are not apart of this driver but can be used:

        %Thorlabs.MotionControl.GenericMotorCLI.KCubeMotor.KCubeDCStatus

        % obj.Device.Home(obj.WaitTimeOut);
        % obj.Device.SetBacklash(value)
        % obj.Device.IdentifyDevice()
        % obj.Device.ResetConnection
        % obj.Device.ResetStageToDefaults
        % Status = obj.Device.Status()

        %% validate functions

        function ValidateArgument (obj , arg , RangeType)

            arguments

                obj

                arg (1,1) double {mustBeNumeric}

                RangeType (1,:) char {mustBeMember(RangeType,{'range_move' , 'range_velocity' , 'range_acceleration'})}

            end

            if arg > obj.(RangeType)(2) || arg < obj.(RangeType)(1)

                error ('Argument is not in the proper range!');

            end

        end

    end

end

% remember to call obj.Device.Status after each movement.