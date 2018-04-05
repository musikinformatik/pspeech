

(

/*

Parameter

*/


// TTL commandline pfad

~ttlCmd = "/usr/local/bin/parashell 0x378 ";

// deterministische Latenz für das Signal zum MRS (kann frei angepasst werden)
// wenn sie nicht ausreicht, gibt es eine Warnung.

~ttlLatency = 0.004;


// Schwellwert für Analysebeginn
Ndef(\ampThresh, 0.05);

// Maximale Verzögerung vor erstem ps-Trigger (in sec)
Ndef(\trigOnsetDelayMax, 1.0);

// Minimale Verzögerung vor erstem ps-Trigger (in sec)
Ndef(\trigOnsetDelayMin, 0.5);

// Minimale Zeit zwischen ps-Triggern (in sec)
Ndef(\trigDistanceMin, 700/1000);

// Maximale Zeit zwischen ps-Triggern (in sec)
Ndef(\trigDistanceMax, 900/1000);

//  Länge des Shifts (in sec)
Ndef(\shiftDur, 0.2);

// Zeitvelauf
Ndef(\time, { Sweep.ar(1, rate:1) });

// Relativer Wert das pitch shifts
Ndef(\shiftRatio, (-200 / 100).midiratio);

Ndef(\auditionAmp, 0.6);
Ndef(\onoff_in, 1);


// f0 - Analyse (unsicher!)

// erwarteter Frequenzbereich für f0 (in Hz)
// zum Verändern muss der pitch shift aktualisiert werden
Ndef(\minF0, 200);
Ndef(\maxF0, 400);

// wenn Frequenz gefunden wurde, toleriere zeitweisen Verlust so lange:
Ndef(\graceTimeF0, 1.3);


~getParameters = {

	[
		"TTL latency", ~ttlLatency,
		"amplitude theshold", Ndef(\ampThresh).source,
		"minimal time before ps-onset", Ndef(\trigOnsetDelayMin).source,
		"maximal time before ps-onset", Ndef(\trigOnsetDelayMax).source,
		"minimal time between ps-events", Ndef(\trigDistanceMin).source,
		"maximal time between ps-events", Ndef(\trigDistanceMax).source,
		"pitch shift duration", Ndef(\shiftDur).source,
		"pitch shift interval (cent)", Ndef(\shiftRatio, (-200 / 100).midiratio).source.ratiomidi.round(0.0001) * 100,
		"audition amplitude", Ndef(\auditionAmp).source,

	]

};


/*

Signalverarbeitung

*/



// Mikrophon-Input

~inputDefaultFunction = { (SoundIn.ar([0,1]).sum * Ndef.kr(\auditionAmp, 1)) * Ndef.kr(\onoff_in, 1) };
~inputTestFunction = { SinOsc.ar(440) * 0.3 };

Ndef(\input, ~inputDefaultFunction);


// Detecting Input


Ndef(\inputRunning, {
	var in, amp;

	in = Ndef.ar(\input, 1);

	// onset detection via amplitude threshold
	amp = Amplitude.ar(in, attackTime:0.5, releaseTime:0.5).lag(0.2);
	amp > Ndef.kr(\ampThresh, 1);

});


// Messung des Input-Output-Amplitudenverhältnisses: setzt voraus, dass man Mikro und Kopfhörer
// möglichst "angemessen" verbindet.
// Experimentell, zuerst prüfen.

/*
Ndef(\ampComparison, {
	var input = Ndef.ar(\input, 1);
	var output = Ndef.ar(\audition, 1);
	var indb = Amplitude.kr(input, 0.2, 1).ampdb;
	var outdb = Amplitude.kr(output, 0.2, 1).ampdb;
	var diff = outdb - indb;
	SendReply.kr(Impulse.kr(8), '/diffdB', diff);
	diff
});

*/

// Detection of f0

/*
Quoting the helpfile:

Some vowels are still problematic, for instance a wide open mouth sound somewhere between a low pitched short 'a' sound as in 'sat', and long 'i' sound as in 'fire', contains enough overtone energy to confuse the algorithm.
*/


Ndef(\analysisPitchFull, {
	var in = Ndef.ar(\input, 1);
	var p = Pitch.kr(in,
		initFreq: Ndef.kr(\minF0, 1),
		minFreq: Ndef.kr(\minF0, 1),
		maxFreq: Ndef.kr(\maxF0, 1),
		execFreq: 100,
		maxBinsPerOctave: 64,
		median:16,
		ampThreshold:0.1,
		peakThreshold:0.5,
		downSample:1,
		clar:0
	);
	//p.poll(p[1]);
	p
});

Ndef(\scpectralFlatness, {
	var in = Ndef.ar(\input, 1);
	var fftchain = FFT(LocalBuf(2048), in);
	SpecFlatness.kr(fftchain)
});


Ndef(\f0, { Ndef.kr(\analysisPitchFull, 2).at(0) });

// we calculate spectral flatness to exclude noise
// pitch thinks it has found a frequency (there is one, arguably)
// we can only eliminate these outliers by comparing with the full spectrum
(
Ndef(\hasFreq, {
	var fromPitch = Ndef.kr(\analysisPitchFull, 2).at(1);
	var fromFlatness = Ndef.kr(\scpectralFlatness, 1) < 0.2;
	var damped = Amplitude.kr(fromPitch * fromFlatness, 0, Ndef.kr(\graceTimeF0, 1)) > 0.01;
	var hasFreq = damped  * Ndef.kr(\inputRunning, 1);
	hasFreq
})
);

//Ndef(\triggersHappen, { Ndef.kr(\inputRunning, 1) });
Ndef(\triggersHappen, { Ndef.kr(\hasFreq, 1) });

// Pitch Shift


Ndef(\pitchShiftRunning, {
	var triggersHappen, trigger, triggerPossible, trigOnsetDelayMask, trigOnsetDelay;
	var output, prevOutput, randTrig;
	var timeSincePrevTriggerOff, delayTime;

	prevOutput = LocalIn.kr(1);
	timeSincePrevTriggerOff = Sweep.kr(prevOutput);

	// triggers only happen when a frequency has been detected and input is running.
	triggersHappen = Ndef.kr(\triggersHappen, 1);

	// randomise between minimum and maximum trig onset delay time
	trigOnsetDelay = Latch.kr(
		TRand.kr(
			Ndef.kr(\trigOnsetDelayMin, 1),
			Ndef.kr(\trigOnsetDelayMax, 1),
			triggersHappen
		),
		triggersHappen
	);

	// and this only after a certain time
	trigOnsetDelayMask = Sweep.kr(triggersHappen) > trigOnsetDelay;

	triggerPossible = triggersHappen * trigOnsetDelayMask * (1 - prevOutput);

	// goes to 1 when triggers are possible, else 0
	trigger =  HPZ1.kr(triggerPossible) > 0;

	// when triggers are possible, calculate random delaytime
	delayTime = TRand.kr(Ndef.kr(\trigDistanceMin, 1), Ndef.kr(\trigDistanceMax, 1), trigger);

	// ... and delay the trigger signal by this delay time
	randTrig = TDelay.kr(trigger, delayTime);

	// but do not trigger after it has become impossible
	randTrig = randTrig * triggerPossible;

	// actual on-off is eactly shiftDur
	output = Trig1.kr(randTrig, Ndef.kr(\shiftDur, 1));

	// send back up the trigger, so we know when it is off again
	LocalOut.kr(output);

	// (delayTime * 1000).poll(output, "time (ms) since previous trigger");

	output

});


~pitchShiftGateFunction = {
	var onoff = Ndef.kr(\pitchShiftRunning, 1);
	onoff  = onoff.lagud(0, 0.1); // 100 ms soft fading out pitch shift
	onoff
};

~pitchShiftPlaybackGateFunction = {
	A2K.kr(PlayBuf.ar(1, ~pitchShiftPlaybackBuffer, rate: 1, loop:0, doneAction:2))
};

Ndef(\pitchShiftAudible, ~pitchShiftGateFunction);



Ndef(\pitchShiftedByDelay, {
	var onoff = Ndef.kr(\pitchShiftRunning, 1);
	var maxDur = 4;
	var buf = LocalBuf(SampleRate.ir * maxDur).clear;
	var rate;
	var in = Ndef.ar(\input, 1);
	var shifted;

	// this delays the end of the pitch shift just a little so that
	// the audition can be switched off before the shift ends (and clicks)

	var diff = HPZ1.kr(onoff);
	var trigOn = diff > 0;
	var offDelay = 0.2;
	var trigOff = DelayN.kr(diff < 0, offDelay, offDelay);
	var trig = trigOn + trigOff;

	//trigOn.poll(trigOn, "trigOn");
	//offDelay.poll(trigOff, "trigOff");

	RecordBuf.ar(in, buf, BufFrames.kr(buf), run: -1.0, trigger: trig);

	rate = Select.kr(onoff, [1.0, Ndef.kr(\shiftRatio, 1)]);
	rate = rate.lagud(0, 0.1);

	shifted = PlayBuf.ar(
		in.numChannels,
		buf,
		-1.0 * rate,
		1.0,
		BufFrames.kr(buf),
		trigger: trig,
		loop: 1
	)
});


Ndef(\pitchShiftedByGranulation, {
	var in;
	in = Ndef.ar(\input, 1);
	PitchShift.ar(
		in,
		windowSize:0.2,
		pitchRatio: Ndef.kr(\shiftRatio, 1),
		pitchDispersion:0,
		timeDispersion:0
	)
});


Ndef(\pitchShiftMethod, { Ndef.ar(\pitchShiftedByDelay, 1) });
//Ndef(\pitchShiftMethod, { Ndef.ar(\pitchShiftedByGranulation, 1) });
//Ndef(\pitchShiftMethod, { DC.ar(1) });

~auditionFunction = {
	var onoff = Ndef.kr(\pitchShiftAudible, 1);
	var sig = SelectX.ar(onoff, [
		Ndef.ar(\input, 1),
		Ndef.ar(\pitchShiftMethod, 1)
	]);
	CheckBadValues.ar(sig, post:2);
	sig
};

~auditionTestFunction = {
	WhiteNoise.ar(0.1)
};

~auditionPlaybackFunction = {
	PlayBuf.ar(1, ~auditionPlaybackBuffer, rate: 1, loop:0, doneAction:2)
};

Ndef(\audition, ~auditionFunction).playN([0, 1]);
//Ndef(\audition, { Ndef.ar(\input, 1) }).playN([0, 1]);

// write pitch shift signal to extra channel, convert to audio rate

Ndef(\pitchShiftOnOffSignal, {
	var onoff = Ndef.kr(\pitchShiftAudible, 1);
	K2A.ar(onoff)
});

// Ndef(\sendMISCSignal).play(out:4); // misc channel


// equivalent of the recording channels
// used for scope

Ndef(\scopingOutput, {
	var channels;
	channels = [
		Ndef.ar(\input, 1), // input voice
		Ndef.ar(\audition, 1), // processed voice
		Ndef.ar(\pitchShiftOnOffSignal, 1) // pitchshift on/off
	];
	SendPeakRMS.ar(channels, 20, cmdName:'/pspeech_rms');
});


// Open Sound Control Communication (OSC) and TTL commands


Ndef(\inputRunningOSC, {
	var running = Ndef.kr(\inputRunning, 1) * EnvGen.kr(Env([0, 0, 1], [0.1, 0]));
	SendReply.kr(HPZ1.kr(running) > 0, "/voice_start", Ndef.kr(\time, 1));
	SendReply.kr(HPZ1.kr(running) < 0, "/voice_stop", Ndef.kr(\time, 1));
});

Ndef(\analysisPitchOSC, {
	var hasFreq;
	hasFreq = Ndef.kr(\hasFreq, 1) > 0;
	//hasFreq = Ndef.kr(\hasFreq, 1) > 0;
	//hasFreq.poll;
	SendReply.kr(HPZ1.kr(hasFreq) > 0, "/f0_start", Ndef.kr(\time, 1));
	SendReply.kr(HPZ1.kr(hasFreq) < 0, "/f0_stop", Ndef.kr(\time, 1));

});

Ndef(\pitchShiftOSC, {
	var shiftGate = Ndef.kr(\pitchShiftAudible, 1) * EnvGen.kr(Env([0, 0, 1], [0.1, 0]));
	SendReply.kr(shiftGate, "/ps_start", Ndef.kr(\time, 1));
	SendReply.kr(1 - shiftGate * Line.kr(0, 1, 0.1), "/ps_stop", Ndef.kr(\time, 1));
});

~post = false;

OSCdef(\c1, { |msg| var time = msg[3]; ~ttlvoiceStart.(time); if(~post) { msg.postln }; }, "/voice_start");
OSCdef(\c2, { |msg| var time = msg[3]; ~ttlvoiceEnd.(time);if(~post) { msg.postln }; }, "/voice_stop");
OSCdef(\c3, { |msg| var time = msg[3]; if(~post) { msg.postln }; }, "/f0_start");
OSCdef(\c4, { |msg| var time = msg[3]; if(~post) { msg.postln }; }, "/f0_stop");
OSCdef(\c5, { |msg| var time = msg[3]; ~ttlshiftStart.(time); if(~post) { msg.postln }; }, "/ps_start");
OSCdef(\c6, { |msg| var time = msg[3]; ~ttlshiftEnd.(time); if(~post) { msg.postln }; }, "/ps_stop");



{
	var array = [0, 0, 0, 0];
	var dict = (0..15).collect(_.asBinaryDigits(4));
	var cmds = Dictionary.new; // lookup table for efficiency
	var timeReferenceHere, timeReferenceThere;

	dict.do { |array, i| cmds[array] = ~ttlCmd + i };

	//cmds.postcs;

	~sendCmd = { |which, time|
		fork {
			var dt, elapsedHere, elapsedThere, ttlPulseLength = 0.01;
			var firstTime = timeReferenceHere.isNil;
			if(firstTime) {
				timeReferenceHere = Main.elapsedTime;
				timeReferenceThere = time;
				dt = ~ttlLatency;
			} {
				elapsedHere = Main.elapsedTime - timeReferenceHere;
				elapsedThere = time - timeReferenceThere;
				dt = elapsedThere - elapsedHere + ~ttlLatency;
				timeReferenceHere = Main.elapsedTime;
				timeReferenceThere = time;
			};
			if(~post) {
				"ttl remaining latency: %. Scheduled at % sec after audio event"
				.format(dt, ~ttlLatency).postln
			};
			//[\elapsedHere, elapsedHere, \elapsedThere, elapsedThere, \dt, dt].postln;
			if(dt < 0) {
				"---- TTL latency too low (%). Sending anyway. ----".format(dt).warn;
				dt = 0
			};

			dt.wait;

			array[which] = 1;
			unixCmd(cmds[array],  postOutput:false);
			ttlPulseLength.wait;
			array[which] = 0;
			unixCmd(cmds[array],  postOutput:false);
		}
	};

	~ttlvoiceStart = { |time| ~sendCmd.(3, time) };
	~ttlvoiceEnd = { |time| ~sendCmd.(2, time) };
	~ttlshiftStart = { |time| ~sendCmd.(1, time) };
	~ttlshiftEnd = { |time| ~sendCmd.(0, time) };

}.value;


"----------- pspeech-setup finished ------------".postln;

);




