import argparse
import json
import os
import subprocess

def get_on_lights(ha_url, supervisor_token):
    states_json = subprocess.check_output([
        'curl', '-s', '-X', 'GET',
        '-H', f'Authorization: Bearer {supervisor_token}',
        '-H', 'Content-Type: application/json',
        ha_url + '/states'
    ]).decode('utf-8')

    on_ids = [entity['entity_id'].split('_')[-1] for entity in json.loads(states_json) 
               if entity['entity_id'].startswith("light.esp_train_tracker_") and entity['state'] == "on"]
    
    return ' '.join(on_ids)

def set_light_color(ha_url, supervisor_token, sta_id, color_rgb, brightness):
    safe_brightness = min(max(int(brightness), 1), 100)
    R, G, B = map(int, color_rgb.split(','))

    DATA = {
        "entity_id": f"light.esp_train_tracker_{sta_id}",
        "rgb_color": [R, G, B],
        "brightness_pct": safe_brightness
    }

    subprocess.run([
        'curl', '-s', '-X', 'POST',
        '-H', f'Authorization: Bearer {supervisor_token}',
        '-H', 'Content-Type: application/json',
        '-d', json.dumps(DATA),
        ha_url + '/services/light/turn_on'
    ], stdout=subprocess.DEVNULL)

def turn_off_light(ha_url, supervisor_token, sta_id):
    DATA = {
        "entity_id": f"light.esp_train_tracker_{sta_id}"
    }

    subprocess.run([
        'curl', '-s', '-X', 'POST',
        '-H', f'Authorization: Bearer {supervisor_token}',
        '-H', 'Content-Type: application/json',
        '-d', json.dumps(DATA),
        ha_url + '/services/light/turn_off'
    ], stdout=subprocess.DEVNULL)

def main():
    parser = argparse.ArgumentParser(description="Control lights based on train data.")
    parser.add_argument('--station-list', required=True, help='Path to the CTA station list CSV file.')
    parser.add_argument('--input-dir', required=True, help='Directory containing route JSON files.')
    parser.add_argument('--output-file', required=True, help='Output JSON file path.')

    args = parser.parse_args()

    ha_url = os.getenv('HA_URL', 'http://supervisor/core/api')
    supervisor_token = os.getenv('SUPERVISOR_TOKEN')

    if not supervisor_token:
        raise ValueError("SUPERVISOR_TOKEN environment variable is not set.")

    if not os.path.exists(args.output_file):
        raise FileNotFoundError(f"JSON file not found at {args.output_file}")

    PREVIOUSLY_ON_IDS_STRING = get_on_lights(ha_url, supervisor_token)

    with open(args.output_file, 'r') as f:
        data = json.load(f)

    ACTIVE_LIGHT_IDS = []

    for train in data.get('trains', []):
        sta_id = train.get('nextStaId')
        color = train.get('output_color')

        if isinstance(sta_id, int) and 0 <= sta_id <= 255:
            set_light_color(ha_url, supervisor_token, str(sta_id), color, os.getenv('BRIGHTNESS', '100'))
            ACTIVE_LIGHT_IDS.append(str(sta_id))

    ACTIVE_IDS_STRING = ' '.join(ACTIVE_LIGHT_IDS)

    for i in PREVIOUSLY_ON_IDS_STRING.split():
        if i and i not in ACTIVE_IDS_STRING:
            turn_off_light(ha_url, supervisor_token, i)

if __name__ == "__main__":
    main()
