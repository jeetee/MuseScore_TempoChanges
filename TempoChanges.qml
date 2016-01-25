//=============================================================================
//  TempoChanges Plugin
//
//  Based on the principle of hidden tempo markings mentioned in the 2.0 handbook
//  Attempts to create a linear ritartando or accelerando
//
//  Copyright (2016) Johan Temmerman (jeetee)
//=============================================================================
import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1

import MuseScore 1.0

MuseScore {
      menuPath: "Plugins.TempoChanges"
      version: "0.3"
      description: qsTr("Creates linear hidden tempo markers.\nSee also: https://musescore.org/en/handbook/tempo-0#ritardando-accelerando")
      pluginType: "dialog"
      //requiresScore: true //not supported before 2.1.0, manual checking onRun

      width:  240
      height: 240

      onRun: {
            if (typeof curScore === 'undefined') {
                  console.log(qsTranslate("QMessageBox", "No score open.\nThis plugin requires an open score to run.\n"));
                  Qt.quit();
            }
      }

      function applyTempoChanges()
      {
            var cursor = curScore.newCursor();
            cursor.rewind(1); //start of selection
            if (!cursor.segment) { //no selection
                  console.log('No selection');
                  return;
            }
            var endTick;
            cursor.rewind(2); //find end of selection
            if (cursor.tick == 0) {
                  // this happens when the selection includes
                  // the last measure of the score.
                  // rewind(2) goes behind the last segment (where
                  // there's none) and sets tick=0
                  endTick = curScore.lastSegment.tick + 1;
            }
            else {
                  endTick = cursor.tick;
            }
            cursor.rewind(1); //move back to start of selection

            var startTick = cursor.tick;
            var durationTicks = endTick - startTick;
            console.log(durationTicks);
            var startTempo = startBPMvalue.text;
            if (startTempo == "") {
                  startTempo = startBPMvalue.placeholderText;
            }
            startTempo = parseInt(startTempo) / 60;
            var endTempo = endBPMvalue.text;
            if (endTempo == "") {
                  endTempo = endBPMvalue.placeholderText;
            }
            endTempo = parseInt(endTempo) / 60;
            var tempoRange = (endTempo - startTempo);
            console.log('Applying to selection [' + startTick + ', ' + endTick + '] = ' + durationTicks);
            console.log(startTempo + ' (' + (startTempo*60) + ') -> ' + endTempo + ' (' + (endTempo*60) + ') = ' + tempoRange);

            curScore.startCmd();
            //add indicative text if required
            if (startTextValue.text != "") {
                  var startText = newElement(Element.STAFF_TEXT);
                  startText.text = startTextValue.text;
                  cursor.add(startText);
            }

            while (cursor.segment && (cursor.tick < endTick)) {
                  //linear interpolation of the desired tempo
                  var newTempo = ((cursor.tick - startTick) / durationTicks * tempoRange) + startTempo;
                  applyTempoToSegment(newTempo, cursor, false);
                  cursor.next();
            }
            //processed selection, now end at new tempo with a visible element
            if (cursor.segment) { //but only if there still is an element availble
                  applyTempoToSegment(endTempo, cursor, true);
            }
            curScore.endCmd(false);
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

      function applyTempoToSegment(tempo, cursor, visible)
      {
            console.log('Applying new tempo: ' + tempo);
            var tempoElement = findExistingTempoElement(cursor.segment);
            var addTempo = false;
            if (tempoElement === undefined) {
                  tempoElement = newElement(Element.TEMPO_TEXT);
                  addTempo = true;
            }
            tempoElement.text = '<sym>metNoteQuarterUp</sym> = ' + Math.round(tempo * 60);
            tempoElement.visible = visible;
            if (addTempo) {
                  cursor.add(tempoElement);
            }
            //changing of tempo can only happen after being added to the segment
            tempoElement.tempo = tempo;
            tempoElement.followText = true; //allows for manual fiddling by the user afterwards
      }

      Rectangle {
            color: "lightgrey"
            anchors.fill: parent

            GridLayout {
                  columns: 2
                  anchors.fill: parent
                  anchors.margins: 10

                  Label {
                        text: qsTr("Start text: ")
                  }
                  TextField {
                        id: startTextValue
                        placeholderText: 'rit. / accel.'
                        implicitHeight: 24
                  }

                  Label {
                        text: qsTr("Start BPM: ")
                  }
                  TextField {
                        id: startBPMvalue
                        placeholderText: '120'
                        validator: IntValidator { bottom: 1;/* top: 512;*/}
                        implicitHeight: 24
                  }

                  Label {
                        text: qsTr("End BPM: ")
                  }
                  TextField {
                        id: endBPMvalue
                        placeholderText: '60'
                        validator: IntValidator { bottom: 1;/* top: 512;*/}
                        implicitHeight: 24
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
