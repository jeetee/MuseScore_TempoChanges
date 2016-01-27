# MuseScore TempoChanges
This plugin uses the hidden tempo texts technique to simulate linear tempo changes such as accelerando and ritradando in [MuseScore](https://musescore.org). The technique itself is taken straight out of [the online handbook](https://musescore.org/en/handbook/tempo-0#ritardando-accelerando).

### How does it work?
1. Select the range of notes over which the tempo change has to take place
2. Open up the plugin from `Plugins > TempoChanges`
  * **Staff Text:** Optional staff text to be created at the start of the tempo change. Leave blank if undesired.
  * **BPM beat:** Reference beat duration for both tempo settings below
  * **Start BPM:** Tempo of the first note in the selection (in BPM beats)
  * **End BPM:** Tempo of the first note *after* the selection (in BPM beats)
3. Hit `Apply`. The plugin will now create invisible tempo texts on each segment within the selection and a final visible one on the first note after the selection with the resulting end tempo.

### Screenshots
Plugin Dialog and resulting score fragment

![Applying the Plugin](http://jeetee.github.io/MuseScore_TempoChanges/images/applying_plugin.png) ![Result](http://jeetee.github.io/MuseScore_TempoChanges/images/plugin_result.png)

### Download and Install
https://github.com/jeetee/MuseScore_TempoChanges/archive/2.0.zip

For installation see [Plugins](https://musescore.org/en/handbook/plugins-0).

Tested with MuseScore 2.0.2, should work on 2.0+
