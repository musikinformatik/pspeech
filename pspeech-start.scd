

loadRelative("library/pspeech-setup.scd");
loadRelative("library/pspeech-commands.scd");
loadRelative("library/pspeech-GUI.scd");

~reset.value;

"--------------- PSPEECH VERSION % -----------------".format(~pspeechVersion).postln;
