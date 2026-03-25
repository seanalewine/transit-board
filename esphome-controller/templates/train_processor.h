// Train data processing for CTA train tracker
// This file is included via the esphome includes directive

#include "station_map.h"
#include <map>
#include <string>
#include <cstdio>
#include <cstring>
#include <vector>
#include <queue>
#include <set>

using namespace esphome;
using namespace esphome::light;

static const int NUM_LEDS = 320;
static const int TICK_INTERVAL_MS = 200;

struct RGBColor {
    float r;
    float g;
    float b;
};

struct TrainTransition {
    int from_led;    // -1 if no LED to turn off (new train)
    int to_led;      // -1 if no LED to turn on (departed train)
    uint8_t r;
    uint8_t g;
    uint8_t b;
    std::string rn;  // run number for logging
};

static std::map<std::string, int> previous_trains;
static std::map<std::string, int> pending_trains;
static std::map<std::string, std::string> pending_train_lines;
static std::queue<TrainTransition> gradual_queue;
static std::map<int, RGBColor> current_led_colors;
static bool light_initialized = false;
static bool pending_mode_change = false;

static const char* TAG = "train";

uint8_t to_byte(float f) { return (uint8_t)(f * 255); }

uint8_t apply_brightness(uint8_t value) {
    float brightness = id(global_brightness).state / 100.0f;
    return (uint8_t)(value * brightness);
}

void update_all_led_brightness() {
    if (!light_initialized || current_led_colors.empty()) {
        return;
    }
    auto light = static_cast<AddressableLight*>(id(stop_indicators).get_output());
    if (light == nullptr) {
        return;
    }
    for (auto& pair : current_led_colors) {
        int led = pair.first;
        RGBColor color = pair.second;
        light->get(led).set(Color(apply_brightness(to_byte(color.r)), 
                                   apply_brightness(to_byte(color.g)), 
                                   apply_brightness(to_byte(color.b))));
    }
    light->schedule_show();
}



RGBColor get_line_color(const std::string& line) {
    if (line == "red")       return {198/255.0f,  12/255.0f,  48/255.0f};
    if (line == "blue")      return {  0/255.0f, 161/255.0f, 222/255.0f};
    if (line == "brn")       return {150/255.0f,  75/255.0f,   0/255.0f};
    if (line == "g")         return {  0/255.0f, 155/255.0f,  58/255.0f};
    if (line == "org")       return {255/255.0f, 146/255.0f,  25/255.0f};
    if (line == "p")         return { 82/255.0f,  35/255.0f, 152/255.0f};
    if (line == "pink")      return {226/255.0f, 126/255.0f, 166/255.0f};
    if (line == "y")         return {249/255.0f, 227/255.0f,   0/255.0f};
    return {0.0f, 0.0f, 0.0f};
}

void clear_gradual_queue() {
    gradual_queue = std::queue<TrainTransition>();
}

void activate_bypass_mode();

void process_pending_mode_change() {
    if (!pending_mode_change) {
        return;
    }
    pending_mode_change = false;
    clear_gradual_queue();
    id(gradual_queue_size) = 0;
    if (id(update_mode).current_option() == "Bypass") {
        activate_bypass_mode();
    } else {
        id(fetch_all_routes).execute();
    }
}

void apply_transitions_immediately(const std::vector<TrainTransition>& departures,
                                   const std::vector<TrainTransition>& transitions) {
    auto light = static_cast<AddressableLight*>(id(stop_indicators).get_output());
    light_initialized = true;
    for (auto& dep : departures) {
        if (dep.from_led >= 0) {
            light->get(dep.from_led).set(Color(0, 0, 0));
            current_led_colors.erase(dep.from_led);
        }
    }
    for (auto& t : transitions) {
        if (t.from_led >= 0) {
            light->get(t.from_led).set(Color(0, 0, 0));
            current_led_colors.erase(t.from_led);
        }
        if (t.to_led >= 0) {
            light->get(t.to_led).set(Color(apply_brightness(t.r), apply_brightness(t.g), apply_brightness(t.b)));
            current_led_colors[t.to_led] = {t.r / 255.0f, t.g / 255.0f, t.b / 255.0f};
        }
    }
    light->schedule_show();
}

