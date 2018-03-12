
(
var w, a, u, text, updateInfo, pbut, rbut, resetBut, dbview, postbut, viewsToReset;
var infoVoice, infoF0, infoPitchShift;
var inputLevel, outputLevel, pitchShiftLevel;


w = Window("Parkinson und Sprache", Rect(100, 100, 640, 400), resizable:false);
if(~window.notNil) { ~window.close }; ~window = w;

w.view.keyDownAction = { |v, key, mod|
	if(mod.isShift) {
		resetBut.states = [["reboot\n& reset"]]
	}
};

w.view.keyUpAction = {
	resetBut.states = [["reset"]]
};

resetBut = Button(w, Rect(100, 100, 70, 50)).states_([["reset"]]).action_({ |but, mod|
	 if(mod.isShift) { s.quit };
	~reset.value;
	viewsToReset.do(_.value = 0);
	postbut.value = ~post.binaryValue;
});


rbut = Button(w, Rect(180, 100, 70, 50))
.states_([
	["record", Color.black],
	["stop rec", Color.black, Color.red(1, 0.5)]]
).action_({ |b|
	if(b.value == 1) { ~startRecording } { ~stopRecording }.value
});

pbut = Button(w, Rect(20, 100, 70, 50))
.states_([
	["mute\ninput", Color.black],
	["unmute\ninput", Color.black, Color.red(1, 0.5)]]
).action_({ |b|
	if(b.value == 0) { Ndef(\onoff_in, 1) } { Ndef(\onoff_in, 0) }
});


/*

Testing

*/

a = Button(w, Rect(20, 250, 70, 50))
.states_([
	["test\noutput"],
	["stop\ntest", Color.black, Color.yellow]
])
.action_({ |b|
	if(b.value == 1) {
		Ndef(\audition, ~auditionTestFunction)
	} {
		Ndef(\audition, ~auditionFunction)
	}
});

viewsToReset = viewsToReset.add(a);


a = Button(w, Rect(300, 250, 70, 50))
.states_([
	["start\nplayback"],
	["stop\nplayback", Color.black, Color.yellow]
])
.action_({ |b|
	if(b.value == 1) {
		~preparePlayback.value {
			Ndef(\audition, ~auditionPlaybackFunction)
		};
	} {
		Ndef(\audition, ~auditionFunction)
	}
});


viewsToReset = viewsToReset.add(a);


a = Button(w, Rect(20, 310, 70, 50)).states_([["test\npitch"], ["stop\ntest", Color.black, Color.yellow]]).action_({ |b|
	if(b.value == 1) {
		Ndef(\input, ~inputTestFunction.postcs)
	} {
		Ndef(\input, ~inputDefaultFunction.postcs)
	}
});
viewsToReset = viewsToReset.add(a);


postbut = Button(w, Rect(100, 250, 70, 50));
postbut.states_([["start\nposting", Color.black], ["stop\nposting", Color.black, Color.yellow]]);
postbut.action_({ |b| ~post = b.value.booleanValue.postln });
postbut.value_(~post.binaryValue);

dbview = StaticText(w, Rect(100, 310, 70, 50));
OSCdef(\ampdb, { |msg| defer { dbview.string = msg[3].asString } }, "/diffdB");

text = StaticText(w, Rect(20, 20, 200, 40));

updateInfo = { |color|
	var str = infoPitchShift + infoVoice + infoF0;
	if(w.isClosed.not) {
		defer {
			text.string = str;
			color !? { text.background = color }
		}
	}
};

infoVoice = "warte ... ";
infoPitchShift = "";
infoF0 = "";

updateInfo.( Color.clear );

OSCdef(\g1, { |msg|
	infoVoice = "stimme";
	updateInfo.(Color.green(1, 0.2))
}, '/voice_start');
OSCdef(\g2, { |msg|
	infoVoice = "warte ... ";
	updateInfo.(Color.clear)
}, '/voice_stop');
OSCdef(\g3, { |msg|
	infoF0 = "( f0 )";
	updateInfo.()
}, '/f0_start');
OSCdef(\g4, { |msg|
	infoF0 = "";
	updateInfo.()
}, '/f0_stop');
OSCdef(\g5, { |msg|
	infoPitchShift = "pitch shift";
	updateInfo.(Color.blue(1, 0.3))
}, '/ps_start');
OSCdef(\g6, { |msg|
	infoPitchShift = "";
	updateInfo.(Color.green(1, 0.2))
}, '/ps_stop');


Slider(w, Rect(100, 210, 150, 30))
.value_(Ndef(\auditionAmp).source.explin(0.1, 10, 0, 1))
.action_({ |sl| Ndef(\auditionAmp, sl.value.linexp(0, 1, 0.1, 10)) });


a = PopUpMenu(w, Rect(100, 170, 150, 30)).items_(["warte auf f0", "warte auf input"]).action_({ |v|
	if(v.value == 0) {
		Ndef(\triggersHappen, { Ndef.kr(\hasFreq, 1) });
	} {
		Ndef(\triggersHappen, { Ndef.kr(\inputRunning, 1) });
	}
});

viewsToReset = viewsToReset.add(a);


a = PopUpMenu(w, Rect(260, 170, 150, 30)).items_(["delayshift", "trigger only"]).action_({ |v|
	if(v.value == 0) {
		Ndef(\pitchShiftMethod, { Ndef.ar(\pitchShiftedByDelay, 1) })
	} {
		//Ndef(\pitchShiftMethod, { Ndef.ar(\pitchShiftedByGranulation, 1) });
		Ndef(\pitchShiftMethod, { DC.ar(1) })
	}
});
viewsToReset = viewsToReset.add(a);

StaticText(w, Rect(270, 20, 30, 20)).string_("in");
StaticText(w, Rect(270, 50, 30, 20)).string_("out");
StaticText(w, Rect(270, 80, 30, 20)).string_("shift");


inputLevel = LevelIndicator(w, bounds:Rect(310, 20, 300, 20));
outputLevel = LevelIndicator(w, bounds:Rect(310, 50, 300, 20));
pitchShiftLevel = LevelIndicator(w, bounds:Rect(310, 80, 300, 20));

[inputLevel, outputLevel].do { |a|
	a.warning = 0.8;
	a.critical = 0.9;
	a.drawsPeak = true;
	a.meterColor = Color.green;
	a.warningColor = Color.yellow;
	a.criticalColor  = Color.red;
};

// never warn
pitchShiftLevel.critical = 10;
pitchShiftLevel.warning = 10;
pitchShiftLevel.meterColor = Color(0, 0.3, 1);
pitchShiftLevel.background = Color.grey(0.2);

OSCdef(\rms, { |msg|
	defer {
		var rmsData = msg[3..].clump(2);
		var peak, rms;
		[inputLevel, outputLevel, pitchShiftLevel].do { |view, i|
			#peak, rms = rmsData[i];
			view.peakLevel = peak.ampdb.linlin(-40, 0, 0, 1);
			view.value = rms.ampdb.linlin(-40, 0, 0, 1);
		};
	}

}, "/pspeech_rms").fix;


w.front;
w.onClose = {
	OSCdef(\rms).remove;
	rbut.value = 0;
};
)