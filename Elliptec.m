classdef Elliptec < handle
    % driver for elliptec motor from ThorLabs

    properties
        msg
        InitStatus
        port
        address
        info
        status
        limits
        filter_loc
    end

    methods

        function obj = Elliptec(COM,address)
            obj.port = serialport(COM, 9600, 'DataBits',8,...
                    'StopBits',1,'Parity','none','FlowControl','none','Timeout',2);
                obj.address = address;
                writeline(obj.port,[obj.address 'in']);
                pause(0.1);
                tmpData = obj.ReadELL();
                tmpData = tmpData(4:end-1);
                obj.info = struct('type', ['ELL',int2str(hex2dec(tmpData(1:2)))],...
                'serial_number',tmpData(3:10),'year_of_manufacture',tmpData(11:14),...
                'firmware',tmpData(15:16),'hardware_version',tmpData(17:18),...
                'travel',hex2dec(tmpData(19:22)),'pulse_per_mm',hex2dec(tmpData(23:end)));
                if ~isempty(tmpData)
                    obj.status.text = {['Type: ' obj.info.type],...
                        ['Serial number: ' obj.info.serial_number],...
                        ['Year of manufacture: ' obj.info.year_of_manufacture],...
                        ['Firmware: ' obj.info.firmware],...
                        ['Hardware version: ' obj.info.hardware_version],...
                        ['Travel [mm]: ' num2str( obj.info.travel )],...
                        ['Pulse per mm: ' num2str( obj.info.pulse_per_mm )]};
                    obj.limits = [0, obj.info.travel];
                    obj.InitStatus = true;

                    writeline(obj.port,[obj.address 'gj']); % get jog size
                    pause(0.1);
                    tmpData = obj.ReadELL();
                    jog_size = double(typecast( uint32( hex2dec(tmpData(4:end-1)) ),'int32'));
                    obj.info.jog_size = jog_size;

                    obj.filter_loc = [0,1,2,3] .* obj.info.jog_size;


                    obj.msg.txt = "ELL is set";
                    obj.msg.color = [0 1 0];
                end
        end

        function data = ReadELL(obj)
            % Read data back from serial port
                data = '';
                while obj.port.NumBytesAvailable > 0
                    t = read(obj.port, obj.port.NumBytesAvailable,'char');
                    data = [data,t];
                    if ~isempty(t) && t(end)==10 % got data and the end is line down
                        break
                    end
                    pause(0.01);
                end
            
        end



        function closeConnection(obj)

            if obj.InitStatus
                delete(obj.port);
                clear obj.port;
                obj.InitStatus = false;
                
                obj.msg.txt = 'Device Disconnected';
                obj.msg.color = [0 1 0]; % green

            else
                obj.msg.txt = 'NO Device to disconnect';
                obj.msg.color = [1 1 1]; % white

            end


        end


        function pos = home(obj)

            if obj.InitStatus

                try
                    writeline(obj.port,[obj.address 'ho']);
                    pause(1.5);
                    tmpData = obj.ReadELL();
                    pos = double(typecast( uint32( hex2dec(tmpData(4:end-1)) ),'int32'));
                    obj.msg.txt = "homming is done";
                    obj.msg.color = [0 1 0];
                catch
                    obj.msg.txt = "Error while homming";
                    obj.msg.color = [1 0 0];
                
                end

            else
                obj.msg.txt = "no motor is set";
                obj.msg.color = [1 0 0];

            end

        end


        function err_flag = move2filter(obj,filter_num)

            if obj.InitStatus

                writeline(obj.port,[obj.address 'ma' dec2hex(obj.filter_loc(filter_num),8)])
                pause(1.5);
                % obj.wait_busy();
                % wait for stop mooving
                tmpData = obj.ReadELL();
                pos = double(typecast( uint32( hex2dec(tmpData(4:end-1)) ),'int32'));

                % didn't move to the right location
                if pos ~= obj.filter_loc(filter_num)
                    err_flag = true;
                    obj.msg.txt = "motor did't move to the right position";
                    obj.msg.color = [1 0 0];

                else
                    err_flag = false;
                    obj.msg.txt = "moved to filter " + num2str(filter_num);
                    obj.msg.color = [0 1 0];
                end

            else
                obj.msg.txt = "no motor is set";
                obj.msg.color = [1 0 0];
            end

        end


        % function busy = is_busy(obj)
        %     busy = false;
        %     if obj.InitStatus
        %         writeline(obj.port,[obj.address 'gs' dec2hex(0,8)])
        %         pause(0.1);
        %         tmpData = obj.ReadELL();
        %         motor_status = double(typecast( uint32( hex2dec(tmpData(4:end-1)) ),'int32'));
        % 
        %         if motor_status==9
        %             busy = ture;
        %         end
        %     end
        % end


        % function wait_busy(obj)
        %     timeout = 5; % sec
        % 
        %     start = tic;
        %     curr_time = start;
        % 
        %     b = obj.is_busy
        % 
        %     try 
        %         while obj.is_busy && (curr_time - start < timeout)
        %             curr_time = toc;
        %         end
        % 
        %         if curr_time - start >= timeout
        %             obj.msg.txt = 'timeout reached' ;
        %             obj.msg.color = [1 0 0]; % red
        % 
        %         end
        %         d = curr_time - start
        %     catch err
        %         obj.msg.txt = err.message ;
        %         obj.msg.color = [1 0 0]; % red
        % 
        %     end
        % 
        % end


        function filter_num = get_curr_filter(obj)

            try

                writeline(obj.port,[obj.address 'gp' dec2hex(0,8)])
                pause(0.1);
                tmpData = obj.ReadELL();
                pos = double(typecast( uint32( hex2dec(tmpData(4:end-1)) ),'int32'));
                filter_num = pos/obj.info.jog_size + 1;
                
                if mod(filter_num, 1) == 0 && filter_num>=0 && filter_num<=4
                        return                
                else
                    error("possition error")

                end

            catch err
                obj.msg.txt = err.message ;
                obj.msg.color = [1 0 0]; % red
            end


        end




    end
end