void activate_bypass_mode() {
    previous_trains.clear();
    current_led_colors.clear();
    auto light = static_cast<AddressableLight*>(id(stop_indicators).get_output());
    light_initialized = true;
    for (int i = 0; i < NUM_LEDS; i++) {
        light->get(i).set(Color(0, 0, 0));
    }
    for (int i = 0; i < STATION_MAP_SIZE; i++) {
        int led = STATION_MAP[i].unifiedId;
        if (led >= 0 && led < NUM_LEDS) {
            RGBColor color = get_line_color(STATION_MAP[i].line);
            light->get(led).set(Color(apply_brightness(to_byte(color.r)), apply_brightness(to_byte(color.g)), apply_brightness(to_byte(color.b))));
            current_led_colors[led] = color;
        }
    }
    light->schedule_show();
}

void process_gradual_update() {
    if (gradual_queue.empty()) {
        return;
    }

    auto light = static_cast<AddressableLight*>(id(stop_indicators).get_output());
    light_initialized = true;
    TrainTransition t = gradual_queue.front();
    gradual_queue.pop();

    if (t.from_led >= 0) {
        light->get(t.from_led).set(Color(0, 0, 0));
        current_led_colors.erase(t.from_led);
    }
    if (t.to_led >= 0) {
        light->get(t.to_led).set(Color(apply_brightness(t.r), apply_brightness(t.g), apply_brightness(t.b)));
        current_led_colors[t.to_led] = {t.r / 255.0f, t.g / 255.0f, t.b / 255.0f};
    }
    light->schedule_show();

    ESP_LOGD(TAG, "Gradual transition rn=%s: off %d -> on %d (%d remaining)",
             t.rn.c_str(), t.from_led, t.to_led, gradual_queue.size());
}

void process_json_body(const std::string& body, const std::string& line) {
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, body);

    if (error) {
        ESP_LOGE(TAG, "JSON error %s: %s", line.c_str(), error.c_str());
        return;
    }

    JsonObject root = doc.as<JsonObject>();
    if (!root["ctatt"].is<JsonObject>()) {
        ESP_LOGW(TAG, "Missing ctatt %s", line.c_str());
        return;
    }

    JsonObject ctatt = root["ctatt"];
    if (!ctatt["route"].is<JsonArray>()) {
        return;
    }

    JsonArray routes = ctatt["route"];
    if (routes.isNull() || routes.size() == 0) {
        return;
    }

    JsonObject route = routes[0];
    if (!route["train"].is<JsonArray>()) {
        return;
    }

    JsonArray trains = route["train"];
    if (trains.isNull()) {
        return;
    }

    bool is_bidirectional = id(bidirectional).state;
    int max_trains_per_line = id(trains_per_line).state;

    struct TrainInfo {
        std::string rn;
        int unifiedId;
        int direction;
    };

    std::vector<TrainInfo> filtered_trains;

    for (JsonObject train : trains) {
        if (!train["rn"] || !train["nextStaId"]) {
            continue;
        }

        const char* rn_str = train["rn"];
        if (!rn_str || strlen(rn_str) == 0) {
            continue;
        }

        int direction = train["trDr"].as<int>();
        if (!is_bidirectional && direction != 1) {
            continue;
        }

        int nextStaId = train["nextStaId"].as<int>();
        int unifiedId = lookup_unified_id(nextStaId, line);
        if (unifiedId < 0) {
            continue;
        }

        filtered_trains.push_back({std::string(rn_str), unifiedId, direction});

        if (max_trains_per_line > 0 && (int)filtered_trains.size() >= max_trains_per_line) {
            break;
        }
    }

    for (auto& t : filtered_trains) {
        pending_trains[t.rn] = t.unifiedId;
        pending_train_lines[t.rn] = line;
    }
}

