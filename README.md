@startuml
' Single Emitter Matching - Radar Pulse Only
' Title: NMDB Single Emitter Matching Flow

title NMDB Single Emitter Matching Flow - Radar Pulse (No Modulation)

actor "Third-Party Product" as Client
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
      "frequency": 9200,
      "pri": 1.3,
      "pulse_width": 0.5
    }
end note
activate API

API -> NMDB: Store request
activate NMDB
NMDB --> API: request_id
deactivate NMDB

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

Engine -> NRD: Query TechRadar + Mode + Waveform
activate NRD
NRD --> Engine: List of Radar candidates with technical data
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
        
        Result: MATCH ✓ (Weight: 30%)
    end note
    
    Engine -> Engine: Compare PRI
    note right of Engine
        Request: 1.3 us (single)
        NRD: 1.1 - 1.4 us (range)
        Tolerance: ±10%
        
        Request range = 1.3 ±10% = 1.17 to 1.43 us
        NRD range = 1.1 to 1.4 us
        Overlap? YES
        
        Result: MATCH ✓ (Weight: 25%)
    end note
    
    Engine -> Engine: Compare Pulse Width
    note right of Engine
        Request: 0.5 us (single)
        NRD: 0.4 - 0.6 us (range)
        Tolerance: ±15%
        
        Request range = 0.5 ±15% = 0.425 to 0.575 us
        NRD range = 0.4 to 0.6 us
        Overlap? YES
        
        Result: MATCH ✓ (Weight: 10%)
    end note
end

== 4. Calculate Confidence Score ==

Engine -> Engine: Calculate Weighted Score
note right of Engine
    CONFIDENCE SCORE CALCULATION:
    
    For Radar Pulse (Mandatory fields only):
    
    - Frequency:   30%  ✓  → 0.30
    - PRI:         25%  ✓  → 0.25
    - Pulse Width: 10%  ✓  → 0.10
    
    Total weights = 65%
    
    CONFIDENCE SCORE = 0.30 + 0.25 + 0.10 = 0.65
end note

Engine -> Engine: Assign Confidence Label
note right of Engine
    CONFIDENCE LABEL:
    
    Score 0.65 is between 0.50 and 0.79
    Label = "MEDIUM"
    
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
    Rank 1: Score 0.65 (Medium)
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
    
    Engine -> NRD: Get PLATFORM data
    activate NRD
    NRD --> Engine: Platform Name, Type, Class, Installation Details
    deactivate NRD
    
    Engine -> NRD: Get COUNTRY data
    activate NRD
    NRD --> Engine: Origin Country, Affiliation, Country Codes
    deactivate NRD
    
    Engine -> NRD: Get UNIT data
    activate NRD
    NRD --> Engine: Operating Unit, Unit Type, Parent Command
    deactivate NRD
end

== 7. Build Complete Response Object ==

loop For each matched candidate
    Engine -> Engine: Assemble complete response
    note right
        Response contains:
        
        1. MATCH METADATA
           - Rank: 1
           - Confidence Score: 0.65
           - Confidence Label: "Medium"
        
        2. EMITTER INFO
           - ID, Name, Type
        
        3. TECHNICAL DETAILS
           - Frequency: 9100-9400 MHz
           - PRI: 1.1-1.4 us
           - Pulse Width: 0.4-0.6 us
        
        4. PLATFORM INFO
           - Platform Name, Type
        
        5. COUNTRY INFO
           - Origin Country, Affiliation
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
    - Emitter, Platform, Country, Unit data
end note
deactivate API

@enduml
