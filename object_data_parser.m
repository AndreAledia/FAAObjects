% filepath: d:\Repos\FAAObjects\object_data_parser.m
function object_data_parser()
    % Main function to parse DOF file and plot obstacles on a MATLAB map

    % Replace with the actual path to your DOF file
    dof_filename = 'DOF_250119/06-CA.Dat';
    
    % Parse the DOF file
    obstacles = parse_dof_file(dof_filename);
    
    % Create the obstacle map
    create_obstacle_map(obstacles);
end

function records = parse_dof_file(filename)
    % Reads a DOF file and returns a struct array of obstacle data
    fid = fopen(filename, 'r');
    records = [];
    
    if fid == -1
        error('Could not open file: %s', filename);
    end
    
    % Skip header lines (first 4 lines)
    for i = 1:4
        fgetl(fid);
    end
    
    while ~feof(fid)
        line = fgetl(fid);
        
        % Skip empty lines or lines that are too short to be data
        if isempty(line) || length(line) < 80
            continue;
        end
        
        % Skip lines made up only of dashes
        if all(line == '-')
            continue;
        end
        
        % Parse the line
        record = parse_dof_line(line);
        records = [records; record]; %#ok<AGROW>
    end
    
    fclose(fid);
end

function record = parse_dof_line(line)
    % Parses a single DOF data line and returns a struct of relevant fields
    record.oas_code = strtrim(line(1:2));
    record.obstacle_number = strtrim(line(4:9));
    record.verification_status = strtrim(line(11));
    record.country_id = strtrim(line(13:14));
    record.state_id = strtrim(line(16:17));
    record.city_name = strtrim(line(19:34));
    record.lat_deg = str2double(strtrim(line(36:37)));
    record.lat_min = str2double(strtrim(line(39:40)));
    record.lat_sec = str2double(strtrim(line(42:46)));
    record.lat_hem = strtrim(line(47));
    record.lon_deg = str2double(strtrim(line(49:51)));
    record.lon_min = str2double(strtrim(line(53:54)));
    record.lon_sec = str2double(strtrim(line(56:60)));
    record.lon_hem = strtrim(line(61));
    record.obstacle_type = strtrim(line(63:80));
    record.quantity = str2double(strtrim(line(82)));
    record.agl_height = str2double(strtrim(line(84:88)));
    record.amsl_height = str2double(strtrim(line(90:94)));
    record.lighting = strtrim(line(96));
    record.horizontal_accuracy = str2double(strtrim(line(98)));
    record.vertical_accuracy = str2double(strtrim(line(100)));
    record.mark_indicator = strtrim(line(102));
    record.faa_study_number = strtrim(line(104:117));
    record.action = strtrim(line(119));
    record.julian_date = strtrim(line(121:127));
end

function decimal = dms_to_decimal(deg, min, sec, hemisphere)
    % Converts degrees, minutes, seconds, and hemisphere to decimal degrees
    if isnan(deg), deg = 0; end
    if isnan(min), min = 0; end
    if isnan(sec), sec = 0; end
    
    decimal = deg + min / 60 + sec / 3600;
    if strcmpi(hemisphere, 'S') || strcmpi(hemisphere, 'W')
        decimal = -decimal;
    end
end

function create_obstacle_map(obstacles)
    % Plots obstacles on a MATLAB map using geoscatter
    lat_min = 36; lat_max = 40;
    lon_min = -124; lon_max = -120;
    
    lats = [];
    lons = [];
    labels = {};
    
    for i = 1:length(obstacles)
        obs = obstacles(i);
        
        % Convert lat/lon from DMS to decimal degrees
        lat = dms_to_decimal(obs.lat_deg, obs.lat_min, obs.lat_sec, obs.lat_hem);
        lon = dms_to_decimal(obs.lon_deg, obs.lon_min, obs.lon_sec, obs.lon_hem);
        
        % Filter objects outside the specified bounds
        if lat < lat_min || lat > lat_max || lon < lon_min || lon > lon_max
            continue;
        end
        
        lats = [lats; lat]; %#ok<AGROW>
        lons = [lons; lon]; %#ok<AGROW>
        labels{end+1} = sprintf('OAS#%s-%s\nType: %s\nCity: %s\nAGL: %d ft\nAMSL: %d ft', ...
            obs.oas_code, obs.obstacle_number, obs.obstacle_type, obs.city_name, ...
            obs.agl_height, obs.amsl_height); %#ok<AGROW>
    end
    
    % Plot the data on a map
    figure;
    worldmap([lat_min lat_max], [lon_min lon_max]);
    geoscatter(lats, lons, 50, 'r', 'filled');
    title('Obstacle Map');
    
    % Add labels to the points
    for i = 1:length(lats)
        textm(lats(i), lons(i), labels{i}, 'FontSize', 8);
    end
end