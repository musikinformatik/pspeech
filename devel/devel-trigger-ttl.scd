(
fork {
	unixCmd("/usr/local/bin/parashell 0x378 1").postln;
	0.01.wait;
	unixCmd("/usr/local/bin/parashell 0x378 0").postln;
}
)



(
var array = [0, 0, 0, 0];

~ttlreset = true;

Tdef(\ttl, {
	var makeCmd = {
		"/usr/local/bin/parashell 0x378 " ++ array.reverse.convertDigits(2);
	};
	inf.do {
		fork {
			unixCmd(makeCmd.value, postOutput:false);
			0.01.wait;
			unixCmd("/usr/local/bin/parashell 0x378 0", postOutput:false);
			if(~ttlreset) { array = [0, 0, 0, 0] };
		};

		1.wait;
	}
}).play;

~ttlvoiceStart = { array[0] = 1 };
~ttlvoiceEnd = { array[1] = 1 };
~ttlshiftStart = { array[2] = 1 };
~ttlshiftEnd = { array[3] = 1 };
)


~ttlvoiceStart.value;
~ttlvoiceEnd.value;
~ttlshiftStart.value;
~ttlshiftEnd.value;
~ttlreset = false;
~ttlreset = true;

Tdef(\ttl).stop;


//fork { inf.do { |i| 0.1.wait; ~sendCmd.(i % 4) }}


(
var array = [0, 0, 0, 0];
var dict = (0..15).collect(_.asBinaryDigits(4));
var cmds = Dictionary.new;
dict.do { |array, i| cmds[array] = "/usr/local/bin/parashell 0x378 " + i };

cmds.postcs;

~sendCmd = { |which|
	fork {
		array[which] = 1;
		unixCmd(cmds[array],  postOutput:false);
		0.01.wait;
		array[which] = 0;
		unixCmd(cmds[array],  postOutput:false);
	}
};

~ttlvoiceStart = { ~sendCmd.(3) };
~ttlvoiceEnd = { ~sendCmd.(2) };
~ttlshiftStart = { ~sendCmd.(1) };
~ttlshiftEnd = { ~sendCmd.(0) };
)

