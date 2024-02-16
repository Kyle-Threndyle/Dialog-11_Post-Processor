/**
  Copyright (C) 2012-2013 by Autodesk, Inc.
  All rights reserved.

  Deckel Dialog 11 post processor configuration.

  $Revision: 42285 2a92613bd2b26bbe483938c4c193a033ed9d6f3f $
  $Date: 2019-04-01 14:08:11 $

  FORKID {3EA6DF37-22CE-487c-AEB8-CCC2AD82123E}
*/

description = "Deckel Dialog 11";
vendor = "Deckel";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2013 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 40783;

longDescription =
  "Post for Deckel Dialog 11. Note that there are quite some difference between the Dialog 11 controls so this post would most likely need further customization to work properly for the specific control.";

extension = "nc";
programNameIsInteger = true;
setCodePage("ascii");

capabilities = CAPABILITY_MILLING;
tolerance = spatial(0.002, MM);

highFeedrate = unit == IN ? 100 : 1000;
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(360);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 1, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  retractZ: 5, // CHANGE SO IT UPDATES WITH IN/MM 5IN 125MM
  useToolNumberForCompensation: true, // use tool number of compensation
  scale: false, // use 1000 scaling for XYZ //set by Kyle Threndyle Nov 03 2019
  useG0Star2: false, // use G0*2 for rapid moves in more than one axis
};

// user-defined property definitions
propertyDefinitions = {
  showSequenceNumbers: {
    title: "Use sequence numbers",
    description: "Use sequence numbers for each block of outputted code.",
    group: 1,
    type: "boolean",
  },
  sequenceNumberStart: {
    title: "Start sequence number",
    description: "The number at which to start the sequence numbers.",
    group: 1,
    type: "integer",
  },
  sequenceNumberIncrement: {
    title: "Sequence number increment",
    description:
      "The amount by which the sequence number is incremented by in each block.",
    group: 1,
    type: "integer",
  },
  separateWordsWithSpace: {
    title: "Separate words with space",
    description: "Adds spaces between words if 'yes' is selected.",
    type: "boolean",
  },
  retractZ: {
    title: "Retract Z value",
    description: "Specifies the amount to retract in Z.",
    type: "number",
  },
  useToolNumberForCompensation: {
    title: "Use tool number for compensation",
    description: "Use tool numbers for compensation output.",
    type: "boolean",
  },
  scale: {
    title: "1000 Scaling for XYZ",
    description: "Enable to scale the XYZ axis by 1000.",
    type: "boolean",
  },
  useG0Star2: {
    title: "Use G0*2 for rapid moves",
    description: "Enable to use G0*2 for rapid moves in more than one axis.",
    type: "boolean",
  },
};

var singleLineCoolant = false; // specifies to output multiple coolant codes in one line rather than in separate lines
// samples:
// {id: COOLANT_THROUGH_TOOL, on: 88, off: 89}
// {id: COOLANT_THROUGH_TOOL, on: [8, 88], off: [9, 89]}
var coolants = [
  { id: COOLANT_FLOOD, on: 8 },
  { id: COOLANT_MIST },
  { id: COOLANT_THROUGH_TOOL },
  { id: COOLANT_AIR },
  { id: COOLANT_AIR_THROUGH_TOOL },
  { id: COOLANT_SUCTION },
  { id: COOLANT_FLOOD_MIST },
  { id: COOLANT_FLOOD_THROUGH_TOOL },
  { id: COOLANT_OFF, off: 9 },
];

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var offset = 50;

var oFormat = createFormat({ decimals: 0 });
var gFormat = createFormat({ prefix: "G", decimals: 0 });
var mFormat = createFormat({ prefix: "M", decimals: 0 });
var uFormat = createFormat({ prefix: "%*", decimals: 0 }); //updated by Kyle Threndyle Nov 03 2019
var nFormat = createFormat({ prefix: "N", decimals: 0 });

