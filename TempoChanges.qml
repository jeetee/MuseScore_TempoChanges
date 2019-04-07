//=============================================================================
//  TempoChanges Plugin
//
//  Based on the principle of hidden tempo markings mentioned in the handbook
//  Attempts to create a linear ritartando or accelerando
//
//  Copyright (C) 2016-2019 Johan Temmerman (jeetee)
//=============================================================================
import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1

import MuseScore 3.0

MuseScore {
      menuPath: "Plugins.TempoChanges"
      version: "3.0.1"
      description: qsTr("Creates linear hidden tempo markers.\nSee also: https://musescore.org/en/handbook/3/tempo#ritardando-accelerando")
      pluginType: "dialog"
      requiresScore: true

      width:  240
      height: 240

      onRun: {
            if ((mscoreMajorVersion == 3) && (mscoreMinorVersion == 0) && (mscoreUpdateVersion < 5)) {
                  console.log(qsTr("Unsupported MuseScore version.\nTempoChanges needs v3.0.5 or above.\n"));
                  Qt.quit();
            }
      }

      function applyTempoChanges()
      {
            var sel = getSelection();
            if (sel === null) { //no selection
                  console.log('No selection');
                  return;
            }
            var durationTicks = sel.end - sel.start;

            var beatBaseItem = beatBase.model.get(beatBase.currentIndex);
            var startTempo = getTempoFromInput(startBPMvalue) * beatBaseItem.mult;
            var endTempo = getTempoFromInput(endBPMvalue) * beatBaseItem.mult;
            var tempoRange = (endTempo - startTempo);
            console.log('Applying to selection [' + sel.start + ', ' + sel.end + '] = ' + durationTicks);
            console.log(startTempo + ' (' + (startTempo*60) + ') -> ' + endTempo + ' (' + (endTempo*60) + ') = ' + tempoRange);

            var cursor = curScore.newCursor();
            cursor.rewind(1); //start of selection
            var tempoTracker = {}; //tracker to ensure only one marking is created per 0.1 tempo changes
            var endSegment = { track: undefined, tick: undefined };

            curScore.startCmd();
            //add indicative text if required
            if (startTextValue.text != "") {
                  var startText = newElement(Element.STAFF_TEXT);
                  startText.text = startTextValue.text;
                  if (startText.textStyleType !== undefined) {
                        startText.textStyleType = TextStyleType.TECHNIQUE;
                  }
                  cursor.add(startText);
            }

            for (var trackIdx = 0; trackIdx < cursor.score.ntracks; ++trackIdx) {
                  cursor.rewind(1);
                  cursor.track = trackIdx;

                  while (cursor.segment && (cursor.tick < sel.end)) {
                        //non-linear interpolation of the desired tempo
                        var newTempo = deltaTempo((cursor.tick - sel.start) / durationTicks) * tempoRange + startTempo;
                        applyTempoToSegment(newTempo, cursor, false, beatBaseItem, tempoTracker);
                        cursor.next();
                  }

                  if (cursor.segment) { //first element after selection
                        if ((endSegment.tick === undefined) || (cursor.tick < endSegment.tick)) { //is closer to the selection end than in previous tracks
                              endSegment.track = cursor.track;
                              endSegment.tick = cursor.tick;
                        }
                  }
            }
            //processed selection, now end at new tempo with a visible element
            if ((endSegment.track !== undefined) && (endSegment.tick !== undefined)) { //but only if we found one
                  //relocate it
                  cursor.rewind(1);
                  cursor.track = endSegment.track;
                  while (cursor.tick < endSegment.tick) { cursor.next(); }
                  //arrived at end segment, write marking
                  applyTempoToSegment(endTempo, cursor, true, beatBaseItem);
            }

            curScore.endCmd(false);
      }

      function getSelection()
      {
            var selection = null;
            var cursor = curScore.newCursor();
            cursor.rewind(1); //start of selection
            if (!cursor.segment) { //no selection
                  console.log('No selection');
                  return selection;
            }
            selection = {
                  start: cursor.tick,
                  end: null
            };
            cursor.rewind(2); //find end of selection
            if (cursor.tick == 0) {
                  // this happens when the selection includes
                  // the last measure of the score.
                  // rewind(2) goes behind the last segment (where
                  // there's none) and sets tick=0
                  selection.end = curScore.lastSegment.tick + 1;
            }
            else {
                  selection.end = cursor.tick;
            }
            return selection;
      }

      function getTempoFromInput(input)
      {
            var tempo = input.text;
            if (tempo == "") {
                  tempo = input.placeholderText;
            }
            tempo = parseFloat(tempo) / 60;
            return tempo;
      }

      function findExistingTempoElement(segment)
      { //look in reverse order, there might be multiple TEMPO_TEXTs attached
            // in that case MuseScore uses the last one in the list
            for (var i = segment.annotations.length; i-- > 0; ) {
                  if (segment.annotations[i].type === Element.TEMPO_TEXT) {
                        return (segment.annotations[i]);
                  }
            }
            return undefined; //invalid - no tempo text found
      }

      function applyTempoToSegment(tempo, cursor, visible, beatBaseItem, tempoTracker)
      {
            var quarterBaseTempo = Math.round(tempo * 60 * 10) / 10; //internal bpm is allowed up to 1 decimal place
            var beatBaseTempo = Math.round(tempo * 60 / beatBaseItem.mult * 10) / 10; //as is displayed marking
            var tempoElement = findExistingTempoElement(cursor.segment);
            var addTempo = false;
            if (tempoElement === undefined) {
                  if (!tempoTracker || (tempoTracker && !tempoTracker[quarterBaseTempo])) { //only create new element for tempo if tempo wasn't added yet
                        tempoElement = newElement(Element.TEMPO_TEXT);
                        addTempo = true;
                  }
                  else {
                       return;
                  }
            }
            console.log(((addTempo)?'Applying new tempo: ' : 'Changing existing tempo into: ') + beatBaseTempo);

            tempoElement.text = beatBaseItem.sym + ' = ' + beatBaseTempo;
            tempoElement.visible = visible;
            if (addTempo) {
                  cursor.add(tempoElement);
            }
            //changing of tempo can only happen after being added to the segment
            tempoElement.tempo = quarterBaseTempo / 60; //real tempo setting according to followText
            tempoElement.followText = true; //allows for manual fiddling by the user afterwards

            if (tempoTracker) {
                  tempoTracker[quarterBaseTempo] = true;
            }
      }

      function deltaTempo(fraction)
      {
        // fraction is the current fraction of the number of ticks in the range 0.0 - 1.0
        //
        // The early/late linearity slider also ranges from 0.0 to 1.0, or just shy of that to avoid exceptions.
        // With the slider at 0 we would like all of the tempo change to be applied immediately.
        // With the slider at at 1/4 we would like the mid tempo to be reached 1/4 of the way through the change.
        // With the slider at at 1/2 we would like the mid tempo to be reached 1/2 way through the change, etc.
        //
        // For any input slider value l, we want the equivalent fraction f to be mapped to 1/2
        //
        // We can do this by raising the fraction to a certain power.
        //
        // f^p = 1/2  ; where f = l
        //
        // log(f^p) = p.log(f) = log(1/2)
        //
        // p = log(1/2) / log(f)
        //
        var power = Math.log(1/2) / Math.log(linearity.value);
        return Math.pow(fraction, power)
      }

      Rectangle {
            color: "lightgrey"
            anchors.fill: parent

            GridLayout {
                  columns: 2
                  anchors.fill: parent
                  anchors.margins: 10

                  Label {
                        text: qsTranslate("Ms::MuseScore", "Staff Text") + ":"
                  }
                  TextField {
                        id: startTextValue
                        placeholderText: 'rit. / accel.'
                        implicitHeight: 24
                  }

                  Label {
                        text: qsTr("BPM beat:")
                  }
                  ComboBox {
                        id: beatBase
                        model: ListModel {
                              id: beatBaseList
                              //mult is a tempo-multiplier compared to a crotchet      
                              //ListElement { text: '\uECA0';               mult: 8     ; sym: '<sym>metNoteDoubleWhole</sym>' } // 2/1
                              ListElement { text: '\uECA2';               mult: 4     ; sym: '<sym>metNoteWhole</sym>' } // 1/1
                              //ListElement { text: '\uECA3 \uE1E7 \uE1E7'; mult: 3.5   ; sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/2..
                              ListElement { text: '\uECA3 \uECB7';        mult: 3     ; sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym>' } // 1/2.
                              ListElement { text: '\uECA3';               mult: 2     ; sym: '<sym>metNoteHalfUp</sym>' } // 1/2
                              ListElement { text: '\uECA5 \uECB7 \uECB7'; mult: 1.75  ; sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/4..
                              ListElement { text: '\uECA5 \uECB7';        mult: 1.5   ; sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym>' } // 1/4.
                              ListElement { text: '\uECA5';               mult: 1     ; sym: '<sym>metNoteQuarterUp</sym>' } // 1/4
                              ListElement { text: '\uECA7 \uECB7 \uECB7'; mult: 0.875 ; sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/8..
                              ListElement { text: '\uECA7 \uECB7';        mult: 0.75  ; sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym>' } // 1/8.
                              ListElement { text: '\uECA7';               mult: 0.5   ; sym: '<sym>metNote8thUp</sym>' } // 1/8
                              ListElement { text: '\uECA9 \uECB7 \uECB7'; mult: 0.4375; sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } //1/16..
                              ListElement { text: '\uECA9 \uECB7';        mult: 0.375 ; sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym>' } //1/16.
                              ListElement { text: '\uECA9';               mult: 0.25  ; sym: '<sym>metNote16thUp</sym>' } //1/16
                        }
                        currentIndex: 5
                        implicitHeight: 42
                        style: ComboBoxStyle {
                              font.family: 'MScore Text'
                              font.pointSize: 18
                              padding.top: 5
                              padding.bottom: 5
                        }
                  }

                  Label {
                        text: qsTr("Start BPM:")
                  }
                  TextField {
                        id: startBPMvalue
                        placeholderText: '120'
                        validator: DoubleValidator { bottom: 1;/* top: 512;*/ decimals: 1; notation: DoubleValidator.StandardNotation; }
                        implicitHeight: 24
                  }

                  Label {
                        text: qsTr("End BPM:")
                  }
                  TextField {
                        id: endBPMvalue
                        placeholderText: '60'
                        validator: DoubleValidator { bottom: 1;/* top: 512;*/ decimals: 1; notation: DoubleValidator.StandardNotation; }
                        implicitHeight: 24
                  }

                  GroupBox {
                    Layout.columnSpan: 2
                    title: "Early / Late"
                    RowLayout {
                      Slider {
                        id: linearity
                        minimumValue: 0.001
                        maximumValue: 0.999
                        value: 0.5
                      }
                    }
                  }

                  Button {
                        id: applyButton
                        Layout.columnSpan: 2
                        text: qsTranslate("PrefsDialogBase", "Apply")
                        onClicked: {
                              applyTempoChanges();
                              Qt.quit();
                        }
                  }
            }
      }
}
// vim: ft=javascript
