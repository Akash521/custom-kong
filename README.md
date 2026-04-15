@startuml
' Batch Processing - All Signal Types (Radar Pulse, Radar CW, COMINT)
' Title: NMDB Batch Matching Flow

title NMDB Batch Matching Flow - All Signal Types

actor "Third-Party Product" as Client
participant "NMDB API" as API
participant "Batch Manager" as BatchMgr
participant "Async Worker" as Worker
participant "Matching Engine" as Engine
database "NRD Database" as NRD
database "NMDB Database" as NMDB

== 1. Batch Request Received ==

Client -> API: POST /nmdb/match with multiple emitters
note right of Client
    Example Batch Request:
    {
      "signals": [
        {"signal_type": "Radar_Pulse", 
         "frequency": 9200, "pri": 1.3, "pulse_width": 0.5},
        
        {"signal_type": "Radar_CW", 
         "frequency": 9450, "modulation_type": "CW"},
        
        {"signal_type": "COMINT", 
         "frequency": 250, "modulation_type": "FM"}
      ]
    }
end note
activate API

API -> BatchMgr: Create batch job
activate BatchMgr

BatchMgr -> NMDB: Create batch record
activate NMDB
NMDB --> BatchMgr: batch_id
deactivate NMDB

== 2. Create Individual Requests for Each Signal ==

loop For each signal in array
    
    BatchMgr -> NMDB: Create match_request linked to batch
    activate NMDB
    NMDB --> BatchMgr: request_id
    deactivate NMDB
    
    BatchMgr -> NMDB: Store emitter parameters
    activate NMDB
    NMDB --> BatchMgr: stored
    deactivate NMDB
    
    note right of BatchMgr
        Signal Types:
        1. Radar_Pulse
        2. Radar_CW
        3. COMINT
    end note
end

BatchMgr --> API: Return Batch ID
deactivate BatchMgr

API --> Client: 202 Accepted
note right of Client
    Response:
    {
      "batch_id": "BATCH-001",
      "total_signals": 3,
      "status": "processing",
      "status_url": "/batch/BATCH-001/status"
    }
end note
deactivate API

== 3. Async Processing in Background ==

API -> Worker: Trigger async processing for batch_id
activate Worker

Worker -> NMDB: Get all pending requests for this batch
activate NMDB
NMDB --> Worker: List of signals to process
deactivate NMDB

== 4. Process Each Signal Based on Type ==

loop For each signal in batch
    
    Worker -> Worker: Get signal_type from request
    
    alt Signal Type = Radar_Pulse
    
        Worker -> Engine: Process Radar Pulse
        activate Engine
        
        Engine -> Engine: Validate mandatory fields
        note right of Engine
            Mandatory: Frequency, PRI, Pulse Width
        end note
        
        Engine -> NRD: Query To DB
        activate NRD
        NRD --> Engine: Return candidates
        deactivate NRD
        
        loop For each candidate
            Engine -> Engine: Compare Frequency (±5% tolerance)
            Engine -> Engine: Compare PRI (±10% tolerance)
            Engine -> Engine: Compare Pulse Width (±15% tolerance)
            Engine -> Engine: Calculate Score (30%+25%+10% = 65% max)
        end
        
        Engine -> Engine: Filter below 0.20, Rank, Limit
        Engine --> Worker: Radar Pulse results
        deactivate Engine
        
    else Signal Type = Radar_CW
    
        Worker -> Engine: Process Radar CW
        activate Engine
        
        Engine -> Engine: Validate mandatory fields
        note right of Engine
            Mandatory: Frequency only
            Modulation: Optional
        end note
        
        Engine -> NRD: Query To DB
        activate NRD
        NRD --> Engine: Return candidates
        deactivate NRD
        
        loop For each candidate
            Engine -> Engine: Compare Frequency (±5% tolerance)
            
            alt Modulation provided
                Engine -> Engine: Compare Modulation (exact match)
                note right
                    If matches: +40% weight
                    If not: 0% for modulation
                end note
            else No modulation provided
                Engine -> Engine: Skip modulation (no penalty)
            end
        end
        
        Engine -> Engine: Calculate Score
        note right of Engine
            Radar CW Scoring:
            - Frequency: 60% (always checked)
            - Modulation: 40% (only if provided)
            
            Max score = 60% (if no modulation)
            Max score = 100% (if modulation matches)
        end note
        
        Engine -> Engine: Filter below 0.20, Rank, Limit
        Engine --> Worker: Radar CW results
        deactivate Engine
        
    else Signal Type = COMINT
    
        Worker -> Engine: Process COMINT
        activate Engine
        
        Engine -> Engine: Validate mandatory fields
        note right of Engine
            Mandatory: Frequency AND Modulation
            Both must be present
        end note
        
        Engine -> NRD: Query To DB
        activate NRD
        NRD --> Engine: Return candidates
        deactivate NRD
        
        loop For each candidate
            Engine -> Engine: Compare Frequency (±5% tolerance)
            Engine -> Engine: Compare Modulation (exact match)
        end
        
        Engine -> Engine: Calculate Score
        note right of Engine
            COMINT Scoring:
            - Frequency: 50%
            - Modulation: 50%
            
            Max score = 100%
        end note
        
        Engine -> Engine: Filter below 0.20, Rank, Limit
        Engine --> Worker: COMINT results
        deactivate Engine
    end
    
    == 5. Store Results for This Signal ==
    
    Worker -> NMDB: Store match results for this request
    activate NMDB
    NMDB --> Worker: stored
    deactivate NMDB
    
    Worker -> NMDB: Update batch progress (processed_signals +1)
    activate NMDB
    NMDB --> Worker: progress updated
    deactivate NMDB
end

== 6. Batch Complete ==

Worker -> NMDB: Mark batch as completed
activate NMDB
NMDB --> Worker: batch complete
deactivate NMDB

deactivate Worker

== 7. Client Polls for Status ==

Client -> API: GET /batch/BATCH-001/status
activate API

API -> NMDB: Get batch status
activate NMDB
NMDB --> API: Status: completed, 3 of 3 signals done
deactivate NMDB

API --> Client: 200 OK with status
deactivate API

== 8. Client Retrieves Results ==

Client -> API: GET /batch/BATCH-001/results
activate API

API -> NMDB: Get all match results for this batch
activate NMDB
NMDB --> API: Complete results per signal
deactivate NMDB

API --> Client: 200 OK with paginated results
note right of Client
    Response includes per signal:
    
    Signal 1 (Radar_Pulse):
    - Rank, Score 0.65 (Medium)
    - Emitter, Platform, Country, Unit
    
    Signal 2 (Radar_CW):
    - Rank, Score 0.60 (Medium)
    - Emitter, Platform, Country, Unit
    
    Signal 3 (COMINT):
    - Rank, Score 0.95 (High)
    - Emitter, Platform, Country, Unit
end note
deactivate API

@enduml