var listXYZFormat = createFormat({
  decimals: unit == MM ? 3 : 4,
  forceSign: true,
});
var xyzFormat = createFormat({ decimals: unit == MM ? 3 : 4 });
var feedFormat = createFormat({ decimals: 0 });
var toolFormat = createFormat({ decimals: 0 });
var listOffsetFormat = createFormat({ decimals: 0, width: 2, zeropad: true });
var offsetFormat = createFormat({
  decimals: 0,
  width: 2,
  zeropad: true,
  forceSign: true,
});
var rpmFormat = createFormat({ decimals: 0, forceSign: false }); //updated by Kyle Threndyle Nov 03 2019
var secFormat = createFormat({ decimals: 1 }); // seconds - range 0.1-99.9
var taperFormat = createFormat({ decimals: 1, scale: DEG });

var toolspecFormat = createFormat({ decimals: unit == IN ? 5 : 4 }); //added by Kyle Threndyle Nov 03 2019

var xOutput = createVariable({ prefix: "X" }, xyzFormat);
var yOutput = createVariable({ prefix: "Y" }, xyzFormat);
var zOutput = createVariable(
  {
    onchange: function () {
      retracted = false;
    },
    prefix: "Z",
  },
  xyzFormat
);
var feedOutput = createVariable({ prefix: "F" }, feedFormat);
var sOutput = createVariable({ prefix: "S", force: true }, rpmFormat);

// circular output
var iOutput = createReferenceVariable({ prefix: "II", force: true }, xyzFormat); //updated by Kyle Threndyle Nov 03 2019
var jOutput = createReferenceVariable({ prefix: "JI", force: true }, xyzFormat); //updated by Kyle Threndyle Nov 03 2019
var kOutput = createReferenceVariable({ prefix: "KI", force: true }, xyzFormat); //updated by Kyle Threndyle Nov 03 2019

var gMotionModal = createModal({}, gFormat); // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // G90-91
var gPlaneModal = createModal(
  {
    onchange: function () {
      gMotionModal.reset();
    },
  },
  gFormat
); // G17-19
var gCycleModal = createModal({ force: true }, gFormat); // G81, ...

var WARNING_WORK_OFFSET = 0;

// collected state
var sequenceNumber;
var currentWorkOffset;
var nextCycleCall = 1;
var cycleCalls = "";
var retracted = false; // specifies that the tool has been retracted to the safe plane
var programName; //updated by Kyle Threndyle Nov 03 2019
/**
  Writes the specified block.
*/
function writeBlock() {
  var text = formatWords(arguments);
  if (!text) {
    return;
  }
  if (properties.showSequenceNumbers) {
    writeWords2(nFormat.format(sequenceNumber), arguments);
    sequenceNumber += properties.sequenceNumberIncrement;
    if (sequenceNumber >= 10000) {
      sequenceNumber = properties.sequenceNumberStart;
    }
  } else {
    writeWords(arguments);
  }
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(
    "[" + filterText(String(text).toUpperCase(), permittedCommentChars) + "]"
  ); //updated by Kyle Threndyle Nov 03 2019
}

