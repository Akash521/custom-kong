The purpose of this system is to receive technical parameters from third-party product , compare those parameters against the NRD database, and return a ranked list of matching NRD records with a confidence score.

The flow from request to response is as follows:

third-party product  sends the technical parameters it has collected (frequency, PRI, pulse width, modulation, scan type, etc.)

third-party product  sends a POST request to the NMDB matching API with those parameters.

NMDB receives the request, saves in DB, and begins the matching process
Matching engine queries NRD technical entities (TechRadar, TechTransceiver, TechSeeker, etc.) and compares each one against the incoming parameters
For each NRD emitter, a confidence score is calculated based on how many parameters match and how closely
Results are ranked from highest to lowest confidence score and saved to the DB
API returns the ranked list of matching emitters to the third-party product .
✔️ Questions About What Data We Will Receive
(These determine what fields NMDB must expect in the POST /match request)

Which exact technical parameters will the third-party product  send? — Resolved

Will the data always include frequency range (min/max), or can it be single frequency only? → (For now single string value) — Resolved

Is this a real-time request or batch — one emitter at a time or many? → single or Batch both can happen  — Resolved
Can the third-party product  send multiple detected emitters in one request or only one at a time? → single and multiple both can happen — Resolved



Emitter parameters required and optional

Radar Pulse: PRI level, PW level, and Frequency level — all mandatory
Continuous Wave: Frequency level mandatory; modulation (optional)
COMINT: Frequency and modulation — both mandatory. 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Remaining Questions.
1.What file format will third-party product  provide for batch matching? — Pending
2. Will signals ever be incomplete? → If yes then should we have to perform analysis or not. — Pending
(Example: only frequency present, but no PRI or modulation-)
3. Will the third-party product  send emitter type hint? — Pending
(Radar, Transceiver, Unknown) — this can reduce search space.
4. Does the third-party product  send any additional metadata? — Pending
(Signal ID, timestamp, confidence level, direction of arrival, classification)
answer: responded to this in the last call: "Time, DoA, location - largely irrelevant. One parameter that could have relevance is the region of operation, if we are identifying the specific platform.". Can discuss  again regarding the region
5. What does third-party product  expect NMDB to return? — Pending
(Single match, ranked list, or multiple families? Duplicate of below? 
answer: Perhaps this question is more: "how much data is returned for each match", probably we need a subset of what is available only, to be returned in the list.)
6. How should third-party product  handle multiple possible matches from NMDB? — Pending
(Show top 1, top 3, or all above confidence threshold? 
answer: May need a paginated list, ordered by confidence)
7. Where exactly does third-party product  expect NMDB matching to be triggered? — Pending
(Automatically during tactical analysis, or only when analyst reviews unidentified contacts?)
answer: steps , which involves a manually triggered activity in third-party product 
8.Is there any NRD data we must never return because it is classified or sensitive?   — Pending (For example: some NRD fields like ELNOT, platform installation details, or tactical links may be sensitive — we need confirmation on what cannot be returned
answer: no filtering of NRD data based on classification, assuming everything is same level
9. Configuration: Parameters configurable by user, e.g. thresholds, weights for confidence. Are these configured via e.g. LP or via config files by an Admin?


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

After a match, NMDB can return those values we have available in the NRD schema

Emitter Info: ID, name, classification, function, manufacturer.
Technical Details: mode, waveform, frequency/PRI/PW characteristics, modulation.
Platform: platform class & instance, installation details, platform type, origin country.
Country: origin, affiliation, codes.


✔️ Questions About What Data We Will Match Against
(These determine which NRD fields need to be extracted and compared)

Should we apply tolerance when comparing NRD data? →  
(Confirm: frequency ±5%, PRI ±10%, etc.) - Fuzzy‑matching

2. Should confidence score be calculated by us? Yes — Resolved

NRD Emitter We have
ELINT Emitters (Radar / RF sensing / Guidance)
Radar  →  Mode → Waveform 

Radar Parameters



Polarisation

RadarCode 

ELNOT 

Mode 

Mode Parameters

ModulationType 
ModulationInfo
Multifunction (YES/No)
Phase
EmissionFunction 
ScanType
Waveform 
Waveform



IntrapulseModulation (tech:IntrapulseModulationType) 
FrequencyLevel (tech:FrequencyLevelType) 
PWLevel (tech:PWLevelType)
PRILevel (tech:PRILevelType) 
-------------------------------------------------------------------------------------------------------------------------

Seeker

SeekerType (xs:string) — required
FrequencyRange (common:FrequencyRangeType) — optional
Laser

FunctionCode 
LaserCode
MinWavelength 
MaxWavelength 
StabilityDeviation
StabilityTime
ClockRate 
ParameterLevel
OptronicMode
Sensor

SensorType 
FrequencyRange 
Sensitivity 
PassiveSensor

IR_Band 
ScanType 
ThresholdContrast 
Technology 
COMINT Emitters (Communication radios)
Transceiver

MinBandwidth
MaxBandwidth 
MinBaudRate 
MaxBaudRate 
MinFrequency
MaxFrequency 
MinPower
MaxPower 
TransmissionMode
ModulationAnalogue 
ModulationDigital
