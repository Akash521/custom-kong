NMDB Matching System - Complete Step-by-Step Explanation for Testing
No Code - Pure Explanation with Examples
Part 1: What We Receive from Trident (3 Types of Emitters)
Emitter Type 1: Radar Pulse
Trident sends these 3 values (ALL mandatory):

Frequency = 9200 MHz

PRI = 1.3 microseconds

Pulse Width = 0.5 microseconds

Emitter Type 2: Radar CW
Trident sends:

Frequency = 9450 MHz (MANDATORY)

Modulation = "CW" (OPTIONAL - may or may not send)

Emitter Type 3: COMINT
Trident sends these 2 values (BOTH mandatory):

Frequency = 250 MHz

Modulation = "FM"

Part 2: What NRD Database Has (20,000 Records)
For Radar Pulse, NRD stores RANGES:
Example Emitter	Frequency Range	PRI Range	PW Range
SA-6 Straight Flush	9100 to 9400 MHz	1.1 to 1.4 us	0.4 to 0.6 us
AN/APG-68	9000 to 9200 MHz	2.0 to 2.5 us	0.8 to 1.2 us
SA-8 Land Roll	9300 to 9500 MHz	0.8 to 1.0 us	0.3 to 0.5 us
For Radar CW, NRD stores:
Example Emitter	Frequency Range	Modulation
Continuous Wave Radar	9400 to 9500 MHz	CW
For COMINT, NRD stores:
Example Emitter	Frequency Range	Modulation
VHF Transceiver	240 to 260 MHz	FM
UHF Radio	400 to 420 MHz	AM
Part 3: Step-by-Step Matching Process
STEP 1: Identify Signal Type
System looks at what Trident sent:

If it has Frequency + PRI + PW → Radar Pulse

If it has Frequency only (or Frequency + Modulation) → Radar CW

If it has Frequency + Modulation → COMINT

STEP 2: Apply Tolerance to Create a Range
Why: Trident sends a single value. NRD has ranges. We need to compare.

For Frequency (always ±5% tolerance):

Trident Value	Calculate Min	Calculate Max	Resulting Range
9200 MHz	9200 - 5% = 8740	9200 + 5% = 9660	8740 to 9660 MHz
For PRI (only for Radar Pulse, ±10% tolerance):

Trident Value	Calculate Min	Calculate Max	Resulting Range
1.3 us	1.3 - 10% = 1.17	1.3 + 10% = 1.43	1.17 to 1.43 us
For Pulse Width (only for Radar Pulse, ±15% tolerance):

Trident Value	Calculate Min	Calculate Max	Resulting Range
0.5 us	0.5 - 15% = 0.425	0.5 + 15% = 0.575	0.425 to 0.575 us
STEP 3: Database Uses Indexes to Find Candidates
Without Index (BAD):

Database reads all 20,000 records one by one

Takes 2-5 seconds

With GiST Index (GOOD):

Database jumps directly to records that might match

Takes 10-30 milliseconds

How Index Helps:

Frequency index: Finds all emitters with frequency range overlapping 8740-9660

Result: 20,000 → 200 candidates (10ms)

PRI index: From those 200, finds emitters with PRI overlapping 1.17-1.43

Result: 200 → 40 candidates (5ms)

PW index: From those 40, finds emitters with PW overlapping 0.425-0.575

Result: 40 → 15 candidates (5ms)

STEP 4: Check Overlap for Each Candidate
Question: Does Trident's range overlap with NRD's range?

Example for SA-6 Straight Flush:

Parameter	Trident Range (after tolerance)	NRD Range	Overlap?
Frequency	8740 to 9660	9100 to 9400	YES (9100-9400 inside)
PRI	1.17 to 1.43	1.1 to 1.4	YES (1.17-1.4 overlaps)
PW	0.425 to 0.575	0.4 to 0.6	YES (0.425-0.575 inside)
Result: ALL THREE overlap → MATCH

Example for AN/APG-68:

Parameter	Trident Range	NRD Range	Overlap?
Frequency	8740 to 9660	9000 to 9200	YES (9000-9200 inside)
PRI	1.17 to 1.43	2.0 to 2.5	NO (1.43 < 2.0)
PW	0.425 to 0.575	0.8 to 1.2	NO (0.575 < 0.8)
Result: Only Frequency matches