function onOpen() {
  if (properties.scale) {
    listXYZFormat = createFormat({
      decimals: 0,
      width: 6,
      zeropad: true,
      forceSign: true,
      scale: 1000,
    });
    xyzFormat = createFormat({ decimals: 0, scale: 1000 });

    xOutput = createVariable({ prefix: "X" }, xyzFormat);
    yOutput = createVariable({ prefix: "Y" }, xyzFormat);
    zOutput = createVariable({ prefix: "Z" }, xyzFormat);

    iOutput = createReferenceVariable({ prefix: "II", force: true }, xyzFormat); //updated by Kyle Threndyle Nov 03 2019
    jOutput = createReferenceVariable({ prefix: "JI", force: true }, xyzFormat); //updated by Kyle Threndyle Nov 03 2019
    kOutput = createReferenceVariable({ prefix: "KI", force: true }, xyzFormat); //updated by Kyle Threndyle Nov 03 2019
  }

  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;
  var programId;
  if (programName) {
    try {
      programId = getAsInt(programName);
    } catch (e) {
      error(localize("Numbers only bud!")); //updated by Kyle Threndyle Nov 03 2019
      return;
    }
    if (!(programId >= 1 && programId <= 9999)) {
      //updated by Kyle Threndyle Nov 03 2019
      error(
        localize(
          "Don't get all fancy with your big numbers. Godzilla only reads program numbers between 1 and 9999."
        )
      );
      return;
    }
    writeln("%" + oFormat.format(programId) + "*%"); //updated by Kyle Threndyle Nov 03 2019
  } else {
    error(localize("You need to name your program stupid."));
    return;
  }

  if (programComment) {
    writeComment(programComment);
  }

  writeln(
    "G90 G64" +
      (unit == IN ? " G70" : " G71") +
      SP +
      "[ABSOLUTE MODE, SMOOTHING ON, " +
      (unit == IN ? "IMPERIAL DIMENSIONS" : "METRIC DIMENSIONS") +
      "]"
  ); //updated by Kyle Threndyle Nov 03 2019
  {
    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var l = properties.useToolNumberForCompensation
          ? tool.number
          : tool.lengthOffset;
        if (l <= 0 || l > offset) {
          warning(localize("The length offset is invalid."));
        }
        // writeWords("D" + listOffsetFormat.format(l), listXYZFormat.format(0) /*, "( " + getToolTypeName(tool.type) + " )"*/);   //updated by Kyle Threndyle Nov 03 2019
      }

      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var d = properties.useToolNumberForCompensation
          ? tool.number
          : tool.diameterOffset;
        if (d <= 0 || d > offset) {
          warning(localize("The diameter offset is invalid."));
        }
        //writeWords("D" + listOffsetFormat.format(d + offset), listXYZFormat.format(tool.diameter/2) /*, "( " + getToolTypeName(tool.type) + " )"*/);  //updated by Kyle Threndyle Nov 03 2019
      }
    }
  }

  // dump tool information
  if (false) {
    var zRanges = {};
    if (is3D()) {
      var numberOfSections = getNumberOfSections();
      for (var i = 0; i < numberOfSections; ++i) {
        var section = getSection(i);
        var zRange = section.getGlobalZRange();
        var tool = section.getTool();
        if (zRanges[tool.number]) {
          zRanges[tool.number].expandToRange(zRange);
        } else {
          zRanges[tool.number] = zRange;
        }
      }
    }

    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment =
          "T" +
          toolFormat.format(tool.number) +
          "  " +
          "D=" +
          xyzFormat.format(tool.diameter) +
          " " +
          localize("CR") +
          "=" +
          xyzFormat.format(tool.cornerRadius);
        if (tool.taperAngle > 0 && tool.taperAngle < Math.PI) {
          comment +=
            " " +
            localize("TAPER") +
            "=" +
            taperFormat.format(tool.taperAngle) +
            localize("deg");
        }
        if (zRanges[tool.number]) {
          comment +=
            " - " +
            localize("ZMIN") +
            "=" +
            xyzFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
  }
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onParameter(name, value) {}

function isProbeOperation() {
  return (
    hasParameter("operation-strategy") &&
    getParameter("operation-strategy") == "probe"
  );
}

function onSection() {
  var insertToolCall =
    isFirstSection() ||
    (currentSection.getForceToolChange &&
      currentSection.getForceToolChange()) ||
    tool.number != getPreviousSection().getTool().number;

  retracted = false;
  /*
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  */
  var newWorkPlane =
    isFirstSection() ||
    !isSameDirection(
      getPreviousSection().getGlobalFinalToolAxis(),
      currentSection.getGlobalInitialToolAxis()
    ) ||
    (currentSection.isOptimizedForMachine() &&
      getPreviousSection().isOptimizedForMachine() &&
      Vector.diff(
        getPreviousSection().getFinalToolAxisABC(),
        currentSection.getInitialToolAxisABC()
      ).length > 1e-4) ||
    (!machineConfiguration.isMultiAxisConfiguration() &&
      currentSection.isMultiAxis()) ||
    (!getPreviousSection().isMultiAxis() && currentSection.isMultiAxis()) ||
    (getPreviousSection().isMultiAxis() && !currentSection.isMultiAxis()); // force newWorkPlane between indexing and simultaneous operations
  if (insertToolCall /*|| newWorkOffset*/ || newWorkPlane) {
    zOutput.reset();
  }

  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }

  if (insertToolCall) {
    setCoolant(COOLANT_OFF);

    if (tool.number > 99) {
      warning(localize("Your tool number is TOO DAMN HIGH! 1-99 please.")); //updated by Kyle Threndyle Nov 03 2019
    }

    writeBlock(
      gMotionModal.format(0),
      zOutput.format(properties.retractZ),
      "TT" + toolFormat.format(tool.number) + SP + "M6" + SP
    ); //updated by Kyle Threndyle Nov 03 2019 and Nov 9 2021

    if (tool.comment) {
      writeBlock("[TOOL DESCRIPTION: " + tool.comment + "]"); //updated by Kyle Threndyle Nov 03 2019
    }
    writeBlock(
      "[TOOL DIAMETER = " +
        toolspecFormat.format(tool.diameter) +
        (unit == IN ? "IN" : "MM") +
        ", TOOL RADIUS = " +
        toolspecFormat.format(tool.diameter / 2) +
        (unit == IN ? "IN" : "MM") +
        "]"
    ); //updated by Kyle Threndyle Nov 03 2019

    var showToolZMin = false;
    if (showToolZMin) {
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        var zRange = currentSection.getGlobalZRange();
        var number = tool.number;
        for (var i = currentSection.getId() + 1; i < numberOfSections; ++i) {
          var section = getSection(i);
          if (section.getTool().number != number) {
            break;
          }
          zRange.expandToRange(section.getGlobalZRange());
        }
        //writeComment(localize("ZMIN") + "=" + zRange.getMinimum());   //updated by Kyle Threndyle Nov 03 2019
      }
    }
  }

  if (
    insertToolCall ||
    forceSpindleSpeed ||
    isFirstSection() ||
    rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent()) ||
    tool.clockwise != getPreviousSection().getTool().clockwise
  ) {
    forceSpindleSpeed = false;

    if (spindleSpeed < 1) {
      error(localize("Spindle speed out of range."));
      return;
    }
    if (spindleSpeed > 6300) {
      error(
        localize(
          "Spindle speed is TOO DAMN HIGH! Reset spindle speed between 1-6300 rpm."
        )
      );
    }
    writeBlock(
      sOutput.format((tool.clockwise ? 1 : -1) * spindleSpeed) + SP + "M3" //updated by Kyle Threndyle Nov 03 2019
    );
  }

  /*
  // wcs
  if (insertToolCall) { // force work offset when changing tool
    currentWorkOffset = undefined;
  }
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified."), WARNING_WORK_OFFSET);
  }
  if (workOffset > 0) {
    if (workOffset > 6) {
      error(localize("Work offset out of range."));
      return;
    } else {
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }
*/

  forceXYZ();

  {
    // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  // set coolant after we have positioned at Z
  setCoolant(tool.coolant); //updated by Kyle Threndyle Nov 03 2019 " writeBlock("G4F5 [DWELL FOR COOLANT START]")

  forceAny();
  gMotionModal.reset();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted && !insertToolCall) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    }
  }

  if (insertToolCall) {
    gMotionModal.reset();

    writeBlock(
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y)
    );
    writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
  } else {
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y)
    );
  }

  if (insertToolCall) {
    gPlaneModal.reset();
  }
}

