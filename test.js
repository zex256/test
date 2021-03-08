// Copyright 2021 ZEX All Rights Reserved.
var Version = '1.0';
var shell = new ActiveXObject('WScript.Shell');
var fso = new ActiveXObject("Scripting.FileSystemObject");
var dom = new ActiveXObject("MSXML2.DOMDocument.6.0");
var color = new Array();
color[0] = 'aqua';
color[1] = 'seagreen1';
color[2] = 'lightpink';
color[3] = 'cadetblue1';
color[4] = 'greenyellow';
color[5] = 'darkorchid1';
color[6] = 'fuchsia';
color[7] = 'mediumspringgreen';
color[8] = 'gold';
color[9] = 'powderblue';
color[10] = 'orangered';
color[11] = 'green';
color[12] = 'purple';
color[13] = 'red';
color[14] = 'teal';
color[15] = 'magenta';
var digraph = 'digraph profile_ProfileNum_ProfileName {\n\
  graph [\n\
    charset = "UTF-8",\n\
    label = "XmlFileName    Profile No.ProfileNum  ProfileName",\n\
    labelloc = "t",\n\
    labeljust = "c",\n\
    bgcolor = teal,\n\
    fontname = "Source Serif Pro Black",\n\
    fontcolor = white,\n\
    fontsize = 18,\n\
    style = "filled",\n\
    rankdir = LR,\n\
    margin = 0.2,\n\
    splines = spline,\n\
    ranksep = 1.0,\n\
    nodesep = 0.5\n\
  ];\n\
  node [\n\
    shape = box,\n\
    style = "bold,filled",\n\
    fontsize = 12.5,\n\
    fontcolor = black,\n\
    fontname = "Source Serif Pro Black",\n\
    color = gold,\n\
    fillcolor = 1,\n\
    fixedsize = true,\n\
    height = 0.9,\n\
    width = 1.2\n\
  ];\n\
  edge [\n\
    style = solid,\n\
    fontsize = 12,\n\
    fontcolor = gold,\n\
    fontname = "Source Serif Pro Black",\n\
    color = gold,\n\
    labelfloat = true,\n\
    labeldistance = 1.8,\n\
    labelangle = 50\n\
  ];\n\
  // node define\n\
FilterChainManager\
Effector\
Renderer\
}\n';

main(WScript.Arguments);
function main(args) {
  if (!args.length) {
    WScript.Echo('VisualizeSoundServiceXML Version ' + Version + '\n'
        + 'SoundService.XMLファイルを引数に指定して下さい。');
    return;
  }
  var XmlFilePath = args(0);
  dom.async = false;
  dom.load(XmlFilePath);
  if (dom.parseError.errorCode) {
    WScript.Echo('parseError:' + dom.parseError.reason);
    return;
  }
  var Profile = dom.documentElement.getElementsByTagName("Profile");
  for (var i = 0; i < Profile.length; i++) {
    var e = Profile[i];
    var dot = digraph;
    var XmlFileName = fso.GetFileName(XmlFilePath);
    dot = dot.replace(/XmlFileName/g, XmlFileName);
    var ProfileNum  = e.getElementsByTagName("ProfileNum")[0].text;
    dot = dot.replace(/ProfileNum/g, ProfileNum);
    var ProfileName = e.getElementsByTagName("ProfileName")[0].text;
    dot = dot.replace(/ProfileName/g, ProfileName);
    var FilterChainManager = e.getElementsByTagName("FilterChainManager");
    dot = dot.replace(/FilterChainManager/,
        CnvFilterChainManagerToNode(FilterChainManager));
    var Effector = e.getElementsByTagName("Effector");
    dot = dot.replace(/Effector/, CnvEffectorToNode(Effector));
    var Renderer = e.getElementsByTagName("Renderer");
    dot = dot.replace(/Renderer/, CnvRendererToNode(Renderer));
    // DOTファイル出力
    var DotFilePath = XmlFilePath + ".dot";
    SaveToFile(DotFilePath, dot);
    // PNG画像生成
    var PngFilePath = XmlFilePath + ".png";
    shell.Run(('dot -Tpng ' + DotFilePath + ' -o ' + PngFilePath), 1, true);
    // PNG画像表示
    shell.Run(PngFilePath); 
  }
}

