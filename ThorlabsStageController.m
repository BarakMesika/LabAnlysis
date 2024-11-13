classdef ThorlabsStageController < handle
    
    properties
        CommObj   % Communication session object. runs on VISA protocol
        IsEmulated = false;
        InitStatus = false;
        ErrMsg = '';
        StageX
        YStageLimits 
        XStageLimits 
    end
    
    methods
        
        function Obj = ThorlabsStageController(XAxis,emulation)
            % returns an opened and ready to go controller object for thorlabs linear stages
            % this is essentially a wrapper around tldcmotor, which enables quick integration of thorlabs stages into probestation
            
            if ~emulation % user wants to NOT emulate
                try
                    Obj.StageX = XAxis;
                    Obj.InitStatus = true;
                catch err
                    Obj.ErrMsg = err.message ;
                    Obj.InitStatus = false;
                end
                
            else % user WANTS to emulate
                Obj.InitStatus = true;
                Obj.IsEmulated = true;
            end
        end
        
        function RetMsg = InitStages(Obj,fig)
            RetMsg.color='green';
            if ~Obj.IsEmulated
                try
                    d = uiprogressdlg(fig,'Message',"please wait, initializing linear stages");
                    counter = 0;
                    Obj.StageX.Device.EnableDevice();
                    IsHomedX = Obj.StageX.Home;
                    pause(0.1);
                    Obj.StageX.GetStatus();
                    while(Obj.StageX.Device.Status.IsMoving)   % Wait for Homing to complete
                        Obj.StageX.GetStatus();
                        counter = counter+1;
                        d.Value = mod(counter,10)/10;
                        pause(0.2);
                    end
                    Obj.StageX.Device.SetBacklash(0);
                    Obj.XStageLimits = Obj.StageX.range_move;

                    
                    close(d);
                    RetMsg.txt='Homing successful';
                    
                catch err
                    close(d);
                    RetMsg.color='red';
                    RetMsg.txt = err.message;
                end
            else %Object IS emulated
                Obj.XStageLimits = [0 150];
                RetMsg.txt = "Stage homing successful";
                RetMsg.color='blue';
            end
        end
        
        function PingMsg = Ping(Obj)
            %simple ping. return the Identification message programmed in the device
            PingMsg.color='green';
            if ~Obj.IsEmulated % if Controller ISN'T emulated
                try
                    % PingMsg.txt = Obj.Controller.qIDN();
                    PingMsg.txt="Ping";
                catch err
                    PingMsg.txt=append('Ping attempt failed: ',err.message);
                    PingMsg.color='red';
                end
            else % if Controller IS emulated
                PingMsg.txt='Emulation Ping';
                PingMsg.color='blue';
            end
        end
        
        function RetMsg = CloseComm(Obj)
            % For controlled shutdown
            RetMsg.color = 'green';
            if ~Obj.IsEmulated
                try
                    Obj.StageX.Close();
                    RetMsg.txt = 'Communication closing successful';
                catch err
                    RetMsg.txt = append('Communication closing unsuccessful: ', err.message);
                    RetMsg.color = 'red';
                end
            else % if Attenuator IS emulated
                RetMsg.txt = 'Emulated Communication closing successful';
                RetMsg.color = 'blue';
            end
        end
        
        function [Position,ErrMsg] = GetPosition(Obj)
            % Returns a NUMERIC (NOT STRING) vector with the position of each stage
            ErrMsg.txt = nan;
            ErrMsg.color = 'green';
            if ~Obj.IsEmulated
                try
                    Position(1) = Obj.StageX.GetPositionAbsolute();  % Query controller for position of the X axis
                catch err
                    ErrMsg.txt = append('Position query unsuccessful: ', err.message);
                    ErrMsg.color = 'red';
                end
            else %is emulated - return Pi as default value
                Position(1)=(rand)*50; %return position in [-25,25]
            end
        end
        
        function RetMsg = MoveToAbsPosition(Obj,Position)
            % Moves the selected axis to the absolute position
            % ax - numeric INT input. Position - numeric input (mm)
            RetMsg.color='green';
            if ~Obj.IsEmulated
                
                Stage = Obj.StageX;
                ax = 'X';
                
                try
                   Stage.MoveToAbsolute(Position);
                   pause(0.2);
                   Stage.GetStatus();
                   while(Stage.Device.Status.IsMoving) % wait for stage to finish moving1
                       Obj.StageX.GetStatus();
                       pause(0.2);
                   end
                   RetMsg.txt = ['Stage Move Successful.'];
                catch err
                    RetMsg.txt = append('Unexpected Error: ', err.message);
                    RetMsg.color='red';
                end
                
            else % object IS emulated
                RetMsg.txt ='Emulation Move Successful';
                RetMsg.color='blue';
            end
        end
            
        function RetMsg = MoveJog(Obj,ax,StpSize)
            % moves the selected axis by the requested amount
            % (final position = current position + MoveSize)
            % StpSize - Numeric input
            % ax - char input ('1' \ '2')
            RetMsg.color = 'green';
            if ~Obj.IsEmulated
                try
                    [Pos,ErrMsg] = Obj.GetPosition();
                    NewPos = Pos + StpSize;
                    Obj.MoveToAbsPosition(str2double(ax),NewPos);
                    
                    RetMsg.txt = append('Successfully moved Axis by ',num2str(StpSize));
                catch err
                    RetMsg.txt = append('Unexpected error:', err.message);
                    RetMsg.color = 'red';
                end
            else
                RetMsg.txt = append('Emulated movement successful');
                RetMsg.color='blue';
            end
        end
        
        function RetMsg = EmergencyStop(Obj)
            if ~Obj.IsEmulated
                try
                    Obj.StageX.Device.StopImmediate;

                    RetMsg.txt = 'Stages stopped';
                    RetMsg.color = 'green';
                catch err
                    RetMsg.txt = err.message;
                    RetMsg.color = 'red';
                end
            else
                RetMsg.txt = 'Emulated Stages stopped';
                RetMsg.color = 'blue';
            end
            
        end
        
    end
end