function onDwell(seconds) {
  if (seconds > 99.9) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.1, seconds, 99.9);
  writeBlock(gFormat.format(4), "F" + secFormat.format(seconds));
}

function onSpindleSpeed(spindleSpeed) {
  writeBlock(
    sOutput.format((tool.clockwise ? 1 : -1) * spindleSpeed) +
      SP +
      (tool.clockwise ? "M3" : "M4")
  ); //updated by Kyle Threndyle Nov 03 2019
}

function onCycle() {
  writeBlock(gPlaneModal.format(17));
}

function onCyclePoint(x, y, z) {
  if (!isSameDirection(getRotation().forward, new Vector(0, 0, 1))) {
    expandCyclePoint(x, y, z);
    return;
  }
  if (true) {
    repositionToCycleClearance(cycle, x, y, z);

    if (cycleCalls == "") {
      cycleCalls = EOL;
    }

    var F = cycle.feedrate;

    var S = (tool.clockwise ? 1 : -1) * spindleSpeed;
    var P = !cycle.dwell ? 0 : clamp(0.1, cycle.dwell, 99.9); // in seconds

    writeBlock(feedOutput.format(F));

    switch (cycleType) {
      case "drilling": //updated by Kyle Threndyle Nov 03 2019
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),

          writeBlock(
            gCycleModal.format(81),
            //feedOutput.format(F),
            //sOutput.format(S),
            "OA" + xyzFormat.format(cycle.stock),
            "TA" + xyzFormat.format(cycle.bottom),
            "EA" + xyzFormat.format(cycle.clearance),
            "SA" + xyzFormat.format(cycle.clearance)
          ) + EOL;
        break;
      case "counter-boring":
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(81),
            feedOutput.format(F),
            sOutput.format(S),
            "Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            conditional(P > 0, gFormat.format(4)),
            conditional(P > 0, "F" + secFormat.format(P)),
            "Z" + xyzFormat.format(cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      case "chip-breaking":
        cycleCalls +=
          // formatWords(
          //   writeln("%" + oFormat.format(programName) + "*" + nextCycleCall),
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(82),
            feedOutput.format(F),
            sOutput.format(S),
            "Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            "Z" + xyzFormat.format(-cycle.incrementalDepth),
            "Z" + xyzFormat.format(machineParameters.chipBreakingDistance),
            conditional(P > 0, gFormat.format(4)),
            conditional(P > 0, "F" + secFormat.format(P)),
            "Z" + xyzFormat.format(cycle.clearance - cycle.retract),
            writeln("?")
          ) + EOL;
        break;
      case "deep-drilling": //needs more work //updated by Kyle Threndyle Nov 03 2019
        cycleCalls +=
          // formatWords(
          //writeln("%" + programName + "*" + uFormat.format(nextCycleCall)),
          // uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(83),
            //feedOutput.format(F),
            //sOutput.format(S),
            "TA" + xyzFormat.format(cycle.bottom),
            "MI" + xyzFormat.format(cycle.incrementalDepth),
            "SA" + xyzFormat.format(cycle.clearance),
            "EA" + xyzFormat.format(cycle.clearance),
            conditional(
              cycle.incrementalDepthReduction != 0,
              "DI" + xyzFormat.format(-cycle.incrementalDepthReduction)
            ),
            conditional(P > 0, gFormat.format(4)),
            conditional(P > 0, "F" + secFormat.format(P)),
            "OA" + xyzFormat.format(cycle.stock) //old (cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      case "tapping":
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(84),
            //feedFormat.format(tool.getTappingFeedrate()),
            //sOutput.format(S),
            "OA" + xyzFormat.format(cycle.stock), //updated by Kyle Threndyle Nov 03 2019
            "TA" + xyzFormat.format(cycle.bottom), //updated by Kyle Threndyle Nov 03 2019
            "EA" + xyzFormat.format(cycle.clearance), //updated by Kyle Threndyle Nov 03 2019
            "SA" + xyzFormat.format(cycle.clearance), //updated by Kyle Threndy
            "ST" + xyzFormat.format(tool.getThreadPitch())
            //"Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            //"Z" + xyzFormat.format(cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      case "left-tapping":
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(84),
            feedFormat.format(tool.getTappingFeedrate()),
            sOutput.format(S),
            "Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            "Z" + xyzFormat.format(cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      case "right-tapping":
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(84),
            feedFormat.format(tool.getTappingFeedrate()),
            sOutput.format(S),
            "Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            "Z" + xyzFormat.format(cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      case "reaming":
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(85),
            feedOutput.format(F),
            sOutput.format(S),
            "Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            conditional(P > 0, gFormat.format(4)),
            conditional(P > 0, "F" + secFormat.format(P)),
            "Z" + xyzFormat.format(cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      case "boring":
        cycleCalls +=
          // formatWords(
          //   uFormat.format(nextCycleCall),
          writeBlock(
            gCycleModal.format(86),
            feedOutput.format(F),
            sOutput.format(S),
            "Z" + xyzFormat.format(-(cycle.retract - cycle.bottom)),
            conditional(P > 0, gFormat.format(4)),
            conditional(P > 0, "F" + secFormat.format(P)),
            "Z" + xyzFormat.format(cycle.clearance - cycle.retract)
          ) + EOL;
        break;
      default:
        expandCyclePoint(x, y, z);
    }
  }

  if (cycleExpanded) {
    expandCyclePoint(x, y, z);
  } else {
    //writeBlock(feedOutput.format(cycle.feedrate));
    writeBlock(gMotionModal.format(0), xOutput.format(x), yOutput.format(y));
    //writeBlock(uFormat.format(nextCycleCall));
    nextCycleCall += 0; //KT changed from 1 to 0 to stop %*1 from indexing on each drill
  }
}

