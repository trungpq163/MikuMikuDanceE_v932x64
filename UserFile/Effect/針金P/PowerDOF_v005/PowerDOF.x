xof 0302txt 0064
template Header {
 <3D82AB43-62DA-11cf-AB39-0020AF71E433>
 WORD major;
 WORD minor;
 DWORD flags;
}

template Vector {
 <3D82AB5E-62DA-11cf-AB39-0020AF71E433>
 FLOAT x;
 FLOAT y;
 FLOAT z;
}

template Coords2d {
 <F6F23F44-7686-11cf-8F52-0040333594A3>
 FLOAT u;
 FLOAT v;
}

template Matrix4x4 {
 <F6F23F45-7686-11cf-8F52-0040333594A3>
 array FLOAT matrix[16];
}

template ColorRGBA {
 <35FF44E0-6C7C-11cf-8F52-0040333594A3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
 FLOAT alpha;
}

template ColorRGB {
 <D3E16E81-7835-11cf-8F52-0040333594A3>
 FLOAT red;
 FLOAT green;
 FLOAT blue;
}

template IndexedColor {
 <1630B820-7842-11cf-8F52-0040333594A3>
 DWORD index;
 ColorRGBA indexColor;
}

template Boolean {
 <4885AE61-78E8-11cf-8F52-0040333594A3>
 WORD truefalse;
}

template Boolean2d {
 <4885AE63-78E8-11cf-8F52-0040333594A3>
 Boolean u;
 Boolean v;
}

template MaterialWrap {
 <4885AE60-78E8-11cf-8F52-0040333594A3>
 Boolean u;
 Boolean v;
}

template TextureFilename {
 <A42790E1-7810-11cf-8F52-0040333594A3>
 STRING filename;
}

template Material {
 <3D82AB4D-62DA-11cf-AB39-0020AF71E433>
 ColorRGBA faceColor;
 FLOAT power;
 ColorRGB specularColor;
 ColorRGB emissiveColor;
 [...]
}

template MeshFace {
 <3D82AB5F-62DA-11cf-AB39-0020AF71E433>
 DWORD nFaceVertexIndices;
 array DWORD faceVertexIndices[nFaceVertexIndices];
}

template MeshFaceWraps {
 <4885AE62-78E8-11cf-8F52-0040333594A3>
 DWORD nFaceWrapValues;
 Boolean2d faceWrapValues;
}

template MeshTextureCoords {
 <F6F23F40-7686-11cf-8F52-0040333594A3>
 DWORD nTextureCoords;
 array Coords2d textureCoords[nTextureCoords];
}

template MeshMaterialList {
 <F6F23F42-7686-11cf-8F52-0040333594A3>
 DWORD nMaterials;
 DWORD nFaceIndexes;
 array DWORD faceIndexes[nFaceIndexes];
 [Material]
}

template MeshNormals {
 <F6F23F43-7686-11cf-8F52-0040333594A3>
 DWORD nNormals;
 array Vector normals[nNormals];
 DWORD nFaceNormals;
 array MeshFace faceNormals[nFaceNormals];
}

template MeshVertexColors {
 <1630B821-7842-11cf-8F52-0040333594A3>
 DWORD nVertexColors;
 array IndexedColor vertexColors[nVertexColors];
}

template Mesh {
 <3D82AB44-62DA-11cf-AB39-0020AF71E433>
 DWORD nVertices;
 array Vector vertices[nVertices];
 DWORD nFaces;
 array MeshFace faces[nFaces];
 [...]
}

Header{
1;
0;
1;
}

