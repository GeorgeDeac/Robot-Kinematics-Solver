%       - revolute_joint (insert 1 for revolute joints, 0 for prismatic joints)
%       - N (number of joints)
%       - DHTABLE (denavit-hartember table)

%   Add/remove the following parameters (depending on your dh-table):
%       - dn (z axis offset)
%       - an (x axis offset)

%       - set a proper value of k (length magnitude of the links)
%       - set jnt_value array (joint values to plot)
%       - adapt the number of bodies and joints

clear all
clc

syms a alpha d theta
%% Robot parameters
disp('::: INPUT DATA ::::::::::::::::::::::::::::::::');

revolute_joint  = [1 1 1]
prismatic_joint = (-1)*(revolute_joint-1)

N   = 3                 % joint number                   
q   = sym('q',[N,1])    % joints symbolic variables
syms d1 d2 a3           % z and x offset along link

%% Denavit-Hartemberg table
disp('::: DH TABLE :::::::::::::::::::::::::::::::::::');
DHTABLE = [     pi/2    0       d1      q(1);
                pi/2    0       0      q(2);
                0       a3      d2       q(3);    ]

%% General Denavit-Hartenberg trasformation matrix
DH = [  cos(theta)  -sin(theta)*cos(alpha) sin(theta)*sin(alpha)  a*cos(theta);
        sin(theta)  cos(theta)*cos(alpha)  -cos(theta)*sin(alpha) a*sin(theta);
          0             sin(alpha)             cos(alpha)            d;
          0               0                      0                   1  ];


%% Direct Kinematics
% Build transformation matrices for each link
A = cell(1,N);
for i = 1:N
    alpha   = DHTABLE(i,1);
    a       = DHTABLE(i,2);
    d       = DHTABLE(i,3);
    theta   = DHTABLE(i,4);
    A{i} = subs(DH);
end
clear alpha a d theta
%% Build base-to-end-effector transformation matrix 
T = eye(4);
for i = 1:N 
    T =  T * A{i};
    T = simplify(T);
end

P05 = T(1:3, 4);   % poition vector
R05 = T(1:3, 1:3); % rotation matrix
disp('::: TRANSFORMATION MATRIX ::::::::::::::::::::::');
T % base-to-end-effector transformation matrix


%% compute Geometric Jacobian matrix

% linear component
Jl = zeros(0,0);
for i = 1:N
   Jl = simplify( [Jl , diff(P05,q(i))] );
end

% angular component
Ja = zeros(0,0);
R = eye(3);
z = [0 0 1]';
for i = 1:N
    Ja  = [Ja , R * z * revolute_joint(i)];
    R   = simplify( R * (A{i}(1:3,1:3)) );
end
clear z R
% full geometric Jacobian
disp('::: GEOMETRIC JACOBIAN :::::::::::::::::::::::::');
J = [Jl ; Ja]


%% Redundancy analysis
if N==3
    disp('::: Determinant of the linear Jacobian:');
    J_det = simplify(det(Jl(:,1:3)))
elseif N==4
    disp('::: Minor determinants of the linear Jacobian:');
    J_det_a = simplify(det(Jl(:,1:3)))
    J_det_b = simplify(det(Jl(:,2:4)))
    J_det_c = simplify(det([Jl(:,1:2),Jl(1:3,4)]))
    J_det_d = simplify(det([Jl(:,3:4),Jl(1:3,1)]))
elseif N>4
    %in this case is not convenient use the analysis of the determinant
    %to spot singularities. A better approach is based on the null-space
    %analysis
    disp('::: Jacobian null space:');
    J_null = simplify(null(J))
end


%% Plot
disp('::: PLOT stuff ::::::::::::::::::::::::::::::::')

% joint values to plot (MODIFY HERE!)
k = 0.5;
jnt_value = [-pi/2, -2*pi/5, pi];

k = 0.5;	% fixed magnitude for prismatic joints

%dh table without non constant parameters
DH = DHTABLE;
DH = subs(DHTABLE, {d1,d2,a3}, {k,k,k});    %modify here
for i = 1:N
    DH = subs(DH, q(i), jnt_value(i));
end
DH = sym2double(DH)

body1 = rigidBody('body1');
body2 = rigidBody('body2');
body3 = rigidBody('body3');
body = [body1, body2, body3];

jnt1 = rigidBodyJoint('jnt1','revolute');
jnt2 = rigidBodyJoint('jnt2','revolute');
jnt3 = rigidBodyJoint('jnt3','revolute');
jnt = [jnt1, jnt2, jnt3];

robot = build_robot(body, jnt, DH);
jnt_config = build_jnt_config(robot, jnt_value);
showdetails(robot)
show(robot, jnt_config);
axis on


%%
% input:
%       - body: 1xN array of rigidBody objects
%       - jnt: 1xN array of rigidBodyJoint objects
%       - DH: Denavit hartemberg Nx4 matrix
%            Only Double type matrix allowed (no symbolic!)
%           params are give in the following order: [alpha | a | d | theta]
% output:
%       - robot: rigidBodyTree object
function robot = build_robot(body, jnt, DH)
    robot = rigidBodyTree;
    N = size(body,2);
    
    % [alpha a d theta] --> [a  alpha  d  theta]
    DH = [DH(:,2), DH(:,1), DH(:,3), DH(:,4)];
    
    for i = 1:N
        %transformation from jnt(i-1) to jnt(i)
        setFixedTransform(jnt(i), DH(i,:), 'dh');
        body(i).Joint = jnt(i);
        % attach bodies
        if i==1
            addBody(robot, body(i), 'base');% attach body 1 to the base frame
        else
            addBody(robot, body(i), body(i-1).Name);
        end
    end
end

% input:
%       - robot: rigidBodyTree object
%       - jnt_value: 1xN array with joint variables
%           (non constant parameters)
% output:
%       - jnt_config: 1xN JointPosition object array
function jnt_config = build_jnt_config(robot, jnt_value)
    N = size(robot.Bodies,2);
    %build joint configuration object
    jnt_config = homeConfiguration(robot);
    for i = 1:N
        jnt_config(i).JointPosition = jnt_value(i);
    end
end

% input:
%   - m: symbolic matrix (with syms already substituted with numbers!)
% output:
%   - ret: double type matrix
function ret = sym2double(m)
    ret = zeros(size(m,1), size(m,2));
    for i = 1:size(m,1);
        for j = 1:size(m,2)
            ret(i,j) = double(m(i,j));
        end
    end
end
