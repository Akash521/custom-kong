
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    SINGLE vs BATCH PROCESSING - COMPARISON                          │
├─────────────────────────────────┬───────────────────────────────────────────────────┤
│      SINGLE EMITTER             │              BATCH PROCESSING                     │
├─────────────────────────────────┼───────────────────────────────────────────────────┤
│                                 │                                                   │
│  INPUT                          │  INPUT                                            │
│  ┌─────────────┐                │  ┌─────────────────────────────┐                  │
│  │ 1 Emitter   │                │  │ Multiple Emitters (N)       │                  │
│  │ Parameters  │                │  │ ┌─────┐ ┌─────┐ ┌─────┐     │                  │
│  └──────┬──────┘                │  │ │ #1  │ │ #2  │ │ #N  │     │                  │
│         │                        │  │ └──┬──┘ └──┬──┘ └──┬──┘     │                  │
│         ▼                        │  └────┼──────┼───────┼─────────┘                  │
│                                 │       │      │       │                            │
│  PROCESSING                     │       ▼      ▼       ▼                            │
│  ┌─────────────────────────┐    │  ┌─────────────────────────────────┐              │
│  │ 1. Validate             │    │  │ 1. Create BATCH Record          │              │
│  │ 2. Query NRD            │    │  │ 2. For Each Signal:             │              │
│  │ 3. Compare All          │    │  │    - Create Request Record      │              │
│  │ 4. Calculate Scores     │    │  │    - Run Matching Engine        │              │
│  │ 5. Filter & Rank        │    │  │    - Store Individual Results   │              │
│  │ 6. Store Results        │    │  │ 3. Track Progress               │              │
│  │ 7. Return Response      │    │  │ 4. Update Batch Status          │              │
│  └─────────────────────────┘    │  └─────────────────────────────────┘              │
│                                 │                                                   │
│  RESPONSE                       │  RESPONSE (Immediate)                              │
│  ┌─────────────────────────┐    │  ┌─────────────────────────────┐                  │
│  │ Immediate:              │    │  │ Batch ID + Status URL       │                  │
│  │ Ranked List with        │    │  │ (Async Processing)          │                  │
│  │ Confidence Scores       │    │  └─────────────────────────────┘                  │
│  └─────────────────────────┘    │                                                   │
│                                 │  RESPONSE (Later - Polling)                       │
│  WAIT TIME                      │  ┌─────────────────────────────┐                  │
│  ┌─────────────────────────┐    │  │ GET /batch/{id}/results     │                  │
│  │ Synchronous             │    │  │ Returns:                    │                  │
│  │ < 2 seconds (target)    │    │  │ - All signal results        │                  │
│  └─────────────────────────┘    │  │ - Paginated                 │                  │
│                                 │  │ - Per-request details       │                  │
│                                 │  └─────────────────────────────┘                  │
│                                 │                                                   │
│  BEST FOR                       │  BEST FOR                                         │
│  ┌─────────────────────────┐    │  ┌─────────────────────────────┐                  │
│  │ Real-time tactical      │    │  │ Bulk analysis               │                  │
│  │ Single signal analysis  │    │  │ Historical data processing  │                  │
│  │ Low latency required    │    │  │ Large volume of signals     │                  │
│  └─────────────────────────┘    │  └─────────────────────────────┘                  │
│                                 │                                                   │
└─────────────────────────────────┴───────────────────────────────────────────────────┘
