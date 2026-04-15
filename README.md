@startuml
' Batch Processing Sequence Diagram
' Title: NMDB Batch Matching Flow

title NMDB Batch Matching Flow - Sequence Diagram

actor "Third-Party\nProduct" as Client
participant "NMDB\nAPI" as API
participant "Batch\nManager" as BatchMgr
participant "Matching\nEngine" as Engine
database "NRD\n(Read-Only)" as NRD
database "NMDB\n(Tables)" as NMDB
participant "Async\nWorker" as Worker

== Batch Request Reception ==

Client -> API: POST /nmdb/match\n{signals: [ emitter1, emitter2, ... ]}
activate API

API -> BatchMgr: create_batch_job(signals)
activate BatchMgr

BatchMgr -> NMDB: INSERT INTO batch_request\n(status='pending', total_signals=N)
activate NMDB
NMDB --> BatchMgr: batch_id
deactivate NMDB

loop For each signal in array
    BatchMgr -> NMDB: INSERT INTO match_request\n(batch_id, status='pending')
    activate NMDB
    NMDB --> BatchMgr: request_id
    deactivate NMDB
    
    BatchMgr -> NMDB: INSERT INTO emitter_signal\n(request_id, parameters)
    activate NMDB
    NMDB --> BatchMgr: stored
    deactivate NMDB
end

BatchMgr -> NMDB: UPDATE batch_request\nSET status='processing'
activate NMDB
NMDB --> BatchMgr: updated
deactivate NMDB

BatchMgr --> API: batch_id
deactivate BatchMgr

API --> Client: 202 Accepted\n{\n  "batch_id": "BATCH-001",\n  "total_signals": 150,\n  "status": "processing",\n  "status_url": "/batch/BATCH-001/status"\n}
deactivate API

== Asynchronous Processing ==

API -> Worker: trigger_async_processing(batch_id)
activate Worker

Worker -> NMDB: SELECT * FROM match_request\nWHERE batch_id = 'BATCH-001'\nAND status = 'pending'
activate NMDB
NMDB --> Worker: list of pending requests
deactivate NMDB

loop For each pending request
    Worker -> Worker: Load emitter parameters
    
    Worker -> NRD: SELECT FROM tech_radar\nJOIN tech_mode\nJOIN tech_waveform
    activate NRD
    NRD --> Worker: Radar candidates
    deactivate NRD
    
    Worker -> NRD: SELECT FROM tech_transceiver
    activate NRD
    NRD --> Worker: Transceiver candidates
    deactivate NRD
    
    Worker -> Engine: process_match(request_id, params)
    activate Engine
    
    Engine -> Engine: Compare with tolerance
    Engine -> Engine: Calculate weighted score
    
    loop For each matched result
        Engine -> NMDB: INSERT INTO match_result
        activate NMDB
        NMDB --> Engine: stored
        deactivate NMDB
    end
    
    Engine -> NMDB: UPDATE match_request\nSET status='completed',\n total_results=N
    activate NMDB
    NMDB --> Engine: updated
    deactivate NMDB
    
    Engine --> Worker: completed
    deactivate Engine
    
    Worker -> NMDB: UPDATE batch_request\nSET processed_signals = processed_signals + 1
    activate NMDB
    NMDB --> Worker: updated
    deactivate NMDB
end

Worker -> NMDB: UPDATE batch_request\nSET status='completed',\n completed_at=NOW()
activate NMDB
NMDB --> Worker: updated
deactivate NMDB

Worker --> Worker: Batch processing complete
deactivate Worker

== Status Polling (Later) ==

Client -> API: GET /batch/BATCH-001/status
activate API

API -> NMDB: SELECT * FROM batch_request\nWHERE id = 'BATCH-001'
activate NMDB
NMDB --> API: batch status
deactivate NMDB

API --> Client: 200 OK\n{\n  "batch_id": "BATCH-001",\n  "status": "completed",\n  "processed_signals": 150,\n  "percent_complete": 100\n}
deactivate API

== Results Retrieval (Later) ==

Client -> API: GET /batch/BATCH-001/results?page=1
activate API

API -> NMDB: SELECT * FROM match_request\nWHERE batch_id = 'BATCH-001'
activate NMDB
NMDB --> API: list of request_ids
deactivate NMDB

loop For each request_id
    API -> NMDB: SELECT * FROM match_result\nWHERE request_id = ?
    activate NMDB
    NMDB --> API: results for request
    deactivate NMDB
end

API --> Client: 200 OK\n{\n  "batch_id": "BATCH-001",\n  "results": [\n    {request_id: "REQ-001", best_match: {...}},\n    {request_id: "REQ-002", best_match: {...}}\n  ]\n}
deactivate API

@enduml