Mesh {
 168;
 0.50000;0.00000;-0.00000;,
 0.50000;-0.02165;-0.01250;,
 0.50000;0.00000;-0.02500;,
 0.50000;0.00000;-0.00000;,
 0.50000;-0.02165;0.01250;,
 0.50000;0.00000;-0.00000;,
 0.50000;-0.00000;0.02500;,
 0.50000;0.00000;-0.00000;,
 0.50000;0.02165;0.01250;,
 0.50000;0.00000;-0.00000;,
 0.50000;0.02165;-0.01250;,
 0.50000;0.00000;-0.00000;,
 0.50000;0.00000;-0.02500;,
 -0.50000;0.00000;0.00000;,
 -0.50000;0.00000;-0.02500;,
 -0.50000;-0.02165;-0.01250;,
 -0.50000;0.00000;0.00000;,
 -0.50000;-0.02165;0.01250;,
 -0.50000;0.00000;0.00000;,
 -0.50000;0.00000;0.02500;,
 -0.50000;0.00000;0.00000;,
 -0.50000;0.02165;0.01250;,
 -0.50000;0.00000;0.00000;,
 -0.50000;0.02165;-0.01250;,
 -0.50000;0.00000;0.00000;,
 -0.50000;0.00000;-0.02500;,
 0.00000;0.00000;0.00000;,
 -0.50000;-0.02165;-0.01250;,
 0.50000;0.00000;-0.02500;,
 0.00000;0.00000;0.00000;,
 -0.50000;-0.02165;0.01250;,
 0.50000;-0.02165;-0.01250;,
 0.00000;0.00000;0.00000;,
 -0.50000;0.00000;0.02500;,
 0.50000;-0.02165;0.01250;,
 0.00000;0.00000;0.00000;,
 -0.50000;0.02165;0.01250;,
 0.50000;-0.00000;0.02500;,
 0.00000;0.00000;0.00000;,
 -0.50000;0.02165;-0.01250;,
 0.50000;0.02165;0.01250;,
 0.00000;0.00000;0.00000;,
 -0.50000;0.00000;-0.02500;,
 0.50000;0.02165;-0.01250;,
 0.50000;-0.02165;-0.01250;,
 -0.50000;0.00000;-0.02500;,
 0.50000;-0.02165;0.01250;,
 -0.50000;-0.02165;-0.01250;,
 0.50000;-0.00000;0.02500;,
 -0.50000;-0.02165;0.01250;,
 0.50000;0.02165;0.01250;,
 -0.50000;0.00000;0.02500;,
 0.50000;0.02165;-0.01250;,
 -0.50000;0.02165;0.01250;,
 0.50000;0.00000;-0.02500;,
 -0.50000;0.02165;-0.01250;,
 0.00000;0.50000;0.00000;,
 0.02165;0.50000;-0.01250;,
 0.00000;0.50000;-0.02500;,
 0.00000;0.50000;0.00000;,
 0.02165;0.50000;0.01250;,
 0.00000;0.50000;0.00000;,
 0.00000;0.50000;0.02500;,
 0.00000;0.50000;0.00000;,
 -0.02165;0.50000;0.01250;,
 0.00000;0.50000;0.00000;,
 -0.02165;0.50000;-0.01250;,
 0.00000;0.50000;0.00000;,
 0.00000;0.50000;-0.02500;,
 0.00000;-0.50000;0.00000;,
 0.00000;-0.50000;-0.02500;,
 0.02165;-0.50000;-0.01250;,
 0.00000;-0.50000;0.00000;,
 0.02165;-0.50000;0.01250;,
 0.00000;-0.50000;0.00000;,
 -0.00000;-0.50000;0.02500;,
 0.00000;-0.50000;0.00000;,
 -0.02165;-0.50000;0.01250;,
 0.00000;-0.50000;0.00000;,
 -0.02165;-0.50000;-0.01250;,
 0.00000;-0.50000;0.00000;,
 0.00000;-0.50000;-0.02500;,
 0.00000;0.00000;0.00000;,
 0.02165;-0.50000;-0.01250;,
 0.00000;0.50000;-0.02500;,
 0.00000;0.00000;0.00000;,
 0.02165;-0.50000;0.01250;,
 0.02165;0.50000;-0.01250;,
 0.00000;0.00000;0.00000;,
 -0.00000;-0.50000;0.02500;,
 0.02165;0.50000;0.01250;,
 0.00000;0.00000;0.00000;,
 -0.02165;-0.50000;0.01250;,
 0.00000;0.50000;0.02500;,
 0.00000;0.00000;0.00000;,
 -0.02165;-0.50000;-0.01250;,
 -0.02165;0.50000;0.01250;,
 0.00000;0.00000;0.00000;,
 0.00000;-0.50000;-0.02500;,
 -0.02165;0.50000;-0.01250;,
 0.02165;0.50000;-0.01250;,
 0.00000;-0.50000;-0.02500;,
 0.02165;0.50000;0.01250;,
 0.02165;-0.50000;-0.01250;,
 0.00000;0.50000;0.02500;,
 0.02165;-0.50000;0.01250;,
 -0.02165;0.50000;0.01250;,
 -0.00000;-0.50000;0.02500;,
 -0.02165;0.50000;-0.01250;,
 -0.02165;-0.50000;0.01250;,
 0.00000;0.50000;-0.02500;,
 -0.02165;-0.50000;-0.01250;,
 0.00000;0.00000;-0.50000;,
 -0.01250;-0.02165;-0.50000;,
 -0.02500;0.00000;-0.50000;,
 0.00000;0.00000;-0.50000;,
 0.01250;-0.02165;-0.50000;,
 0.00000;0.00000;-0.50000;,
 0.02500;0.00000;-0.50000;,
 0.00000;0.00000;-0.50000;,
 0.01250;0.02165;-0.50000;,
 0.00000;0.00000;-0.50000;,
 -0.01250;0.02165;-0.50000;,
 0.00000;0.00000;-0.50000;,
 -0.02500;0.00000;-0.50000;,
 0.00000;0.00000;0.50000;,
 -0.02500;0.00000;0.50000;,
 -0.01250;-0.02165;0.50000;,
 0.00000;0.00000;0.50000;,
 0.01250;-0.02165;0.50000;,
 0.00000;0.00000;0.50000;,
 0.02500;0.00000;0.50000;,
 0.00000;0.00000;0.50000;,
 0.01250;0.02165;0.50000;,
 0.00000;0.00000;0.50000;,
 -0.01250;0.02165;0.50000;,
 0.00000;0.00000;0.50000;,
 -0.02500;0.00000;0.50000;,
 0.00000;0.00000;0.00000;,
 -0.01250;-0.02165;0.50000;,
 -0.02500;0.00000;-0.50000;,
 0.00000;0.00000;0.00000;,
 0.01250;-0.02165;0.50000;,
 -0.01250;-0.02165;-0.50000;,
 0.00000;0.00000;0.00000;,
 0.02500;0.00000;0.50000;,
 0.01250;-0.02165;-0.50000;,
 0.00000;0.00000;0.00000;,
 0.01250;0.02165;0.50000;,
 0.02500;0.00000;-0.50000;,
 0.00000;0.00000;0.00000;,
 -0.01250;0.02165;0.50000;,
 0.01250;0.02165;-0.50000;,
 0.00000;0.00000;0.00000;,
 -0.02500;0.00000;0.50000;,
 -0.01250;0.02165;-0.50000;,
 -0.01250;-0.02165;-0.50000;,
 -0.02500;0.00000;0.50000;,
 0.01250;-0.02165;-0.50000;,
 -0.01250;-0.02165;0.50000;,
 0.02500;0.00000;-0.50000;,
 0.01250;-0.02165;0.50000;,
 0.01250;0.02165;-0.50000;,
 0.02500;0.00000;0.50000;,
 -0.01250;0.02165;-0.50000;,
 0.01250;0.02165;0.50000;,
 -0.02500;0.00000;-0.50000;,
 -0.01250;0.02165;0.50000;;
 
 144;
 3;0,1,2;,
 3;3,4,1;,
 3;5,6,4;,
 3;7,8,6;,
 3;9,10,8;,
 3;11,12,10;,
 3;13,14,15;,
 3;16,15,17;,
 3;18,17,19;,
 3;20,19,21;,
 3;22,21,23;,
 3;24,23,25;,
 3;2,1,0;,
 3;1,4,3;,
 3;4,6,5;,
 3;6,8,7;,
 3;8,10,9;,
 3;10,12,11;,
 3;15,14,13;,
 3;17,15,16;,
 3;19,17,18;,
 3;21,19,20;,
 3;23,21,22;,
 3;25,23,24;,
 3;26,27,14;,
 3;26,28,1;,
 3;29,30,15;,
 3;29,31,4;,
 3;32,33,17;,
 3;32,34,6;,
 3;35,36,19;,
 3;35,37,8;,
 3;38,39,21;,
 3;38,40,10;,
 3;41,42,23;,
 3;41,43,12;,
 3;26,44,2;,
 3;26,45,15;,
 3;29,46,1;,
 3;29,47,17;,
 3;32,48,4;,
 3;32,49,19;,
 3;35,50,6;,
 3;35,51,21;,
 3;38,52,8;,
 3;38,53,23;,
 3;41,54,10;,
 3;41,55,25;,
 3;56,57,58;,
 3;59,60,57;,
 3;61,62,60;,
 3;63,64,62;,
 3;65,66,64;,
 3;67,68,66;,
 3;69,70,71;,
 3;72,71,73;,
 3;74,73,75;,
 3;76,75,77;,
 3;78,77,79;,
 3;80,79,81;,
 3;58,57,56;,
 3;57,60,59;,
 3;60,62,61;,
 3;62,64,63;,
 3;64,66,65;,
 3;66,68,67;,
 3;71,70,69;,
 3;73,71,72;,
 3;75,73,74;,
 3;77,75,76;,
 3;79,77,78;,
 3;81,79,80;,
 3;82,83,70;,
 3;82,84,57;,
 3;85,86,71;,
 3;85,87,60;,
 3;88,89,73;,
 3;88,90,62;,
 3;91,92,75;,
 3;91,93,64;,
 3;94,95,77;,
 3;94,96,66;,
 3;97,98,79;,
 3;97,99,68;,
 3;82,100,58;,
 3;82,101,71;,
 3;85,102,57;,
 3;85,103,73;,
 3;88,104,60;,
 3;88,105,75;,
 3;91,106,62;,
 3;91,107,77;,
 3;94,108,64;,
 3;94,109,79;,
 3;97,110,66;,
 3;97,111,81;,
 3;112,113,114;,
 3;115,116,113;,
 3;117,118,116;,
 3;119,120,118;,
 3;121,122,120;,
 3;123,124,122;,
 3;125,126,127;,
 3;128,127,129;,
 3;130,129,131;,
 3;132,131,133;,
 3;134,133,135;,
 3;136,135,137;,
 3;114,113,112;,
 3;113,116,115;,
 3;116,118,117;,
 3;118,120,119;,
 3;120,122,121;,
 3;122,124,123;,
 3;127,126,125;,
 3;129,127,128;,
 3;131,129,130;,
 3;133,131,132;,
 3;135,133,134;,
 3;137,135,136;,
 3;138,139,126;,
 3;138,140,113;,
 3;141,142,127;,
 3;141,143,116;,
 3;144,145,129;,
 3;144,146,118;,
 3;147,148,131;,
 3;147,149,120;,
 3;150,151,133;,
 3;150,152,122;,
 3;153,154,135;,
 3;153,155,124;,
 3;138,156,114;,
 3;138,157,127;,
 3;141,158,113;,
 3;141,159,129;,
 3;144,160,116;,
 3;144,161,131;,
 3;147,162,118;,
 3;147,163,133;,
 3;150,164,120;,
 3;150,165,135;,
 3;153,166,122;,
 3;153,167,137;;
 
 MeshMaterialList {
  4;
  144;
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  3,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  1,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2,
  2;;
  Material {
   0.800000;0.000000;0.037600;0.600000;;
   5.000000;
   0.000000;0.000000;0.000000;;
   0.000000;0.000000;0.000000;;
  }
  Material {
   0.153600;0.800000;0.000000;0.600000;;
   5.000000;
   0.000000;0.000000;0.000000;;
   0.000000;0.000000;0.000000;;
  }
  Material {
   0.000000;0.021600;0.800000;0.600000;;
   5.000000;
   0.000000;0.000000;0.000000;;
   0.000000;0.000000;0.000000;;
  }
  Material {
   1.000000;1.000000;1.000000;1.000000;;
   0.000000;
   0.000000;0.000000;0.000000;;
   0.000000;0.000000;0.000000;;
  }
 }
 MeshNormals {
  60;
  1.000000;0.000000;0.000000;,
  -1.000000;0.000000;0.000000;,
  0.000000;-0.499994;-0.866029;,
  0.043261;-0.499526;-0.865218;,
  -0.043261;-0.499526;-0.865218;,
  0.000000;-1.000000;-0.000000;,
  0.043261;-0.999064;-0.000000;,
  -0.043261;-0.999064;0.000000;,
  0.000000;-0.499994;0.866029;,
  0.043261;-0.499526;0.865218;,
  -0.043261;-0.499526;0.865218;,
  0.000000;0.499994;0.866029;,
  0.043261;0.499526;0.865218;,
  -0.043261;0.499526;0.865218;,
  0.000000;1.000000;0.000000;,
  0.043261;0.999064;0.000000;,
  -0.043261;0.999064;0.000000;,
  0.000000;0.499994;-0.866029;,
  0.043261;0.499526;-0.865218;,
  -0.043261;0.499526;-0.865218;,
  0.000000;1.000000;0.000000;,
  0.000000;-1.000000;0.000000;,
  0.499994;0.000000;-0.866029;,
  0.499526;0.043261;-0.865218;,
  0.499526;-0.043261;-0.865218;,
  1.000000;0.000000;0.000000;,
  0.999064;0.043261;0.000000;,
  0.999064;-0.043261;-0.000000;,
  0.499994;0.000000;0.866029;,
  0.499526;0.043261;0.865218;,
  0.499526;-0.043261;0.865218;,
  -0.499994;0.000000;0.866029;,
  -0.499526;0.043261;0.865218;,
  -0.499526;-0.043261;0.865218;,
  -1.000000;0.000000;0.000000;,
  -0.999064;0.043261;0.000000;,
  -0.999064;-0.043261;0.000000;,
  -0.499994;0.000000;-0.866029;,
  -0.499526;0.043261;-0.865218;,
  -0.499526;-0.043261;-0.865218;,
  0.000000;0.000000;-1.000000;,
  0.000000;0.000000;1.000000;,
  -0.866029;-0.499994;0.000000;,
  -0.865218;-0.499526;-0.043261;,
  -0.865218;-0.499526;0.043261;,
  0.000000;-1.000000;-0.000000;,
  0.000000;-0.999064;-0.043261;,
  -0.000000;-0.999064;0.043261;,
  0.866029;-0.499994;-0.000000;,
  0.865218;-0.499526;-0.043261;,
  0.865218;-0.499526;0.043261;,
  0.866029;0.499994;0.000000;,
  0.865218;0.499526;-0.043261;,
  0.865218;0.499526;0.043261;,
  0.000000;1.000000;0.000000;,
  0.000000;0.999064;-0.043261;,
  0.000000;0.999064;0.043261;,
  -0.866029;0.499994;0.000000;,
  -0.865218;0.499526;-0.043261;,
  -0.865218;0.499526;0.043261;;
  144;
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;1,1,1;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;0,0,0;,
  3;2,3,3;,
  3;2,4,4;,
  3;5,6,6;,
  3;5,7,7;,
  3;8,9,9;,
  3;8,10,10;,
  3;11,12,12;,
  3;11,13,13;,
  3;14,15,15;,
  3;14,16,16;,
  3;17,18,18;,
  3;17,19,19;,
  3;11,12,12;,
  3;11,13,13;,
  3;14,15,15;,
  3;14,16,16;,
  3;17,18,18;,
  3;17,19,19;,
  3;2,3,3;,
  3;2,4,4;,
  3;5,6,6;,
  3;5,7,7;,
  3;8,9,9;,
  3;8,10,10;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;21,21,21;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;20,20,20;,
  3;22,23,23;,
  3;22,24,24;,
  3;25,26,26;,
  3;25,27,27;,
  3;28,29,29;,
  3;28,30,30;,
  3;31,32,32;,
  3;31,33,33;,
  3;34,35,35;,
  3;34,36,36;,
  3;37,38,38;,
  3;37,39,39;,
  3;31,32,32;,
  3;31,33,33;,
  3;34,35,35;,
  3;34,36,36;,
  3;37,38,38;,
  3;37,39,39;,
  3;22,23,23;,
  3;22,24,24;,
  3;25,26,26;,
  3;25,27,27;,
  3;28,29,29;,
  3;28,30,30;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;41,41,41;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;40,40,40;,
  3;42,43,43;,
  3;42,44,44;,
  3;45,46,46;,
  3;45,47,47;,
  3;48,49,49;,
  3;48,50,50;,
  3;51,52,52;,
  3;51,53,53;,
  3;54,55,55;,
  3;54,56,56;,
  3;57,58,58;,
  3;57,59,59;,
  3;51,52,52;,
  3;51,53,53;,
  3;54,55,55;,
  3;54,56,56;,
  3;57,58,58;,
  3;57,59,59;,
  3;42,43,43;,
  3;42,44,44;,
  3;45,46,46;,
  3;45,47,47;,
  3;48,49,49;,
  3;48,50,50;;
 }
 MeshTextureCoords {
  168;
  0.083330;0.000000;,
  0.166670;0.000000;,
  0.000000;0.000000;,
  0.250000;0.000000;,
  0.333330;0.000000;,
  0.416670;0.000000;,
  0.500000;0.000000;,
  0.583330;0.000000;,
  0.666670;0.000000;,
  0.750000;0.000000;,
  0.833330;0.000000;,
  0.916670;0.000000;,
  1.000000;0.000000;,
  0.083330;1.000000;,
  0.000000;1.000000;,
  0.166670;1.000000;,
  0.250000;1.000000;,
  0.333330;1.000000;,
  0.416670;1.000000;,
  0.500000;1.000000;,
  0.583330;1.000000;,
  0.666670;1.000000;,
  0.750000;1.000000;,
  0.833330;1.000000;,
  0.916670;1.000000;,
  1.000000;1.000000;,
  0.083335;0.493358;,
  0.083335;0.746640;,
  0.000000;0.246640;,
  0.250000;0.493594;,
  0.250000;0.746718;,
  0.166670;0.246718;,
  0.416665;0.493830;,
  0.416665;0.746876;,
  0.333330;0.246876;,
  0.583335;0.493830;,
  0.583335;0.746954;,
  0.500000;0.246954;,
  0.750000;0.493594;,
  0.750000;0.746876;,
  0.666670;0.246876;,
  0.916665;0.493358;,
  0.916665;0.746718;,
  0.833330;0.246718;,
  0.083335;0.246640;,
  0.000000;0.746640;,
  0.250000;0.246718;,
  0.166670;0.746718;,
  0.416665;0.246876;,
  0.333330;0.746876;,
  0.583335;0.246954;,
  0.500000;0.746954;,
  0.750000;0.246876;,
  0.666670;0.746876;,
  0.916665;0.246718;,
  0.833330;0.746718;,
  0.083330;0.000000;,
  0.166670;0.000000;,
  0.000000;0.000000;,
  0.250000;0.000000;,
  0.333330;0.000000;,
  0.416670;0.000000;,
  0.500000;0.000000;,
  0.583330;0.000000;,
  0.666670;0.000000;,
  0.750000;0.000000;,
  0.833330;0.000000;,
  0.916670;0.000000;,
  1.000000;0.000000;,
  0.083330;1.000000;,
  0.000000;1.000000;,
  0.166670;1.000000;,
  0.250000;1.000000;,
  0.333330;1.000000;,
  0.416670;1.000000;,
  0.500000;1.000000;,
  0.583330;1.000000;,
  0.666670;1.000000;,
  0.750000;1.000000;,
  0.833330;1.000000;,
  0.916670;1.000000;,
  1.000000;1.000000;,
  0.083335;0.503213;,
  0.083335;0.751562;,
  0.000000;0.251562;,
  0.250000;0.503477;,
  0.250000;0.751650;,
  0.166670;0.251650;,
  0.416665;0.503741;,
  0.416665;0.751826;,
  0.333330;0.251826;,
  0.583335;0.503741;,
  0.583335;0.751915;,
  0.500000;0.251915;,
  0.750000;0.503477;,
  0.750000;0.751826;,
  0.666670;0.251826;,
  0.916665;0.503213;,
  0.916665;0.751650;,
  0.833330;0.251650;,
  0.083335;0.251562;,
  0.000000;0.751562;,
  0.250000;0.251650;,
  0.166670;0.751650;,
  0.416665;0.251826;,
  0.333330;0.751826;,
  0.583335;0.251915;,
  0.500000;0.751915;,
  0.750000;0.251826;,
  0.666670;0.751826;,
  0.916665;0.251650;,
  0.833330;0.751650;,
  0.083330;0.000000;,
  0.166670;0.000000;,
  0.000000;0.000000;,
  0.250000;0.000000;,
  0.333330;0.000000;,
  0.416670;0.000000;,
  0.500000;0.000000;,
  0.583330;0.000000;,
  0.666670;0.000000;,
  0.750000;0.000000;,
  0.833330;0.000000;,
  0.916670;0.000000;,
  1.000000;0.000000;,
  0.083330;1.000000;,
  0.000000;1.000000;,
  0.166670;1.000000;,
  0.250000;1.000000;,
  0.333330;1.000000;,
  0.416670;1.000000;,
  0.500000;1.000000;,
  0.583330;1.000000;,
  0.666670;1.000000;,
  0.750000;1.000000;,
  0.833330;1.000000;,
  0.916670;1.000000;,
  1.000000;1.000000;,
  0.083335;0.498865;,
  0.083335;0.749401;,
  0.000000;0.249401;,
  0.250000;0.498929;,
  0.250000;0.749465;,
  0.166670;0.249464;,
  0.416665;0.498865;,
  0.416665;0.749465;,
  0.333330;0.249464;,
  0.583335;0.498738;,
  0.583335;0.749401;,
  0.500000;0.249401;,
  0.750000;0.498674;,
  0.750000;0.749337;,
  0.666670;0.249337;,
  0.916665;0.498738;,
  0.916665;0.749337;,
  0.833330;0.249337;,
  0.083335;0.249401;,
  0.000000;0.749401;,
  0.250000;0.249464;,
  0.166670;0.749465;,
  0.416665;0.249464;,
  0.333330;0.749465;,
  0.583335;0.249401;,
  0.500000;0.749401;,
  0.750000;0.249337;,
  0.666670;0.749337;,
  0.916665;0.249337;,
  0.833330;0.749337;;
 }
}