function onCycleEnd() {}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onRapid(_x, _y, _z) {
  if (pendingRadiusCompensation >= 0) {
    error(
      localize("Radius compensation mode cannot be changed at rapid traversal.")
    );
    return;
  }

  var movingAxes = 0;
  movingAxes |= xyzFormat.areDifferent(_x, xOutput.getCurrent()) ? 1 : 0;
  movingAxes |= xyzFormat.areDifferent(_y, yOutput.getCurrent()) ? 2 : 0;
  movingAxes |= xyzFormat.areDifferent(_z, zOutput.getCurrent()) ? 4 : 0;

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);

  if (x || y || z) {
    if (movingAxes == 1 || movingAxes == 2 || movingAxes == 4) {
      writeBlock(gMotionModal.format(0), x, y, z); // axes are not synchronized
      feedOutput.reset();
    } else {
      if (properties.useG0Star2) {
        gMotionModal.reset();
        writeBlock(gMotionModal.format(0) + "*2", x, y, z);
        feedOutput.reset();
      } else {
        writeBlock(
          gMotionModal.format(1),
          x,
          y,
          z,
          feedOutput.format(highFeedrate)
        );
      }
    }
  }
}

function onLinear(_x, _y, _z, feed) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      writeBlock(gPlaneModal.format(17));
      var d = properties.useToolNumberForCompensation
        ? tool.number
        : tool.diameterOffset;
      if (d <= 0 || d > offset) {
        warning(localize("The diameter offset is invalid."));
      }
      var useDWord = false;
      switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(
            gMotionModal.format(1),
            gFormat.format(41),
            x,
            y,
            conditional(useDWord, "D" + offsetFormat.format(d + offset)),
            f,
            gFormat.format(64),
            mFormat.format(62)
          );
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(
            gMotionModal.format(1),
            gFormat.format(42),
            x,
            y,
            conditional(useDWord, "D" + offsetFormat.format(d + offset)),
            f,
            gFormat.format(64),
            mFormat.format(62)
          );
          break;
        default:
          writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) {
      // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error(
      localize(
        "Radius compensation cannot be activated/deactivated for a circular move."
      )
    );
    return;
  }

  if (false && isHelical()) {
    var t = tolerance;
    if (hasParameter("operation:tolerance")) {
      t = getParameter("operation:tolerance");
    }
    linearize(t);
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    switch (getCircularPlane()) {
      case PLANE_XY:
        writeBlock(
          gPlaneModal.format(17),
          gMotionModal.format(clockwise ? 2 : 3),
          zOutput.format(z),
          iOutput.format(cx - start.x, 0),
          jOutput.format(cy - start.y, 0),
          feedOutput.format(feed)
        );
        break;
      case PLANE_ZX:
        writeBlock(
          gPlaneModal.format(18),
          gMotionModal.format(clockwise ? 2 : 3),
          yOutput.format(y),
          iOutput.format(cx - start.x, 0),
          kOutput.format(cz - start.z, 0),
          feedOutput.format(feed)
        );
        break;
      case PLANE_YZ:
        writeBlock(
          gPlaneModal.format(19),
          gMotionModal.format(clockwise ? 2 : 3),
          xOutput.format(x),
          jOutput.format(cy - start.y, 0),
          kOutput.format(cz - start.z, 0),
          feedOutput.format(feed)
        );
        break;
      default:
        var t = tolerance;
        if (hasParameter("operation:tolerance")) {
          t = getParameter("operation:tolerance");
        }
        linearize(t);
    }
  } else {
    switch (getCircularPlane()) {
      case PLANE_XY:
        xOutput.reset();
        yOutput.reset();
        writeBlock(
          gPlaneModal.format(17),
          gMotionModal.format(clockwise ? 2 : 3),
          xOutput.format(x),
          yOutput.format(y),
          zOutput.format(z),
          iOutput.format(cx - start.x, 0),
          jOutput.format(cy - start.y, 0),
          feedOutput.format(feed)
        );
        break;
      case PLANE_ZX:
        zOutput.reset();
        xOutput.reset();
        writeBlock(
          gPlaneModal.format(18),
          gMotionModal.format(clockwise ? 2 : 3),
          xOutput.format(x),
          yOutput.format(y),
          zOutput.format(z),
          iOutput.format(cx - start.x, 0),
          kOutput.format(cz - start.z, 0),
          feedOutput.format(feed)
        );
        break;
      case PLANE_YZ:
        yOutput.reset();
        zOutput.reset();
        writeBlock(
          gPlaneModal.format(19),
          gMotionModal.format(clockwise ? 2 : 3),
          xOutput.format(x),
          yOutput.format(y),
          zOutput.format(z),
          jOutput.format(cy - start.y, 0),
          kOutput.format(cz - start.z, 0),
          feedOutput.format(feed)
        );
        break;
      default:
        var t = tolerance;
        if (hasParameter("operation:tolerance")) {
          t = getParameter("operation:tolerance");
        }
        linearize(t);
    }
  }
}

