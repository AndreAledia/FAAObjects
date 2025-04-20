import folium


def parse_dof_line(line: str) -> dict:
    """
    Parses a single DOF data line (after the header lines) and returns a dictionary
    of all relevant fields. This follows the fixed-column specifications given by
    the FAA DOF documentation.
    """

    # Note: Python strings are zero-indexed, but the FAA specification is one-indexed.
    # We must carefully map the specification's columns [1..N] to Python's [0..N-1].

    # Columns (inclusive) -> Python slicing [start_index:end_index]
    # For example, columns 1-2 -> line[0:2], columns 36-37 -> line[35:37], etc.
    
    # If a field has whitespace, we call .strip() to clean it up.

    return {
        # Columns 1-2: OAS Code (State or area code, e.g., 06 for California)
        "oas_code": line[0:2].strip(),

        # Columns 3: a dash ("-"), we can ignore or store to verify
        # Columns 4-9: Obstacle Number
        "obstacle_number": line[3:9].strip(),

        # Column 10: blank
        # Column 11: Verification status 'O' = verified, 'U' = unverified
        "verification_status": line[10].strip(),

        # Column 12: blank
        # Columns 13-14: Country ID
        "country_id": line[12:14].strip(),

        # Column 15: blank
        # Columns 16-17: State ID
        "state_id": line[15:17].strip(),

        # Column 18: blank
        # Columns 19-34: City (16 characters)
        "city_name": line[18:34].strip(),

        # Column 35: blank
        # Columns 36-37: Latitude Degrees
        "lat_deg": line[35:37].strip(),

        # Column 38: blank
        # Columns 39-40: Latitude Minutes
        "lat_min": line[38:40].strip(),

        # Column 41: blank
        # Columns 42-46: Latitude Seconds
        "lat_sec": line[41:46].strip(),

        # Column 47: Latitude Hemisphere (N/S)
        "lat_hem": line[46].strip(),

        # Column 48: blank
        # Columns 49-51: Longitude Degrees
        "lon_deg": line[48:51].strip(),

        # Column 52: blank
        # Columns 53-54: Longitude Minutes
        "lon_min": line[52:54].strip(),

        # Column 55: blank
        # Columns 56-60: Longitude Seconds
        "lon_sec": line[55:60].strip(),

        # Column 61: Longitude Hemisphere (E/W)
        "lon_hem": line[60].strip(),

        # Column 62: blank
        # Columns 63-80: Obstacle Type
        "obstacle_type": line[62:80].strip(),

        # Column 81: blank
        # Column 82: Quantity
        "quantity": line[81].strip(),

        # Column 83: blank
        # Columns 84-88: AGL Height
        "agl_height": line[83:88].strip(),

        # Column 89: blank
        # Columns 90-94: AMSL Height
        "amsl_height": line[89:94].strip(),

        # Column 95: blank
        # Column 96: Lighting
        "lighting": line[95].strip(),

        # Column 97: blank
        # Column 98: Horizontal Accuracy
        "horizontal_accuracy": line[97].strip(),

        # Column 99: blank
        # Column 100: Vertical Accuracy
        "vertical_accuracy": line[99].strip(),

        # Column 101: blank
        # Column 102: Mark Indicator
        "mark_indicator": line[101].strip(),

        # Column 103: blank
        # Columns 104-117: FAA Study Number
        "faa_study_number": line[103:117].strip(),

        # Column 118: blank
        # Column 119: Action ('A' = Add, 'C' = Change, etc.)
        "action": line[118].strip(),

        # Column 120: blank
        # Columns 121-127: Julian date
        "julian_date": line[120:127].strip(),
    }


def parse_dof_file(filename: str):
    """
    Reads a DOF file and returns a list of dictionaries (one per obstacle data line).
    Skips header lines (the first four lines in the main DOF file) and any lines
    that are just dashes.
    """
    records = []
    with open(filename, "r", encoding="utf-8") as f:
        # Typically, the first four lines are headers in the DOF:
        # 1) CURRENCY DATE line
        # 2) Column titles for LAT/LONG
        # 3) Column titles for OAS# etc.
        # 4) A line of dashes
        # This can vary slightly for the full file vs. state files, but generally
        # we skip until we find lines that look like actual data lines.

        for line in f:
            # Trim trailing newline
            line = line.rstrip("\n")

            # Skip empty lines or lines that are too short to be data
            if not line.strip() or len(line) < 80:
                continue

            # Skip lines made up only of dashes
            if set(line.strip()) == {"-"}:
                continue

            # Now parse the line
            record = parse_dof_line(line)
            records.append(record)
    return records



def dms_to_decimal_degrees(deg_str, min_str, sec_str, hemisphere):
    """
    Converts 'degrees minutes seconds + hemisphere' (e.g. 117 05 49.19 W)
    into decimal degrees, returning a float. West/South are negative.
    """
    try:
        degrees = float(deg_str)
    except:
        degrees = 0.0
    try:
        minutes = float(min_str)
    except:
        minutes = 0.0
    try:
        seconds = float(sec_str)
    except:
        seconds = 0.0

    decimal = degrees + minutes / 60.0 + seconds / 3600.0

    if hemisphere.upper() in ("S", "W"):
        decimal = -decimal

    return decimal

def create_obstacle_map(obstacle_data, map_filename="obstacles_map.html"):
    """
    Takes a list of DOF obstacle records (dicts) and plots them on a folium map.
    Saves the interactive map to 'obstacles_map.html' by default.
    """
    # You can choose a default start location (e.g., continental US)
    obstacle_map = folium.Map(location=[37.8283, -121.5795], zoom_start=5)

    for obs in obstacle_data:
        print(obs)
        # Convert lat/lon from DMS -> decimal
        lat = dms_to_decimal_degrees(
            obs["lat_deg"], obs["lat_min"], obs["lat_sec"], obs["lat_hem"]
        )
        lon = dms_to_decimal_degrees(
            obs["lon_deg"], obs["lon_min"], obs["lon_sec"], obs["lon_hem"]
        )

        # Some lines in the DOF might have missing or invalid lat/lon, so skip if lat/lon is 0
        if lat == 0 and lon == 0:
            continue

        # Create a marker. Use obstacle_number + obstacle_type for label/tooltip
        popup_text = (
            f"OAS#{obs['oas_code']}-{obs['obstacle_number']}<br>"
            f"Type: {obs['obstacle_type']}<br>"
            f"City: {obs['city_name']}<br>"
            f"AGL Height: {obs['agl_height']} ft<br>"
            f"AMSL Height: {obs['amsl_height']} ft<br>"
            f"Lighting: {obs['lighting']}<br>"
            f"Action: {obs['action']}<br>"
            f"Julian Date: {obs['julian_date']}"
        )

        folium.Marker(
            location=[lat, lon],
            tooltip=f"{obs['obstacle_type']}",
            popup=popup_text,
        ).add_to(obstacle_map)

    # Save to an HTML file so you can open it locally in a browser
    obstacle_map.save(map_filename)
    print(f"Map saved to {map_filename}")


if __name__ == "__main__":
    # Example usage
    # Replace 'DOF.DAT' with the actual path to your DOF file
    dof_filename = "DOF_250119/06-CA.Dat"

    obstacles = parse_dof_file(dof_filename)

    create_obstacle_map(obstacles, "obstacles_map.html")

