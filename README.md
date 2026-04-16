@startuml
' Single Emitter Matching - Radar Pulse Only
' Title: NMDB Single Emitter Matching Flow

title NMDB Single Emitter Matching Flow - Radar Pulse 

actor "Trident" as Client
participant "NMDB API" as API
participant "Request Validator" as Validator
participant "Matching Engine" as Engine
database "NRD Database" as NRD
database "NMDB Database" as NMDB

== 1. Request Reception ==

Client -> API: POST /nmdb/match with single emitter parameters
note right of Client
    Example Request (Radar Pulse):
    {
      "signal_type": "Radar_Pulse"
      "frequency": 9200,
      "pri": 1.3,
      "pulse_width": 0.5
    }
end note


API -> Validator: Validate request
activate Validator

Validator -> Validator: Check mandatory fields for Radar Pulse
note right of Validator
    Mandatory fields for Radar Pulse:
    - Frequency ✓
    - PRI ✓
    - Pulse Width ✓
end note

alt Missing Mandatory Fields
    Validator --> API: Validation Error
    API --> Client: 400 Bad Request
    deactivate Validator
    deactivate API
    
else Valid Pass
    Validator --> API: Valid
    deactivate Validator
    
    API -> NMDB: Store emitter parameters
    activate NMDB
    NMDB --> API: stored
    deactivate NMDB
    
    API -> Engine: process_match(request_id, params)
    activate Engine
end

== 2. Find Candidates in NRD ==

Engine -> Engine: Identify signal type (Radar_Pulse)


Engine -> NRD: Query by Range Overlap + Mode + Waveform (GiST indexed)
activate NRD
note right of NRD
    NRD uses PostgreSQL GiST indexes for efficient range matching:
    - frequency_range && :request_frequency_range
    - pri_range       && :request_pri_range
    - pw_range        && :request_pw_range
end note
NRD --> Engine: Candidate emitters (via GiST index scan)
deactivate NRD


== 3. Compare Each Mandatory Field with Tolerance ==

loop For each NRD candidate
    
    Engine -> Engine: Compare Frequency
    note right of Engine
        Request: 9200 MHz (single)
        NRD: 9100 - 9400 MHz (range)
        Tolerance: ±5%
        
        Request range = 9200 ±5% = 8740 to 9660 MHz
        NRD range = 9100 to 9400 MHz
        Overlap? YES
        
        Result: MATCH ✓ (Weight: 50%)
    end note
    
    Engine -> Engine: Compare PRI
    note right of Engine
        Request: 1.3 us (single)
        NRD: 1.1 - 1.4 us (range)
        Tolerance: ±10%
        
        Request range = 1.3 ±10% = 1.17 to 1.43 us
        NRD range = 1.1 to 1.4 us
        Overlap? YES
        
        Result: MATCH ✓ (Weight: 35%)
    end note
    
    Engine -> Engine: Compare Pulse Width
    note right of Engine
        Request: 0.5 us (single)
        NRD: 0.4 - 0.6 us (range)
        Tolerance: ±15%
        
        Request range = 0.5 ±15% = 0.425 to 0.575 us
        NRD range = 0.4 to 0.6 us
        Overlap? YES
        
        Result: MATCH ✓ (Weight: 15%)
    end note
end

== 4. Calculate Confidence Score ==

Engine -> Engine: Calculate Weighted Score
note right of Engine
    CONFIDENCE SCORE CALCULATION:
    
    For Radar Pulse (Mandatory fields only):
    
    - Frequency:   50%  ✓  → 0.50
    - PRI:         35%  ✓  → 0.35
    - Pulse Width: 15%  ✓  → 0.15
    
    Total weights = 100%
    
    CONFIDENCE SCORE = 0.50 + 0.35 + 0.15 = 1.00
end note

Engine -> Engine: Assign Confidence Label
note right of Engine
    CONFIDENCE LABEL:
    
    Score 1.00 is between 0.80 and 1.00
    Label = "High"
    
    Ranges:
    - High:   0.80 to 1.00
    - Medium: 0.50 to 0.79
    - Low:    0.20 to 0.49
    - No Match: below 0.20
end note

== 5. Filter & Rank Results ==

Engine -> Engine: Filter candidates below 0.20 threshold

Engine -> Engine: Sort by confidence score descending

Engine -> Engine: Assign rank (1 = highest score)

note right of Engine
    Rank 1: Score 1.00 (High)
    Rank 2: Score 0.55 (Medium)
    Rank 3: Score 0.30 (Low)
end note

Engine -> Engine: Limit to max_results (default = 50)

== 6. Gather Complete Emitter Data from NRD ==

loop For each matched candidate
    
    Engine -> NRD: Get EMITTER basic info
    activate NRD
    NRD --> Engine: ID, Name, Type, Classification, Function, Manufacturer
    deactivate NRD
    
    Engine -> NRD: Get TECHNICAL details
    activate NRD
    NRD --> Engine: Frequency range, PRI range, PW range
    deactivate NRD
    
end

== 7. Build Complete Response Object ==

loop For each matched candidate
    Engine -> Engine: Assemble complete response
    note right
        Response contains:
        
        1. MATCH METADATA
           - Rank: 1
           - Confidence Score: 1.00
           - Confidence Label: "High"
        
        2. EMITTER INFO
           - ID, Name, Type
        
        3. TECHNICAL DETAILS
           - Frequency: 9100-9400 MHz
           - PRI: 1.1-1.4 us
           - Pulse Width: 0.4-0.6 us
        
    end note
    
    Engine -> NMDB: Store complete match result
    activate NMDB
    NMDB --> Engine: stored
    deactivate NMDB
end

Engine -> NMDB: Update match_request status to completed
activate NMDB
NMDB --> Engine: updated
deactivate NMDB

Engine --> API: Complete results with scores and all data
deactivate Engine

== 8. Return Complete Response to Client ==

API --> Client: 200 OK with ranked results
note right of Client
    Response includes for each match:
    - Rank & Confidence Score & Label
    - Emitter Info
end note
deactivate API

@enduml