var currentCoolantMode = COOLANT_OFF;
var coolantOff = undefined;

function setCoolant(coolant) {
  var coolantCodes = getCoolantCodes(coolant);
  if (Array.isArray(coolantCodes)) {
    if (singleLineCoolant) {
      writeBlock(coolantCodes.join(getWordSeparator()));
    } else {
      for (var c in coolantCodes) {
        writeBlock(coolantCodes[c]);
      }
    }
    return undefined;
  }
  return coolantCodes;
}

function getCoolantCodes(coolant) {
  var multipleCoolantBlocks = new Array(); // create a formatted array to be passed into the outputted line
  if (!coolants) {
    error(localize("Coolants have not been defined."));
  }
  if (isProbeOperation()) {
    // avoid coolant output for probing
    coolant = COOLANT_OFF;
  }
  if (coolant == currentCoolantMode) {
    return undefined; // coolant is already active
  }
  if (
    coolant != COOLANT_OFF &&
    currentCoolantMode != COOLANT_OFF &&
    coolantOff != undefined
  ) {
    if (Array.isArray(coolantOff)) {
      for (var i in coolantOff) {
        multipleCoolantBlocks.push(mFormat.format(coolantOff[i]));
      }
    } else {
      multipleCoolantBlocks.push(mFormat.format(coolantOff));
    }
  }

  var m;
  var coolantCodes = {};
  for (var c in coolants) {
    // find required coolant codes into the coolants array
    if (coolants[c].id == coolant) {
      coolantCodes.on = coolants[c].on;
      if (coolants[c].off != undefined) {
        coolantCodes.off = coolants[c].off;
        break;
      } else {
        for (var i in coolants) {
          if (coolants[i].id == COOLANT_OFF) {
            coolantCodes.off = coolants[i].off;
            break;
          }
        }
      }
    }
  }
  if (coolant == COOLANT_OFF) {
    m = !coolantOff ? coolantCodes.off : coolantOff; // use the default coolant off command when an 'off' value is not specified
  } else {
    coolantOff = coolantCodes.off;
    m = coolantCodes.on;
  }

  if (!m) {
    onUnsupportedCoolant(coolant);
    m = 9;
  } else {
    if (Array.isArray(m)) {
      for (var i in m) {
        multipleCoolantBlocks.push(mFormat.format(m[i]));
      }
    } else {
      multipleCoolantBlocks.push(mFormat.format(m));
    }
    currentCoolantMode = coolant;
    return multipleCoolantBlocks; // return the single formatted coolant value
  }
  return undefined;
}

