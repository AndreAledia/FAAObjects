% filepath: d:\Repos\FAAObjects\object_data_parser.m
function object_data_parser(p_lat, p_lon, a_agl)
    % Main function to parse DOF file and plot obstacles on a MATLAB map

    % Replace with the actual path to your DOF file
    dof_filename = 'DOF_250119/06-CA.Dat';
    
    % Parse the DOF file
    obstacles = parse_dof_file(dof_filename);
    
    % Create the obstacle map
    create_obstacle_map(obstacles, p_lat, p_lon, a_agl);
end

function records = parse_dof_file(filename)
    % Reads a DOF file and returns a struct array of obstacle data
    fid = fopen(filename, 'r');
    if fid == -1
        error('Could not open file: %s', filename);
    end
    
    % Read all lines into memory
    lines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = lines{1};
    
    % Skip header lines (first 4 lines)
    lines = lines(5:end);
    
    % Preallocate a cell array for parallel processing
    num_lines = length(lines);
    parsed_records = cell(num_lines, 1);
    
    % Start parallel processing
    parfor i = 1:num_lines
        line = lines{i};
        
        % Skip empty lines or lines that are too short to be data
        if isempty(line) || length(line) < 80 || all(line == '-')
            continue;
        end
        
        % Parse the line
        parsed_records{i} = parse_dof_line(line);
    end
    
    % Combine non-empty results into a single struct array
    records = [parsed_records{:}];
end

function str = struct2str(s)
    % Converts a struct to a string for display
    fields = fieldnames(s);
    str = '';
    for i = 1:length(fields)
        field = fields{i};
        value = s.(field);
        if isnumeric(value)
            value = num2str(value);
        end
        str = [str, sprintf('%s: %s, ', field, value)]; %#ok<AGROW>
    end
    str = str(1:end-2); % Remove trailing comma and space
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

function create_obstacle_map(obstacles, p_lat, p_lon, a_agl)
    % Plots obstacles on a MATLAB map using geoscatter
    lat_min = 36; lat_max = 40;
    lon_min = -124; lon_max = -120;

    lats = [];
    lons = [];
    labels = {};

    radius = 0.5; % Flat radius in degrees (approx. 30-40 miles depending on latitude)

    for i = 1:length(obstacles)
        obs = obstacles(i);

        % Convert lat/lon from DMS to decimal degrees
        lat = dms_to_decimal(obs.lat_deg, obs.lat_min, obs.lat_sec, obs.lat_hem);
        lon = dms_to_decimal(obs.lon_deg, obs.lon_min, obs.lon_sec, obs.lon_hem);

        % Filter objects outside the specified bounds
        if lat < lat_min || lat > lat_max || lon < lon_min || lon > lon_max
            continue;
        end

        % Check against all p_lat, p_lon, and a_agl values
        is_within_radius = false;
        for j = 1:length(p_lat)
            % Check if the object is within the flat radius
            if sqrt((lat - p_lat(j))^2 + (lon - p_lon(j))^2) <= radius
                % Check if the height difference is less than 500 feet
                if abs(obs.agl_height - a_agl(j)) < 500
                    is_within_radius = true;
                    break;
                end
            end
        end

        % Skip the object if it doesn't meet the criteria
        if ~is_within_radius
            continue;
        end

        % Add the object to the map
        lats = [lats; lat]; %#ok<AGROW>
        lons = [lons; lon]; %#ok<AGROW>
        labels{end+1} = sprintf('OAS#%s-%s\nType: %s\nCity: %s\nAGL: %d ft\nAMSL: %d ft', ...
            obs.oas_code, obs.obstacle_number, obs.obstacle_type, obs.city_name, ...
            obs.agl_height, obs.amsl_height); %#ok<AGROW>
    end

    % Plot the data on a geographic map
    figure;
    ax = geoaxes; % Create a GeographicAxes object
    geoscatter(ax, lats, lons, 50, 'r', 'filled');
    title('Obstacle Map');

    % Add labels to the points
    for i = 1:length(lats)
        text(ax, lons(i), lats(i), labels{i}, 'FontSize', 8);
    end
end