STEP 5: Calculate Confidence Score
For Radar Pulse (weights: Frequency 50%, PRI 30%, PW 20%):

SA-6 Straight Flush:

Frequency matches → add 50%

PRI matches → add 30%

PW matches → add 20%

TOTAL = 100%

AN/APG-68:

Frequency matches → add 50%

PRI does NOT match → add 0%

PW does NOT match → add 0%

TOTAL = 50%

STEP 6: Assign Confidence Label
Score Range	Label	Meaning
80% to 100%	HIGH	Strong match
50% to 79%	MEDIUM	Partial match
20% to 49%	LOW	Weak match
Below 20%	NO MATCH	Not returned
SA-6 Straight Flush: 100% → HIGH
AN/APG-68: 50% → MEDIUM

STEP 7: Rank and Return Results
Rank 1: SA-6 Straight Flush (100% - HIGH)
Rank 2: AN/APG-68 (50% - MEDIUM)

Part 4: Complete Example 1 - Radar Pulse
What Trident Sends:
text
Signal Type: Radar Pulse
Frequency: 9200 MHz
PRI: 1.3 us
Pulse Width: 0.5 us
What System Does:
Step 1: Identify as Radar Pulse

Step 2: Apply tolerances

Frequency: 9200 ±5% = 8740 to 9660 MHz

PRI: 1.3 ±10% = 1.17 to 1.43 us

PW: 0.5 ±15% = 0.425 to 0.575 us

Step 3: Database uses indexes to find candidates

Frequency index: 20,000 → 200 candidates

PRI index: 200 → 40 candidates

PW index: 40 → 15 candidates

Step 4: Check overlap for each candidate

Candidate 1: SA-6 Straight Flush

Frequency: 8740-9660 vs 9100-9400 → OVERLAP YES

PRI: 1.17-1.43 vs 1.1-1.4 → OVERLAP YES

PW: 0.425-0.575 vs 0.4-0.6 → OVERLAP YES

Score = 50% + 30% + 20% = 100% → HIGH

Candidate 2: AN/APG-68

Frequency: 8740-9660 vs 9000-9200 → OVERLAP YES

PRI: 1.17-1.43 vs 2.0-2.5 → OVERLAP NO

PW: 0.425-0.575 vs 0.8-1.2 → OVERLAP NO

Score = 50% + 0% + 0% = 50% → MEDIUM

Step 5: Rank results

Rank 1: SA-6 Straight Flush (100% - HIGH)

Rank 2: AN/APG-68 (50% - MEDIUM)

Step 6: Return to Trident with platform, country, unit data

What Trident Receives:
text
Request ID: REQ-001
Total Results: 2

Result 1:
  Rank: 1
  Emitter: SA-6 Straight Flush
  Country: Russia
  Platform: 2K12 Kub
  Confidence: 100% - HIGH
  Matched Fields: Frequency, PRI, Pulse Width

Result 2:
  Rank: 2
  Emitter: AN/APG-68
  Country: USA
  Platform: F-16
  Confidence: 50% - MEDIUM
  Matched Fields: Frequency only
Part 5: Complete Example 2 - Radar CW (With Modulation)
What Trident Sends:
text
Signal Type: Radar CW
Frequency: 9450 MHz
Modulation: CW
What System Does:
Step 1: Identify as Radar CW

Step 2: Apply tolerance to frequency

Frequency: 9450 ±5% = 8978 to 9922 MHz

Step 3: Database uses index

Frequency index: 20,000 → 1 candidate

Step 4: Check overlap

Candidate: Continuous Wave Radar

Frequency: 8978-9922 vs 9400-9500 → OVERLAP YES

Modulation: "CW" vs "CW" → MATCH YES

Step 5: Calculate score

Frequency (60% weight) → 60%

Modulation (40% weight) → 40%

TOTAL = 100% → HIGH

Step 6: Return result

What Trident Receives:
text
Request ID: REQ-002
Total Results: 1

Result 1:
  Rank: 1
  Emitter: Continuous Wave Radar
  Country: Unknown
  Platform: Generic
  Confidence: 100% - HIGH
  Matched Fields: Frequency, Modulation
