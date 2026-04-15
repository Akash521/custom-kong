@startuml
' Single Emitter Matching Sequence Diagram
' Title: NMDB Single Emitter Matching Flow

title NMDB Single Emitter Matching Flow - Sequence Diagram

actor "Third-Party\nProduct" as Client
participant "NMDB\nAPI" as API
participant "Request\nValidator" as Validator
participant "Matching\nEngine" as Engine
database "NRD\n(Read-Only)" as NRD
database "NMDB\n(Tables)" as NMDB

== Request Reception ==

Client -> API: POST /nmdb/match\n{single emitter parameters}
activate API

API -> NMDB: INSERT INTO match_request\n(status = 'pending')
activate NMDB
NMDB --> API: request_id
deactivate NMDB

API -> Validator: Validate request
activate Validator

Validator -> Validator: Check mandatory fields\nbased on signal type

alt Missing Mandatory Fields
    Validator --> API: Validation Error
    API --> Client: 400 Bad Request\n{error: "missing fields"}
    deactivate Validator
    deactivate API
else Valid Pass
    Validator --> API: Valid
    deactivate Validator
    
    API -> NMDB: INSERT INTO emitter_signal\n(request_id, parameters)
    activate NMDB
    NMDB --> API: stored
    deactivate NMDB
    
    API -> Engine: process_match(request_id, params)
    activate Engine
end

== NRD Query ==

Engine -> Engine: Identify signal type\n(Radar_Pulse / CW / COMINT)

Engine -> NRD: SELECT FROM tech_radar\nJOIN tech_mode\nJOIN tech_waveform
activate NRD
NRD --> Engine: List of Radar candidates
deactivate NRD

Engine -> NRD: SELECT FROM tech_transceiver
activate NRD
NRD --> Engine: List of Transceiver candidates
deactivate NRD

Engine -> NRD: SELECT FROM tech_seeker
activate NRD
NRD --> Engine: List of Seeker candidates
deactivate NRD

== Comparison & Scoring ==

loop For each NRD candidate
    Engine -> Engine: Compare frequency\nwith ±5% tolerance
    Engine -> Engine: Compare PRI\nwith ±10% tolerance
    Engine -> Engine: Compare pulse width\nwith ±15% tolerance
    Engine -> Engine: Compare modulation\n(exact match)
    Engine -> Engine: Compare scan type\n(exact match)
    Engine -> Engine: Calculate weighted score
    note right
        Weights by signal type:
        - Frequency: 30%
        - PRI: 25%
        - PW: 10%
        - Modulation: 20%
        - Others: 15%
    end note
end

== Filter & Rank ==

Engine -> Engine: Filter below threshold\n(min_confidence = 0.20)

Engine -> Engine: Sort by score descending\nAssign rank (1, 2, 3...)

Engine -> Engine: Limit to max_results\n(default = 50)

== Store Results ==

loop For each matched result
    Engine -> NMDB: INSERT INTO match_result\n(request_id, rank, score,\n matched_fields, returned_data)
    activate NMDB
    NMDB --> Engine: stored
    deactivate NMDB
end

Engine -> NMDB: UPDATE match_request\nSET status='completed',\n total_results=N, completed_at=NOW()
activate NMDB
NMDB --> Engine: updated
deactivate NMDB

Engine --> API: results[]
deactivate Engine

== Response ==

API --> Client: 200 OK\n{\n  "request_id": "REQ-001",\n  "results": [\n    {rank:1, score:0.92, ...},\n    {rank:2, score:0.61, ...}\n  ]\n}
deactivate API

@enduml
