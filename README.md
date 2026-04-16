@startuml
' Single Emitter Matching - Radar Pulse Only (Complete)
' Title: NMDB Single Emitter Matching Flow

title NMDB Single Emitter Matching Flow - Radar Pulse (Complete)

actor "Trident" as Client
participant "NMDB API" as API
participant "Request Validator" as Validator
participant "Matching Engine" as Engine
database "NRD Database" as NRD
database "NMDB Database" as NMDB

== 1. Request Reception & Validation ==

Client -> API: POST /nmdb/match with single emitter parameters
note right of Client
    Example Request (Radar Pulse):
    {
      "signal_type": "Radar_Pulse",
      "frequency": 9200,
      "pri": 1.3,
      "pulse_width": 0.5
    }
end note
activate API

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
    
    API -> NMDB: Step 1: Create match_request record (status='pending')
    activate NMDB
    NMDB --> API: request_id
    deactivate NMDB
    
    API -> NMDB: Step 2: Store emitter parameters
    activate NMDB
    NMDB --> API: stored
    deactivate NMDB
    
    API -> Engine: process_match(request_id, params)
    activate Engine
end

== 2. Apply Tolerance to Request Values ==

Engine -> Engine: Step 3: Identify signal type (Radar_Pulse)

Engine -> Engine: Step 4: Apply tolerance to create ranges
note right of Engine
    Frequency: 9200 ±5% = 8740 to 9660 MHz
    PRI: 1.3 ±10% = 1.17 to 1.43 us
    Pulse Width: 0.5 ±15% = 0.425 to 0.575 us
end note

== 3. Find Candidates in NRD (Using GiST Indexes) ==

Engine -> NRD: Step 5: Query by Range Overlap (GiST indexed)
note right of NRD
    NRD uses PostgreSQL GiST indexes:
    - frequency_range && '[8740,9660]'
    - pri_range && '[1.17,1.43]'
    - pw_range && '[0.425,0.575]'
end note
activate NRD

NRD -> NRD: GiST index scan
note right of NRD
    20,000 → 200 → 40 → 15 candidates
    Time: 20-30ms
end note

NRD --> Engine: Step 6: Return candidate emitters (15 rows)
deactivate NRD

== 4. Compare Each Field with Tolerance ==

loop For each NRD candidate (15 times)
    
    Engine -> Engine: Compare Frequency
    note right of Engine
        Request: 8740-9660
        NRD: 9100-9400
        Overlap? YES
        Result: MATCH ✓ (Weight: 50%)
    end note
    
    Engine -> Engine: Compare PRI
    note right of Engine
        Request: 1.17-1.43
        NRD: 1.1-1.4
        Overlap? YES
        Result: MATCH ✓ (Weight: 30%)
    end note
    
    Engine -> Engine: Compare Pulse Width
    note right of Engine
        Request: 0.425-0.575
        NRD: 0.4-0.6
        Overlap? YES
        Result: MATCH ✓ (Weight: 20%)
    end note
end

== 5. Calculate Confidence Score ==

Engine -> Engine: Step 7: Calculate Weighted Score
note right of Engine
    CONFIDENCE SCORE CALCULATION:
    
    - Frequency:   50% ✓ → 0.50
    - PRI:         30% ✓ → 0.30
    - Pulse Width: 20% ✓ → 0.20
    
    TOTAL = 1.00 (100%)
end note

Engine -> Engine: Step 8: Assign Confidence Label
note right of Engine
    Score 1.00 → Label = "HIGH"
    
    Thresholds:
    - HIGH:   0.80 to 1.00
    - MEDIUM: 0.50 to 0.79
    - LOW:    0.20 to 0.49
    - NO MATCH: below 0.20
end note

== 6. Filter, Rank & Handle No Match ==

Engine -> Engine: Step 9: Filter candidates below 0.20 threshold

alt No candidates above threshold
    Engine -> NMDB: Update match_request status='completed' (0 results)
    activate NMDB
    NMDB --> Engine: updated
    deactivate NMDB
    
    Engine --> API: No matches found
    API --> Client: 200 OK with empty results list
    deactivate Engine
    deactivate API
    
else Has candidates
    Engine -> Engine: Step 10: Sort by confidence score descending
    
    Engine -> Engine: Step 11: Assign rank (1 = highest score)
    note right of Engine
        Rank 1: Score 1.00 (HIGH)
        Rank 2: Score 0.55 (MEDIUM)
        Rank 3: Score 0.30 (LOW)
    end note
    
    Engine -> Engine: Step 12: Limit to max_results (default = 50)
    
    == 7. Gather Emitter Data ==
    
    loop For each matched candidate
        Engine -> NRD: Get EMITTER basic info
        activate NRD
        NRD --> Engine: ID, Name, Type, Classification
        deactivate NRD
        
        Engine -> NRD: Get TECHNICAL details
        activate NRD
        NRD --> Engine: Frequency range, PRI range, PW range
        deactivate NRD
    end
    
    == 8. Store Results ==
    
    loop For each matched candidate
        Engine -> NMDB: Store match result
        activate NMDB
        NMDB --> Engine: stored
        deactivate NMDB
    end
    
    Engine -> NMDB: Update match_request status='completed', total_results=N
    activate NMDB
    NMDB --> Engine: updated
    deactivate NMDB
    
    Engine --> API: Complete results with scores
    deactivate Engine
    
    == 9. Return Response ==
    
    API --> Client: 200 OK with ranked results
    note right of Client
        Response:
        {
          "request_id": "REQ-001",
          "results": [
            {
              "rank": 1,
              "name": "SA-6 Straight Flush",
              "confidence_score": 1.00,
              "confidence_label": "HIGH"
            }
          ]
        }
    end note
    deactivate API
end

@enduml
