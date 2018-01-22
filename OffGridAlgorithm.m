% This algorithm finds the most-cost effective configuration of solar
% photovoltaic (PV) and energy storage for Sustainable Energy Generation
% Systems(SEGSs).

clear
clc

% To use the example data, open example_power_data.mat by double clicking the file or 
% use the commented code directly below. 

%cd 'Location of file example_power_data.mat'
%load ('example_power_data.mat')

% choose the data to analyze
power_supply = TID_Supply;      % power supply data (MW)
power_demand = TID_Demand_17;   % power demand data (MW)
PV_size = 500;             % set the DC PV system size of the power_supply data (MW)

% Algorithm Parameters
eff_start = 0.9;        % initial efficiency 
eff_end = 0.7;          % final efficiency 
discharge_rate = 0.05;  % ESS discharge rate per month
price_ESS_MWh = 160000;     % set the price of energy storage (dollars per MWh)
price_PV_MW = 1640000;      % set the price of the solar panels (dollars per kW)
year = 20;                  % set number of years to simulate

% scaling power supply data for G2C ratio of 1
scale = trapz(power_demand)/trapz(power_supply);
power_supply = power_supply*scale;
PV_size_MW = PV_size*scale;     % compute PV system size for G2C ratio of 1

power_supply = repmat(power_supply,[year 1]);   % duplicate power supply data
power_demand = repmat(power_demand,[year 1]);   % duplicate power demand data
time = size(power_supply,1);	% total hours to simulate

eff = linspace(eff_start, eff_end, time);   % create array of efficiency values from eff_start to eff_end
discharge_rate = discharge_rate/720;        % compute ESS self-discharge rate per hour

energy_stored = zeros(size(power_supply));  % create matrix to store time-series stored energy values
difference = zeros(size(power_supply));     % create matrix to store time-series difference between generation and consumption
 
n = 1;  % initial G2C ratio to simulate
x = 0;  % variable used to increment n by 0.1
y = 0;  % variable used to increment n by 0.01
z = 0;  % variable used to increment n by 0.001

% This while loop finds the minimum G2C ratio that balances the system. 
% Starting at a G2C ratio of 1, the algorithm gradually increases n and 
% checks if the system is balanced. If the system is not balanced, the G2C
% ratio is increased and the system is reevaluated. This process continues
% until the minimum G2C ratio that balances the system is found. 

% First, the algorithm increments the G2C ratio by 0.1 until the system
% becomes balanced. Then, the G2C ratio is decremented by 0.1 and then
% incremented by 0.01 until the system become balanced. Then, the G2C ratio
% is decremented by 0.01 and then incremented by 0.001 until the system
% become balanced.

% For example, if the minimum G2C ratio is 1.222, the algorithm will
% iterate through these G2C ratios
% G2C=1 (unbalanced) - increment by 0.1
% G2C=1.1 (unbalanced) - increment by 0.1
% G2C=1.2 (unbalanced) - increment by 0.1 
% G2C=1.3 (balanced) - decrement by 0.1 and increment by 0.01
% G2C=1.21 (unbalanced) - increment by 0.01
% G2C=1.22 (unbalanced) - increment by 0.01
% G2C=1.23 (balanced) - decrement by 0.01 and increment by 0.001
% G2C=1.221 (unbalanced) - increment by 0.001
% G2C=1.222 (balanced) - minimum G2C ratio

while(1)
    sim_supply = power_supply.*(trapz(power_demand)*n/trapz(power_supply));
    energy_stored = zeros(time,1);
    % This while loops find the initial energy stored value
    % (energy_stored(1)) such that the stored energy in the first year is
    % all positive
    while (1)
        difference = zeros(time,1);        
        for i = 2:time           
            power_produced = trapz(sim_supply(i-1:i));       
            power_demanded = trapz(power_demand(i-1:i));     
            difference(i) = power_produced - power_demanded; 
            if difference(i)>0 
                energy_stored(i) = energy_stored(i-1) + difference(i)*eff(i) - energy_stored(i-1)*discharge_rate;
            else
                energy_stored(i) = energy_stored(i-1) + difference(i) - energy_stored(i-1)*discharge_rate;
            end
        end
        if sum(energy_stored(1:8760)<0)==0
            break
        end        
        energy_stored(1) = energy_stored(1) + max(-floor(min(energy_stored(1:8760))),0);
    end
    % check if system is balanced
    if sum(energy_stored<0)~=0
        if x == 0
            n = n + 0.1;
        elseif y == 0
            n = n + 0.01;
        elseif z == 0
            n = n + 0.001;
        end
    elseif x == 0   
        n = n - 0.1;
        x = 1;
    elseif y == 0
        n = n - 0.01;
        y = 1;
    else
        break
    end
