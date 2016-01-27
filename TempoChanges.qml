//=============================================================================
//  TempoChanges Plugin
//
//  Based on the principle of hidden tempo markings mentioned in the 2.0 handbook
//  Attempts to create a linear ritartando or accelerando
//
//  Copyright (C) 2016 Johan Temmerman (jeetee)
//=============================================================================
import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1

import MuseScore 1.0

MuseScore {
      menuPath: "Plugins.TempoChanges"
      version: "2.0"
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
            var sel = getSelection();
            if (sel === null) { //no selection
                  console.log('No selection');
                  return;
            }
            var durationTicks = sel.end - sel.start;

            var beatBaseItem = beatBase.model.get(beatBase.currentIndex);
            var startTempo = getTempoFromInput(startBPMvalue) / beatBaseItem.div;
            var endTempo = getTempoFromInput(endBPMvalue) / beatBaseItem.div;
            var tempoRange = (endTempo - startTempo);
            console.log('Applying to selection [' + sel.start + ', ' + sel.end + '] = ' + durationTicks);
            console.log(startTempo + ' (' + (startTempo*60) + ') -> ' + endTempo + ' (' + (endTempo*60) + ') = ' + tempoRange);

            var cursor = curScore.newCursor();
            cursor.rewind(1); //start of selection

            curScore.startCmd();
            //add indicative text if required
            if (startTextValue.text != "") {
                  var startText = newElement(Element.STAFF_TEXT);
                  startText.text = startTextValue.text;
                  cursor.add(startText);
            }

            while (cursor.segment && (cursor.tick < sel.end)) {
                  //linear interpolation of the desired tempo
                  var newTempo = ((cursor.tick - sel.start) / durationTicks * tempoRange) + startTempo;
                  applyTempoToSegment(newTempo, cursor, false, beatBaseItem);
                  cursor.next();
            }
            //processed selection, now end at new tempo with a visible element
            if (cursor.segment) { //but only if there still is an element availble
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
            tempo = parseInt(tempo) / 60;
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

      function applyTempoToSegment(tempo, cursor, visible, beatBaseItem)
      {
            console.log('Applying new tempo: ' + tempo);
            var tempoElement = findExistingTempoElement(cursor.segment);
            var addTempo = false;
            if (tempoElement === undefined) {
                  tempoElement = newElement(Element.TEMPO_TEXT);
                  addTempo = true;
            }
            tempoElement.text = beatBaseItem.sym + ' = ' + Math.round(tempo * 60 * beatBaseItem.div);
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
                        text: qsTranslate("Ms::MuseScore", "Staff Text") + ": "
                  }
                  TextField {
                        id: startTextValue
                        placeholderText: 'rit. / accel.'
                        implicitHeight: 24
                  }

                  Label {
                        text: qsTr("BPM beat: ")
                  }
                  ComboBox {
                        id: beatBase
                        model: ListModel {
                              id: beatBaseList
                              //div is a tempo-divider compared to a crotchet      
                              //ListElement { text: '\uE1D0';               div: 8     ; sym: '<sym>metNoteDoubleWhole</sym>' } // 2/1
                              ListElement { text: '\uE1D2';               div: 4     ; sym: '<sym>metNoteWhole</sym>' } // 1/1
                              //ListElement { text: '\uE1D3 \uE1E7 \uE1E7'; div: 3.5   ; sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/2..
                              ListElement { text: '\uE1D3 \uE1E7';        div: 3     ; sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym>' } // 1/2.
                              ListElement { text: '\uE1D3';               div: 2     ; sym: '<sym>metNoteHalfUp</sym>' } // 1/2
                              ListElement { text: '\uE1D5 \uE1E7 \uE1E7'; div: 1.75  ; sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/4..
                              ListElement { text: '\uE1D5 \uE1E7';        div: 1.5   ; sym: '<sym>metNoteQuarterUp</sym><sym>metAugmentationDot</sym>' } // 1/4.
                              ListElement { text: '\uE1D5';               div: 1     ; sym: '<sym>metNoteQuarterUp</sym>' } // 1/4
                              ListElement { text: '\uE1D7 \uE1E7 \uE1E7'; div: 0.875 ; sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/8..
                              ListElement { text: '\uE1D7 \uE1E7';        div: 0.75  ; sym: '<sym>metNote8thUp</sym><sym>metAugmentationDot</sym>' } // 1/8.
                              ListElement { text: '\uE1D7';               div: 0.5   ; sym: '<sym>metNote8thUp</sym>' } // 1/8
                              ListElement { text: '\uE1D9 \uE1E7 \uE1E7'; div: 0.4375; sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } //1/16..
                              ListElement { text: '\uE1D9 \uE1E7';        div: 0.375 ; sym: '<sym>metNote16thUp</sym><sym>metAugmentationDot</sym>' } //1/16.
                              ListElement { text: '\uE1D9';               div: 0.25  ; sym: '<sym>metNote16thUp</sym>' } //1/16
                        }
                        currentIndex: 5
                        implicitHeight: 42
                        style: ComboBoxStyle {
                              font.family: 'MScore Text'
                              font.pointSize: 18
                              padding.top: 5
                              padding.bottom: -10
                        }
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
