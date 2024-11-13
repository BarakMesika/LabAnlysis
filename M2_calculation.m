%% M2 calculation

clear; clc;

%% set stage and camera
address = 1111; % stage adress using 
Stage = ThorlabsStageController(XAxis,1);


%%
% steps: 
% 1) find waist location (w0 - waist size, z0 - waist location)
% 2) find rayleigh length(z_r)
% 3) get 3 images in and out the z_r from both sides or z0
% 4) for each image calculate D4Sigma
% 5) plot and fit D4Sigma vs z to get M2

%% Find Waist Location

initial_jog = 1; % mm

% move stage to 0

direction = true;

% take image and calculate width
% pre_width =

jog_size = initial_jog;

current_width = pre_width;

% find the intrest zone 
while pre_width > current_width
    % jog up and calculate width
    % current_width =
end

jog_size = jog_size / 2;


while jog_size >= initial_jog/10

    if pre_width < current_width % switch side 
        direction = ~direction;
    end

    % jog
    if direction % jog up
        % jog up  
    else % jog down
        % jog down 
    end    

    pre_width = current_width;
    % calculate width
    % current_width = 

     jog_size = jog_size / 2;
end
    
w0 = current_width;
z0 = % get stage location


%% Find Rayleigh Length
w_r = w0 * sqrt(2);

jog_size = 0.1; % mm

% move to the waist location
current_width = w0;

while current_width < w_r
    
    % jog up and calculate waist
    % current width = 

end

z_r = % get stage location


%% get images



%% calculate D4Sigma
function results = get_D4sigma(frame)
            
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

end