end

% This loop generates a series of decreasing doubles [524288, 262144,
% 131072, ..., 2, 1]. The first value must be greater than the storage
% capacity of the minimum G2C ratio.

d = 1;
for r = 2:20
    d(r) = d(r-1)*2;
end
d = fliplr(d);

g2c = [[n:0.002:2.2],[2.202:0.02:4.5]]; % Simulate G2C ratios from the minimum G2C ratio to 4.5

% Creates matrix where the columns represent the power supply data for each
% G2C ratio. The first column is the power supply data for the smallest G2C
% ratio. The last column is the power supply data for the largest G2C ratio
% (4.5).
power_supply = repmat(power_supply,[1 size(g2c,2)]); 
power_supply = power_supply*diag(g2c);

energy_stored = zeros(size(power_supply));  % create matrix to store time-series stored energy values
difference = zeros(size(power_supply));     % create matrix to store time-series difference between generation and consumption


% This loop finds the initial energy storage values for each G2C ratio such 
% that there are no negative storage values for the first year
while (1)
    for i = 2:8760
        power_produced = trapz(power_supply(i-1:i,:),1);        % compute PV generation in the ith interval
        power_demanded = trapz(power_demand(i-1:i));            % compute power consumption in the ith interval
        difference(i,:) = power_produced - power_demanded;
        x = difference(i,:)>0;
        y = difference(i,:)<0;
        energy_stored(i,:) = energy_stored(i-1,:) + (difference(i,:)*eff(i)).*x + (difference(i,:)).*y - energy_stored(i-1,:)*discharge_rate;
    end
    if sum(sum(energy_stored(1:8760,:)<0))==0
        break
    end
    energy_stored(1,:) = energy_stored(1,:) + max(-floor(min(energy_stored((1:8760),:))),0);
end

% Array (emax) contains the storage capacity to simulate for each G2C ratio
% starting with the maximum possible capacity.
emax = ones(1,size(g2c,2))*d(1);

% This loop simulates the SEGSs. If the stored energy data contains
% negative values the storage capacity is increased by the next double. If
% the stored energy data contains all positive values the storage capacity
% is decreased by the next double. The algorithm iterates through these
% values [524288, 262144, 131072, 65536, 32768, 16384, 8192, 4096, 2048,
% 1024, 512, 256, 128, 64, 32, 16, 8, 4, 2, 1]. 

% For example, the energy storage capacity for the minimum G2C ratio is
% 362781 MWh. Therefore, energy storage capacity will change as follows:
% emax(1) = 524288; (over) -- decrement by 262144
% emax(1) = 262144; (under) -- increment by 131072
% emax(1) = 393216; (over) -- decrement by 65536
% emax(1) = 327680; (under) -- increment by 32768
% emax(1) = 360448; (under) -- increment by 16384
% emax(1) = 376832; (over) -- decrement by 8192
% emax(1) = 368640; (over) -- decrement by 4096
% emax(1) = 364544; (over) -- decrement by 2048
% emax(1) = 362496; (under) -- increment by 1024
% emax(1) = 363520; (over) -- decrement by 512
% emax(1) = 363008; (over) -- decrement by 256
% emax(1) = 362752; (under) -- increment by 128
% emax(1) = 362880; (over) -- decrement by 64
% emax(1) = 362816; (over) -- decrement by 32
% emax(1) = 362784; (over) -- decrement by 16
% emax(1) = 362768; (under) -- increment by 8
% emax(1) = 362776; (under) -- increment by 4
% emax(1) = 362780; (under) -- increment by 2
% emax(1) = 362782; (over) -- decrement by 1
% emax(1) = 362781; result