static std::string cached_arrivals = "No station selected";

void update_station_options(const std::string& display_line) {
    static std::vector<std::string> stored_options;
    static esphome::FixedVector<const char*> option_ptrs;

    std::string line = get_line_code(display_line);
    if (line.empty()) {
        stored_options = {"Select a line"};
        option_ptrs.init(1);
        option_ptrs.clear();
        option_ptrs.push_back(stored_options[0].c_str());
        id(arrivals_station).traits.set_options(option_ptrs);
        id(arrivals_station).publish_state("Select a line");
        return;
    }
    auto stations = get_station_names_for_line(line);
    if (stations.empty()) {
        stored_options = {"No stations found"};
        option_ptrs.init(1);
        option_ptrs.clear();
        option_ptrs.push_back(stored_options[0].c_str());
        id(arrivals_station).traits.set_options(option_ptrs);
        id(arrivals_station).publish_state("No stations found");
    } else {
        stored_options = stations;
        option_ptrs.init(stations.size());
        option_ptrs.clear();
        for (auto &s : stored_options) {
            option_ptrs.push_back(s.c_str());
        }
        id(arrivals_station).traits.set_options(option_ptrs);
        id(arrivals_station).publish_state(stations[0]);
        int mapid = get_mapid_from_station_str(stations[0]);
        if (mapid > 0) {
            id(arrivals_mapid) = mapid;
        }
    }
}

void process_arrivals_response(const std::string& body) {
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, body);

    if (error) {
        ESP_LOGE("arrivals", "JSON parse error: %s", error.c_str());
        cached_arrivals = "API error";
        id(next_arrivals).publish_state(cached_arrivals);
        return;
    }

    if (!doc["ctatt"].is<JsonObject>()) {
        cached_arrivals = "No arrivals data";
        id(next_arrivals).publish_state(cached_arrivals);
        return;
    }

    JsonObject ctatt = doc["ctatt"];
    if (!ctatt["eta"].is<JsonArray>()) {
        cached_arrivals = "No arrivals available";
        id(next_arrivals).publish_state(cached_arrivals);
        return;
    }

    JsonArray etas = ctatt["eta"];
    if (etas.isNull() || etas.size() == 0) {
        cached_arrivals = "No arrivals available";
        id(next_arrivals).publish_state(cached_arrivals);
        return;
    }

    std::string result;
    int count = 0;

    for (JsonObject eta : etas) {
        if (count >= 3) break;

        const char* arrT = eta["arrT"] | "";
        const char* destNm = eta["destNm"] | "";
        const char* rt = eta["rt"] | "";
        const char* isApp = eta["isApp"] | "0";
        const char* isSch = eta["isSch"] | "0";
        const char* isDly = eta["isDly"] | "0";

        if (strlen(arrT) < 16) continue;

        int arr_hour = std::stoi(std::string(arrT).substr(11, 2));
        int arr_min  = std::stoi(std::string(arrT).substr(14, 2));

        time_t now = ::time(nullptr);
        struct tm* local = ::localtime(&now);
        int now_total = local->tm_hour * 60 + local->tm_min;
        int arr_total = arr_hour * 60 + arr_min;
        int minutes = arr_total - now_total;
        if (minutes < 0) minutes += 1440;

        char line[64];
        if (std::string(isApp) == "1") {
            snprintf(line, sizeof(line), "%s - Approaching", destNm);
        } else if (std::string(isDly) == "1") {
            snprintf(line, sizeof(line), "%s - %d min (Delayed)", destNm, minutes);
        } else if (std::string(isSch) == "1") {
            snprintf(line, sizeof(line), "%s - %d min (Sched)", destNm, minutes);
        } else {
            snprintf(line, sizeof(line), "%s - %d min", destNm, minutes);
        }

        if (!result.empty()) result += "\n";
        result += line;
        count++;
    }

    if (result.empty()) {
        result = "No arrivals available";
    }

    cached_arrivals = result;
    id(next_arrivals).publish_state(cached_arrivals);
}

