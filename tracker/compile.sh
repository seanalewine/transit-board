#!/usr/bin/with-contenv bashio

# Define the array of train line abbreviations
TRAIN_LINES=("red" "blue" "brn" "g" "org" "p" "pink" "y")

# Define the output file path
OUTPUT_FILE="/data/active_train_summary.json"

# Initialize the output file with an empty JSON array, which jq will fill
# We use a temporary file for the initial processed data before final wrapping.
TEMP_OUTPUT_FILE="temp_$OUTPUT_FILE"

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
    .ctatt.route[].train[] |
    {
        nextStaId: .nextStaId,
        trDr: .trDr,
        isApp: .isApp,
        isDly: .isDly,
        # Dynamically set the line value using the shell variable
        line: "'"${LINE_CODE}"'"
    }
    ' "$INPUT_FILE" >> "$TEMP_OUTPUT_FILE"
done

# Check if the temporary file has content before final processing
if [ -s "$TEMP_OUTPUT_FILE" ]; then
    echo "--------------------------------------------------------"
    echo "Wrapping data and saving final output to ${OUTPUT_FILE}"

    # Use 'jq -s' to "slurp" all objects in the temporary file into a single array
    # and then wrap that array with the final parent object {"trains": ...}.
    jq -s '{trains: .}' "$TEMP_OUTPUT_FILE" > "$OUTPUT_FILE"

    # Clean up the temporary file
    rm "$TEMP_OUTPUT_FILE"

    echo "Successfully completed processing."
    echo "Output saved to $OUTPUT_FILE"
    
    # Display the first few lines of the output file for verification (optional)
    echo -e "\n--- Start of $OUTPUT_FILE Snippet ---"
    head -n 20 "$OUTPUT_FILE"
    echo "--- End of $OUTPUT_FILE Snippet ---"
else
    echo "--------------------------------------------------------"
    echo "Error: No data was processed. Check file paths and permissions."
fi

return