var mapCommand = {
  COMMAND_STOP: 0,
  COMMAND_OPTIONAL_STOP: 1,
  COMMAND_END: 2,
  COMMAND_SPINDLE_CLOCKWISE: 3,
  COMMAND_SPINDLE_COUNTERCLOCKWISE: 4,
  COMMAND_STOP_SPINDLE: 5,
  COMMAND_ORIENTATE_SPINDLE: 19,
  COMMAND_LOAD_TOOL: 6,
};

function onCommand(command) {
  switch (command) {
    case COMMAND_START_SPINDLE:
      onCommand(
        tool.clockwise
          ? COMMAND_SPINDLE_CLOCKWISE
          : COMMAND_SPINDLE_COUNTERCLOCKWISE
      );
      return;
    case COMMAND_LOCK_MULTI_AXIS:
      return;
    case COMMAND_UNLOCK_MULTI_AXIS:
      return;
    case COMMAND_BREAK_CONTROL:
      return;
    case COMMAND_TOOL_MEASURE:
      return;
  }

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  writeBlock(gPlaneModal.format(17));
  if (!isLastSection() && getNextSection().getTool().coolant != tool.coolant) {
    setCoolant(COOLANT_OFF);
  }
  forceAny();
}

/** Output block to do safe retract and/or move to home position. */
function writeRetract() {
  if (arguments.length == 0) {
    error(localize("No axis specified for writeRetract()."));
    return;
  }
  var words = []; // store all retracted axes in an array
  for (var i = 0; i < arguments.length; ++i) {
    let instances = 0; // checks for duplicate retract calls
    for (var j = 0; j < arguments.length; ++j) {
      if (arguments[i] == arguments[j]) {
        ++instances;
      }
    }
    if (instances > 1) {
      // error if there are multiple retract calls for the same axis
      error(localize("Cannot retract the same axis twice in one line"));
      return;
    }
    switch (arguments[i]) {
      case X:
        words.push(
          "X" +
            xyzFormat.format(
              machineConfiguration.hasHomePositionX()
                ? machineConfiguration.getHomePositionX()
                : 0
            )
        );
        break;
      case Y:
        words.push(
          "Y" +
            xyzFormat.format(
              machineConfiguration.hasHomePositionY()
                ? machineConfiguration.getHomePositionY()
                : 0
            )
        );
        break;
      case Z:
        words.push("Z" + xyzFormat.format(properties.retractZ));
        retracted = true; // specifies that the tool has been retracted to the safe plane
        zOutput.reset();
        break;
      default:
        error(localize("Bad axis specified for writeRetract()."));
        return;
    }
  }
  if (words.length > 0) {
    writeBlock(gMotionModal.format(0), words); // retract
  }
}

function onClose() {
  setCoolant(COOLANT_OFF);
  // writeln("T" + toolFormat.format(0)); // cancel length offset
  writeRetract(Z);

  writeBlock(mFormat.format(30));
  //writeln("?");//updated by Kyle Threndyle Nov 03 2019
  //CYCLE LIST
  //writeln("N0 [CYCLE LIST]"); //updated by Kyle Threndyle Nov 03 2019
  // writeln("%" + (programName) + "*" + nextCycleCall) ////update to add amultiple drill cycles. updated by Kyle Threndyle Nov 03 2019
  //write(cycleCalls);
  //writeln("?");//updated by Kyle Threndyle Nov 03 2019
  writeln("");
  //TOOL TABLE
  //writeln("%" + (programName) + "*T")
  //writeBlock("T" + (tool.number) + " I/M:I R" + xyzFormat.format(tool.diameter)/2) //update to add amultiple tools
  writeln("%");
}
