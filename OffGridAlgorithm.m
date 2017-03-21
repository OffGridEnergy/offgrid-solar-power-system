% Created by: Ricardo Rangel

% open example_power_data file by double clicking the file or
% loading it directly
%cd 'directory with example_power_data file'
%load('example_power_data')

% set power supply data and power demand data to analyze
power_supply = power_supply_san_diego; % Watts
power_demand = power_demand_commercial_building; % kW


% Initialization parameters (These values can be changed)
eff = 0.90;                     % efficiency of the energy storage system
pkwh = 400;                     % energy storage cost per kWh
PV_size = 4;                    % DC PV System Size (kW)
pskW = 4000;                    % solar cost per kW
% Initialization complete

% Check if power_supply and power_demand data are the same size
if size(power_supply,1) ~= size(power_demand,1)
    disp ('power_supply and power_demand not equal size')
else
    
    time = size(power_supply,1);
    n = 1;                      % scaling factor for solar power
    % scaling PV size so expected annual generation is equal expected annual consumption 
    sim_supply = power_supply.*(trapz(power_demand)*n/trapz(power_supply));     
    energy_stored = zeros(time,1);            % allocate memory for energy storage
    difference = zeros(time,1);               % allocate memory for energy difference of each interval
    energy_stored(1) = 0;                     % arbitary initial energy stored
    
    % This for loops simulates the energy storage system when the expected
    % annual generation equals the expected annual consumption 
    for i = 2:time              
        energy_produced = trapz(sim_supply(i-1:i));       % energy produced in the ith interval
        energy_demanded = trapz(power_demand(i-1:i));     % energy demanded in the ith interval
        difference(i) = energy_produced - energy_demanded; % energy difference in the ith interval
        
        if difference(i)>0  % Does generation exceed consumption in the ith interval?
            % store the extra energy after subtracting the energy losses
            energy_stored(i) = energy_stored(i-1) + difference(i)*eff;
        else    % energy consumption exceeds energy generation
            % Use stored energy to meet energy demand
            energy_stored(i) = energy_stored(i-1) + difference(i);
        end
    end
    energy_stored = energy_stored-min(energy_stored);   % shift energy stored graph up

    % Continue increasing the PV system size until the amount of stored energy  starts 
    % and ends the year with the same amount of energy
    
    % This while loop finds the first stable renewable energy system. This
    % while loop continuous increasing the PV size simulating the energy storage
    % system each time. This while loop stops when the renewable power
    % system starts and ends the year with the same amount of energy. 
    
    while energy_stored(end)<energy_stored(1)
        n = n + 0.005;                                      % increase the PV scaling factor
        sim_supply = power_supply.*(trapz(power_demand)*n/trapz(power_supply)); % scaling PV power output
        energy_stored = zeros(time,1);            % allocate memory for energy storage
        difference = zeros(time,1);               % allocate memory for energy difference of each interval
        energy_stored(1) = 0;                     % arbitary initial energy storage
        for i = 2:time              
            energy_produced = trapz(sim_supply(i-1:i));       % energy produced in the ith interval
            energy_demanded = trapz(power_demand(i-1:i));     % energy demanded in the ith interval
            difference(i) = energy_produced - energy_demanded; % energy difference in the ith interval

            if difference(i)>0  % Does generation exceed consumption in the ith interval?
                % store the extra energy after subtracting the energy losses
                energy_stored(i) = energy_stored(i-1) + difference(i)*eff;
            else    % energy consumption exceeds energy generation
                % Use stored energy to meet energy demand
                energy_stored(i) = energy_stored(i-1) + difference(i);
            end
        end
    energy_stored = energy_stored-min(energy_stored);   % shift energy stored graph up
    end
    
    % shifting the data so the data starts during the summer season
    power_supply = circshift(power_supply,4380);
    power_demand = circshift(power_demand,4380);
    
  % Initialization parameters (psf values can be changed they determine the
  % increments and how much solar power to consider
    psf = [n:0.05:3];          % power scaling factors to simulate
  % Initialization complete
  
    esc = [];                  % allocate memory for energy storage capacities
    pvw = [];                  % allocate memory for PV system sizes
    k = 1;                     % indexing variable
    solar_system_cost = [];    % allocate memory for solar cost
    storage_cost = [];         % allocate memory for energy storage cost
    
    for n = psf
        sim_supply = power_supply.*(trapz(power_demand)*n/trapz(power_supply)); % scale PV system
        emax = trapz(sim_supply);                               % maximum energy storage capacity
        energy_stored = zeros(time,1);            % allocate memory for energy storage
        difference = zeros(time,1);               % allocate memory for energy difference of each interval
        energy_stored(1) = emax;                     % setting initial energy stored
        for i = 2:time           
            energy_produced = trapz(sim_supply(i-1:i));       % energy produced in the ith interval
            energy_demanded = trapz(power_demand(i-1:i));     % energy demanded in the ith interval
            difference(i) = energy_produced - energy_demanded; % energy difference in the ith interval
            % Is energy supply greater than energy supply?
            if difference(i)>0 
                % if yes, is Energy storage at full capacity?
                if energy_stored(i-1) < emax 
                       % if no, place extra energy in the storage up to the full capacity.  
                    energy_stored(i) = min(emax,energy_stored(i-1) + difference(i)*eff); 
                else
                       % if yes, discard extra energy.
                    energy_stored(i) = emax;
                end
            else                         
                % if no, extract required energy from energy storage system.
                energy_stored(i) = energy_stored(i-1) + difference(i);
            end
        end
        energy_stored = energy_stored - min(energy_stored);     % shift energy stored graph up        
        esc(k) = (max(energy_stored)-min(energy_stored));       % calculate required energy storage capacity
        solar_system_cost(k) = trapz(sim_supply)*pskW*PV_size/(trapz(power_supply)/1e3);  % calculate solar energy cost of $4 per watt installed
        pvw(k)=trapz(sim_supply)*PV_size/(trapz(power_supply)/1e3);
        storage_cost(k) = pkwh*esc(k);                    % calculate energy storage cost
        k=k+1;          % increment indexing variable
    end

    total_cost = solar_system_cost + storage_cost;  % compute cost of each system
    
    % Plotting Energy Storage Capacity (kWh) vs. PV System Size (kW)
    figure(1)
    plot(pvw,esc), grid
    ylabel('Energy Storage Capacity (kWh)','FontSize',12,'FontName','TimesNewRoman')
    xlabel('PV System Size (kW)','FontSize',12,'FontName','TimesNewRoman')
    axis([0 pvw(end) 0 esc(1)])
    
    % Plotting System Cost vs PV System Size
    figure(2)
    plot(pvw,total_cost/1e3), grid
    ylabel('System Cost (thousands of dollars)','FontSize',12,'FontName','TimesNewRoman')
    xlabel('PV System Size (kW)','FontSize',12,'FontName','TimesNewRoman')
    
end

loc=find(total_cost==min(total_cost));                  % find most cost-effective configuration
optimized_total_cost_thousands = min(total_cost)/1e3;    % cost (thousands of dollars) of most cost-effective configuration
cost_optimized_PV_size_kW = pvw(loc);                   % PV system size (kW) for most cost-effective configuration
cost_optimized_storage_size_kWh = esc(loc);              % Storage Capacity (kWh) for most cost-effective configuration




