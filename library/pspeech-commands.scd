~pspeechVersion = "0.1.1";

~path = "pspeech-setup.scd".resolveRelative;
~filePrefix = "pspeech";
~recPath = Platform.recordingsDir;

if(pathMatch(~recPath +/+ "*").isEmpty) {
	"nonexisting Platform.recordingsDir: creating directory %".format(~recPath).postln;
	unixCmd("mkdir '%'".format(~recPath))
};

~reset = {

	var s = Server.default;

	//Server.killAll;
	Ndef.clear;

	s.options.memSize = 131072;
	s.options.hardwareBufferSize = 256;
	s.options.sampleRate = 96000;

	s.options.recSampleFormat = "int16";

	//s.reboot;

	s.waitForBoot {
		load(~path);
	};
};

// recording each channel separately
~prepareRecording = {
	var timestamp = Date.localtime.stamp;
	var labels = ["input", "output", "trigger"];
	var pathHead = ~recPath +/+ ~filePrefix ++ "_" ++ timestamp;

	~recorders = { Recorder(Server.default) }.dup(3);
	~recorders.do { |x, i|
		var path = (pathHead ++ "_" ++ labels[i] ++ ".aiff").postln;
		x.prepareForRecord(path: path, numChannels:1)
	};
	~writeParameterFile.(pathHead ++ "_" ++ timestamp ++ "__parameters.csv");

};

~writeParameterFile = { |path|
	var params = ~getParameters.value;
	var timestamp = Date.localtime.asString;
	var string = "pspeech version %. Date of Recording: %\n".format(~pspeechVersion, timestamp);
	string = string ++ "filename, " ++ path.basename.cs ++ "\n";
	params.pairsDo { |key, val| string = string ++ key ++ ", " ++ val ++ "\n" };
	"\n------------------------".postln;
	string.post;
	"------------------------\n".postln;
	File.use(path, "w", { |file| file << string });
};


~startRecording = { |path|
	var signals = [
		Ndef(\input), // input voice
		Ndef(\audition), // processed voice
		Ndef(\pitchShiftOnOffSignal) // pitch shift trigger
	];

	// pitchshift on/off
	if(Server.default.serverRunning) {
		~recorders.do { |x|
			if(x.isRecording) { x.stopRecording }
		};

		Server.default.bind { // all recording starts in sync
			~prepareRecording.value;
			Server.default.sync;
			~recorders.do { |r, i|
				r.record(
					bus:signals[i].index,
					numChannels: 1
				)
			};
		};
	} {
		"can't record, server not running.".warn;
	};
};

~stopRecording = {
	~recorders.do(_.stopRecording);

};



~testOutput = {
	{ SinOsc.ar(440) * 0.3 * EnvGen.kr(Env.linen, doneAction:2) }.play;
};

~testPitchDetection = {
	fork {
		Ndef(\input, { SinOsc.ar(440) * 0.3 * EnvGen.kr(Env.linen(0.01, 3, 0.1), doneAction:2) });
		3.5.wait;
		Ndef(\input, { (SoundIn.ar([0,1]).sum * Ndef.kr(\auditionAmp, 1)) * Ndef.kr(\onoff_in, 1) });

	}
};

