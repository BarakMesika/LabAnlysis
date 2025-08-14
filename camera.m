classdef camera < handle
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
                    % for the large camera sensor
                    obj.device = videoinput("gentl", 1, "Mono12"); 
                    obj.param.pxl_length = 3.45; % um
                    
                    % for the small sensor
                    % obj.device = videoinput("gentl", 1, "Mono10"); 
                    % obj.param.pxl_length = 4.8; % um

                    triggerconfig(obj.device, 'manual');
                    start(obj.device);

                    obj.src = getselectedsource(obj.device);
                    tmpRes = get(obj.device, 'VideoResolution');
                    obj.param.Width = tmpRes(2);
                    obj.param.Height = tmpRes(1);

                    obj.InitStatus = true;

                else
                    obj = [];
                    obj.InitStatus = false;
                    obj.msg.txt = 'Camera NOT FOUND' ;
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
                stop(obj.device);
                delete(obj.device);
                clear obj.device;
                
                msg.txt = 'Device Disconnected';
                msg.color = [0 1 0]; % green

            else
                msg.txt = 'NO Device to disconnect';
                msg.color = [1 1 1]; % white

            end


        end

        % get 1 frame from the camera
        function frame = getFrame(obj)

            if obj.InitStatus
                % frame = double( getsnapshot(obj.device) );
                frame = getsnapshot(obj.device);
            else
                frame = [];
            end

        end



        function results = get_D4sigma(~,frame,thr)

            if nargin<3
                thr=100;
            end
            
            % thr = 100; % TODO: find right threshold
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


        % changing the thr every iteration until the D4s stays the same
        function [results,thr] = get_D4sigma_dymanic(obj,frame,start_thr)


            change_thr = 2 * 0.01; % presentege
            max_iter = 200;
            min_step = 5;

            % thr = 10;
            if nargin < 3
                thr = mean(frame, 'all');
            else
                thr = start_thr;
            end

            max_thr = max(frame(:)) / 1.5;
            thr_step = min([thr/10, min_step]);
            D4s_prev = obj.get_D4sigma(frame,0);

            iter = 1;
            while (thr < max_thr) 

                D4s_curr = obj.get_D4sigma(frame,thr);

                if abs(D4s_curr.D4sigmaX - D4s_prev.D4sigmaX)/max([D4s_curr.D4sigmaX , D4s_prev.D4sigmaX]) < change_thr
                    if abs(D4s_curr.D4sigmaY - D4s_prev.D4sigmaY)/max([D4s_curr.D4sigmaY , D4s_prev.D4sigmaY]) < change_thr
                        results = D4s_curr;
                        % fprintf("thr = %d\n",thr);
                        return;

                    end
                end
                
                
                if iter>max_iter
                    error("more then %d iteration for D4s", max_iter);
                end

                % for next iteretion
                thr = thr+thr_step;
                iter = iter+1;
                D4s_prev = D4s_curr;
            end

            % error("maximun threshold reached");
            msgbox("maximun threshold reached");
            results = obj.get_D4sigma(frame,thr);





        end

        % getting D4s in a diffarend way, by changing the window of the
        % frame around the center of the beam (insted of working with the
        % thr ajasments)
        % I didnt you this way
        function results = get_D4s_with_windowing(obj,frame)

            start_window = 3; % firt NxN window
            req_change = 2; % presents of change
            window_step = 1.5; % incress the window by N each iteration

            % get center
            [xCent,yCent] = obj.getCenter(frame);
            small_change = false;

            % first window
            frame_filtered = apply_window(frame, xCent, yCent, start_window);
            D4s_prev = obj.get_D4sigma(frame_filtered,0);

            window_size = start_window * window_step;

            while ~small_change

                % zero values outsize the window
                frame_filtered = apply_window(frame, xCent, yCent, window_size);

                % calculate D4s. no thr
                D4s_curr = obj.get_D4sigma(frame_filtered,0);
                % widwthX = D4s_curr.D4sigmaX

                if D4s_prev.D4sigmaX / D4s_curr.D4sigmaX * 100 < req_change &&...
                        D4s_prev.D4sigmaY / D4s_curr.D4sigmaY * 100 < req_change

                    small_change = true;

                else

                    window_size = window_size*window_step;

                end


            end

            results = D4s_curr;



        end

        function [xCent,yCent] = getCenter(obj,frame)

            [results,~] = obj.get_D4sigma_dymanic(frame);
            xCent=round(results.xCent);
            yCent=round(results.yCent);

        end

        

    end

end


function output_matrix = apply_window(input_matrix, center_x, center_y, window_size)
    % Get the size of the input matrix
    [rows, cols] = size(input_matrix);
    
    % Create a copy of the input matrix
    output_matrix = input_matrix;
    
    % Calculate the window boundaries
    left = max(1, center_x - floor(window_size/2));
    right = min(cols, center_x + floor(window_size/2));
    top = max(1, center_y - floor(window_size/2));
    bottom = min(rows, center_y + floor(window_size/2));
    
    % Create a mask of zeros
    mask = zeros(size(input_matrix));
    
    % Set the window region in the mask to ones
    mask(top:bottom, left:right) = 1;
    
    % Apply the mask to the output matrix
    output_matrix = output_matrix .* mask;
end