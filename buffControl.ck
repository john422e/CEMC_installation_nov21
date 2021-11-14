// SETUP --------------------------------------------------------

// DATA
[ 513.4, 616.0, 770.0, 1155.1, 1319.8 ] @=> float group0[];
[ 12, 12, 12, 12, 12 ] @=> int group0pos[];

[ 513.4, 599.2, 642.1, 770.8, 1155.7 ] @=> float group1[];
[ 12, 12, 26, 26, 12 ] @=> int group1pos[];

[ 502.9, 558.8, 670.3, 1006.2, 1117.9 ] @=> float group2[];
[ 26, 12, 26, 26, 12 ] @=> int group2pos[];

[ 432.8, 562.8, 649.3, 1169.0, 1212.1 ] @=> float group3[];
[ 26, 26, 26, 26, 12 ] @=> int group3pos[];

[ 487.4, 557.1, 709.2, 1114.1, 1418.4 ] @=> float group4[];
[ 0, 26, 12, 12, 12 ] @=> int group4pos[]; // 0 means it's in both locations

[ 535.7, 642.6, 857.5, 1142.9, 1499.9 ] @=> float group5[];
[ 0, 26, 26, 12, 12 ] @=> int group5pos[];

[group0, group1, group2, group3, group4, group5] @=> float groups[][];
[group0pos, group1pos, group2pos, group3pos, group4pos, group5pos] @=> int groupPos[][];
	
// osc
OscIn in;
OscMsg msg;
10001 => in.port;
in.listenAll();

// sensor vars
100.0 => float maxDist; // distance maximum (lower values trigger sound)
30.0 => float minDist; // distance minimum (higher values trigger sound)
10.0 => float distOffset; // set for each sensor to compensate for irregularities
float dist;
float amp1;
float amp2;
0 => int offCount; // track time since qualifying distance value
10 => int offThresh; // turn sound off when count exceeds this

// file handling
me.dir() + "audio/" => string path;
path + "m12.wav" => string buf1fn;
path + "m26.wav" => string buf2fn;
<<< buf1fn, buf2fn >>>;

// sound
2 => int numBufs;
[buf1fn, buf2fn] @=> string bufFNs[];
SndBuf buffers[numBufs];
int bufSize[numBufs];
Envelope bufEnvs[numBufs];
Pan2 bufPans[numBufs];
// Sines
5 => int numSines;
SinOsc sines[numSines];
Envelope sinEnvs[numSines];
Pan2 sinPans[numSines];
Gain sinGains[numSines];

// set up soundchains for buffers
for( 0 => int i; i < numBufs; i++ ) {
	// read and set buffers
	bufFNs[i] => buffers[i].read;
	buffers[i].samples() => bufSize[i]; // don't think i need this
	1 => buffers[i].loop;
	buffers[i] => bufEnvs[i] => bufPans[i] => dac;
}
// set up soundchains for sinoscs
0.1 => float sinGainLevel;
for( 0 => int i; i < numSines; i++) {
	sines[i] => sinEnvs[i] => sinGains[i] => sinPans[i] => dac;
	sinGainLevel => sinGains[i].gain;
}

// initialize pans and gains
0.5 => buffers[1].gain;
-1 => bufPans[0].pan => sinPans[0].pan;
1 => bufPans[1].pan => sinPans[1].pan;


// initialize sines

2 => int currentGroup;
for( 0 => int i; i < numSines; i++ ) {
	groups[currentGroup][i] => sines[i].freq;
	if( groupPos[currentGroup][i] == 12 ) -1 => sinPans[i].pan;
	if( groupPos[currentGroup][i] == 26 ) 1 => sinPans[i].pan;
	else 0 => sinPans[i].pan;
}

// FUNCTIONS ---------------------------------------------------

fun float normalize( float inVal, float x1, float x2 ) {
	/*
	for standard mapping:
	x1 = min, x2 = max
	inverted mapping:
	x2 = min, x1 = max
	*/
	// catch out of range numbers and cap
	if( x1 > x2 ) { // for inverted ranges
		if( inVal < x2 ) x2 => inVal;
		if( inVal > x1 ) x1 => inVal;
	}
	// normal mapping
	else {
		if( inVal < x1 ) x1 => inVal;
		if( inVal > x2 ) x2 => inVal;
	}
	(inVal-x1) / (x2-x1) => float outVal;
	return outVal;
}

fun void getNewGroup() {
	// sets globals, returns nothing
	<<< "NEW GROUP" >>>;
	Math.random2(0, groups.size() - 1) => currentGroup;
	for( 0 => int i; i < numSines; i++ ) {
		groups[currentGroup][i] => sines[i].freq;
		if( groupPos[currentGroup][i] == 12 ) -1 => sinPans[i].pan;
		if( groupPos[currentGroup][i] == 26 ) 1 => sinPans[i].pan;
		else 0 => sinPans[i].pan;
	}
}

getNewGroup(); // initialize

fun void get_osc() {
	while( true ) {
		// check for osc messages
		in => now;
		while( in.recv(msg) ) {
			// start piece
			if( msg.address == "/beginPiece" ) {
				<<< "BEGINNING CUED" >>>;
				//spork ~ main();
			};
			// get random group
			if( msg.address == "/newGroup" ) getNewGroup();
				
			// ultrasonic sensor distance
			if( msg.address == "/distance" ) {
				msg.getFloat(0) => dist;
				<<< "/distance", dist >>>;
				// set amps from value if distance within range
				if( dist <= maxDist && dist > minDist ) {
					0 => offCount; // reset count
					normalize(dist, maxDist, minDist) => amp1; // does minDist need to be distOffset?
					1 - amp1 => amp2;
					<<< amp1, amp2 >>>;
					amp1 => bufEnvs[0].target;
					amp2 => bufEnvs[1].target;
					for( 0 => int i; i < numSines; i++ ) {
						if( groupPos[currentGroup][i] == 12 ) amp2 => sinEnvs[i].target;
						if( groupPos[currentGroup][i] == 26 ) amp1 => sinEnvs[i].target;
						else amp2 => sinEnvs[i].target;
					}
					amp2 => sinEnvs[0].target;
					bufEnvs[0].keyOn();
					sinEnvs[0].keyOn();
				}
				if( dist > (maxDist*1.5) ) offCount++;
			}
		}
	}
}


// this will trigger everything when /beginPiece comes in from masterSpeakerCtl.ck
spork ~ get_osc(); // start sensor listener

0 => int second_i;

<<< "STARTING PIECE" >>>;
// run forever
while( true ) {
	1::second => now;
	second_i++;
	if( second_i % 600 == 0 ) getNewGroup(); // set new group every ten minutes
	// turn off sound when 
	if( offCount >= offThresh ) {
		// turn everything off
		for( 0 => int i; i < numBufs; i++ ) {
			2 => bufEnvs[i].time;
			bufEnvs[i].keyOff();
		}
		for( 0 => int i; i < numSines; i++ ) {
			2 => sinEnvs[i].time;
			sinEnvs[i].keyOff();
		}
		2::second => now;
		// reset env time
		for( 0 => int i; i < numBufs; i++ ) {
			0.1 => bufEnvs[i].time;
		}
		for( 0 => int i; i < numSines; i++ ) {
			0.1 => sinEnvs[i].time;
		}
	}
}