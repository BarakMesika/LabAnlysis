classdef camera
    %camera Summary of this class goes here
    %   Detailed explanation goes here

    properties
        device
        param
        src

        InitStatus
        msg = '';

    end

    methods

        function obj = camera()
            try
                tmp = imaqhwinfo ('gentl', 1);

                if ~isempty(tmp.DeviceName)
                    obj.device = videoinput("gentl", 1, "Mono12");
                    triggerconfig(obj.device, 'manual');
                    start(obj.device);

                    obj.src = getselectedsource(obj.device);
                    tmpRes = get(obj.device, 'VideoResolution');
                    obj.param.Width = tmpRes(2);
                    obj.param.Height = tmpRes(1);
                    obj.param.pxl_length = 3.45; % um

                    obj.InitStatus = true;

                else
                    obj = [];
                    obj.InitStatus = false;
                    obj.msg = 'Camera NOT FOUND' ;
                    obj.msg.color = [1 0 0]; % red

                end


            catch err
                obj.msg.txt = err.message ;
                obj.msg.color = [1 0 0]; % red
                obj.InitStatus = false;

            end
        end


        function msg = closeConnection(obj)

            if obj.InitStatus
                delete(obj.device);
                clear obj.device;
                
                msg.txt = 'Device Disconnected';
                msg.color = [0 1 0]; % green

            else
                msg.txt = 'NO Device to disconnect';
                msg.color = [1 1 1]; % white

            end


        end


        function frame = getFrame(obj)

            if obj.InitStatus
                frame = double( getsnapshot(obj.device) );
            else
                frame = [];
            end

        end



        function results = get_D4sigma(~,frame)
            
            % thr = max(max(frame(1:5, 1:5)))*5;
            thr = 100; % TODO: find right threshold
            frame = frame-thr;
            
            frame(frame<0) = 0;
            im = double( frame );
            [x, y] = meshgrid(1:size(frame,2), 1:size(frame,1));
            xCent = sum(sum(x.*im))/sum(sum(im));
            yCent = sum(sum(y.*im))/sum(sum(im));
            D4sigmaX = 4*sqrt( sum(sum((x-xCent).^2.*im))/sum(sum(im)) );
            D4sigmaY = 4*sqrt( sum(sum((y-yCent).^2.*im))/sum(sum(im)) );
            D4sigmaXY = sum(sum((x-xCent).*(y-yCent).*im))/sum(sum(im));

            results.xCent = xCent;
            results.yCent = yCent;
            results.D4sigmaX = D4sigmaX;
            results.D4sigmaY = D4sigmaY;
            results.D4sigmaXY = D4sigmaXY;

            theta = 0.5*atan( D4sigmaXY/((0.25*D4sigmaX)^2 -(0.25*D4sigmaY)^2) );
            t = linspace(0, 2*pi, 40);
            xelip = D4sigmaX/2*cos(t);
            yelip = D4sigmaY/2*sin(t);
            R  = [cos(theta) -sin(theta); sin(theta)  cos(theta)];
            CorR = R*[xelip ; yelip];
            results.xel = xCent+CorR(1,:);
            results.yel = yCent+CorR(2,:);

        end

        

    end

end