for r = 1:size(d,2)-1
    for i = 2:time
        power_produced = trapz(power_supply(i-1:i,:),1);        % solar energy produced in the ith interval
        power_demanded = trapz(power_demand(i-1:i));            % the power demanded in the ith interval
        difference(i,:) = power_produced - power_demanded;
        x = (difference(i,:)>0).*((energy_stored(i-1,:) + difference(i,:)*eff(i)) > emax);
        y = (difference(i,:)>0).*((energy_stored(i-1,:) + difference(i,:)*eff(i)) < emax);    
        z = difference(i,:)<0;
        energy_stored(i,:) =  emax.*x;
        energy_stored(i,:) = energy_stored(i-1,:) + (difference(i,:)*eff(i)).*y + (difference(i,:)).*z - energy_stored(i-1,:).*(y+z)*discharge_rate;
    end
    % find G2C ratios that contain negative storage values
    loc_passed = find( (sum(energy_stored<0)>0)==1);
    % find G2C ratios that contain all positive storage values
    loc_not_passed = find((sum(energy_stored<0)>0)==0);
    % for G2C ratios with negative storage values, increase the capacity
    emax(loc_passed) = emax(loc_passed) + d(r+1); 
    % for G2C ratios with positive storage values, decrease the capacity
    emax(loc_not_passed) = emax(loc_not_passed) - d(r+1); 
end

storage_cost = price_ESS_MWh*emax;                  % compute storage cost of each configuration
PV_system_cost = g2c*PV_size_MW*price_PV_MW;        % compute PV system cost of each configuration
total_cost = (PV_system_cost + storage_cost)/1e9;   % compute total cost (billions of dollars) of each configuration

loc=find(total_cost==min(total_cost));                  % find the most cost-effective configuration
g2c_min = g2c(loc)                                      % display G2C ratio of most cost-effective configuration
optimized_total_cost_billions = min(total_cost)         % display the cost (billions of dollars) of most cost-effective configuration
cost_optimized_PV_size_MW = g2c(loc)*PV_size_MW         % display PV system size (MW) of most cost-effective configuration
cost_optimized_storage_size_MWh = emax(loc)             % display storage capacity (MWh) of most cost-effective configuration

inverter_size = energy_stored(2:end,loc) - energy_stored(1:end-1,loc);
inverter_size = max(max(inverter_size),min(inverter_size))      % display required inverter size (MW)

% Plot Required Storage Capacity vs. PV System Size
figure(1)
hFig = figure(1); set(gcf,'PaperPositionMode','auto'); set(hFig, 'Position', [100 100 800 500]);
plot(g2c*PV_size_MW,emax/1e3,'LineWidth',1.2), grid
ylabel('Required Storage Capacity (GWh)','FontSize',12,'FontName','TimesNewRoman')
xlabel('PV System Size (MW)','FontSize',12,'FontName','TimesNewRoman')
axis([0 8000 0 4e2])

% Plot Total System Cost vs. PV System Size
figure(2)
hFig = figure(2); set(gcf,'PaperPositionMode','auto'); set(hFig, 'Position', [100 100 700 500]);
hold on
plot(g2c*PV_size_MW,total_cost,'LineWidth',1.5), grid
axis([0 9000 0 70])
ylabel('Total System Cost (Billions of dollars)','FontSize',12,'FontName','TimesNewRoman')
xlabel('SEGS Configuration (PV System Size (MW))','FontSize',12,'FontName','TimesNewRoman')
plot(cost_optimized_PV_size_MW,optimized_total_cost_billions,'rx','LineWidth',2)

% Plot Required Storage Capacity vs. G2C Ratio
figure(3)
hFig = figure(3); set(gcf,'PaperPositionMode','auto'); set(hFig, 'Position', [100 100 800 500]);
plot(g2c,emax/1e3,'LineWidth',1.2), grid
ylabel('Required Storage Capacity (GWh)','FontSize',12,'FontName','TimesNewRoman')
xlabel('SEGS Configuration (G2C ratio)','FontSize',12,'FontName','TimesNewRoman')
axis([0 5 0 4e2])

% Plot Total System Cost vs. G2C Ratio
figure(4)
hFig = figure(4); set(gcf,'PaperPositionMode','auto'); set(hFig, 'Position', [100 100 800 500]);
hold on
plot(g2c,total_cost,'LineWidth',1.5), grid
ylabel('Total System Cost (Billions of dollars)','FontSize',12,'FontName','TimesNewRoman')
xlabel('SEGS Configuration (G2C ratio)','FontSize',12,'FontName','TimesNewRoman')
plot(g2c(loc),optimized_total_cost_billions,'rx','LineWidth',2)
hold off
axis([0 5 0 70])
