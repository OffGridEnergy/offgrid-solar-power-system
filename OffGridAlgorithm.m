% The algorithm requires the expected time-series power demand of the
% building and the expected time-series power output of the solar panels.
% The file, example_power_data.mat, contains an example of each.

% To use the example, open the file (example_power_data.mat) which will
% load the data into the workspace.

% choose the data to analyze
power_supply = power_supply_san_diego; % Watts
power_demand = power_demand_commercial_building; % kW


% Initialization parameters
eff = 0.90;                     % set the efficiency of the energy storage system in decimal notation
pkwh = 400;                     % set the price of energy storage (dollars per kWh)
PV_size = 4;                    % set the DC PV System Size of the power_supply data (kW)
pskW = 4000;                    % set the price of the solar panels (dollars per kW)
% Initialization complete

% Check if power_supply and power_demand are the same size
if size(power_supply,1) ~= size(power_demand,1)
    disp ('power_supply and power_demand are not of equal size')
else
    time = size(power_supply,1);    % size of time-series data
    
    % scale PV size so annual generation equals annual consumption 
    sim_supply = power_supply.*(trapz(power_demand)/trapz(power_supply));  
    % when annual generation equals annual consumption
    
    n = 1;                      % n is the power scaling factor (PSF)
    % PSF=1 means the expected annual generation equals the expected annual consumption
    
    energy_stored = zeros(time,1);            % allocate memory for stored energy
    difference = zeros(time,1);               % allocate memory for energy difference of each interval
    energy_stored(1) = 0;                     % set initial stored energy (note: this value is arbitrary)
    
    % This loop models the stored energy of the system for PSF = 1
    for i = 2:time              
        power_produced = trapz(sim_supply(i-1:i));       % energy produced in the ith interval
        power_demanded = trapz(power_demand(i-1:i));     % energy demanded in the ith interval
        difference(i) = power_produced - power_demanded; % energy difference in the ith interval

        if difference(i)>0  % check if generation exceeds consumption in the ith interval
            % if yes, store extra energy after subtracting energy storage losses
            energy_stored(i) = energy_stored(i-1) + difference(i)*eff;
        else    % if no, use stored energy to meet energy difference
            energy_stored(i) = energy_stored(i-1) + difference(i); 
        end
    end
    energy_stored = energy_stored-min(energy_stored);   % shift stored energy data 

    % This while loop finds the first stable off-grid configuration. 
    % Stability is achieved when the final stored energy is greater than the
    % initial stored energy. 
    % Each pass through this loop simulates the stored energy with the
    % current PSF. After each loop, stability is checked. If the system is
    % unstable, the PSF increases by 0.005, and the system is simulated again.     
    while energy_stored(end)<energy_stored(1)
        n = n + 0.005;                                      % increase the PSF
        sim_supply = power_supply.*(trapz(power_demand)*n/trapz(power_supply)); % scale the solar time-series data
        energy_stored = zeros(time,1);            % allocate memory for stored energy
        difference = zeros(time,1);               % allocate memory for energy difference of each interval
        energy_stored(1) = 0;                     % set initial stored energy (note: this value is arbitrary)
        for i = 2:time              
            power_produced = trapz(sim_supply(i-1:i));       % energy produced in the ith interval
            power_demanded = trapz(power_demand(i-1:i));     % energy demanded in the ith interval
            difference(i) = power_produced - power_demanded; % energy difference in the ith interval

            if difference(i)>0  % check if generation exceeds consumption in the ith interval
                % if yes, store extra energy after subtracting energy storage losses
                energy_stored(i) = energy_stored(i-1) + difference(i)*eff;
            else    % if no, use stored energy to meet energy difference
                energy_stored(i) = energy_stored(i-1) + difference(i); 
            end
        end
    energy_stored = energy_stored-min(energy_stored);   % shift the stored energy data
    end
    
    % shift the data so it starts during the summer
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
        energy_stored(1) = emax;                     % set initial stored energy (note: this value is arbitrary)
        for i = 2:time           
            energy_produced = trapz(sim_supply(i-1:i));       % energy produced in the ith interval
            energy_demanded = trapz(power_demand(i-1:i));     % energy demanded in the ith interval
            difference(i) = energy_produced - energy_demanded; % energy difference in the ith interval
            % check if generation exceeds consumption in the ith interval
            if difference(i)>0 
                % if yes, check if energy storage is at full capacity
                if energy_stored(i-1) < emax 
                       % if no, place extra energy in storage
                    energy_stored(i) = min(emax,energy_stored(i-1) + difference(i)*eff); 
                else
                       % if yes, discard extra energy
                    energy_stored(i) = emax;
                end
            else                         
                % if no, use stored energy to meet energy difference
                energy_stored(i) = energy_stored(i-1) + difference(i);
            end
        end
        energy_stored = energy_stored - min(energy_stored);     % shift stored energy data      
        esc(k) = (max(energy_stored)-min(energy_stored));       % calculate required energy storage capacity
        solar_system_cost(k) = trapz(sim_supply)*pskW*PV_size/(trapz(power_supply)/1e3);  % calculate solar energy cost of $4 per watt installed
        pvw(k)=trapz(sim_supply)*PV_size/(trapz(power_supply)/1e3);
        storage_cost(k) = pkwh*esc(k);                    % calculate energy storage cost
        k=k+1;          % increment index variable
    end
    
    total_cost = solar_system_cost + storage_cost;  % compute cost of each system
    
    % Plot Energy Storage Capacity (kWh) vs. PV System Size (kW)
    figure(1)
    plot(pvw,esc), grid
    ylabel('Energy Storage Capacity (kWh)','FontSize',12,'FontName','TimesNewRoman')
    xlabel('PV System Size (kW)','FontSize',12,'FontName','TimesNewRoman')
    axis([0 pvw(end) 0 esc(1)])
    
    % Plot System Cost vs PV System Size
    figure(2)
    plot(pvw,total_cost/1e3), grid
    ylabel('System Cost (thousands of dollars)','FontSize',12,'FontName','TimesNewRoman')
    xlabel('PV System Size (kW)','FontSize',12,'FontName','TimesNewRoman')
end

loc=find(total_cost==min(total_cost));                  % find most cost-effective configuration
optimized_total_cost_thousands = min(total_cost)/1e3    % cost (thousands of dollars) of most cost-effective configuration
cost_optimized_PV_size_kW = pvw(loc)                   % PV system size (kW) for most cost-effective configuration
cost_optimized_storage_size_kWh = esc(loc)              % Storage Capacity (kWh) for most cost-effective configuration
