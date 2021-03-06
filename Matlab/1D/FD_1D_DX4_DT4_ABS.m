%% FD_1D_DX4_DT4_ABS.m 1-D acoustic Finite-Difference modelling
% GNU General Public License v3.0
%
% Author: Florian Wittkamp 2016
%
% Finite-Difference acoustic seismic wave simulation
% Discretization of the first-order acoustic wave equation
%
% Temporal second-order accuracy O(DT^4)
% Spatial fourth-order accuracy  O(DX^4)
%
% Temporal discretization is based on the Adams-Basforth method
% Theory is available in:
% Bohlen, T., & Wittkamp, F. (2016).
% Three-dimensional viscoelastic time-domain finite-difference
% seismic modelling using the staggered Adams?Bashforth time integrator.
% Geophysical Journal International, 204(3), 1781-1788.

%% Initialisation
disp(' ');
disp(['Starting ', mfilename ]);
close all; clearvars;
addpath functions

%% Input Parameter

% Discretization
c1=20;  % Number of grid points per dominant wavelength
c2=0.5;   % CFL-Number
nx=2000; % Number of grid points
T=10;     % Total propagation time 

% Source Signal
f0= 10;      % Center frequency Ricker-wavelet
q0= 1;       % Maximum amplitude Ricker-Wavelet
xscr = 100;  % Source position (in grid points)

% Receiver
xrec1=400; % Position Reciever 1 (in grid points)
xrec2=800;  % Position Reciever 2 (in grid points)
xrec3=1800;  % Position Reciever 3 (in grid points)

% Velocity and density
modell_v=[1000*ones(1,round(nx/2)), 1500*ones(1,round(nx/2))]; % P-wave velocity in m/s
rho=[1*ones(1,round(nx/2)), 1.5*ones(1,round(nx/2))];         % Density in g/cm^3
% This is a easy two layer case

%% Preparation

% Init wavefields
vx=zeros(1,nx);
p=zeros(1,nx);
p_x=zeros(1,nx);
p_x2=zeros(1,nx);
p_x3=zeros(1,nx);
p_x4=zeros(1,nx);
vx_x=zeros(1,nx);
vx_x2=zeros(1,nx);
vx_x3=zeros(1,nx);
vx_x4=zeros(1,nx);

% Calculate first Lame-Paramter
l=rho.*modell_v.*modell_v;

cmin=min(modell_v(:)); % Lowest P-wave velocity
cmax=max(modell_v(:)); % Highest P-wave velocity
fmax=2*f0;             % Maximum frequency
dx=cmin/(fmax*c1);     % Spatial discretization (in m)
dt=dx/(cmax)*c2;       % Temporal discretization (in s)
lampda_min=cmin/fmax;  % Smallest wavelength

% Output model parameter:
disp(['Model size: x:',num2str(dx*nx),' in m']);
disp(['Temporal discretization: ',num2str(dt),' s']);
disp(['Spatial discretization: ',num2str(dx),' m']);
disp(['Number of gridpoints per minimum wavelength: ',num2str(lampda_min/dx)]);

% Create space and time vector
x=0:dx:(dx*nx-dx); % Space vector
t=0:dt:(T-dt);     % Time vector
nt=numel(t);       % Number of time steps

% Plotting model
figure
subplot(2,1,1)
plot(x,modell_v,'r','LineWidth',2)
xlabel('Depth in m')
ylabel('VP in m/s')
set(gca,'FontSize',16)
title('Model')
subplot(2,1,2)
plot(x,rho,'LineWidth',2)
xlabel('Depth in m')
ylabel('Density in g/cm^3')
set(gca,'FontSize',16)

% Source signal - Ricker-wavelet
tau=pi*f0*(t-1.5/f0);
q=q0*(1-2*tau.^2).*exp(-tau.^2);

% Plotting source signal
figure(2)
plot(t,q)
title('Source signal Ricker-Wavelet')
xlabel('Time in s')
ylabel('Amplitude')

% Init Seismograms
Seismogramm=zeros(3,nt); % Three seismograms

% Calculation of some coefficients
i_dx=1/(dx);

%% Time stepping
disp('Starting time stepping...');
tic;
for n=2:nt-1;
    
    % Inject source wavelet
    p(xscr)=p(xscr)+q(n);
    
    % Update velocity
    for kx=5:nx-5;
        p_x(kx)=i_dx*9/8*(p(kx+1)-p(kx))...
            -i_dx*1/24*(p(kx+2)-p(kx-1));
        
        vx(kx)=vx(kx)-dt/rho(kx)*(13/12*p_x(kx)-5/24*p_x2(kx)+1/6*p_x3(kx)-1/24*p_x4(kx));
        
    end
    
    % Save old spatial derivations for Adam-Bashforth method
    p_x4=p_x3;
    p_x3=p_x2;
    p_x2=p_x;
    
    % Update pressure
    for kx=5:nx-5;
        vx_x(kx)=i_dx*9/8*(vx(kx)-vx(kx-1))...
            -i_dx*1/24*(vx(kx+1)-vx(kx-2));
        
        p(kx)=p(kx)-l(kx)*dt*(13/12*vx_x(kx)-5/24*vx_x2(kx)+1/6*vx_x3(kx)-1/24*vx_x4(kx));
    end
    
    % Save old spatial derivations for Adam-Bashforth method
    vx_x4=vx_x3;
    vx_x3=vx_x2;
    vx_x2=vx_x;
    
    
    % Save seismograms
    Seismogramm(1,n)=p(xrec1);
    Seismogramm(2,n)=p(xrec2);
    Seismogramm(3,n)=p(xrec3);
    
    % Plot Snapshot
    if(~mod(n,20))
        
        figure(3)
        plot(p(:)*c2*2,x)
        hold on
        rec=plot(0,xrec1*dx,0,xrec2*dx,0,xrec3*dx,0,xscr*dx);
        ylabel('Depth in m')
        xlabel('Amplitude')
        title(['Wavefield at ', num2str(n*dt), 's'])
        set(rec,'MarkerSize',20,'Marker','.');
        axis([-q0 q0 0 dx*nx])
        axis ij
        hold off
        drawnow;
        pause(0.01)
        
    end
end
time=toc;
N_t=numel(2:nt-1);
disp(['Finished with ', num2str(N_t),' time steps, in ',...
    num2str(time),' s']);
disp(['Time pro time step: ', num2str(time/N_t),' in s (Average)']);

%% Plot seismograms
figure(4)
set(4,'Position',[570 110 560 420])
subplot(3,1,1)
plot(t,Seismogramm(1,:));
xlabel('Time in s');
ylabel('Amplitude');
title(['Receiver at ', num2str(dx*xrec1), ' m']);
subplot(3,1,2)
plot(t,Seismogramm(2,:));
xlabel('Time in s');
ylabel('Amplitude');
title(['Receiver at ', num2str(dx*xrec2), ' m']);
subplot(3,1,3)
plot(t,Seismogramm(3,:));
xlabel('Time in s');
ylabel('Amplitude');
title(['Receiver at ', num2str(dx*xrec3), ' m']);

disp(' ');

% Save seismogram in matlab format
output=['Seismograms/',mfilename,'.mat'];
save(output,'Seismogramm','dt','T','time','dx');