//=============================================================================
//  TempoChanges Plugin
//
//  Based on the principle of hidden tempo markings mentioned in the handbook
//  Attempts to create a ritartando or accelerando
//
//  Copyright (C) 2016-2019 Johan Temmerman (jeetee)
//                2019 billhails & BSG & jeetee: added power curves
//=============================================================================
import QtQuick 2.2
import QtQuick.Controls 1.1
import QtQuick.Controls.Styles 1.3
import QtQuick.Layouts 1.1
import QtQuick.Window 2.2
import Qt.labs.settings 1.0

import MuseScore 3.0

MuseScore {
      menuPath: "Plugins.TempoChanges"
      version: "3.4.1"
      description: qsTr("Creates hidden tempo markers.\nSee also: https://musescore.org/en/handbook/3/tempo#ritardando-accelerando")
      pluginType: "dialog"
      requiresScore: true
      id: 'pluginId'

      property int margin: 10
      property int previousBeatIndex: 5

      width:  360
      height: 240

      onRun: {
            if ((mscoreMajorVersion == 3) && (mscoreMinorVersion == 0) && (mscoreUpdateVersion < 5)) {
                  console.log(qsTr("Unsupported MuseScore version.\nTempoChanges needs v3.0.5 or above.\n"));
                  pluginId.parent.Window.window.close();
                  return;
            }
            prefillSurroundingTempo();
      }

      Settings {
            id: settings
            category: "Plugin-TempoChanges"
            property alias midpointSlider: midpointSlider.value
            property alias curveType: curveType.currentIndex
            property alias beatBase: beatBase.currentIndex
      }

//      Settings {
//            id: mscoreSettings
//            category: "ui/application"
//            //property var globalStyle //MS::MuseScoreStyleType - enum doesn't translate to a value in the plugin framework
//      }

      function prefillSurroundingTempo()
      {
            var sel = getSelection();
            if (sel === null) { //no selection
                  console.log('No selection');
                  return;
            }
            var beatBaseItem = beatBase.model.get(beatBase.currentIndex);
            // Start Tempo
            var foundTempo = undefined;
            var segment = sel.startSeg;
            while ((foundTempo === undefined) && (segment)) {
                  foundTempo = findExistingTempoElement(segment);
                  segment = segment.prev;
            }
            if (foundTempo !== undefined) {
                  console.log('Found start tempo text = ' + foundTempo.text);
                  // Try to extract base beat
                  var targetBeatBaseIndex = findBeatBaseFromMarking(foundTempo);
                  if (targetBeatBaseIndex != -1) {
                        // Apply it
                        previousBeatIndex = targetBeatBaseIndex;
                        beatBase.currentIndex = targetBeatBaseIndex;
                        beatBaseItem = beatBase.model.get(targetBeatBaseIndex);
                  }
                  // Update input field according to the (detected) beat
                  startBPMvalue.placeholderText = Math.round(foundTempo.tempo * 60 / beatBaseItem.mult * 10) / 10;
            }
            // End Tempo
            foundTempo = undefined
            segment = sel.endSeg;
            while ((foundTempo === undefined) && (segment)) {
                  foundTempo = findExistingTempoElement(segment);
                  segment = segment.next;
            }
            if (foundTempo !== undefined) {
                  console.log('Found end tempo text = ' + foundTempo.text);
                  endBPMvalue.placeholderText = Math.round(foundTempo.tempo * 60 / beatBaseItem.mult * 10) / 10;
            }
      }

      /// Analyses tempo marking text to attempt to discover the base beat being used
      /// If a beat is detected, returns the index in the beatBaseList matching the marking
      /// @returns -1 if beat is not detected or not present in our beatBaseList
      function findBeatBaseFromMarking(tempoMarking)
      {
            var metronomeMarkIndex = -1;
            // First look for metronome marking symbols
            var foundTempoText = tempoMarking.text.replace('<sym>space</sym>', '');
            var foundMetronomeSymbols = foundTempoText.match(/(<sym>met.*<\/sym>)+/g);
            if (foundMetronomeSymbols !== null) {
                  // Locate the index in our dropdown matching the found beatString
                  for (metronomeMarkIndex = beatBase.model.count; --metronomeMarkIndex >= 0; ) {
                        if (beatBase.model.get(metronomeMarkIndex).sym == foundMetronomeSymbols[0]) {
                              break; // Found this marking in the dropdown at metronomeMarkIndex
                        }
                  }
            }
            else {
                  // Metronome marking symbols are substituted with their character entity if the text was edited
                  // UTF-16 range [\uECA0 - \uECB6] (double whole - 1024th)
                  for (var beatString, charidx = 0; charidx < foundTempoText.length; charidx++) {
                        beatString = foundTempoText[charidx];
                        if ((beatString >= "\uECA2") && (beatString <= "\uECA9")) {
                              // Found base tempo - continue looking for augmentation dots
                              while (++charidx < foundTempoText.length) {
                                    if (foundTempoText[charidx] == "\uECB7") {
                                          beatString += " \uECB7";
                                    }
                                    else if (foundTempoText[charidx] != ' ') {
                                          break; // No longer augmentation dots or spaces
                                    }
                              }
                              // Locate the index in our dropdown matching the found beatString
                              for (metronomeMarkIndex = beatBase.model.count; --metronomeMarkIndex >= 0; ) {
                                    if (beatBase.model.get(metronomeMarkIndex).text == beatString) {
                                          break; // Found this marking in the dropdown at metronomeMarkIndex
                                    }
                              }
                              break; // Done processing base tempo
                        }
                  }
            }
            return metronomeMarkIndex;
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

            // When we're at the start of the selection (0% tickRange) the output must be the startTempo (0% of the tempotransition)
            // When we're at midpointSlider % of the selection tickRange, the output must be halfway between start & endTempo (50% of the tempotransition)
            // When we're at the end of the selection (100% tickRange) the output must be the endTempo (100% of the tempotransition)
            //
            //
            // We can do this by raising the % tickRange to some power p, because for any p
            // (0% )^p = 0% and (100% )^p = 100%
            // and so we only need calculate p for the current slider value,
            // where we know the result should be 1/2.
            //
            // What power p do we need to raise the current slider value x to, in order to equal 1/2?
            //
            // x^p      = 1/2
            //
            // log(x^p) = log(1/2)
            //
            // p log(x) = log(1/2)
            //
            //            log(1/2)
            // p        = --------
            //             log(x)
            //
            var midPoint = ((curveType.isLinear) ? 50.0 : midpointSlider.value) / 100; //linear == hit midpoint at 50% tickRange
            var p = Math.log(0.5) / Math.log(midPoint);
            // To find the matching tempo for each tick, we perform (%tickrange)^(p)
            for (var trackIdx = 0; trackIdx < cursor.score.ntracks; ++trackIdx) {
                  cursor.rewind(1);
                  cursor.track = trackIdx;

                  while (cursor.segment && (cursor.tick < sel.end)) {
                        //interpolation of the desired tempo
						var curveXpct = (cursor.tick - sel.start) / durationTicks;
                        var outputPct = Math.pow(curveXpct, p);
                        var newTempo = (outputPct * tempoRange) + startTempo;
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
                  startSeg: cursor.segment,
                  end: null,
                  endSeg: null
            };
            cursor.rewind(2); //find end of selection
            if (cursor.tick == 0) {
                  // this happens when the selection includes
                  // the last measure of the score.
                  // rewind(2) goes behind the last segment (where
                  // there's none) and sets tick=0
                  selection.end = curScore.lastSegment.tick + 1;
                  selection.endSeg = curScore.lastSegment;
            }
            else {
                  selection.end = cursor.tick;
                  selection.endSeg = cursor.segment;
            }
            return selection;
      }

      function getFloatFromInput(input)
      {
            var value = input.text;
            if (value == "") {
                  value = input.placeholderText;
            }
            return parseFloat(value);
      }

      function getTempoFromInput(input)
      {
            return getFloatFromInput(input) / 60;
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
            tempoElement.tempoFollowText = true; //allows for manual fiddling by the user afterwards

            if (tempoTracker) {
                  tempoTracker[quarterBaseTempo] = true;
            }
      }

      GridLayout {
            id: 'mainLayout'
            anchors.fill: parent
            anchors.margins: 10
            columns: 3

            focus: true

            Label {
                  text: qsTranslate("Ms::MuseScore", "Staff Text") + ":"
            }
            TextField {
                  id: startTextValue
                  placeholderText: 'rit. / accel.'
                  implicitHeight: 24
            }
            Canvas {
                  id: canvas
                  Layout.rowSpan: 4
                  Layout.minimumWidth: 102
                  Layout.minimumHeight: 102
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  
                  onPaint: {
                        var w = canvas.width;
                        var h = canvas.height;
                        var ctx = getContext("2d");

                        //square plot area
                        var length = (w > h) ? h : w;
                        var top = (h - length) / 2;
                        var left = (w - length) / 2;
                        ctx.clearRect(0, 0, w, h);
                        ctx.fillStyle = '#555555';
                        ctx.fillRect(left, top, length, length);
                        ctx.strokeStyle = '#000000';
                        ctx.lineWidth = 1;
                        ctx.strokeRect(left, top, length, length);

                        //grid lines
                        ctx.strokeStyle = '#888888';
                        ctx.beginPath();
                        var divisions = 4;
                        for (var i = divisions - 1; i > 0; --i) {
                              //vertical
                              ctx.moveTo(left + ((i*length)/divisions), top);
                              ctx.lineTo(left + ((i*length)/divisions), top+length);
                              //horizontal
                              ctx.moveTo(left         , top + ((i*length)/divisions));
                              ctx.lineTo(left + length, top + ((i*length)/divisions));
                        }
                        ctx.stroke();

                        //graph
                        ctx.strokeStyle = '#abd3fb';
                        ctx.lineWidth = 2;
                        var start = getFloatFromInput(startBPMvalue);
                        var end = getFloatFromInput(endBPMvalue);
                        var midPoint = ((curveType.isLinear) ? 50.0 : midpointSlider.value) / 100;
                        ctx.beginPath();
                        ctx.moveTo(left + length, (start > end) ? top + length : top);
                        for (var x = length; x >= 0; --x) {
                              var outputPct = Math.pow((x / length), (Math.log(0.5) / Math.log(midPoint)));
                              var newY = (start > end) ? (top + (outputPct * length)) : (top + length - (outputPct * length));
                              ctx.lineTo(left + x, newY);
                        }
                        ctx.stroke();
                        
                        //write BPMs
                        canvasStartBPM.text = start;
                        canvasStartBPM.topPadding = (start > end) ? (top + 2) : (top + length - canvasStartBPM.contentHeight - 2);
                        canvasEndBPM.text = end;
                        canvasEndBPM.topPadding = (start > end) ? (top + length - canvasEndBPM.contentHeight - 2): (top + 2);
                        //keep them inside the grid or is there enough room next to it?
                        var longestBPMText = Math.max(canvasStartBPM.contentWidth, canvasEndBPM.contentWidth);
                        if ((longestBPMText + 2 + 2) < left) {
                              //outside
                              canvasStartBPM.leftPadding = left - 2 - canvasStartBPM.contentWidth;
                              canvasEndBPM.leftPadding = left - 2 - canvasEndBPM.contentWidth;
                        }
                        else {
                              //inside
                              canvasStartBPM.leftPadding = left + 2;
                              canvasEndBPM.leftPadding = left + 2;
                        }
                  }
                  Label {
                        id: canvasStartBPM
                        color: '#d8d8d8'
                  }
                  Label {
                        id: canvasEndBPM
                        color: '#d8d8d8'
                  }
            } //end of Canvas

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
                        //ListElement { text: '\uECA3 \uECB7 \uECB7'; mult: 3.5   ; sym: '<sym>metNoteHalfUp</sym><sym>metAugmentationDot</sym><sym>metAugmentationDot</sym>' } // 1/2..
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
                        textColor: '#000000'
                        selectedTextColor: '#000000'
                        font.family: 'MScore Text'
                        font.pointSize: 18
                        padding.top: 5
                        padding.bottom: 5
                  }
                  onCurrentIndexChanged: { // update the value fields to match the new beatBase
                        var changeFactor = beatBase.model.get(currentIndex).mult / beatBase.model.get(previousBeatIndex).mult;
                        if (startBPMvalue.text == "") {
                              startBPMvalue.placeholderText = Math.round(getFloatFromInput(startBPMvalue) / changeFactor * 10) / 10;
                        }
                        else {
                              startBPMvalue.text = Math.round(getFloatFromInput(startBPMvalue) / changeFactor * 10) / 10;
                        }
                        if (endBPMvalue.text == "") {
                              endBPMvalue.placeholderText = Math.round(getFloatFromInput(endBPMvalue) / changeFactor * 10) / 10;
                        }
                        else {
                              endBPMvalue.text = Math.round(getFloatFromInput(endBPMvalue) / changeFactor * 10) / 10;
                        }
                        previousBeatIndex = currentIndex; // keep track reference for next change
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
                  onTextChanged: { canvas.requestPaint(); }
            }

            Label {
                  text: qsTr("End BPM:")
            }
            TextField {
                  id: endBPMvalue
                  placeholderText: '60'
                  validator: DoubleValidator { bottom: 1;/* top: 512;*/ decimals: 1; notation: DoubleValidator.StandardNotation; }
                  implicitHeight: 24
                  onTextChanged: { canvas.requestPaint(); }
            }

            ComboBox {
                  id: curveType
                  model: ListModel {
                        ListElement { text: qsTr("Linear") }
                        ListElement { text: qsTr("Curved") }
                  }
                  Layout.preferredWidth: 80

                  property bool isLinear: {
                        return (curveType.currentText === qsTr("Linear"));
                  }

                  onCurrentIndexChanged: {
                        canvas.requestPaint();
                  }
            }
            Label {
                  text: qsTr("midpoint:")
                  Layout.alignment: Qt.AlignRight
            }
            Slider {
                  id: midpointSlider
                  Layout.fillWidth: true

                  minimumValue: 1
                  maximumValue: 99
                  value: 75.0
                  stepSize: 0.1

                  enabled: !curveType.isLinear
                  
                  style: SliderStyle {
                        groove: Rectangle { //background
                              id: grooveRect
                              implicitHeight: 6
                              color: (enabled) ? '#555555' : '#565656'
                              radius: implicitHeight
                              border {
                                    color: '#888888'
                                    width: 1
                              }
                              
                              Rectangle {
                                    //value fill
                                    implicitHeight: grooveRect.implicitHeight
                                    implicitWidth: styleData.handlePosition
                                    color: (enabled) ? '#abd3fb' : '#567186'
                                    radius: grooveRect.radius
                                    border {
                                          color: '#888888'
                                          width: 1
                                    }
                              }
                        }
                        handle: Rectangle {
                              anchors.centerIn: parent
                              color: (enabled) ? (control.pressed ? '#ffffff': '#d8d8d8') : '#565656'
                              border.color: '#666666'
                              border.width: 1
                              implicitWidth: 16
                              implicitHeight: 16
                              radius: 8
                        }
                  }
            }

            Label { 
                  Layout.columnSpan: 2 //just taking up two cells to make the next element align
            }
            RowLayout {
                  Layout.alignment: Qt.AlignHCenter

                  SpinBox {
                        id: sliderValue
                        Layout.preferredWidth: 60

                        minimumValue: midpointSlider.minimumValue
                        maximumValue: midpointSlider.maximumValue
                        value: midpointSlider.value
                        decimals: 1
                        stepSize: midpointSlider.stepSize

                        onValueChanged: {
                              midpointSlider.value = value;
                              canvas.requestPaint();
                        }

                        enabled: !curveType.isLinear
                  }
                  Label { text: '%' }
            }

            Button {
                  id: applyButton
                  Layout.columnSpan: 3
                  text: qsTranslate("PrefsDialogBase", "Apply")
                  onClicked: {
                        applyTempoChanges();
                        pluginId.parent.Window.window.close();
                  }
            }

      }

      Keys.onEscapePressed: {
            pluginId.parent.Window.window.close();
      }
      Keys.onReturnPressed: {
            applyTempoChanges();
            pluginId.parent.Window.window.close();
      }
      Keys.onEnterPressed: {
            applyTempoChanges();
            pluginId.parent.Window.window.close();
      }
}
