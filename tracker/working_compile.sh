#!/usr/bin/with-contenv bashio

#Define train line colors from config.yaml
RED_COLOR=$(bashio::config 'red_line_color')
PINK_COLOR=$(bashio::config 'pink_line_color')
ORANGE_COLOR=$(bashio::config 'orange_line_color')
YELLOW_COLOR=$(bashio::config 'yellow_line_color')
GREEN_COLOR=$(bashio::config 'green_line_color')
BLUE_COLOR=$(bashio::config 'blue_line_color')
PURPLE_COLOR=$(bashio::config 'purple_line_color')
BROWN_COLOR=$(bashio::config 'brown_line_color')

# Define the array of train line abbreviations
TRAIN_LINES=("red" "blue" "brn" "g" "org" "p" "pink" "y")

# Define the output file path
OUTPUT_FILE="/data/active_train_summary.json"

# Initialize the output file with an empty JSON array, which jq will fill
# We use a temporary file for the initial processed data before final wrapping.
TEMP_OUTPUT_FILE="/data/temp_train_summary.json"

# Start by clearing the temporary output file
> "$TEMP_OUTPUT_FILE"

echo "Starting processing of CTA Train Lines: ${TRAIN_LINES[@]}"
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
    # The output is appended (>>) to the temporary file as a stream of JSON objects.
    jq '
    .ctatt.route[] |
    select(.train) |
    .train[] |
    {
        nextStaId: .nextStaId,
        #trDr: .trDr,
        # Dynamically set the output_color value using the shell variable
        output_color: "'"${LINE_CODE}"'",
        # Create the new "value" field with conditional logic
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
    echo "Applying color codes to 'output_color' field in ${TEMP_OUTPUT_FILE}"

    # Use 'jq' to perform the conditional replacement on the 'output_color' field
    # We pass the shell variables as jq arguments ($RED, $BLUE, etc.)
    # and use a temporary file for the *final* transformation before cleanup.
    TEMP_COLOR_FILE="/data/temp_colored_train_summary.json"

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
        ' "$TEMP_OUTPUT_FILE" > "$TEMP_COLOR_FILE"

    echo "Wrapping data and saving final output to ${OUTPUT_FILE}"

    # Use 'jq -s' to "slurp" all objects in the temporary colored file into a single array
    # and then wrap that array with the final parent object {"trains": ...}.
    jq -s '{trains: .}' "$TEMP_COLOR_FILE" > "$OUTPUT_FILE"

    # Clean up both temporary files
    rm "$TEMP_OUTPUT_FILE"
    rm "$TEMP_COLOR_FILE"

    echo "Successfully completed processing."
    echo "Output saved to $OUTPUT_FILE"

else
    echo "--------------------------------------------------------"
    echo "Error: No data was processed. Check file paths and permissions."
fi

return