float calculate_power_draw() {
    float brightness = id(global_brightness).state / 100.0f;
    float total = 0.0f;
    for (auto& pair : current_led_colors) {
        total += (pair.second.r + pair.second.g + pair.second.b) * brightness;
    }
    return total * 20.0f;  // 20mA per channel
}

void process_all_trains() {
    auto light = static_cast<AddressableLight*>(id(stop_indicators).get_output());
    light_initialized = true;

    if (previous_trains.empty()) {
        current_led_colors.clear();
        for (int i = 0; i < NUM_LEDS; i++) {
            light->get(i).set(Color(0, 0, 0));
        }
        light->schedule_show();

        previous_trains = pending_trains;
        id(active_train_count) = previous_trains.size();

        for (auto& t : previous_trains) {
            RGBColor color = get_line_color(pending_train_lines[t.first]);
            light->get(t.second).set(Color(apply_brightness(to_byte(color.r)), apply_brightness(to_byte(color.g)), apply_brightness(to_byte(color.b))));
            current_led_colors[t.second] = color;
        }
        light->schedule_show();

        pending_trains.clear();
        pending_train_lines.clear();
        return;
    }

    bool is_gradual = id(update_mode).current_option() == "Gradual Update";

    std::vector<TrainTransition> departures;
    std::vector<TrainTransition> transitions;

    for (auto& prev : previous_trains) {
        std::string rn = prev.first;
        int old_id = prev.second;

        auto it = pending_trains.find(rn);
        if (it == pending_trains.end()) {
            departures.push_back({old_id, -1, 0, 0, 0, rn});
        } else if (it->second != old_id) {
            RGBColor color = get_line_color(pending_train_lines[rn]);
            transitions.push_back({old_id, it->second, to_byte(color.r), to_byte(color.g), to_byte(color.b), rn});
        }
    }

    for (auto& curr : pending_trains) {
        if (previous_trains.find(curr.first) == previous_trains.end()) {
            RGBColor color = get_line_color(pending_train_lines[curr.first]);
            transitions.push_back({-1, curr.second, to_byte(color.r), to_byte(color.g), to_byte(color.b), curr.first});
        }
    }

    std::set<int> leds_turning_on;
    for (auto& t : transitions) {
        if (t.to_led >= 0) {
            leds_turning_on.insert(t.to_led);
        }
    }

    std::vector<TrainTransition> filtered_departures;
    for (auto& dep : departures) {
        if (leds_turning_on.find(dep.from_led) == leds_turning_on.end()) {
            filtered_departures.push_back(dep);
        }
    }

    id(active_train_count) = pending_trains.size();
    int total_changes = filtered_departures.size() + transitions.size();

    if (total_changes == 0) {
        // No changes
    } else if (is_gradual) {
        for (auto& dep : filtered_departures) {
            gradual_queue.push(dep);
        }
        for (auto& t : transitions) {
            gradual_queue.push(t);
        }

        int queue_size = gradual_queue.size();
        int refresh_ms = id(refresh_interval).state * 1000;
        int available_ms = refresh_ms - 200;
        if (available_ms < 200) available_ms = 200;
        int interval_ms = available_ms / queue_size;
        if (interval_ms < 100) interval_ms = 100;
        if (interval_ms > 2000) interval_ms = 2000;
        id(gradual_tick_interval) = interval_ms / TICK_INTERVAL_MS;
        if (id(gradual_tick_interval) < 1) id(gradual_tick_interval) = 1;
        id(gradual_tick_count) = 0;
        id(gradual_queue_size) = queue_size;
    } else {
        apply_transitions_immediately(filtered_departures, transitions);
    }

    previous_trains = pending_trains;
    pending_trains.clear();
    pending_train_lines.clear();
}
