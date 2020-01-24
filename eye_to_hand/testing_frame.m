%__________________________________________________________________________

%   INIT STUFF
%__________________________________________________________________________

cd(fileparts(mfilename('fullpath')));
clear;
close;
clc;

pause(2);
%__________________________________________________________________________

% CONNECTION TO VREP
%__________________________________________________________________________

[ID,vrep] = utils.init_connection();

% COLLECTING HANDLES

% vision sensor
[~, h_VS] =vrep.simxGetObjectHandle(ID, 'Vision_sensor_ECM', vrep.simx_opmode_blocking);

% end effector
[~, h_EE] =vrep.simxGetObjectHandle(ID, 'EE', vrep.simx_opmode_blocking);


% end effector
[~, h_home] =vrep.simxGetObjectHandle(ID, 'HOME_POS', vrep.simx_opmode_blocking);

% reference for direct kin
[~, h_RCM]=vrep.simxGetObjectHandle(ID, 'RCM_PSM1', vrep.simx_opmode_blocking);

% reference for direct kin
% first RRP joints
[~, h_j1] = vrep.simxGetObjectHandle(ID,'J1_PSM1',vrep.simx_opmode_blocking);
[~, h_j2] = vrep.simxGetObjectHandle(ID,'J2_PSM1',vrep.simx_opmode_blocking);
[~, h_j3] = vrep.simxGetObjectHandle(ID,'J3_PSM1',vrep.simx_opmode_blocking);

% second RRR joints
[~, h_j4] = vrep.simxGetObjectHandle(ID,'J1_TOOL1',vrep.simx_opmode_blocking);
[~, h_j5] = vrep.simxGetObjectHandle(ID,'J2_TOOL1',vrep.simx_opmode_blocking);
[~, h_j6] = vrep.simxGetObjectHandle(ID,'J3_TOOL1',vrep.simx_opmode_blocking);

% collection of all joint handles
h_joints = [h_j1; h_j2; h_j3; h_j4; h_j5; h_j6];

sync = utils.syncronize(ID, vrep, h_joints, h_RCM, h_VS, h_EE);

if sync
    fprintf(1,'Sycronization: OK... \n');
    pause(1);
end


%__________________________________________________________________________

%	PROCESS LOOP
%__________________________________________________________________________
norma = 0;
while norma==0
    [~, home_position]=vrep.simxGetObjectPosition(ID, h_home, h_RCM, vrep.simx_opmode_streaming);
    [~, home_orientation]=vrep.simxGetObjectOrientation(ID, h_home, h_RCM, vrep.simx_opmode_streaming);
    norma = ( norm(home_position,2) )*( norm(home_orientation,2));
end

% coordinates wrt rcm
%home_position = [0.1245,   -0.0034,   -0.1834];
%home_orientation =[3.1416,   0.0000,  -1.9196];

home_pose = [home_position, home_orientation]';

fprintf(2,'\n ******* STARTING ******* \n');

% starting from zero config
Q = zeros(6,1);
kinematicsRCM.setJoints(ID, vrep, h_joints, Q);
pause(3);

reached = false;
time = 0;

while reached == false
    
    time = time +1;
    
    Q = kinematicsRCM.getJoints(ID, vrep, h_joints);
    
    
    % 1) READ CURRENT POSE OF joint 6 or h_EE wrt RCM frame
    
    [~, ee_position]=vrep.simxGetObjectPosition(ID, h_EE, h_RCM, vrep.simx_opmode_streaming);
    [~, ee_orientation]=vrep.simxGetObjectOrientation(ID, h_EE, h_RCM, vrep.simx_opmode_streaming);
    
    ee_pose= [ee_position, ee_orientation]';
    
    % 2) COMPUTE ERROR
    err = utils.computeError(home_pose,ee_pose);
    
    % 3) EVALUATE EXIT CONDITION (just on position)
    if norm(err,2)< 10^-3
        spot = spot+1;
        mode = 1;
        fprintf(1, 'GOING TOWARD SPOT : %d \n', spot);
        pause(1);
        
    end
    
    % 4) CORRECT AND UPDATE POSE
    
    % computing new configuration via inverse inverse kinematics
    Q = kinematicsRCM.inverse_kinematics(Q,err,0);
    
    % sending to joints
    [~] = vrep.simxSetJointPosition(ID, h_j1, Q(1), vrep.simx_opmode_streaming);
    [~] = vrep.simxSetJointPosition(ID, h_j2, Q(2), vrep.simx_opmode_streaming);
    [~] = vrep.simxSetJointPosition(ID, h_j3, Q(3), vrep.simx_opmode_streaming);
    [~] = vrep.simxSetJointPosition(ID, h_j4, Q(4), vrep.simx_opmode_streaming);
    [~] = vrep.simxSetJointPosition(ID, h_j5, Q(5), vrep.simx_opmode_streaming);
    [~] = vrep.simxSetJointPosition(ID, h_j6, Q(6), vrep.simx_opmode_streaming);
    
    pause(0.01);
    
    % PLOT
    if( mod(time,8)==0)
        
        x = time/100;
        y = norm(err(4:6),2);
        % plot(x,y,'--b');
        subplot(2,1,1)
        stem(x,y,'-k');
        ylim( [0 0.5]);
        xlabel('time')
        ylabel('norm error')
        title('Orientation error')
        hold on
        grid on
        
        subplot(2,1,2)
        y1 = norm(err(1:3),2);
        stem(x,y1,'-k');
        ylim( [0 0.25]);
        xlabel('time')
        ylabel('norm error')
        title('Position error')
        hold on
        grid on
        
    end
    
    
    
end



















fprintf(2,'\n ******* TERMINATED ******* \n');