Part 6: Complete Example 3 - Radar CW (Without Modulation)
What Trident Sends:
text
Signal Type: Radar CW
Frequency: 9450 MHz
(No modulation sent)
What System Does:
Step 1: Identify as Radar CW

Step 2: Apply tolerance to frequency

Frequency: 9450 ±5% = 8978 to 9922 MHz

Step 3: Database uses index

Frequency index: 20,000 → 1 candidate

Step 4: Check overlap

Candidate: Continuous Wave Radar

Frequency: 8978-9922 vs 9400-9500 → OVERLAP YES

Modulation: Not provided by Trident → SKIP

Step 5: Calculate score

Frequency (100% weight because modulation not provided) → 100%

TOTAL = 100% → HIGH

Note: Even without modulation, score is 100% because frequency alone gets full weight when modulation is optional.

Part 7: Complete Example 4 - COMINT
What Trident Sends:
text
Signal Type: COMINT
Frequency: 250 MHz
Modulation: FM
What System Does:
Step 1: Identify as COMINT

Step 2: Apply tolerance to frequency

Frequency: 250 ±5% = 237.5 to 262.5 MHz

Step 3: Database uses index

Frequency index: 20,000 → 1 candidate

Step 4: Check overlap

Candidate: VHF Transceiver

Frequency: 237.5-262.5 vs 240-260 → OVERLAP YES

Modulation: "FM" vs "FM" → MATCH YES

Step 5: Calculate score

Frequency (50% weight) → 50%

Modulation (50% weight) → 50%

TOTAL = 100% → HIGH

Step 6: Return result

What Trident Receives:
text
Request ID: REQ-003
Total Results: 1

Result 1:
  Rank: 1
  Emitter: VHF Transceiver
  Country: Various
  Platform: Communication System
  Confidence: 100% - HIGH
  Matched Fields: Frequency, Modulation
Part 8: Performance Summary
Time Breakdown for Each Request
Step	What Happens	Time
1	Receive request from Trident	<1 ms
2	Apply tolerance to values	<1 ms
3	Database uses frequency index	10 ms
4	Database uses PRI index (Radar Pulse only)	5 ms
5	Database uses PW index (Radar Pulse only)	5 ms
6	Database calculates confidence scores	5 ms
7	Database ranks and limits results	2 ms
8	Send results to Python	5 ms
9	Python formats JSON response	2 ms
TOTAL		30-80 ms
Without Indexes vs With Indexes
Scenario	Time	Result
No indexes	2-5 seconds	TOO SLOW
With GiST indexes	30-80 milliseconds	FAST
Part 9: What Makes This Fast
1. GiST Indexes on Ranges
Index	What It Does
Frequency GiST	Finds overlapping frequency ranges in milliseconds
PRI GiST	Finds overlapping PRI ranges in milliseconds
PW GiST	Finds overlapping PW ranges in milliseconds
2. Filtering in Database
Without Database Filter	With Database Filter
Load 20,000 rows to Python	Only 2-15 rows to Python
Python does all calculations	Database does calculations
Slow (2-5 seconds)	Fast (30-80 ms)
3. Only Final Results to Python
What Goes to Python	How Many Rows
Full database	20,000 rows
After frequency filter	200 rows
After PRI filter	40 rows
After PW filter	15 rows
Final results	2-15 rows
Part 10: Summary Table for Meeting
Question	Answer
What does Trident send for Radar Pulse?	Frequency, PRI, Pulse Width (all mandatory)
What does Trident send for Radar CW?	Frequency (mandatory), Modulation (optional)
What does Trident send for COMINT?	Frequency and Modulation (both mandatory)
What tolerance for Frequency?	±5%
What tolerance for PRI?	±10%
What tolerance for Pulse Width?	±15%
How does database find matches fast?	GiST indexes on ranges
How many records before filtering?	20,000
How many records after filtering?	2-15
Total response time?	30-80 milliseconds
What confidence score for Radar Pulse all match?	100% (HIGH)
What confidence score for Radar Pulse only frequency?	50% (MEDIUM)
What confidence score for Radar CW with modulation?	100% (HIGH)
What confidence score for COMINT both match?	100% (HIGH)