function CnvFilterChainManagerToNode(FilterChainManager) {
  var dot = '';
  for (var i = 0; i < FilterChainManager.length; i++) {
    var e = FilterChainManager[i];
    var ModuleNumber = e.getElementsByTagName("ModuleNumber")[0].text;
    var Thread = e.getElementsByTagName("Thread")[0].text;
    var In_Main1 = e.getElementsByTagName("In_Main1")[0].text;
    if (parseInt(In_Main1, 10)) {
      dot += '  In_Main1 [height = 0.3, width = 1, '
          + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
      dot += '  In_Main1 -> ' + ModuleNumber
          + ' [headlabel = "' + In_Main1 + '"];\n';
    }
    var In_Beep1 = e.getElementsByTagName("In_Beep1")[0].text;
    if (parseInt(In_Beep1, 10)) {
      dot += '  In_Beep1 [height = 0.3, width = 1, '
          + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
      dot += '  In_Beep1 -> ' + ModuleNumber
          + ' [headlabel = "' + In_Beep1 + '"];\n';
    }
    var In_Mic1 = e.getElementsByTagName("In_Mic1")[0].text;
    if (parseInt(In_Mic1, 10)) {
      dot += '  In_Mic1 [height = 0.3, width = 1, '
          + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
      dot += '  In_Mic1 -> ' + ModuleNumber
          + ' [headlabel = "' + In_Mic1 + '"];\n';
    }
    var In_Extra1 = e.getElementsByTagName("In_Extra1")[0].text;
    if (parseInt(In_Extra1, 10)) {
      dot += '  In_Extra1 [height = 0.3, width = 1, '
          + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
      dot += '  In_Extra1 -> ' + ModuleNumber
          + ' [headlabel = "' + In_Extra1 + '"];\n';
    }
    var In_Extra2 = e.getElementsByTagName("In_Extra2")[0].text;
    if (parseInt(In_Extra2, 10)) {
      dot += '  In_Extra2 [height = 0.3, width = 1, '
          + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
      dot += '  In_Extra2 -> ' + ModuleNumber
          + ' [headlabel = "' + In_Extra2 + '"];\n';
    }
    dot += '  ' + ModuleNumber + ' [label = "' + ModuleNumber
        + '\\nFilterChain\\nManager\\nT:' + Thread + '", '
        + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
    var OutputLine = e.getElementsByTagName("OutputLine");
    var ConnectTo = OutputLine[0].childNodes;
    dot += CnvConnectToEdge(ConnectTo, ModuleNumber);
  }
  return dot;
}

function CnvEffectorToNode(Effector) {
  var dot = '';
  for (var i = 0; i < Effector.length; i++) {
    var e = Effector[i];
    var ModuleNumber = e.getElementsByTagName("ModuleNumber")[0].text;
    var Group = e.getElementsByTagName("Group")[0].text;
    var Thread = e.getElementsByTagName("Thread")[0].text;
    var EffectorID = e.getElementsByTagName("EffectorID")[0].text;
    var EffectorName = e.getElementsByTagName("EffectorName")[0].text;
    dot += '  ' + ModuleNumber + ' [label = "' + ModuleNumber + '\\n'
        + EffectorName + '\\n' + EffectorID + '\\n'
        + 'G:' + Group + ' T:' + Thread + '", '
        + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
    var OutputLine = e.getElementsByTagName("OutputLine");
    var ConnectTo = OutputLine[0].childNodes;
    dot += CnvConnectToEdge(ConnectTo, ModuleNumber);
  }
  return dot;
}

function CnvRendererToNode(Renderer) {
  var dot = '';
  for (var i = 0; i < Renderer.length; i++) {
    var e = Renderer[i];
    var ModuleNumber = e.getElementsByTagName("ModuleNumber")[0].text;
    var Thread = e.getElementsByTagName("Thread")[0].text;
    dot += '  ' + ModuleNumber + ' [label = "' + ModuleNumber + '\\n'
        + 'Renderer\\n\\nT:' + Thread + '", '
        + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
    var OutputLine = e.getElementsByTagName("OutputLine");
    var ConnectTo = OutputLine[0].childNodes;
    dot += CnvRendererConnectToEdge(ConnectTo, ModuleNumber, Thread);
  }
  return dot;
}

function CnvConnectToEdge(ConnectTo, FromModuleNumber) {
  var dot = '';
  for (var i = 0; i < ConnectTo.length; i++) {
    var e = ConnectTo[i];
    var ModuleNumber = e.getElementsByTagName("ModuleNumber")[0].text;
    if (parseInt(ModuleNumber, 10)) {
      var PortNumber = e.getElementsByTagName("PortNumber")[0].text;
      dot += '  ' + FromModuleNumber + ' -> ' + ModuleNumber
          + ' [headlabel = "' + PortNumber + '", '
          + 'taillabel = "' + e.nodeName.slice(-1) + '"];\n';
    }
  }
  return dot;
}

function CnvRendererConnectToEdge(ConnectTo, FromModuleNumber, Thread) {
  var dot = '';
  for (var i = 0; i < ConnectTo.length; i++) {
    var e = ConnectTo[i];
    var HalNumber = e.getElementsByTagName("HalNumber")[0].text;
    if (parseInt(HalNumber, 10)) {
      var PortNumber = e.getElementsByTagName("PortNumber")[0].text;
      dot += '  ' + FromModuleNumber + ' -> HAL' + HalNumber
          + ' [headlabel = "' + PortNumber + '", '
          + 'taillabel = "' + e.nodeName.slice(-1) + '"];\n';
      dot += '  HAL' + HalNumber + ' [label = "' + HalNumber + '\\nHAL", '
          + 'height = 0.6, width = 0.6, '
          + 'fillcolor = ' + color[parseInt(Thread, 10)] + '];\n';
    }
  }
  return dot;
}

function SaveToFile(fname, text) {
  var f = fso.CreateTextFile(fname, true, false);
  f.Write(text);
  f.Close();
}
