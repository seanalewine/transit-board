#!/usr/bin/with-contenv bashio

# Define train line colors from config.yaml
RED_COLOR=$(bashio::config 'red_line_color')
PINK_COLOR=$(bashio::config 'pink_line_color')
ORANGE_COLOR=$(bashio::config 'orange_line_color')
YELLOW_COLOR=$(bashio::config 'yellow_line_color')
GREEN_COLOR=$(bashio::config 'green_line_color')
BLUE_COLOR=$(bashio::config 'blue_line_color')
PURPLE_COLOR=$(bashio::config 'purple_line_color')
BROWN_COLOR=$(bashio::config 'brown_line_color')

# --- NEW FEATURE DEFINITIONS ---
CTA_STATION_LIST="/data/ctastationlist.csv"
MAP_FILE="/data/station_id_map.json"
# --- END NEW FEATURE DEFINITIONS ---

# Define the array of train line abbreviations
TRAIN_LINES=("red" "blue" "brn" "g" "org" "p" "pink" "y")

# Define the output file path
OUTPUT_FILE="/data/active_train_summary.json"

# Initialize the output file with an empty JSON array, which jq will fill
TEMP_OUTPUT_FILE="/data/temp_train_summary.json"
TEMP_MAPPED_FILE="/data/temp_mapped_train_summary.json" # New temp file for ID mapping (Map is first)
TEMP_COLOR_FILE="/data/temp_colored_train_summary.json" # Color is second

# Start by clearing the temporary output file
> "$TEMP_OUTPUT_FILE"

echo "Starting processing of CTA Train Lines: ${TRAIN_LINES[@]}"
echo "--------------------------------------------------------"

# Create a JSON map from the CSV file
if [ ! -f "$CTA_STATION_LIST" ]; then
    echo "Fatal Error: CSV station list not found at $CTA_STATION_LIST. Cannot map station IDs."
    exit 1
fi

echo "Creating station ID lookup map from $CTA_STATION_LIST..."

# Use awk to process the CSV, skipping the header (NR>1), and outputting a jq-readable map.
# NEW: Key = nextStaId + ":" + line (e.g., "40830:pink"), Value = unifiedId
# Columns: 1=nextStaId, 2=line, 3=unifiedId (based on the attached CSV structure)
awk -F',' '
BEGIN {
    print "{"
}
NR > 1 {
    # CRITICAL FIX: Aggressively remove carriage returns and other control characters
    # from the fields before printing.
    gsub(/\r/, "", $1); # nextStaId
    gsub(/[[:cntrl:]]/, "", $1);
    gsub(/\r/, "", $2); # line
    gsub(/[[:cntrl:]]/, "", $2);
    gsub(/\r/, "", $3); # unifiedId
    gsub(/[[:cntrl:]]/, "", $3);

    if (NR > 2) {
        printf ",\n"
    }
    # Ensure fields are non-empty before printing.
    if ($1 != "" && $2 != "" && $3 != "") {
        # NEW: Create the key as a concatenation of nextStaId and line
        printf "    \"%s:%s\": \"%s\"", $1, $2, $3
    }
}
END {
    print "\n}"
}
' "$CTA_STATION_LIST" > "$MAP_FILE"

echo "Map created at $MAP_FILE"
echo "--------------------------------------------------------"


# Loop through each train line abbreviation
for LINE_CODE in "${TRAIN_LINES[@]}"; do
    # Construct the input file path using the current line code
    INPUT_FILE="/data/position/${LINE_CODE}.json"

    echo "Processing line: ${LINE_CODE} from ${INPUT_FILE}"

    # Check if the input file exists before attempting to process
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Warning: Input file not found for line ${LINE_CODE} at $INPUT_FILE. Skipping."
        continue
    fi

    # Use 'jq' to parse the file for the current line
    jq '
    .ctatt.route[] |
    select(.train) |
    .train[] |
    {
        nextStaId: .nextStaId,
        output_color: "'"${LINE_CODE}"'",
        line_code: "'"${LINE_CODE}"'", # NEW: Keep the raw line code for mapping
        value: (
            if .isDly == "1" then 2
            elif .isApp == "1" then 1
            else 0
            end
        )
    }
    ' "$INPUT_FILE" >> "$TEMP_OUTPUT_FILE"
done

# Check if the temporary file has content before final processing
if [ -s "$TEMP_OUTPUT_FILE" ]; then
    echo "--------------------------------------------------------"

    # --- STEP 1 (NEW): Map nextStaId and line_code to unifiedId ---
    echo "Mapping 'nextStaId' and 'line_code' to 'unifiedId' using map file $MAP_FILE"

    # Read the JSON map into a jq variable ($id_map) and use it for lookup.
    jq --slurpfile id_map "$MAP_FILE" -f - "$TEMP_OUTPUT_FILE" > "$TEMP_MAPPED_FILE" <<'EOF'
        # The map is the first element of the slurpfile array
        ($id_map[0]) as $map |
        # Construct the key as "nextStaId:line_code"
        ($(.nextStaId) + ":" + .line_code) as $lookup_key |
        
        # Use the lookup key to find the unifiedId, default to original nextStaId if not found
        # Then, remove the temporary 'line_code' field.
        .nextStaId = (
            ($map[$lookup_key] // .nextStaId)
            # The nextStaId from the input JSON is already a string, so we convert it 
            # to a number to match the CSV column structure for unifiedId.
            # If the output .nextStaId must be a string, remove 'tonumber'.
            | tonumber 
        )
        | del(.line_code)
EOF "$TEMP_OUTPUT_FILE" > "$TEMP_MAPPED_FILE"


    # --- STEP 2 (NEW): Apply color codes ---
    echo "Applying color codes to 'output_color' field in ${TEMP_MAPPED_FILE}"

    jq \
        --arg RED "$RED_COLOR" \
        --arg BLUE "$BLUE_COLOR" \
        --arg BROWN "$BROWN_COLOR" \
        --arg GREEN "$GREEN_COLOR" \
        --arg ORANGE "$ORANGE_COLOR" \
        --arg PURPLE "$PURPLE_COLOR" \
        --arg PINK "$PINK_COLOR" \
        --arg YELLOW "$YELLOW_COLOR" \
        '
        .output_color |= 
            if   . == "red"  then $RED
            elif . == "blue" then $BLUE
            elif . == "brn"  then $BROWN
            elif . == "g"    then $GREEN
            elif . == "org"  then $ORANGE
            elif . == "p"    then $PURPLE
            elif . == "pink" then $PINK
            elif . == "y"    then $YELLOW
            else .
            end
        ' "$TEMP_MAPPED_FILE" > "$TEMP_COLOR_FILE"


    # --- STEP 3: Final wrapping and cleanup ---
    echo "Wrapping data and saving final output to ${OUTPUT_FILE}"

    # Use 'jq -s' to "slurp" all objects into a single array and wrap it.
    jq -s '{trains: .}' "$TEMP_COLOR_FILE" > "$OUTPUT_FILE"

    # Clean up temporary files
    rm "$TEMP_OUTPUT_FILE"
    rm "$TEMP_COLOR_FILE"
    rm "$TEMP_MAPPED_FILE"
    rm "$MAP_FILE" # Remove the generated map file

    echo "Successfully completed processing."
    echo "Output saved to $OUTPUT_FILE"

else
    echo "--------------------------------------------------------"
    echo "Error: No data was processed. Check file paths and permissions."
fi

return